import '../../models/enums.dart';
import 'transform_estimator.dart';

/// Per-dimension agreement with the reference (Functional ALG-003).
class AlignmentDimensions {
  const AlignmentDimensions({
    required this.position,
    required this.scale,
    required this.rotation,
    required this.framing,
    required this.orientation,
  });

  static const AlignmentDimensions unknown = AlignmentDimensions(
    position: false,
    scale: false,
    rotation: false,
    framing: false,
    orientation: false,
  );

  final bool position;
  final bool scale;
  final bool rotation;
  final bool framing;
  final bool orientation;

  bool get allSatisfied =>
      position && scale && rotation && framing && orientation;
}

/// Diagnostic metrics. Development builds may display these; production must
/// not (CV section 79, Build Specification sections 87-88).
class AlignmentMetrics {
  const AlignmentMetrics({
    this.referenceKeypoints = 0,
    this.targetKeypoints = 0,
    this.candidateMatches = 0,
    this.inliers = 0,
    this.inlierRatio = 0,
    this.meanReprojectionError = 0,
    this.spatialSpread = 0,
    this.quadrantsCovered = 0,
    this.processingMicroseconds = 0,
  });

  final int referenceKeypoints;
  final int targetKeypoints;
  final int candidateMatches;
  final int inliers;
  final double inlierRatio;
  final double meanReprojectionError;
  final double spatialSpread;
  final int quadrantsCovered;
  final int processingMicroseconds;

  Map<String, Object?> toMap() => {
    'reference_keypoints': referenceKeypoints,
    'target_keypoints': targetKeypoints,
    'candidate_matches': candidateMatches,
    'inliers': inliers,
    'inlier_ratio': inlierRatio,
    'mean_reprojection_error': meanReprojectionError,
    'spatial_spread': spatialSpread,
    'quadrants_covered': quadrantsCovered,
    'processing_us': processingMicroseconds,
  };
}

/// The result of comparing one live frame against the reference
/// (CV section 76, Build Specification section 26).
///
/// [confidence] is a reproducibility score. It is never a clinical accuracy
/// figure and must not be presented as one (CV sections 31, 49, 71).
class AlignmentResult {
  const AlignmentResult({
    required this.status,
    required this.confidence,
    required this.engineVersion,
    this.transform,
    this.translationX = 0,
    this.translationY = 0,
    this.rotationDegrees = 0,
    this.scale = 1,
    this.dimensions = AlignmentDimensions.unknown,
    this.metrics = const AlignmentMetrics(),
    this.unavailableReason,
  });

  /// The honest answer when the evidence does not support an estimate.
  ///
  /// Returning this rather than a low-confidence transform is the core of the
  /// false-confidence requirement: the system says so when it is uncertain
  /// (CV sections 29, 60-61; master prompt Phase 17).
  const AlignmentResult.unavailable({
    required this.engineVersion,
    this.unavailableReason,
    this.metrics = const AlignmentMetrics(),
  }) : status = AlignmentStatus.unavailable,
       confidence = 0,
       transform = null,
       translationX = 0,
       translationY = 0,
       rotationDegrees = 0,
       scale = 1,
       dimensions = AlignmentDimensions.unknown;

  final AlignmentStatus status;

  /// 0-1.
  final double confidence;

  final SimilarityTransform? transform;

  /// Normalised offset, in units of image width/height. Positive x means the
  /// subject sits to the right of where the reference has it.
  final double translationX;
  final double translationY;

  final double rotationDegrees;

  /// Ratio of apparent subject size to the reference's.
  final double scale;

  final AlignmentDimensions dimensions;
  final AlignmentMetrics metrics;
  final String engineVersion;
  final String? unavailableReason;

  bool get isAvailable => status != AlignmentStatus.unavailable;

  /// True when everything the engine can check agrees with the reference.
  ///
  /// Requires a GOOD status *and* every dimension satisfied. A high score with
  /// one dimension off is not "ready" — the clinician would be told to capture
  /// a photograph that does not actually match.
  bool get isReady => status == AlignmentStatus.good && dimensions.allSatisfied;

  /// Score as a percentage, for the optional advanced panel
  /// (Functional ALG-005).
  int get scorePercent => (confidence * 100).round();
}
