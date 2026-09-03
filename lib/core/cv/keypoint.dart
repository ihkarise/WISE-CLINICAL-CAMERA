import 'dart:typed_data';

/// A detected corner with orientation and a binary descriptor.
class Keypoint {
  const Keypoint({
    required this.x,
    required this.y,
    required this.score,
    this.angle = 0,
    this.levelScale = 1,
  });

  /// Position in **level-0 (working image) coordinates**, so keypoints found on
  /// different pyramid levels are directly comparable.
  final double x;
  final double y;

  /// Corner strength from the FAST score. Used to rank keypoints when more are
  /// found than [AlignmentConfig.maxKeypoints] allows.
  final int score;

  /// Intensity-centroid orientation in radians, which is what makes the BRIEF
  /// descriptor rotation-aware (the "R" in ORB).
  final double angle;

  /// Level-0 pixels per pixel of the pyramid level this keypoint was found on.
  /// 1 for the base level, larger for coarser levels.
  final double levelScale;
}

/// A 256-bit binary descriptor, packed into 32 bytes.
class Descriptor {
  Descriptor(this.bits);

  /// 32 bytes = 256 bits.
  final Uint8List bits;

  static const int lengthBytes = 32;
  static const int lengthBits = 256;

  /// Hamming distance: the number of differing bits.
  ///
  /// Uses a popcount table rather than a bit loop because this runs
  /// O(reference keypoints x frame keypoints) times per frame and is the
  /// single hottest path in the engine.
  int distanceTo(Descriptor other) {
    var distance = 0;
    for (var i = 0; i < lengthBytes; i++) {
      distance += _popcount[bits[i] ^ other.bits[i]];
    }
    return distance;
  }

  static final Uint8List _popcount = _buildPopcountTable();

  static Uint8List _buildPopcountTable() {
    final table = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      var count = 0;
      var value = i;
      while (value != 0) {
        count += value & 1;
        value >>= 1;
      }
      table[i] = count;
    }
    return table;
  }
}

/// A candidate correspondence between a reference keypoint and a frame
/// keypoint.
class FeatureMatch {
  const FeatureMatch({
    required this.referenceIndex,
    required this.targetIndex,
    required this.distance,
    required this.ratio,
  });

  final int referenceIndex;
  final int targetIndex;

  /// Hamming distance of the best match.
  final int distance;

  /// best / second-best distance. Lower is less ambiguous (Lowe ratio test).
  final double ratio;
}
