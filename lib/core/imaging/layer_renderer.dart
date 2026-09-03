import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../models/annotation.dart';
import '../../models/enums.dart';
import '../../models/geometry.dart';
import '../../models/measurement.dart';
import '../errors/failures.dart';
import '../errors/result.dart';
import 'image_codec.dart';
import 'layer_stack.dart';

/// Renders a [LayerStack] onto a **copy** of the original.
///
/// The immutability guarantee in code: the source bytes are decoded into a new
/// image and every drawing operation targets that copy. This class has no
/// method that writes to [LayerStack.originalPath] (PRD section 33, Data Model
/// section 38, Privacy PRI-004, Build Specification sections 2.1 and 48).
///
/// Runs on plain Dart, so it works in a background isolate and in tests
/// (Build Specification sections 61, 104).
class LayerRenderer {
  const LayerRenderer();

  /// Renders the composition, returning encoded JPEG bytes.
  ///
  /// [maxDimension] caps the long edge; null keeps the original resolution,
  /// which is the default because Technical Architecture section 44 requires
  /// preserving the maximum practical resolution unless a reduction is chosen.
  Result<Uint8List> render({
    required Uint8List originalBytes,
    required LayerStack stack,
    int? maxDimension,
    int quality = 92,
  }) {
    final decoded = ImageCodec.decode(originalBytes);
    if (decoded == null) {
      return const Result.failed(
        UnreadableImage(technicalDetail: 'original failed to decode'),
      );
    }

    // Every subsequent operation touches this copy, never the input buffer.
    var canvas = img.Image.from(decoded);

    // Geometry is stored in original-image pixels, so if the canvas is
    // resized the drawing must be scaled by the same factor.
    var geometryScale = 1.0;
    if (maxDimension != null) {
      final longest = math.max(canvas.width, canvas.height);
      if (longest > maxDimension) {
        geometryScale = maxDimension / longest;
        canvas = img.copyResize(
          canvas,
          width: (canvas.width * geometryScale).round(),
          height: (canvas.height * geometryScale).round(),
          interpolation: img.Interpolation.average,
        );
      }
    }

    if (stack.hasVisibleGrid) {
      _drawGrid(canvas, stack.gridType!);
    }
    for (final measurement in stack.visibleMeasurements) {
      _drawMeasurement(canvas, measurement, geometryScale);
    }
    for (final annotation in stack.visibleAnnotations) {
      _drawAnnotation(canvas, annotation, geometryScale);
    }
    if (stack.hasVisibleFooter) {
      canvas = _drawFooter(canvas, stack.footerLines);
    }

    return Result.ok(
      Uint8List.fromList(img.encodeJpg(canvas, quality: quality)),
    );
  }

  /// Composes a Before and an After side by side (Functional CMP-001,
  /// export preset BEFORE_AFTER).
  Result<Uint8List> renderPair({
    required Uint8List beforeBytes,
    required Uint8List afterBytes,
    LayerStack? beforeStack,
    LayerStack? afterStack,
    int? maxDimension,
    int quality = 92,
    bool labelled = true,
  }) {
    final before = _renderSide(beforeBytes, beforeStack);
    final after = _renderSide(afterBytes, afterStack);
    if (before == null || after == null) {
      return const Result.failed(
        UnreadableImage(technicalDetail: 'comparison source failed to decode'),
      );
    }

    // Match heights so the pair is visually comparable (Functional CMP-001:
    // "matched dimensions where possible").
    final targetHeight = math.min(before.height, after.height);
    final left = _scaleToHeight(before, targetHeight);
    final right = _scaleToHeight(after, targetHeight);

    const gap = 8;
    final labelHeight = labelled ? 44 : 0;
    var canvas = img.Image(
      width: left.width + gap + right.width,
      height: targetHeight + labelHeight,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    img.compositeImage(canvas, left, dstX: 0, dstY: labelHeight);
    img.compositeImage(
      canvas,
      right,
      dstX: left.width + gap,
      dstY: labelHeight,
    );

    if (labelled) {
      _drawLabel(canvas, 'BEFORE', 8, 12);
      _drawLabel(canvas, 'AFTER', left.width + gap + 8, 12);
    }

    if (maxDimension != null) {
      final longest = math.max(canvas.width, canvas.height);
      if (longest > maxDimension) {
        canvas = img.copyResize(
          canvas,
          width: (canvas.width * maxDimension / longest).round(),
          interpolation: img.Interpolation.average,
        );
      }
    }

    return Result.ok(
      Uint8List.fromList(img.encodeJpg(canvas, quality: quality)),
    );
  }

  img.Image? _renderSide(Uint8List bytes, LayerStack? stack) {
    if (stack == null) return ImageCodec.decode(bytes);
    final rendered = render(originalBytes: bytes, stack: stack);
    return rendered.fold(onOk: ImageCodec.decode, onFailure: (_) => null);
  }

  static img.Image _scaleToHeight(img.Image source, int height) =>
      source.height == height
      ? source
      : img.copyResize(
          source,
          height: height,
          interpolation: img.Interpolation.average,
        );

  // --- Layer drawing --------------------------------------------------------

  void _drawGrid(img.Image canvas, GridType type) {
    final colour = img.ColorRgba8(255, 255, 255, 140);
    final width = canvas.width;
    final height = canvas.height;

    switch (type) {
      case GridType.thirds:
        _drawGridLines(canvas, colour, 3);
      case GridType.quarters:
        _drawGridLines(canvas, colour, 4);
      case GridType.crosshair:
        final cx = width ~/ 2;
        final cy = height ~/ 2;
        final arm = math.min(width, height) ~/ 12;
        img.drawLine(
          canvas,
          x1: cx - arm,
          y1: cy,
          x2: cx + arm,
          y2: cy,
          color: colour,
          thickness: 2,
        );
        img.drawLine(
          canvas,
          x1: cx,
          y1: cy - arm,
          x2: cx,
          y2: cy + arm,
          color: colour,
          thickness: 2,
        );
    }
  }

  void _drawGridLines(img.Image canvas, img.Color colour, int divisions) {
    for (var i = 1; i < divisions; i++) {
      final x = canvas.width * i ~/ divisions;
      final y = canvas.height * i ~/ divisions;
      img.drawLine(
        canvas,
        x1: x,
        y1: 0,
        x2: x,
        y2: canvas.height - 1,
        color: colour,
      );
      img.drawLine(
        canvas,
        x1: 0,
        y1: y,
        x2: canvas.width - 1,
        y2: y,
        color: colour,
      );
    }
  }

  void _drawMeasurement(img.Image canvas, Measurement measurement, double s) {
    // Wise Red: measurements read as technical annotation, not decoration
    // (UX/UI section 32).
    final colour = img.ColorRgb8(0xD6, 0x1F, 0x4B);
    final points = measurement.geometry.points;
    if (points.isEmpty) return;

    final closed =
        measurement.type == MeasurementType.area ||
        measurement.type == MeasurementType.perimeter;

    for (var i = 0; i < points.length - 1; i++) {
      _line(canvas, points[i], points[i + 1], s, colour, 3);
    }
    if (closed && points.length > 2) {
      _line(canvas, points.last, points.first, s, colour, 3);
    }

    for (final point in points) {
      img.fillCircle(
        canvas,
        x: (point.x * s).round(),
        y: (point.y * s).round(),
        radius: 4,
        color: colour,
      );
    }

    // The value, drawn beside the first point.
    _drawLabel(
      canvas,
      measurement.displayValue,
      (points.first.x * s).round() + 8,
      (points.first.y * s).round() - 20,
    );
  }

  void _drawAnnotation(img.Image canvas, Annotation annotation, double s) {
    final argb = annotation.properties.colorValue;
    final colour = img.ColorRgb8(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
    );
    final thickness = math.max(1, annotation.properties.strokeWidth.round());
    final points = annotation.geometry.points;
    if (points.isEmpty) return;

    switch (annotation.type) {
      case AnnotationType.pen:
      case AnnotationType.line:
      case AnnotationType.measurement:
        for (var i = 0; i < points.length - 1; i++) {
          _line(canvas, points[i], points[i + 1], s, colour, thickness);
        }
      case AnnotationType.arrow:
        if (points.length >= 2) {
          _line(canvas, points[0], points[1], s, colour, thickness);
          _drawArrowHead(canvas, points[0], points[1], s, colour, thickness);
        }
      case AnnotationType.circle:
        if (points.length >= 2) {
          final radius = points[0].distanceTo(points[1]) * s;
          img.drawCircle(
            canvas,
            x: (points[0].x * s).round(),
            y: (points[0].y * s).round(),
            radius: radius.round(),
            color: colour,
          );
        }
      case AnnotationType.rectangle:
        if (points.length >= 2) {
          img.drawRect(
            canvas,
            x1: (points[0].x * s).round(),
            y1: (points[0].y * s).round(),
            x2: (points[1].x * s).round(),
            y2: (points[1].y * s).round(),
            color: colour,
            thickness: thickness,
          );
        }
      case AnnotationType.point:
        img.fillCircle(
          canvas,
          x: (points[0].x * s).round(),
          y: (points[0].y * s).round(),
          radius: math.max(3, thickness * 2),
          color: colour,
        );
      case AnnotationType.text:
        if (annotation.text != null) {
          _drawLabel(
            canvas,
            annotation.text!,
            (points[0].x * s).round(),
            (points[0].y * s).round(),
          );
        }
    }
  }

  void _drawArrowHead(
    img.Image canvas,
    ImagePoint from,
    ImagePoint to,
    double s,
    img.Color colour,
    int thickness,
  ) {
    final angle = math.atan2(to.y - from.y, to.x - from.x);
    final length = math.max(10, thickness * 4).toDouble();
    const spread = 0.5;

    for (final offset in [angle - spread, angle + spread]) {
      img.drawLine(
        canvas,
        x1: (to.x * s).round(),
        y1: (to.y * s).round(),
        x2: (to.x * s - length * math.cos(offset)).round(),
        y2: (to.y * s - length * math.sin(offset)).round(),
        color: colour,
        thickness: thickness,
      );
    }
  }

  void _line(
    img.Image canvas,
    ImagePoint a,
    ImagePoint b,
    double s,
    img.Color colour,
    int thickness,
  ) => img.drawLine(
    canvas,
    x1: (a.x * s).round(),
    y1: (a.y * s).round(),
    x2: (b.x * s).round(),
    y2: (b.y * s).round(),
    color: colour,
    thickness: thickness,
  );

  /// Extends the canvas and writes the footer beneath the image.
  ///
  /// Extends rather than overlays, so the footer never covers clinical detail
  /// (UX/UI section 41).
  img.Image _drawFooter(img.Image canvas, List<String> lines) {
    const lineHeight = 22;
    final footerHeight = lines.length * lineHeight + 16;

    final extended = img.Image(
      width: canvas.width,
      height: canvas.height + footerHeight,
    );
    img.fill(extended, color: img.ColorRgb8(0x10, 0x18, 0x28));
    img.compositeImage(extended, canvas, dstX: 0, dstY: 0);

    var y = canvas.height + 8;
    for (final line in lines) {
      img.drawString(
        extended,
        line,
        font: img.arial14,
        x: 12,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += lineHeight;
    }
    return extended;
  }

  void _drawLabel(img.Image canvas, String text, int x, int y) {
    // Dark plate behind the text so it stays readable over any skin tone or
    // background (UX/UI section 55, non-colour-only status).
    final width = text.length * 8 + 10;
    img.fillRect(
      canvas,
      x1: x - 4,
      y1: y - 2,
      x2: x + width,
      y2: y + 20,
      color: img.ColorRgba8(16, 24, 40, 200),
    );
    img.drawString(
      canvas,
      text,
      font: img.arial14,
      x: x,
      y: y,
      color: img.ColorRgb8(255, 255, 255),
    );
  }
}
