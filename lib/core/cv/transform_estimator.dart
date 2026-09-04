import 'dart:math' as math;

import 'alignment_config.dart';
import 'keypoint.dart';

/// A 2D similarity transform: uniform scale, rotation and translation.
///
/// CV section 16 requires the *least complex* model that explains the
/// relationship, and warns that a more complex model is not automatically
/// better. A similarity transform is what a hand-held camera moving and
/// rotating relative to a roughly planar subject actually produces, and it has
/// four parameters rather than the eight a homography needs — so it is far
/// harder to overfit to noise, which is what makes a confident wrong answer.
class SimilarityTransform {
  const SimilarityTransform({
    required this.scale,
    required this.rotationRadians,
    required this.translationX,
    required this.translationY,
  });

  static const SimilarityTransform identity = SimilarityTransform(
    scale: 1,
    rotationRadians: 0,
    translationX: 0,
    translationY: 0,
  );

  final double scale;
  final double rotationRadians;
  final double translationX;
  final double translationY;

  double get rotationDegrees => rotationRadians * 180 / math.pi;

  (double, double) apply(double x, double y) {
    final cos = math.cos(rotationRadians) * scale;
    final sin = math.sin(rotationRadians) * scale;
    return (cos * x - sin * y + translationX, sin * x + cos * y + translationY);
  }

  /// Row-major 3x3 matrix for storage (Data Model section 27).
  List<double> toMatrix() {
    final cos = math.cos(rotationRadians) * scale;
    final sin = math.sin(rotationRadians) * scale;
    return <double>[cos, -sin, translationX, sin, cos, translationY, 0, 0, 1];
  }

  /// Whether the parameters are physically plausible (CV section 22).
  bool isPlausible(AlignmentConfig config) =>
      scale.isFinite &&
      rotationRadians.isFinite &&
      translationX.isFinite &&
      translationY.isFinite &&
      scale >= config.minPlausibleScale &&
      scale <= config.maxPlausibleScale;
}

/// The outcome of a robust estimation.
class TransformEstimate {
  const TransformEstimate({
    required this.transform,
    required this.inlierIndices,
    required this.candidateCount,
    required this.meanReprojectionError,
    required this.spatialSpread,
    required this.quadrantsCovered,
  });

  static const TransformEstimate none = TransformEstimate(
    transform: null,
    inlierIndices: <int>[],
    candidateCount: 0,
    meanReprojectionError: double.infinity,
    spatialSpread: 0,
    quadrantsCovered: 0,
  );

  /// Null when no plausible transform survived.
  final SimilarityTransform? transform;

  final List<int> inlierIndices;
  final int candidateCount;
  final double meanReprojectionError;

  /// Normalised spread of inlier positions, 0-1 (CV section 23).
  final double spatialSpread;

  /// How many image quadrants contain an inlier, 0-4 (CV section 23).
  final int quadrantsCovered;

  int get inlierCount => inlierIndices.length;

  double get inlierRatio =>
      candidateCount == 0 ? 0 : inlierCount / candidateCount;

  bool get hasTransform => transform != null;
}

/// RANSAC estimation of a similarity transform (CV sections 15-16, 22-23).
class TransformEstimator {
  TransformEstimator([
    this.config = const AlignmentConfig(),
    int seed = 20260101,
  ]) : _random = math.Random(seed);

  final AlignmentConfig config;

  /// Seeded so a given input produces the same estimate every run, which is
  /// what makes the regression suite meaningful.
  final math.Random _random;

  /// Estimates the transform taking reference points onto target points.
  TransformEstimate estimate({
    required List<Keypoint> referenceKeypoints,
    required List<Keypoint> targetKeypoints,
    required List<FeatureMatch> matches,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (matches.length < 2) return TransformEstimate.none;

    var bestInliers = <int>[];
    SimilarityTransform? bestTransform;

    for (var iteration = 0; iteration < config.ransacIterations; iteration++) {
      final first = _random.nextInt(matches.length);
      var second = _random.nextInt(matches.length);
      if (second == first) second = (second + 1) % matches.length;
      if (second == first) break;

      final candidate = _fromPair(
        matches[first],
        matches[second],
        referenceKeypoints,
        targetKeypoints,
      );
      if (candidate == null || !candidate.isPlausible(config)) continue;

      final inliers = _inliersFor(
        candidate,
        matches,
        referenceKeypoints,
        targetKeypoints,
      );
      if (inliers.length > bestInliers.length) {
        bestInliers = inliers;
        bestTransform = candidate;
      }
    }

    if (bestTransform == null || bestInliers.length < 2) {
      return TransformEstimate.none;
    }

    // Refit on all inliers: the two-point hypothesis only located the
    // consensus set, it is not the best fit to it.
    final refined =
        _leastSquares(
          bestInliers,
          matches,
          referenceKeypoints,
          targetKeypoints,
        ) ??
        bestTransform;
    if (!refined.isPlausible(config)) return TransformEstimate.none;

    final finalInliers = _inliersFor(
      refined,
      matches,
      referenceKeypoints,
      targetKeypoints,
    );
    if (finalInliers.isEmpty) return TransformEstimate.none;

    return TransformEstimate(
      transform: refined,
      inlierIndices: finalInliers,
      candidateCount: matches.length,
      meanReprojectionError: _meanError(
        refined,
        finalInliers,
        matches,
        referenceKeypoints,
        targetKeypoints,
      ),
      spatialSpread: _spatialSpread(
        finalInliers,
        matches,
        referenceKeypoints,
        imageWidth,
        imageHeight,
      ),
      quadrantsCovered: _quadrantsCovered(
        finalInliers,
        matches,
        referenceKeypoints,
        imageWidth,
        imageHeight,
      ),
    );
  }

  /// The unique similarity transform mapping two reference points onto two
  /// target points.
  SimilarityTransform? _fromPair(
    FeatureMatch a,
    FeatureMatch b,
    List<Keypoint> reference,
    List<Keypoint> target,
  ) {
    final r1 = reference[a.referenceIndex];
    final r2 = reference[b.referenceIndex];
    final t1 = target[a.targetIndex];
    final t2 = target[b.targetIndex];

    final rdx = (r2.x - r1.x).toDouble();
    final rdy = (r2.y - r1.y).toDouble();
    final tdx = (t2.x - t1.x).toDouble();
    final tdy = (t2.y - t1.y).toDouble();

    final referenceLength = math.sqrt(rdx * rdx + rdy * rdy);
    final targetLength = math.sqrt(tdx * tdx + tdy * tdy);
    // Two coincident points define no direction and no scale.
    if (referenceLength < 1e-6 || targetLength < 1e-6) return null;

    final scale = targetLength / referenceLength;
    final rotation = math.atan2(tdy, tdx) - math.atan2(rdy, rdx);

    final cos = math.cos(rotation) * scale;
    final sin = math.sin(rotation) * scale;

    return SimilarityTransform(
      scale: scale,
      rotationRadians: rotation,
      translationX: t1.x - (cos * r1.x - sin * r1.y),
      translationY: t1.y - (sin * r1.x + cos * r1.y),
    );
  }

  /// Closed-form least-squares similarity fit (Umeyama, similarity case).
  SimilarityTransform? _leastSquares(
    List<int> indices,
    List<FeatureMatch> matches,
    List<Keypoint> reference,
    List<Keypoint> target,
  ) {
    if (indices.length < 2) return null;
    final n = indices.length;

    var referenceMeanX = 0.0, referenceMeanY = 0.0;
    var targetMeanX = 0.0, targetMeanY = 0.0;
    for (final index in indices) {
      final match = matches[index];
      referenceMeanX += reference[match.referenceIndex].x;
      referenceMeanY += reference[match.referenceIndex].y;
      targetMeanX += target[match.targetIndex].x;
      targetMeanY += target[match.targetIndex].y;
    }
    referenceMeanX /= n;
    referenceMeanY /= n;
    targetMeanX /= n;
    targetMeanY /= n;

    var sxx = 0.0, sxy = 0.0, referenceVariance = 0.0;
    for (final index in indices) {
      final match = matches[index];
      final rx = reference[match.referenceIndex].x - referenceMeanX;
      final ry = reference[match.referenceIndex].y - referenceMeanY;
      final tx = target[match.targetIndex].x - targetMeanX;
      final ty = target[match.targetIndex].y - targetMeanY;

      sxx += rx * tx + ry * ty;
      sxy += rx * ty - ry * tx;
      referenceVariance += rx * rx + ry * ry;
    }

    if (referenceVariance < 1e-9) return null;

    final rotation = math.atan2(sxy, sxx);
    final scale = math.sqrt(sxx * sxx + sxy * sxy) / referenceVariance;
    if (!scale.isFinite || scale <= 0) return null;

    final cos = math.cos(rotation) * scale;
    final sin = math.sin(rotation) * scale;

    return SimilarityTransform(
      scale: scale,
      rotationRadians: rotation,
      translationX: targetMeanX - (cos * referenceMeanX - sin * referenceMeanY),
      translationY: targetMeanY - (sin * referenceMeanX + cos * referenceMeanY),
    );
  }

  List<int> _inliersFor(
    SimilarityTransform transform,
    List<FeatureMatch> matches,
    List<Keypoint> reference,
    List<Keypoint> target,
  ) {
    final inliers = <int>[];
    for (var i = 0; i < matches.length; i++) {
      if (_error(transform, matches[i], reference, target) <=
          config.ransacInlierThresholdPx) {
        inliers.add(i);
      }
    }
    return inliers;
  }

  double _error(
    SimilarityTransform transform,
    FeatureMatch match,
    List<Keypoint> reference,
    List<Keypoint> target,
  ) {
    final source = reference[match.referenceIndex];
    final destination = target[match.targetIndex];
    final (px, py) = transform.apply(source.x.toDouble(), source.y.toDouble());
    final dx = px - destination.x;
    final dy = py - destination.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _meanError(
    SimilarityTransform transform,
    List<int> indices,
    List<FeatureMatch> matches,
    List<Keypoint> reference,
    List<Keypoint> target,
  ) {
    if (indices.isEmpty) return double.infinity;
    var total = 0.0;
    for (final index in indices) {
      total += _error(transform, matches[index], reference, target);
    }
    return total / indices.length;
  }

  /// Normalised spatial spread of the inliers.
  ///
  /// Guards CV section 23's failure mode. Twenty inliers clustered in one
  /// corner cannot constrain rotation or scale, so a high inlier count alone
  /// must not buy confidence.
  double _spatialSpread(
    List<int> indices,
    List<FeatureMatch> matches,
    List<Keypoint> reference,
    int width,
    int height,
  ) {
    if (indices.length < 2 || width == 0 || height == 0) return 0;

    var meanX = 0.0, meanY = 0.0;
    for (final index in indices) {
      meanX += reference[matches[index].referenceIndex].x / width;
      meanY += reference[matches[index].referenceIndex].y / height;
    }
    meanX /= indices.length;
    meanY /= indices.length;

    var variance = 0.0;
    for (final index in indices) {
      final dx = reference[matches[index].referenceIndex].x / width - meanX;
      final dy = reference[matches[index].referenceIndex].y / height - meanY;
      variance += dx * dx + dy * dy;
    }
    return math.sqrt(variance / indices.length);
  }

  int _quadrantsCovered(
    List<int> indices,
    List<FeatureMatch> matches,
    List<Keypoint> reference,
    int width,
    int height,
  ) {
    if (width == 0 || height == 0) return 0;
    final quadrants = <int>{};
    for (final index in indices) {
      final point = reference[matches[index].referenceIndex];
      final horizontal = point.x < width / 2 ? 0 : 1;
      final vertical = point.y < height / 2 ? 0 : 2;
      quadrants.add(horizontal + vertical);
    }
    return quadrants.length;
  }
}
