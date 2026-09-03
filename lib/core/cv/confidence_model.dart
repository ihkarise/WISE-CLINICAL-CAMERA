import 'dart:math' as math;

import '../../models/enums.dart';
import 'alignment_config.dart';
import 'transform_estimator.dart';

/// Combines the confidence signals CV section 30 names into a single score.
///
/// The specification lists the inputs and states that the weighting "must be
/// determined experimentally". This implementation is deliberately biased
/// toward **under**-confidence, for one reason: the dangerous failure is a high
/// score on a wrong alignment, because the clinician then captures a
/// photograph believing it reproduces the reference when it does not
/// (CV section 71, Testing section 79).
///
/// So the score is not simply a weighted average. Hard gates come first, and
/// any gate that fails collapses the result to UNAVAILABLE rather than
/// producing a merely lower number. Only once every gate passes do the weighted
/// signals decide between GOOD, FAIR and POOR.
class ConfidenceModel {
  const ConfidenceModel([this.config = const AlignmentConfig()]);

  final AlignmentConfig config;

  /// Why an estimate was rejected outright, or null if it passed the gates.
  String? rejectionReason(TransformEstimate estimate) {
    if (!estimate.hasTransform) {
      return 'No transform could be estimated from the visible detail.';
    }
    if (estimate.inlierCount < config.minInliers) {
      return 'Too few reliable matching points '
          '(${estimate.inlierCount} of ${config.minInliers} needed).';
    }
    if (estimate.inlierRatio < config.minInlierRatio) {
      return 'Most matching points disagreed with each other.';
    }
    // CV section 23. Matches crowded into one region cannot constrain the
    // transform, no matter how many of them agree.
    if (estimate.spatialSpread < config.minSpatialSpread) {
      return 'Matching detail is concentrated in one small area.';
    }
    if (estimate.quadrantsCovered < config.minQuadrantsCovered) {
      return 'Matching detail covers too little of the frame.';
    }
    if (!estimate.meanReprojectionError.isFinite ||
        estimate.meanReprojectionError > config.ransacInlierThresholdPx * 2) {
      return 'The estimated view does not fit the reference closely enough.';
    }
    return null;
  }

  /// Scores an estimate that has already passed [rejectionReason].
  ///
  /// [previousTransform] enables the stability signal: an estimate that jumps
  /// around between consecutive frames is less trustworthy than a steady one
  /// (CV section 30, "transform stability").
  double score(
    TransformEstimate estimate, {
    SimilarityTransform? previousTransform,
  }) {
    final weights = config.confidenceWeights;

    // Each signal is normalised to 0-1, where 1 is "as good as this signal
    // gets" rather than "perfect alignment".
    final ratioSignal = _normalise(
      estimate.inlierRatio,
      config.minInlierRatio,
      0.85,
    );

    // Saturates at four times the minimum: beyond that, more inliers stop
    // being evidence of anything.
    final countSignal = _normalise(
      estimate.inlierCount.toDouble(),
      config.minInliers.toDouble(),
      config.minInliers * 4.0,
    );

    final spreadSignal = _normalise(
      estimate.spatialSpread,
      config.minSpatialSpread,
      0.35,
    );

    // Inverted: lower reprojection error is better.
    final errorSignal =
        1 -
        _normalise(
          estimate.meanReprojectionError,
          0,
          config.ransacInlierThresholdPx,
        );

    final stabilitySignal =
        previousTransform == null || estimate.transform == null
        ? 0.5 // No history yet: neither credit nor penalty.
        : _stability(previousTransform, estimate.transform!);

    final weighted =
        ratioSignal * weights.inlierRatio +
        countSignal * weights.inlierCount +
        spreadSignal * weights.spatialDistribution +
        errorSignal * weights.reprojectionError +
        stabilitySignal * weights.transformStability;

    final normalised = weights.total == 0 ? 0.0 : weighted / weights.total;

    // Multiplicative gates. A weighted mean lets one strong signal mask a weak
    // one; multiplying by the two signals that matter most for correctness
    // means a poor spread or a poor inlier ratio caps the score however good
    // everything else looks.
    final gate =
        math.min(1, ratioSignal * 0.5 + 0.5) *
        math.min(1, spreadSignal * 0.5 + 0.5);

    return (normalised * gate).clamp(0.0, 1.0);
  }

  /// Maps a score to a user-facing status using the configured thresholds
  /// (SPECIFICATION_CONFLICTS C-004).
  AlignmentStatus statusFor(double confidence) {
    if (confidence >= config.goodConfidence) return AlignmentStatus.good;
    if (confidence >= config.fairConfidence) return AlignmentStatus.fair;
    return AlignmentStatus.poor;
  }

  /// 1 when two consecutive estimates agree, falling toward 0 as they diverge.
  double _stability(SimilarityTransform previous, SimilarityTransform current) {
    final scaleDelta = (current.scale - previous.scale).abs();
    final rotationDelta = (current.rotationDegrees - previous.rotationDegrees)
        .abs();
    final translationDelta = math.sqrt(
      math.pow(current.translationX - previous.translationX, 2) +
          math.pow(current.translationY - previous.translationY, 2),
    );

    // Tolerances chosen so ordinary hand tremor between frames does not read as
    // instability. Provisional, like every constant here.
    final scaleScore = 1 - _normalise(scaleDelta, 0, 0.2);
    final rotationScore = 1 - _normalise(rotationDelta, 0, 8);
    final translationScore = 1 - _normalise(translationDelta, 0, 30);

    return (scaleScore + rotationScore + translationScore) / 3;
  }

  static double _normalise(double value, double low, double high) {
    if (high <= low) return 0;
    return ((value - low) / (high - low)).clamp(0.0, 1.0);
  }
}
