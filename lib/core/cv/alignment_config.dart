/// Tunable constants for the alignment engine.
///
/// **Every default here is provisional.** CV section 78 forbids defining
/// arbitrary clinical accuracy percentages and requires thresholds to be
/// established experimentally; Functional ALG-006 says the same; Build
/// Specification section 86 requires them to be configuration rather than
/// hard-coded values. Nothing in the engine hard-codes a threshold at a call
/// site — they all come from here.
///
/// See docs/cv/THRESHOLDS.md and SPECIFICATION_CONFLICTS C-004 and C-005 for
/// what still has to be measured before these can be treated as validated.
class AlignmentConfig {
  const AlignmentConfig({
    this.workingResolution = 320,
    this.fastThreshold = 20,
    this.fastContiguous = 9,
    this.nonMaxSuppressionRadius = 3,
    this.maxKeypoints = 400,
    this.descriptorPatchRadius = 15,
    this.pyramidLevels = 4,
    this.pyramidScaleFactor = 1.3,
    this.minPyramidDimension = 48,
    this.loweRatio = 0.8,
    this.maxHammingDistance = 96,
    this.ransacIterations = 200,
    this.ransacInlierThresholdPx = 3,
    this.minInliers = 8,
    this.minInlierRatio = 0.25,
    this.minSpatialSpread = 0.12,
    this.minQuadrantsCovered = 2,
    this.goodConfidence = 0.85,
    this.fairConfidence = 0.70,
    this.translationToleranceFraction = 0.04,
    this.rotationToleranceDegrees = 2,
    this.scaleTolerance = 0.05,
    this.maxPlausibleScale = 4,
    this.minPlausibleScale = 0.25,
    this.temporalSmoothing = 0.6,
    this.confidenceWeights = const ConfidenceWeights(),
  });

  /// Long edge of the CV working image (CV section 8).
  final int workingResolution;

  /// FAST intensity difference threshold.
  final int fastThreshold;

  /// Contiguous arc length on the 16-pixel Bresenham circle (FAST-9).
  final int fastContiguous;

  /// Radius for non-maximum suppression, which stops keypoints clustering on
  /// a single strong edge.
  final int nonMaxSuppressionRadius;

  /// Cap on retained keypoints. Bounds per-frame cost (CV section 56).
  final int maxKeypoints;

  /// Half-width of the BRIEF sampling patch.
  final int descriptorPatchRadius;

  /// Levels in the detection pyramid.
  ///
  /// BRIEF descriptors are not scale-invariant on their own, so without a
  /// pyramid the engine fails precisely when the clinician is standing at the
  /// wrong distance -- the case "Move closer" exists to fix. Four levels at
  /// [pyramidScaleFactor] 1.3 cover roughly a 2.2x range of subject size.
  final int pyramidLevels;

  /// Size ratio between consecutive pyramid levels.
  final double pyramidScaleFactor;

  /// Levels smaller than this on the short edge are not built.
  final int minPyramidDimension;

  /// Lowe ratio test: a match is ambiguous unless the best distance is
  /// meaningfully better than the second best (CV section 14.3).
  final double loweRatio;

  /// Absolute Hamming cut-off for a 256-bit descriptor.
  final int maxHammingDistance;

  final int ransacIterations;

  /// Reprojection error, in working-image pixels, below which a correspondence
  /// counts as an inlier.
  final double ransacInlierThresholdPx;

  /// Below this many inliers no transform is trusted, whatever the ratio
  /// (CV section 22).
  final int minInliers;

  /// Inliers as a fraction of candidate matches (CV section 22).
  final double minInlierRatio;

  /// Normalised standard deviation of inlier positions.
  ///
  /// Guards the failure mode CV section 23 singles out: every match falling in
  /// one small region cannot constrain the transform, however many there are.
  final double minSpatialSpread;

  /// How many image quadrants inliers must occupy (CV section 23).
  final int minQuadrantsCovered;

  /// Confidence at or above which the status is GOOD.
  final double goodConfidence;

  /// Confidence at or above which the status is FAIR.
  final double fairConfidence;

  /// Translation, as a fraction of image size, treated as aligned.
  final double translationToleranceFraction;

  final double rotationToleranceDegrees;

  /// Scale ratio deviation from 1.0 treated as aligned.
  final double scaleTolerance;

  /// Outside this range a transform is degenerate and rejected
  /// (CV section 22: "scale is within plausible limits").
  final double maxPlausibleScale;
  final double minPlausibleScale;

  /// Exponential smoothing across frames, so guidance does not flicker between
  /// contradictory instructions (CV section 28: transform stability).
  /// 0 disables smoothing; 1 freezes the estimate.
  final double temporalSmoothing;

  final ConfidenceWeights confidenceWeights;

  AlignmentConfig copyWith({
    int? workingResolution,
    int? fastThreshold,
    int? maxKeypoints,
    int? pyramidLevels,
    double? loweRatio,
    int? ransacIterations,
    double? ransacInlierThresholdPx,
    int? minInliers,
    double? minInlierRatio,
    double? minSpatialSpread,
    int? minQuadrantsCovered,
    double? goodConfidence,
    double? fairConfidence,
    double? translationToleranceFraction,
    double? rotationToleranceDegrees,
    double? scaleTolerance,
    double? temporalSmoothing,
    ConfidenceWeights? confidenceWeights,
  }) => AlignmentConfig(
    workingResolution: workingResolution ?? this.workingResolution,
    fastThreshold: fastThreshold ?? this.fastThreshold,
    fastContiguous: fastContiguous,
    nonMaxSuppressionRadius: nonMaxSuppressionRadius,
    maxKeypoints: maxKeypoints ?? this.maxKeypoints,
    descriptorPatchRadius: descriptorPatchRadius,
    pyramidLevels: pyramidLevels ?? this.pyramidLevels,
    pyramidScaleFactor: pyramidScaleFactor,
    minPyramidDimension: minPyramidDimension,
    loweRatio: loweRatio ?? this.loweRatio,
    maxHammingDistance: maxHammingDistance,
    ransacIterations: ransacIterations ?? this.ransacIterations,
    ransacInlierThresholdPx:
        ransacInlierThresholdPx ?? this.ransacInlierThresholdPx,
    minInliers: minInliers ?? this.minInliers,
    minInlierRatio: minInlierRatio ?? this.minInlierRatio,
    minSpatialSpread: minSpatialSpread ?? this.minSpatialSpread,
    minQuadrantsCovered: minQuadrantsCovered ?? this.minQuadrantsCovered,
    goodConfidence: goodConfidence ?? this.goodConfidence,
    fairConfidence: fairConfidence ?? this.fairConfidence,
    translationToleranceFraction:
        translationToleranceFraction ?? this.translationToleranceFraction,
    rotationToleranceDegrees:
        rotationToleranceDegrees ?? this.rotationToleranceDegrees,
    scaleTolerance: scaleTolerance ?? this.scaleTolerance,
    maxPlausibleScale: maxPlausibleScale,
    minPlausibleScale: minPlausibleScale,
    temporalSmoothing: temporalSmoothing ?? this.temporalSmoothing,
    confidenceWeights: confidenceWeights ?? this.confidenceWeights,
  );

  /// Cheaper settings for a lower-tier device (CV section 58, Tier B/C).
  static const AlignmentConfig reducedPerformance = AlignmentConfig(
    workingResolution: 240,
    maxKeypoints: 200,
    ransacIterations: 120,
    pyramidLevels: 3,
  );
}

/// Relative weights of the confidence signals CV section 30 lists.
///
/// The specification names the seven inputs but states the weighting "must be
/// determined experimentally". These weights are a starting point, not a
/// validated model (SPECIFICATION_CONFLICTS C-005).
class ConfidenceWeights {
  const ConfidenceWeights({
    this.inlierRatio = 0.30,
    this.inlierCount = 0.15,
    this.spatialDistribution = 0.25,
    this.reprojectionError = 0.20,
    this.transformStability = 0.10,
  });

  final double inlierRatio;
  final double inlierCount;
  final double spatialDistribution;
  final double reprojectionError;
  final double transformStability;

  double get total =>
      inlierRatio +
      inlierCount +
      spatialDistribution +
      reprojectionError +
      transformStability;
}
