import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../core/imaging/markup_geometry.dart';
import '../../models/annotation.dart';
import '../../models/enums.dart';
import '../../models/geometry.dart';
import '../../models/measurement.dart';

/// Draws measurements and annotations over the displayed photograph.
///
/// Draws to the screen only. Nothing here writes a file; the equivalent for
/// export is `LayerRenderer`, which composes onto a copy. Keeping the two
/// separate is what makes on-screen markup provably non-destructive.
class MarkupPainter extends CustomPainter {
  const MarkupPainter({
    required this.measurements,
    required this.annotations,
    required this.pendingPoints,
    required this.imageRect,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<Measurement> measurements;
  final List<Annotation> annotations;
  final List<ImagePoint> pendingPoints;

  /// Where the image sits inside the widget.
  final Rect imageRect;

  final int imageWidth;
  final int imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final measurement in measurements.where((m) => m.visible)) {
      _paintMeasurement(canvas, measurement);
    }
    for (final annotation in annotations.where((a) => a.visible)) {
      _paintAnnotation(canvas, annotation);
    }
    _paintPending(canvas);
  }

  Offset _toScreen(ImagePoint point) => Offset(
    imageRect.left + point.x / imageWidth * imageRect.width,
    imageRect.top + point.y / imageHeight * imageRect.height,
  );

  void _paintMeasurement(Canvas canvas, Measurement measurement) {
    final points = measurement.geometry.points;
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = WiseTokens.wiseRed
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final closed =
        measurement.type == MeasurementType.area ||
        measurement.type == MeasurementType.perimeter;

    final path = Path()
      ..moveTo(_toScreen(points.first).dx, _toScreen(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = _toScreen(point);
      path.lineTo(offset.dx, offset.dy);
    }
    if (closed && points.length > 2) path.close();
    canvas.drawPath(path, paint);

    for (final point in points) {
      canvas.drawCircle(
        _toScreen(point),
        4,
        Paint()..color = WiseTokens.wiseRed,
      );
    }

    _paintLabel(
      canvas,
      measurement.displayValue,
      _toScreen(points.first) + const Offset(8, -22),
    );
  }

  void _paintAnnotation(Canvas canvas, Annotation annotation) {
    final points = annotation.geometry.points;
    if (points.isEmpty) return;

    final argb = annotation.properties.colorValue;
    final paint = Paint()
      ..color = Color(argb)
      ..strokeWidth = annotation.properties.strokeWidth
      ..style = annotation.properties.filled
          ? PaintingStyle.fill
          : PaintingStyle.stroke;

    switch (annotation.type) {
      case AnnotationType.pen:
      case AnnotationType.line:
      case AnnotationType.measurement:
        final path = Path()
          ..moveTo(_toScreen(points.first).dx, _toScreen(points.first).dy);
        for (final point in points.skip(1)) {
          final offset = _toScreen(point);
          path.lineTo(offset.dx, offset.dy);
        }
        canvas.drawPath(path, paint);

      case AnnotationType.arrow:
        if (points.length >= 2) {
          final from = _toScreen(points[0]);
          final to = _toScreen(points[1]);
          canvas.drawLine(from, to, paint);
          _paintArrowHead(canvas, from, to, paint);
        }

      case AnnotationType.circle:
        if (points.length >= 2) {
          canvas.drawCircle(
            _toScreen(points[0]),
            (_toScreen(points[0]) - _toScreen(points[1])).distance,
            paint,
          );
        }

      case AnnotationType.rectangle:
        if (points.length >= 2) {
          canvas.drawRect(
            Rect.fromPoints(_toScreen(points[0]), _toScreen(points[1])),
            paint,
          );
        }

      case AnnotationType.point:
        canvas.drawCircle(
          _toScreen(points[0]),
          annotation.properties.strokeWidth * 1.5,
          Paint()..color = Color(argb),
        );

      case AnnotationType.text:
        if (annotation.text != null) {
          _paintLabel(canvas, annotation.text!, _toScreen(points[0]));
        }
    }
  }

  void _paintArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    // Shared with LayerRenderer so the arrow drawn here and the arrow written
    // into an export are the same shape.
    final barbs = ArrowHead.barbs(
      fromX: from.dx,
      fromY: from.dy,
      toX: to.dx,
      toY: to.dy,
      strokeWidth: paint.strokeWidth,
    );

    for (final barb in barbs) {
      canvas.drawLine(to, Offset(barb.x, barb.y), paint);
    }
  }

  /// The points placed so far, shown so the clinician can see what they are
  /// building before it is committed.
  void _paintPending(Canvas canvas) {
    if (pendingPoints.isEmpty) return;

    final paint = Paint()
      ..color = WiseTokens.aiGlowBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (pendingPoints.length > 1) {
      final path = Path()
        ..moveTo(
          _toScreen(pendingPoints.first).dx,
          _toScreen(pendingPoints.first).dy,
        );
      for (final point in pendingPoints.skip(1)) {
        final offset = _toScreen(point);
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final point in pendingPoints) {
      canvas.drawCircle(
        _toScreen(point),
        5,
        Paint()..color = WiseTokens.aiGlowBlue,
      );
    }
  }

  /// A label on a dark plate, so it stays readable over any skin tone or
  /// background (UX/UI section 55).
  void _paintLabel(Canvas canvas, String text, Offset position) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: WiseTokens.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final background = Rect.fromLTWH(
      position.dx - 4,
      position.dy - 2,
      painter.width + 8,
      painter.height + 4,
    );

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(background, const Radius.circular(4)),
        Paint()..color = WiseTokens.deepNavy.withValues(alpha: 0.8),
      )
      ..save();
    painter.paint(canvas, position);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MarkupPainter oldDelegate) =>
      oldDelegate.measurements != measurements ||
      oldDelegate.annotations != annotations ||
      oldDelegate.pendingPoints != pendingPoints ||
      oldDelegate.imageRect != imageRect;
}
