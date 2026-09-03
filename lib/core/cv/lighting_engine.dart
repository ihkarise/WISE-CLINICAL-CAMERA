import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/enums.dart';
import 'quality_config.dart';
import 'working_image.dart';

/// Image statistics used for lighting comparison (CV section 41).
class LightingStatistics {
  const LightingStatistics({
    required this.meanLuminance,
    required this.stdDevLuminance,
    required this.highlightFraction,
    required this.shadowFraction,
    required this.histogram,
  });

  factory LightingStatistics.of(WorkingImage image, QualityConfig config) {
    final histogram = image.histogram();
    final total = image.length;
    if (total == 0) {
      return LightingStatistics(
        meanLuminance: 0,
        stdDevLuminance: 0,
        highlightFraction: 0,
        shadowFraction: 0,
        histogram: Uint32List(256),
      );
    }

    var highlights = 0;
    var shadows = 0;
    for (var value = 0; value < 256; value++) {
      if (value >= config.highlightClipThreshold)
        highlights += histogram[value];
      if (value <= config.shadowClipThreshold) shadows += histogram[value];
    }

    return LightingStatistics(
      meanLuminance: image.meanLuminance,
      stdDevLuminance: image.luminanceStdDev,
      highlightFraction: highlights / total,
      shadowFraction: shadows / total,
      histogram: histogram,
    );
  }

  final double meanLuminance;
  final double stdDevLuminance;
  final double highlightFraction;
  final double shadowFraction;
  final Uint32List histogram;

  /// Histogram intersection, 0-1. 1 means identical distributions.
  double similarityTo(LightingStatistics other) {
    var intersection = 0;
    var totalSelf = 0;
    var totalOther = 0;
    for (var i = 0; i < 256; i++) {
      intersection += math.min(histogram[i], other.histogram[i]);
      totalSelf += histogram[i];
      totalOther += other.histogram[i];
    }
    final total = math.max(totalSelf, totalOther);
    return total == 0 ? 1 : intersection / total;
  }
}

/// The outcome of a lighting comparison.
class LightingAssessment {
  const LightingAssessment({
    required this.status,
    required this.meanDifference,
    required this.histogramSimilarity,
    this.detail,
  });

  static const LightingAssessment unavailable = LightingAssessment(
    status: LightingStatus.unavailable,
    meanDifference: 0,
    histogramSimilarity: 0,
  );

  final LightingStatus status;

  /// Current mean luminance minus the reference's, in 0-255 units.
  final double meanDifference;

  final double histogramSimilarity;

  /// A specific phrasing when one is warranted, such as a percentage
  /// difference (Technical Architecture section 15).
  final String? detail;

  bool get isWarning => status.isWarning;

  String get message => detail ?? status.label;

  Map<String, Object?> toDetails() => {
    'mean_difference': meanDifference,
    'histogram_similarity': histogramSimilarity,
  };
}

/// Local lighting comparison (CV section 41, Build Specification section 31).
///
/// Uses image statistics only: no cloud call, no model.
///
/// Deliberately does **not** claim the two images have equivalent illumination.
/// It reports that the statistics differ, which is all image statistics can
/// support (CV section 71, master prompt Phase 19).
class LightingEngine {
  const LightingEngine([this.config = const QualityConfig()]);

  final QualityConfig config;

  /// Assesses a frame on its own, with no reference (PHOTO and BEFORE modes).
  LightingAssessment assessAbsolute(WorkingImage frame) {
    final stats = LightingStatistics.of(frame, config);

    if (stats.meanLuminance <= config.tooDarkMeanLuminance ||
        stats.shadowFraction > config.maxClippedFraction) {
      return LightingAssessment(
        status: LightingStatus.tooDark,
        meanDifference: 0,
        histogramSimilarity: 1,
        detail: 'The scene is dark. More light will improve detail.',
      );
    }
    if (stats.meanLuminance >= config.tooBrightMeanLuminance ||
        stats.highlightFraction > config.maxClippedFraction) {
      return LightingAssessment(
        status: LightingStatus.tooBright,
        meanDifference: 0,
        histogramSimilarity: 1,
        detail: 'Bright areas are losing detail.',
      );
    }
    return const LightingAssessment(
      status: LightingStatus.good,
      meanDifference: 0,
      histogramSimilarity: 1,
    );
  }

  /// Compares a frame against the reference (AFTER mode).
  ///
  /// Checks the absolute condition first: an image too dark to read is worth
  /// saying so about even if it happens to match a reference that was also
  /// too dark.
  LightingAssessment compare({
    required WorkingImage reference,
    required WorkingImage frame,
  }) {
    final absolute = assessAbsolute(frame);
    if (absolute.status == LightingStatus.tooDark ||
        absolute.status == LightingStatus.tooBright) {
      return absolute;
    }

    final referenceStats = LightingStatistics.of(reference, config);
    final frameStats = LightingStatistics.of(frame, config);

    final meanDifference =
        frameStats.meanLuminance - referenceStats.meanLuminance;
    final similarity = frameStats.similarityTo(referenceStats);

    // Two independent tests. A hard shadow can redistribute the histogram while
    // leaving the mean almost unchanged, so the mean alone would miss it.
    final meanDiffers =
        meanDifference.abs() > config.luminanceDifferenceThreshold;
    final shapeDiffers = similarity < config.histogramSimilarityThreshold;

    if (!meanDiffers && !shapeDiffers) {
      return LightingAssessment(
        status: LightingStatus.similar,
        meanDifference: meanDifference,
        histogramSimilarity: similarity,
      );
    }

    return LightingAssessment(
      status: LightingStatus.different,
      meanDifference: meanDifference,
      histogramSimilarity: similarity,
      detail: _describe(meanDifference, referenceStats.meanLuminance),
    );
  }

  /// Phrases the difference the way the specification does: "18% brighter than
  /// reference" (Technical Architecture section 15).
  String _describe(double meanDifference, double referenceMean) {
    if (referenceMean <= 0) return 'Lighting differs from the Before image.';
    final percent = (meanDifference / referenceMean * 100).abs().round();
    if (percent < 1) return 'Lighting differs from the Before image.';
    return meanDifference > 0
        ? '$percent% brighter than the Before image'
        : '$percent% darker than the Before image';
  }
}
