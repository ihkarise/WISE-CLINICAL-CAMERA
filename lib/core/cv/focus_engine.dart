import 'dart:math' as math;

import '../../models/enums.dart';
import 'quality_config.dart';
import 'working_image.dart';

/// A focus assessment.
class FocusAssessment {
  const FocusAssessment({
    required this.status,
    required this.score,
    required this.threshold,
  });

  static const FocusAssessment unavailable = FocusAssessment(
    status: FocusStatus.unavailable,
    score: 0,
    threshold: 0,
  );

  final FocusStatus status;

  /// Resolution-normalised Laplacian variance. Higher is sharper.
  final double score;

  final double threshold;

  bool get isWarning => status.isWarning;

  Map<String, Object?> toDetails() => {
    'laplacian_variance': score,
    'threshold': threshold,
  };
}

/// Local blur detection by Laplacian variance (CV section 43, Build
/// Specification section 32, Functional FOC-002).
///
/// Entirely on-device; no cloud processing (Technical Architecture 16).
///
/// The result is **advisory**. Functional FOC-003 and Build Specification
/// section 2.8 both require that a blur warning offers "Capture anyway" rather
/// than blocking, because a clinician may have exactly one chance at a
/// photograph.
class FocusEngine {
  const FocusEngine([this.config = const QualityConfig()]);

  final QualityConfig config;

  FocusAssessment assess(WorkingImage image) {
    if (image.width < 3 || image.height < 3) {
      return FocusAssessment.unavailable;
    }

    final variance = laplacianVariance(image);

    // Normalise by working resolution. A downsampled image has less
    // high-frequency energy purely because of the downsampling, so an
    // unnormalised threshold would call every small image blurred.
    final longestEdge = math.max(image.width, image.height);
    final normalised = variance * (config.focusWorkingResolution / longestEdge);

    return FocusAssessment(
      status: normalised >= config.focusVarianceThreshold
          ? FocusStatus.good
          : FocusStatus.mayBeBlurred,
      score: normalised,
      threshold: config.focusVarianceThreshold,
    );
  }

  /// Variance of the 4-neighbour Laplacian response.
  ///
  /// A sharp image has strong second derivatives at edges and therefore a high
  /// variance; blur smooths them away.
  static double laplacianVariance(WorkingImage image) {
    final width = image.width;
    final height = image.height;
    if (width < 3 || height < 3) return 0;

    final count = (width - 2) * (height - 2);
    if (count <= 0) return 0;

    var sum = 0.0;
    var sumOfSquares = 0.0;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final response =
            (4 * image.at(x, y) -
                    image.at(x - 1, y) -
                    image.at(x + 1, y) -
                    image.at(x, y - 1) -
                    image.at(x, y + 1))
                .toDouble();
        sum += response;
        sumOfSquares += response * response;
      }
    }

    final mean = sum / count;
    return (sumOfSquares / count) - (mean * mean);
  }
}
