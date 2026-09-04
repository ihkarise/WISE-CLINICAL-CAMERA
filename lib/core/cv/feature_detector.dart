import 'dart:math' as math;
import 'dart:typed_data';

import 'alignment_config.dart';
import 'keypoint.dart';
import 'working_image.dart';

/// A corner located on one pyramid level, before it is oriented and described.
class _LevelCorner {
  const _LevelCorner(this.x, this.y, this.score, this.level);
  final int x;
  final int y;
  final int score;
  final int level;
}

/// FAST corner detection over a scale pyramid, with intensity-centroid
/// orientation and rotated BRIEF descriptors — the ORB-style stack CV section
/// 72 recommends for V1.
///
/// Implemented in pure Dart rather than bound to a native CV library. The
/// reasoning, weighed against the dependency checklist in Build Specification
/// section 5, is recorded in SPECIFICATION_CONFLICTS C-013; the short version
/// is that it runs in `flutter test` with no device, which is the only way the
/// CV regression and false-confidence suites can actually execute.
///
/// It sits behind `AlignmentEngine`, so a native implementation can replace it
/// after benchmarking without touching a single caller (CV sections 74-75).
///
/// ## Why the pyramid
///
/// A BRIEF descriptor samples a fixed-size patch, so it is not scale-invariant:
/// the same corner photographed from 20% further away produces a different
/// descriptor and stops matching. Without a pyramid the engine would fail
/// exactly when the clinician is standing at the wrong distance, which is the
/// case the "Move closer" and "Move farther away" guidance exists to fix
/// (CV section 19). Detecting on progressively downsampled copies and
/// describing each keypoint at its own level makes matching survive a change
/// in subject size.
class FeatureDetector {
  const FeatureDetector([this.config = const AlignmentConfig()]);

  final AlignmentConfig config;

  /// Offsets of the 16-pixel Bresenham circle of radius 3 used by FAST.
  static const List<(int, int)> _circle = <(int, int)>[
    (0, -3),
    (1, -3),
    (2, -2),
    (3, -1),
    (3, 0),
    (3, 1),
    (2, 2),
    (1, 3),
    (0, 3),
    (-1, 3),
    (-2, 2),
    (-3, 1),
    (-3, 0),
    (-3, -1),
    (-2, -2),
    (-1, -3),
  ];

  /// Detects corners across the pyramid, orients them and computes descriptors.
  ///
  /// Keypoint coordinates are returned in level-0 (working image) space so the
  /// transform estimator sees one consistent coordinate system.
  ({List<Keypoint> keypoints, List<Descriptor> descriptors}) detect(
    WorkingImage image,
  ) {
    final levels = buildPyramid(image);
    final border = math.max(config.descriptorPatchRadius, 3) + 1;

    final corners = <_LevelCorner>[];
    for (var level = 0; level < levels.length; level++) {
      final levelImage = levels[level];
      if (levelImage.width <= border * 2 || levelImage.height <= border * 2) {
        continue;
      }
      final found = _detectCorners(levelImage, border, level);
      corners.addAll(_suppressNonMaxima(found, levelImage));
    }

    if (corners.isEmpty) {
      return (keypoints: const <Keypoint>[], descriptors: const <Descriptor>[]);
    }

    // Rank across every level together, so a strong coarse-level corner can
    // beat a weak fine-level one rather than levels competing for fixed quotas.
    corners.sort((a, b) => b.score.compareTo(a.score));
    final selected = corners.length > config.maxKeypoints
        ? corners.sublist(0, config.maxKeypoints)
        : corners;

    final keypoints = <Keypoint>[];
    final descriptors = <Descriptor>[];

    for (final corner in selected) {
      final levelImage = levels[corner.level];
      final levelScale = image.width / levelImage.width;
      final angle = _orientation(levelImage, corner.x, corner.y);

      keypoints.add(
        Keypoint(
          // Half-pixel offset keeps the mapping centred: level pixel n covers
          // level-0 pixels [n*s, (n+1)*s).
          x: (corner.x + 0.5) * levelScale - 0.5,
          y: (corner.y + 0.5) * levelScale - 0.5,
          score: corner.score,
          angle: angle,
          levelScale: levelScale,
        ),
      );
      // Described on its own level, which is what carries the scale
      // invariance.
      descriptors.add(_describe(levelImage, corner.x, corner.y, angle));
    }

    return (keypoints: keypoints, descriptors: descriptors);
  }

  /// Builds the detection pyramid, base level first.
  List<WorkingImage> buildPyramid(WorkingImage image) {
    final levels = <WorkingImage>[image];
    var current = image;

    for (var level = 1; level < config.pyramidLevels; level++) {
      final width = (current.width / config.pyramidScaleFactor).round();
      final height = (current.height / config.pyramidScaleFactor).round();
      if (width < config.minPyramidDimension ||
          height < config.minPyramidDimension) {
        break;
      }
      current = current.downsampled(width, height);
      levels.add(current);
    }
    return levels;
  }

  List<_LevelCorner> _detectCorners(WorkingImage image, int border, int level) {
    final corners = <_LevelCorner>[];
    final threshold = config.fastThreshold;

    for (var y = border; y < image.height - border; y++) {
      for (var x = border; x < image.width - border; x++) {
        final centre = image.at(x, y);

        // Cheap rejection on the four compass points: a real corner needs at
        // least three of them to differ from the centre. Skips the great
        // majority of pixels before the full 16-point test.
        var brightCompass = 0;
        var darkCompass = 0;
        for (final index in const [0, 4, 8, 12]) {
          final (dx, dy) = _circle[index];
          final value = image.at(x + dx, y + dy);
          if (value > centre + threshold) brightCompass++;
          if (value < centre - threshold) darkCompass++;
        }
        if (brightCompass < 3 && darkCompass < 3) continue;

        final score = _cornerScore(image, x, y, centre, threshold);
        if (score > 0) corners.add(_LevelCorner(x, y, score, level));
      }
    }
    return corners;
  }

  /// Returns the corner strength, or 0 if this is not a corner.
  ///
  /// A corner requires [AlignmentConfig.fastContiguous] consecutive circle
  /// pixels all brighter or all darker than the centre by the threshold. The
  /// circle is scanned twice to handle arcs that wrap past index 15.
  int _cornerScore(
    WorkingImage image,
    int x,
    int y,
    int centre,
    int threshold,
  ) {
    final values = Int16List(16);
    for (var i = 0; i < 16; i++) {
      final (dx, dy) = _circle[i];
      values[i] = image.at(x + dx, y + dy);
    }

    var brightRun = 0;
    var darkRun = 0;
    var bestBright = 0;
    var bestDark = 0;

    for (var i = 0; i < 32; i++) {
      final value = values[i & 15];
      if (value > centre + threshold) {
        brightRun++;
        darkRun = 0;
      } else if (value < centre - threshold) {
        darkRun++;
        brightRun = 0;
      } else {
        brightRun = 0;
        darkRun = 0;
      }
      bestBright = math.max(bestBright, brightRun);
      bestDark = math.max(bestDark, darkRun);
      if (bestBright >= 16 || bestDark >= 16) break;
    }

    if (bestBright < config.fastContiguous &&
        bestDark < config.fastContiguous) {
      return 0;
    }

    // Strength: total absolute deviation across the circle. Ranking by this
    // keeps the most distinctive corners when the cap is applied.
    var strength = 0;
    for (var i = 0; i < 16; i++) {
      strength += (values[i] - centre).abs();
    }
    return strength;
  }

  /// Keeps only the strongest corner in each neighbourhood, per level.
  ///
  /// Without this, a single strong edge produces a dense line of keypoints,
  /// which is exactly the spatially concentrated distribution CV section 23
  /// warns cannot constrain a transform.
  List<_LevelCorner> _suppressNonMaxima(
    List<_LevelCorner> corners,
    WorkingImage image,
  ) {
    if (corners.isEmpty) return corners;
    final radius = config.nonMaxSuppressionRadius;

    // Sparse score grid for O(1) neighbourhood lookups.
    final scores = <int, int>{};
    for (final corner in corners) {
      scores[corner.y * image.width + corner.x] = corner.score;
    }

    final kept = <_LevelCorner>[];
    for (final corner in corners) {
      var isMaximum = true;
      for (var dy = -radius; dy <= radius && isMaximum; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (dx == 0 && dy == 0) continue;
          final neighbour =
              scores[(corner.y + dy) * image.width + (corner.x + dx)];
          if (neighbour != null && neighbour > corner.score) {
            isMaximum = false;
            break;
          }
        }
      }
      if (isMaximum) kept.add(corner);
    }
    return kept;
  }

  /// Intensity-centroid orientation (CV section 13).
  ///
  /// The vector from the patch centre to its intensity centroid gives a
  /// repeatable angle, which lets the descriptor be sampled in a rotated frame
  /// so matching survives camera roll.
  double _orientation(WorkingImage image, int x, int y) {
    final radius = config.descriptorPatchRadius;
    var m01 = 0.0;
    var m10 = 0.0;

    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > radius * radius) continue;
        final value = image.atClamped(x + dx, y + dy);
        m10 += dx * value;
        m01 += dy * value;
      }
    }
    return math.atan2(m01, m10);
  }

  /// Rotated BRIEF descriptor, sampled on the keypoint's own pyramid level.
  ///
  /// Compares 256 fixed point pairs, each rotated by the keypoint's angle. The
  /// pattern is generated once from a fixed seed so descriptors are stable
  /// across runs, devices and app versions — a descriptor computed today must
  /// match one computed against a Before photograph taken months ago.
  Descriptor _describe(WorkingImage image, int x, int y, double angle) {
    final bits = Uint8List(Descriptor.lengthBytes);
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final pattern = _pattern(config.descriptorPatchRadius);

    for (var i = 0; i < Descriptor.lengthBits; i++) {
      final (ax, ay, bx, by) = pattern[i];

      final rax = (ax * cos - ay * sin).round();
      final ray = (ax * sin + ay * cos).round();
      final rbx = (bx * cos - by * sin).round();
      final rby = (bx * sin + by * cos).round();

      final first = image.atClamped(x + rax, y + ray);
      final second = image.atClamped(x + rbx, y + rby);

      if (first < second) bits[i >> 3] |= 1 << (i & 7);
    }
    return Descriptor(bits);
  }

  static final Map<int, List<(int, int, int, int)>> _patternCache = {};

  /// The BRIEF sampling pattern for a given patch radius.
  ///
  /// Deterministic: a fixed LCG seed, cached per radius. Two builds of the app
  /// must produce identical descriptors or historical references stop matching.
  static List<(int, int, int, int)> _pattern(int radius) =>
      _patternCache.putIfAbsent(radius, () {
        var state = 0x5EED1234;
        int next(int bound) {
          state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
          return (state >> 8) % bound;
        }

        final span = radius * 2 + 1;
        return List<(int, int, int, int)>.generate(
          Descriptor.lengthBits,
          (_) => (
            next(span) - radius,
            next(span) - radius,
            next(span) - radius,
            next(span) - radius,
          ),
          growable: false,
        );
      });
}
