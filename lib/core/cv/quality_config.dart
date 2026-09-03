/// Thresholds for the lighting and focus checks.
///
/// **Provisional.** CV section 44 is explicit: "Do not use one universal
/// threshold without validation", and requires testing across devices,
/// resolutions, clinical conditions, skin texture, wounds and low light.
/// Build Specification sections 32 and 86 require these to be configuration
/// rather than constants at a call site.
///
/// See docs/cv/THRESHOLDS.md and SPECIFICATION_CONFLICTS C-006.
class QualityConfig {
  const QualityConfig({
    this.focusVarianceThreshold = 120,
    this.focusWorkingResolution = 480,
    this.luminanceDifferenceThreshold = 25,
    this.histogramSimilarityThreshold = 0.75,
    this.tooDarkMeanLuminance = 45,
    this.tooBrightMeanLuminance = 215,
    this.highlightClipThreshold = 250,
    this.shadowClipThreshold = 5,
    this.maxClippedFraction = 0.15,
  });

  /// Laplacian variance below which an image is flagged as possibly blurred
  /// (Build Specification section 32).
  ///
  /// Compared against a variance normalised to [focusWorkingResolution] so the
  /// figure means roughly the same thing on a 12 MP and a 48 MP sensor. That
  /// normalisation makes the number *comparable* across devices; it does not
  /// make it *validated*.
  final double focusVarianceThreshold;

  /// Long edge the focus score is normalised against.
  final int focusWorkingResolution;

  /// Mean luminance difference (0-255) above which lighting is "different".
  final double luminanceDifferenceThreshold;

  /// Histogram intersection below which lighting is "different", even when the
  /// means happen to agree. Catches a redistributed histogram, such as a hard
  /// shadow, that leaves the average unchanged.
  final double histogramSimilarityThreshold;

  final double tooDarkMeanLuminance;
  final double tooBrightMeanLuminance;

  /// Luminance at or above which a pixel counts as a blown highlight.
  final double highlightClipThreshold;

  /// Luminance at or below which a pixel counts as a crushed shadow.
  final double shadowClipThreshold;

  /// Clipped fraction above which the frame is called too bright or too dark.
  final double maxClippedFraction;

  QualityConfig copyWith({
    double? focusVarianceThreshold,
    double? luminanceDifferenceThreshold,
    double? histogramSimilarityThreshold,
    double? tooDarkMeanLuminance,
    double? tooBrightMeanLuminance,
    double? maxClippedFraction,
  }) => QualityConfig(
    focusVarianceThreshold:
        focusVarianceThreshold ?? this.focusVarianceThreshold,
    focusWorkingResolution: focusWorkingResolution,
    luminanceDifferenceThreshold:
        luminanceDifferenceThreshold ?? this.luminanceDifferenceThreshold,
    histogramSimilarityThreshold:
        histogramSimilarityThreshold ?? this.histogramSimilarityThreshold,
    tooDarkMeanLuminance: tooDarkMeanLuminance ?? this.tooDarkMeanLuminance,
    tooBrightMeanLuminance:
        tooBrightMeanLuminance ?? this.tooBrightMeanLuminance,
    highlightClipThreshold: highlightClipThreshold,
    shadowClipThreshold: shadowClipThreshold,
    maxClippedFraction: maxClippedFraction ?? this.maxClippedFraction,
  );
}
