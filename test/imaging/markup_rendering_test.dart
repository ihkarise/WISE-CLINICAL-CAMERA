import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wise_clinical_camera/core/imaging/image_codec.dart';
import 'package:wise_clinical_camera/core/imaging/layer_renderer.dart';
import 'package:wise_clinical_camera/core/imaging/layer_stack.dart';
import 'package:wise_clinical_camera/core/imaging/markup_geometry.dart';
import 'package:wise_clinical_camera/features/annotation/markup_painter.dart';
import 'package:wise_clinical_camera/models/annotation.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/models/measurement.dart';

/// What the clinician sees has to be what the export contains.
///
/// The application draws every annotation twice: `MarkupPainter` onto a Flutter
/// canvas for the screen, `LayerRenderer` onto a pixel buffer for the export.
/// Two implementations of the same shapes is a standing invitation to drift,
/// and the Phase 2 audit found they already had — the export floored an
/// arrowhead's barb at 10 px and the painter did not, so a thin arrow looked
/// like a plain line on screen and arrived as an arrow in the exported file.
///
/// The geometry now lives in one place. These tests hold it there.
void main() {
  const size = Size(200, 200);
  const imageRect = Rect.fromLTWH(0, 0, 200, 200);

  Annotation arrow({double strokeWidth = 4}) => Annotation(
    id: 'a1',
    photoId: 'p1',
    type: AnnotationType.arrow,
    geometry: const Geometry([ImagePoint(20, 100), ImagePoint(180, 100)]),
    properties: AnnotationProperties(strokeWidth: strokeWidth),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  MarkupPainter painterWith({
    List<Annotation> annotations = const [],
    List<Measurement> measurements = const [],
    List<ImagePoint> pending = const [],
  }) => MarkupPainter(
    measurements: measurements,
    annotations: annotations,
    pendingPoints: pending,
    imageRect: imageRect,
    imageWidth: 200,
    imageHeight: 200,
  );

  group('the shared arrowhead', () {
    test('barbs sit behind the tip, one either side of the shaft', () {
      final barbs = ArrowHead.barbs(
        fromX: 0,
        fromY: 0,
        toX: 100,
        toY: 0,
        strokeWidth: 4,
      );

      expect(barbs, hasLength(2));
      // Pointing right, so both barbs trail to the left of the tip...
      expect(barbs[0].x, lessThan(100));
      expect(barbs[1].x, lessThan(100));
      // ...and straddle the shaft, one either side.
      expect([barbs[0].y, barbs[1].y]..sort(), [lessThan(0), greaterThan(0)]);
    });

    test('the barb is as long as the spec says, whatever the direction', () {
      for (final angle in [0.0, 1.2, 3.0, -2.4]) {
        final barbs = ArrowHead.barbs(
          fromX: 0,
          fromY: 0,
          toX: 50 * math.cos(angle),
          toY: 50 * math.sin(angle),
          strokeWidth: 5,
        );
        for (final barb in barbs) {
          final dx = barb.x - 50 * math.cos(angle);
          final dy = barb.y - 50 * math.sin(angle);
          expect(
            math.sqrt(dx * dx + dy * dy),
            closeTo(ArrowHead.lengthFor(5), 0.001),
          );
        }
      }
    });

    test('a hairline stroke still gets a visible head', () {
      // Four times a 0.5 px stroke is 2 px, which at a glance is not an arrow.
      expect(ArrowHead.lengthFor(0.5), ArrowHead.minimumLength);
      expect(ArrowHead.lengthFor(10), 40);
    });
  });

  group('the on-screen painter', () {
    test('draws an arrow shaft and exactly two barbs', () {
      final canvas = _RecordingCanvas();

      painterWith(annotations: [arrow()]).paint(canvas, size);

      expect(canvas.lines, hasLength(3), reason: 'one shaft plus two barbs');
    });

    test('its barbs are the shared geometry, not a private copy', () {
      final canvas = _RecordingCanvas();

      painterWith(annotations: [arrow()]).paint(canvas, size);

      final expected = ArrowHead.barbs(
        fromX: 20,
        fromY: 100,
        toX: 180,
        toY: 100,
        strokeWidth: 4,
      );
      final drawn = canvas.lines.sublist(1).map((line) => line.$2).toList();

      for (var index = 0; index < 2; index++) {
        expect(drawn[index].dx, closeTo(expected[index].x, 0.001));
        expect(drawn[index].dy, closeTo(expected[index].y, 0.001));
      }
    });

    test('a hairline arrow gets the same floored head as the export', () {
      final canvas = _RecordingCanvas();

      painterWith(annotations: [arrow(strokeWidth: 0.5)]).paint(canvas, size);

      final tip = canvas.lines[1].$1;
      final barb = canvas.lines[1].$2;
      expect(
        (tip - barb).distance,
        closeTo(ArrowHead.minimumLength, 0.001),
        reason: 'this is the divergence the audit found',
      );
    });

    test('a circle, a rectangle and a point each draw their own shape', () {
      for (final (type, expectCircle, expectRect) in [
        (AnnotationType.circle, true, false),
        (AnnotationType.rectangle, false, true),
        (AnnotationType.point, true, false),
      ]) {
        final canvas = _RecordingCanvas();
        painterWith(
          annotations: [
            Annotation(
              id: 'a',
              photoId: 'p',
              type: type,
              geometry: const Geometry([
                ImagePoint(50, 50),
                ImagePoint(90, 90),
              ]),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
        ).paint(canvas, size);

        expect(canvas.circles.isNotEmpty, expectCircle, reason: '$type');
        expect(canvas.rects.isNotEmpty, expectRect, reason: '$type');
      }
    });

    test('a hidden annotation is not drawn', () {
      final canvas = _RecordingCanvas();

      painterWith(
        annotations: [arrow().copyWith(visible: false)],
      ).paint(canvas, size);

      expect(canvas.lines, isEmpty);
    });

    test('a measurement draws its path and a handle at every point', () {
      final canvas = _RecordingCanvas();

      painterWith(
        measurements: [
          Measurement(
            id: 'm1',
            photoId: 'p1',
            type: MeasurementType.length,
            pixelValue: 100,
            geometry: const Geometry([ImagePoint(10, 10), ImagePoint(110, 10)]),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      ).paint(canvas, size);

      expect(canvas.paths, hasLength(1));
      expect(canvas.circles, hasLength(2));
    });

    test('points placed but not yet committed are shown', () {
      final canvas = _RecordingCanvas();

      painterWith(
        pending: const [ImagePoint(10, 10), ImagePoint(60, 60)],
      ).paint(canvas, size);

      // The clinician has to see what they are building before it commits.
      expect(canvas.paths, hasLength(1));
      expect(canvas.circles, hasLength(2));
    });

    test('an empty editor draws nothing at all', () {
      final canvas = _RecordingCanvas();

      painterWith().paint(canvas, size);

      expect(canvas.lines, isEmpty);
      expect(canvas.paths, isEmpty);
      expect(canvas.circles, isEmpty);
    });
  });

  group('the export renderer', () {
    /// A white canvas, so any drawn pixel is unambiguous.
    Uint8List whiteJpeg({int width = 200, int height = 200}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      return Uint8List.fromList(img.encodeJpg(image, quality: 100));
    }

    test('marks the canvas where the shared geometry puts the barbs', () {
      final rendered = const LayerRenderer().render(
        originalBytes: whiteJpeg(),
        stack: LayerStack(
          originalPath: '/tmp/original.jpg',
          widthPx: 200,
          heightPx: 200,
          annotations: [arrow(strokeWidth: 6)],
        ),
      );

      final decoded = ImageCodec.decode(rendered.valueOrNull!)!;
      final barbs = ArrowHead.barbs(
        fromX: 20,
        fromY: 100,
        toX: 180,
        toY: 100,
        strokeWidth: 6,
      );

      for (final barb in barbs) {
        expect(
          _darkNear(decoded, barb.x.round(), barb.y.round(), radius: 4),
          isTrue,
          reason: 'no ink where the shared geometry says the barb ends',
        );
      }
    });

    test('leaves the canvas alone where nothing was drawn', () {
      final rendered = const LayerRenderer().render(
        originalBytes: whiteJpeg(),
        stack: LayerStack(
          originalPath: '/tmp/original.jpg',
          widthPx: 200,
          heightPx: 200,
          annotations: [arrow()],
        ),
      );

      final decoded = ImageCodec.decode(rendered.valueOrNull!)!;
      expect(_darkNear(decoded, 100, 190, radius: 3), isFalse);
    });
  });
}

/// True when any pixel within [radius] is meaningfully darker than white.
///
/// JPEG is lossy, so an exact colour comparison would be testing the codec
/// rather than the drawing.
bool _darkNear(img.Image image, int x, int y, {int radius = 2}) {
  for (var dy = -radius; dy <= radius; dy++) {
    for (var dx = -radius; dx <= radius; dx++) {
      final px = x + dx;
      final py = y + dy;
      if (px < 0 || py < 0 || px >= image.width || py >= image.height) continue;
      if (image.getPixel(px, py).luminance < 200) return true;
    }
  }
  return false;
}

/// A [Canvas] that records the drawing calls instead of rasterising them.
///
/// Rasterising and comparing pixels would answer "does it look right"; what
/// these tests need to answer is "does it draw the shape the shared geometry
/// specifies", which is a question about the calls.
class _RecordingCanvas implements Canvas {
  final List<(Offset, Offset)> lines = [];
  final List<Offset> circles = [];
  final List<Rect> rects = [];
  final List<Path> paths = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles.add(c);

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);

  @override
  void drawPath(Path path, Paint paint) => paths.add(path);

  // Labels bring in a TextPainter, which drives a handful of other canvas
  // calls. They are not what is under test here.
  @override
  void drawRRect(RRect rrect, Paint paint) {}

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {}

  @override
  void save() {}

  @override
  void restore() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
