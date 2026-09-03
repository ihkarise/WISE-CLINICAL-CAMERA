import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A single-channel 8-bit image at CV working resolution.
///
/// Every CV stage operates on this, never on a full-resolution photograph.
/// The specification is explicit that the full-resolution image should not be
/// used for live-frame calculation and that smooth preview beats CV precision
/// (CV sections 5, 8, 55-57).
class WorkingImage {
  WorkingImage({
    required this.width,
    required this.height,
    required this.pixels,
    this.scaleFromSource = 1,
  }) : assert(pixels.length == width * height, 'pixel buffer size mismatch');

  /// Converts and downsamples a decoded image.
  ///
  /// [maxDimension] caps the long edge. The default of 320 px is provisional:
  /// CV section 8 requires the working resolution to be chosen by device
  /// benchmarking, which has not been done (docs/cv/THRESHOLDS.md).
  factory WorkingImage.fromImage(img.Image source, {int maxDimension = 320}) {
    final longest = math.max(source.width, source.height);
    final scale = longest <= maxDimension ? 1.0 : maxDimension / longest;

    final targetWidth = math.max(1, (source.width * scale).round());
    final targetHeight = math.max(1, (source.height * scale).round());

    final resized = scale == 1.0
        ? source
        : img.copyResize(
            source,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.average,
          );

    final pixels = Uint8List(targetWidth * targetHeight);
    var index = 0;
    for (var y = 0; y < targetHeight; y++) {
      for (var x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixel(x, y);
        // Rec. 601 luma. Integer arithmetic keeps this cheap in the frame loop.
        final luminance =
            (pixel.r * 299 + pixel.g * 587 + pixel.b * 114) ~/ 1000;
        pixels[index++] = luminance.clamp(0, 255).toInt();
      }
    }

    return WorkingImage(
      width: targetWidth,
      height: targetHeight,
      pixels: pixels,
      scaleFromSource: scale,
    );
  }

  /// Decodes bytes and converts in one step. Returns null if undecodable.
  static WorkingImage? fromBytes(Uint8List bytes, {int maxDimension = 320}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return WorkingImage.fromImage(decoded, maxDimension: maxDimension);
  }

  final int width;
  final int height;
  final Uint8List pixels;

  /// Working pixels per source pixel. Lets a transform estimated here be mapped
  /// back to original-image coordinates.
  final double scaleFromSource;

  int get length => pixels.length;

  int at(int x, int y) => pixels[y * width + x];

  /// Bounds-safe read; out-of-range samples clamp to the edge.
  int atClamped(int x, int y) =>
      pixels[y.clamp(0, height - 1) * width + x.clamp(0, width - 1)];

  double get meanLuminance {
    if (pixels.isEmpty) return 0;
    var sum = 0;
    for (final value in pixels) {
      sum += value;
    }
    return sum / pixels.length;
  }

  /// 256-bin luminance histogram.
  Uint32List histogram() {
    final bins = Uint32List(256);
    for (final value in pixels) {
      bins[value]++;
    }
    return bins;
  }

  /// Population standard deviation of luminance. A proxy for how much contrast
  /// the frame carries, used as one input to the low-texture check.
  /// Bilinear downsample to a smaller size, for the detection pyramid.
  ///
  /// Bilinear rather than nearest-neighbour: nearest-neighbour aliases fine
  /// texture into spurious corners, which would put false keypoints on the
  /// coarse levels.
  WorkingImage downsampled(int targetWidth, int targetHeight) {
    final result = Uint8List(targetWidth * targetHeight);
    final xRatio = width / targetWidth;
    final yRatio = height / targetHeight;

    var index = 0;
    for (var y = 0; y < targetHeight; y++) {
      final sourceY = (y + 0.5) * yRatio - 0.5;
      final y0 = sourceY.floor().clamp(0, height - 1);
      final y1 = (y0 + 1).clamp(0, height - 1);
      final yWeight = (sourceY - y0).clamp(0.0, 1.0);

      for (var x = 0; x < targetWidth; x++) {
        final sourceX = (x + 0.5) * xRatio - 0.5;
        final x0 = sourceX.floor().clamp(0, width - 1);
        final x1 = (x0 + 1).clamp(0, width - 1);
        final xWeight = (sourceX - x0).clamp(0.0, 1.0);

        final top = at(x0, y0) * (1 - xWeight) + at(x1, y0) * xWeight;
        final bottom = at(x0, y1) * (1 - xWeight) + at(x1, y1) * xWeight;
        result[index++] = (top * (1 - yWeight) + bottom * yWeight)
            .round()
            .clamp(0, 255);
      }
    }

    return WorkingImage(
      width: targetWidth,
      height: targetHeight,
      pixels: result,
      scaleFromSource: scaleFromSource * (targetWidth / width),
    );
  }

  double get luminanceStdDev {
    if (pixels.isEmpty) return 0;
    final mean = meanLuminance;
    var sum = 0.0;
    for (final value in pixels) {
      final delta = value - mean;
      sum += delta * delta;
    }
    return math.sqrt(sum / pixels.length);
  }
}
