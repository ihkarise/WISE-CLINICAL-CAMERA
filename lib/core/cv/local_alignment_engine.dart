import 'dart:typed_data';

import '../errors/failures.dart';
import '../errors/result.dart';
import '../logging/app_logger.dart';
import 'alignment_config.dart';
import 'alignment_engine.dart';
import 'alignment_result.dart';
import 'confidence_model.dart';
import 'descriptor_matcher.dart';
import 'feature_detector.dart';
import 'transform_estimator.dart';
import 'working_image.dart';

/// The on-device alignment engine (CV section 72's recommended V1 stack).
///
/// Runs entirely locally. No frame, no reference and no derived feature ever
/// leaves the device (CV section 78, Privacy PRI-003).
///
/// Pipeline (CV section 24):
/// ```text
/// reference -> normalise -> detect -> describe
///                                       |
/// live frame -> normalise -> detect -> match -> reject outliers
///                                       |
///                          estimate transform -> confidence -> guidance
/// ```
class LocalAlignmentEngine implements AlignmentEngine {
  LocalAlignmentEngine({AlignmentConfig config = const AlignmentConfig()})
    : _config = config,
      _detector = FeatureDetector(config),
      _matcher = DescriptorMatcher(config),
      _estimator = TransformEstimator(config),
      _confidence = ConfidenceModel(config);

  /// Bumped whenever the algorithm changes in a way that would alter results,
  /// so stored alignments can be identified for reprocessing (CV section 53).
  static const String version = 'cv-1.0.0';

  final AlignmentConfig _config;
  final FeatureDetector _detector;
  final DescriptorMatcher _matcher;
  final TransformEstimator _estimator;
  final ConfidenceModel _confidence;
  final AppLogger _log = const AppLogger('cv');

  /// Previous frame's transform, for the stability signal and for temporal
  /// smoothing. Session state only, cleared by [reset].
  SimilarityTransform? _previousTransform;

  @override
  String get engineVersion => version;

  @override
  Future<Result<ReferenceFeatures>> prepareReference({
    required String photoId,
    required Uint8List imageBytes,
  }) async {
    final working = WorkingImage.fromBytes(
      imageBytes,
      maxDimension: _config.workingResolution,
    );
    if (working == null) {
      return const Result.failed(
        UnreadableImage(technicalDetail: 'reference failed to decode'),
      );
    }

    final detected = _detector.detect(working);
    final features = ReferenceFeatures(
      photoId: photoId,
      image: working,
      keypoints: detected.keypoints,
      descriptors: detected.descriptors,
      engineVersion: version,
      sourceWidth: (working.width / working.scaleFromSource).round(),
      sourceHeight: (working.height / working.scaleFromSource).round(),
    );

    _log.debug('reference prepared', {
      'photo_id': photoId,
      'keypoints': detected.keypoints.length,
      'usable': features.isUsable,
    });

    if (!features.isUsable) {
      // Not an error to hide: the user is told automatic alignment is
      // unavailable and Ghost Overlay still works (Functional ALG-007).
      return Result.failed(
        AlignmentUnavailable(
          technicalDetail:
              'reference has only ${detected.keypoints.length} keypoints',
        ),
      );
    }

    return Result.ok(features);
  }

  @override
  Future<AlignmentResult> analyzeFrame({
    required WorkingImage frame,
    required ReferenceFeatures reference,
  }) async {
    final stopwatch = Stopwatch()..start();

    final detected = _detector.detect(frame);
    if (detected.keypoints.length < _config.minInliers) {
      return _unavailable(
        'Not enough visible detail in the current view.',
        AlignmentMetrics(
          referenceKeypoints: reference.keypoints.length,
          targetKeypoints: detected.keypoints.length,
          processingMicroseconds: stopwatch.elapsedMicroseconds,
        ),
      );
    }

    final matches = _matcher.match(reference.descriptors, detected.descriptors);
    final estimate = _estimator.estimate(
      referenceKeypoints: reference.keypoints,
      targetKeypoints: detected.keypoints,
      matches: matches,
      imageWidth: reference.image.width,
      imageHeight: reference.image.height,
    );

    final metrics = AlignmentMetrics(
      referenceKeypoints: reference.keypoints.length,
      targetKeypoints: detected.keypoints.length,
      candidateMatches: matches.length,
      inliers: estimate.inlierCount,
      inlierRatio: estimate.inlierRatio,
      meanReprojectionError: estimate.meanReprojectionError,
      spatialSpread: estimate.spatialSpread,
      quadrantsCovered: estimate.quadrantsCovered,
      processingMicroseconds: stopwatch.elapsedMicroseconds,
    );

    // Hard gates before any score is computed. Failing one means UNAVAILABLE,
    // not a low number: a low number still reads as an estimate, and there
    // isn't one (CV sections 22-23, 29; Testing section 79).
    final rejection = _confidence.rejectionReason(estimate);
    if (rejection != null) {
      _previousTransform = null;
      return _unavailable(rejection, metrics);
    }

    final transform = estimate.transform!;
    final smoothed = _smooth(transform);
    final confidence = _confidence.score(
      estimate,
      previousTransform: _previousTransform,
    );
    _previousTransform = smoothed;

    // Translation is normalised by image size so guidance thresholds are
    // resolution-independent.
    final translationX = smoothed.translationX / reference.image.width;
    final translationY = smoothed.translationY / reference.image.height;

    final status = _confidence.statusFor(confidence);
    final dimensions = AlignmentDimensions(
      position:
          translationX.abs() <= _config.translationToleranceFraction &&
          translationY.abs() <= _config.translationToleranceFraction,
      scale: (smoothed.scale - 1).abs() <= _config.scaleTolerance,
      rotation:
          smoothed.rotationDegrees.abs() <= _config.rotationToleranceDegrees,
      framing:
          estimate.quadrantsCovered >= _config.minQuadrantsCovered &&
          estimate.spatialSpread >= _config.minSpatialSpread,
      // Sensor orientation is compared by the capture controller, which has
      // access to the reference recipe; the CV engine cannot see it.
      orientation: true,
    );

    return AlignmentResult(
      status: status,
      confidence: confidence,
      transform: smoothed,
      translationX: translationX,
      translationY: translationY,
      rotationDegrees: smoothed.rotationDegrees,
      scale: smoothed.scale,
      dimensions: dimensions,
      metrics: metrics,
      engineVersion: version,
    );
  }

  @override
  Future<AlignmentResult> align({
    required Uint8List referenceBytes,
    required Uint8List targetBytes,
  }) async {
    final prepared = await prepareReference(
      photoId: 'transient',
      imageBytes: referenceBytes,
    );
    if (prepared.isFailure) {
      return AlignmentResult.unavailable(
        engineVersion: version,
        unavailableReason: prepared.failureOrNull?.userMessage,
      );
    }

    final target = WorkingImage.fromBytes(
      targetBytes,
      maxDimension: _config.workingResolution,
    );
    if (target == null) {
      return const AlignmentResult.unavailable(
        engineVersion: version,
        unavailableReason: 'The photograph could not be read.',
      );
    }

    // A still-to-still comparison has no temporal history, so smoothing and
    // the stability signal must not carry over from a live session.
    final saved = _previousTransform;
    _previousTransform = null;
    final result = await analyzeFrame(
      frame: target,
      reference: prepared.valueOrNull!,
    );
    _previousTransform = saved;
    return result;
  }

  @override
  void reset() => _previousTransform = null;

  /// Exponential smoothing across frames (CV section 30, transform stability).
  ///
  /// Without it, small per-frame differences make guidance flip between
  /// "move left" and "move right", which is worse than useless while someone
  /// is holding a camera steady.
  SimilarityTransform _smooth(SimilarityTransform current) {
    final previous = _previousTransform;
    final alpha = _config.temporalSmoothing;
    if (previous == null || alpha <= 0) return current;

    double blend(double from, double to) => from * alpha + to * (1 - alpha);

    return SimilarityTransform(
      scale: blend(previous.scale, current.scale),
      rotationRadians: blend(previous.rotationRadians, current.rotationRadians),
      translationX: blend(previous.translationX, current.translationX),
      translationY: blend(previous.translationY, current.translationY),
    );
  }

  AlignmentResult _unavailable(String reason, AlignmentMetrics metrics) =>
      AlignmentResult.unavailable(
        engineVersion: version,
        unavailableReason: reason,
        metrics: metrics,
      );
}
