import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:wise_clinical_camera/core/cv/working_image.dart';

/// A synthetic ground-truth dataset for the CV regression suite.
///
/// The specifications ask for a controlled dataset with *known* transformations
/// (CV sections 65-66, Testing sections 6-7, 61). No clinical photographs were
/// supplied with the repository, and real ones must not be committed to it
/// (Privacy section 52, Build Specification section 97), so this generates
/// images procedurally and applies exact transforms to them.
///
/// **What this validates:** geometric accuracy against a known answer, and the
/// degenerate cases (low texture, repeated pattern, concentrated detail,
/// occlusion) where the engine must decline rather than guess.
///
/// **What it cannot validate:** real skin, wounds, hair, dressings, varied skin
/// tones, real lighting change, real lens and device variation. Thresholds are
/// therefore *not* validated by these tests passing (CV sections 44, 64, 78).
/// See SPECIFICATION_CONFLICTS C-016.
abstract final class CvDataset {
  /// A richly textured scene: blobs at many scales plus fine noise.
  ///
  /// Corner-rich by construction, so a failure to align one of these is a
  /// failure of the engine, not of the input.
  static img.Image texturedScene({
    int width = 320,
    int height = 320,
    int seed = 42,
  }) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(128, 128, 128));

    final random = math.Random(seed);

    for (var i = 0; i < 60; i++) {
      final cx = random.nextInt(width);
      final cy = random.nextInt(height);
      final radius = 4 + random.nextInt(18);
      final shade = 30 + random.nextInt(200);
      img.fillCircle(
        image,
        x: cx,
        y: cy,
        radius: radius,
        color: img.ColorRgb8(shade, shade, shade),
      );
    }

    for (var i = 0; i < 40; i++) {
      final x = random.nextInt(width);
      final y = random.nextInt(height);
      final w = 5 + random.nextInt(25);
      final h = 5 + random.nextInt(25);
      final shade = 20 + random.nextInt(215);
      img.fillRect(
        image,
        x1: x,
        y1: y,
        x2: math.min(x + w, width - 1),
        y2: math.min(y + h, height - 1),
        color: img.ColorRgb8(shade, shade, shade),
      );
    }

    // Fine grain: gives the descriptor local structure to encode, so nearby
    // keypoints are distinguishable from each other.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final jitter = random.nextInt(40) - 20;
        final value = (pixel.r + jitter).clamp(0, 255).toInt();
        image.setPixelRgb(x, y, value, value, value);
      }
    }

    return image;
  }

  /// A flat field: the low-texture case (Testing ALG-T006).
  static img.Image flatScene({
    int width = 320,
    int height = 320,
    int level = 128,
  }) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(level, level, level));
    return image;
  }

  /// A regular grid: the repeated-pattern case.
  ///
  /// Every cell looks like every other, so a matcher without ambiguity
  /// filtering will happily match the wrong one and produce a confident wrong
  /// alignment. This is the shape of Testing ALG-T007.
  static img.Image repeatingPattern({
    int width = 320,
    int height = 320,
    int period = 20,
  }) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final on = ((x ~/ period) + (y ~/ period)).isEven;
        final value = on ? 210 : 45;
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    return image;
  }

  /// Texture confined to one corner on an otherwise flat field.
  ///
  /// The spatially-concentrated case CV section 23 singles out and Testing
  /// ALG-T008 requires: plenty of matches, none of which constrain the
  /// transform (Testing ALG-T008).
  static img.Image concentratedDetail({
    int width = 320,
    int height = 320,
    int seed = 9,
  }) {
    final image = flatScene(width: width, height: height);
    final random = math.Random(seed);
    final regionWidth = width ~/ 5;
    final regionHeight = height ~/ 5;

    for (var i = 0; i < 120; i++) {
      final x = random.nextInt(regionWidth);
      final y = random.nextInt(regionHeight);
      final shade = random.nextInt(256);
      image.setPixelRgb(x, y, shade, shade, shade);
    }
    return image;
  }

  /// Applies an exact similarity transform. This is the ground truth the
  /// estimate is scored against.
  static img.Image transform(
    img.Image source, {
    double translateX = 0,
    double translateY = 0,
    double rotationDegrees = 0,
    double scale = 1,
  }) {
    var result = source;
    if (scale != 1) {
      result = img.copyResize(
        result,
        width: (source.width * scale).round(),
        height: (source.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
      // Crop or pad back to the original canvas so the frame size is constant,
      // as it would be from a camera.
      result = _fitTo(result, source.width, source.height);
    }
    if (rotationDegrees != 0) {
      result = img.copyRotate(result, angle: rotationDegrees);
      result = _fitTo(result, source.width, source.height);
    }
    if (translateX != 0 || translateY != 0) {
      final canvas = img.Image(width: source.width, height: source.height);
      img.fill(canvas, color: img.ColorRgb8(128, 128, 128));
      img.compositeImage(
        canvas,
        result,
        dstX: translateX.round(),
        dstY: translateY.round(),
      );
      result = canvas;
    }
    return result;
  }

  /// Uniformly brightens or darkens, for the lighting tests.
  static img.Image adjustBrightness(img.Image source, int delta) {
    final result = img.Image.from(source);
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final value = (pixel.r + delta).clamp(0, 255).toInt();
        result.setPixelRgb(x, y, value, value, value);
      }
    }
    return result;
  }

  /// Gaussian blur, for the focus tests.
  static img.Image blur(img.Image source, int radius) =>
      img.gaussianBlur(img.Image.from(source), radius: radius);

  /// Covers a fraction of the image, for the occlusion case.
  static img.Image occlude(img.Image source, double fraction) {
    final result = img.Image.from(source);
    img.fillRect(
      result,
      x1: 0,
      y1: 0,
      x2: result.width - 1,
      y2: (result.height * fraction).round(),
      color: img.ColorRgb8(20, 20, 20),
    );
    return result;
  }

  /// Fine parallel striations: an analogue of a hair-bearing area.
  ///
  /// Dense, highly repetitive, locally self-similar texture — the pattern most
  /// likely to generate plausible but wrong correspondences (CV section 64).
  static img.Image hairLike({
    int width = 320,
    int height = 320,
    int seed = 5,
    double angle = 0.35,
  }) {
    final image = img.Image(width: width, height: height);
    final random = math.Random(seed);
    img.fill(image, color: img.ColorRgb8(150, 130, 120));

    for (var i = 0; i < 900; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final length = 25 + random.nextInt(60);
      final jitter = (random.nextDouble() - 0.5) * 0.25;
      final shade = 40 + random.nextInt(90);
      img.drawLine(
        image,
        x1: x.round(),
        y1: y.round(),
        x2: (x + math.cos(angle + jitter) * length).round(),
        y2: (y + math.sin(angle + jitter) * length).round(),
        color: img.ColorRgb8(shade, shade - 10, shade - 20),
      );
    }
    return image;
  }

  /// A large flat bright region covering part of the frame: an analogue of a
  /// dressing or bandage applied between visits.
  static img.Image withDressing(img.Image source, {double coverage = 0.45}) {
    final result = img.Image.from(source);
    img.fillRect(
      result,
      x1: (result.width * (1 - coverage)).round(),
      y1: 0,
      x2: result.width - 1,
      y2: result.height - 1,
      color: img.ColorRgb8(238, 235, 228),
    );
    return result;
  }

  /// A soft directional gradient: an analogue of a hard shadow falling across
  /// the subject.
  static img.Image withShadow(img.Image source, {double strength = 0.65}) {
    final result = img.Image.from(source);
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final falloff = 1 - strength * (x / result.width);
        final pixel = result.getPixel(x, y);
        final value = (pixel.r * falloff).clamp(0, 255).toInt();
        result.setPixelRgb(x, y, value, value, value);
      }
    }
    return result;
  }

  /// Displaces only part of the frame: an analogue of the subject moving while
  /// the camera did not (CV section 28).
  ///
  /// No single rigid transform explains this, which is exactly the point.
  static img.Image withPartialMovement(
    img.Image source, {
    double fraction = 0.5,
    int shift = 26,
  }) {
    final result = img.Image.from(source);
    final boundary = (result.height * fraction).round();
    final region = img.copyCrop(
      source,
      x: 0,
      y: 0,
      width: source.width,
      height: boundary,
    );
    img.fillRect(
      result,
      x1: 0,
      y1: 0,
      x2: result.width - 1,
      y2: boundary,
      color: img.ColorRgb8(128, 128, 128),
    );
    img.compositeImage(result, region, dstX: shift, dstY: 0);
    return result;
  }

  /// Non-linear tone change: an analogue of daylight versus a clinical lamp,
  /// as opposed to a uniform brightness offset.
  static img.Image withGamma(img.Image source, double gamma) {
    final result = img.Image.from(source);
    final table = List<int>.generate(
      256,
      (i) => (math.pow(i / 255, gamma) * 255).round().clamp(0, 255),
    );
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final value = table[result.getPixel(x, y).r.toInt()];
        result.setPixelRgb(x, y, value, value, value);
      }
    }
    return result;
  }

  static Uint8List toJpeg(img.Image image, {int quality = 95}) =>
      Uint8List.fromList(img.encodeJpg(image, quality: quality));

  static WorkingImage toWorking(img.Image image, {int maxDimension = 320}) =>
      WorkingImage.fromImage(image, maxDimension: maxDimension);

  /// Centres [source] on a canvas of the given size, cropping or padding.
  ///
  /// Cropping is done explicitly rather than by compositing at a negative
  /// offset: `compositeImage` does not clip a negative destination correctly,
  /// which silently produced a translated image instead of a scaled one.
  static img.Image _fitTo(img.Image source, int width, int height) {
    if (source.width == width && source.height == height) return source;

    if (source.width >= width && source.height >= height) {
      return img.copyCrop(
        source,
        x: (source.width - width) ~/ 2,
        y: (source.height - height) ~/ 2,
        width: width,
        height: height,
      );
    }

    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(128, 128, 128));
    img.compositeImage(
      canvas,
      source,
      dstX: (width - source.width) ~/ 2,
      dstY: (height - source.height) ~/ 2,
    );
    return canvas;
  }
}
