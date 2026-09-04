import 'dart:math' as math;

/// Geometry shared by the on-screen painter and the export renderer.
///
/// Both draw the same annotations: `MarkupPainter` onto a Flutter canvas for
/// the clinician, `LayerRenderer` onto a pixel buffer for the export. They
/// necessarily use different drawing APIs, but they must not use different
/// *shapes* — what a clinician marks has to be what the export shows, or the
/// exported image stops being evidence of what they saw.
///
/// Before this existed the two implementations each hard-coded the arrowhead,
/// and had already drifted: the renderer floored the barb length at 10 px and
/// the painter did not, so at a thin stroke the clinician saw a bare line and
/// the export carried an arrow.
abstract final class ArrowHead {
  /// Angle between the shaft and each barb, in radians (~29 degrees).
  static const double spread = 0.5;

  /// Barb length as a multiple of the stroke width.
  static const double lengthFactor = 4;

  /// Shortest barb that still reads as an arrow.
  ///
  /// Without a floor a hairline arrow has a head a couple of pixels long,
  /// which at a glance is just a line — and an arrow that does not look like
  /// one is pointing at nothing.
  static const double minimumLength = 10;

  static double lengthFor(double strokeWidth) =>
      math.max(minimumLength, strokeWidth * lengthFactor);

  /// The two barb endpoints for an arrow running from ([fromX], [fromY]) to
  /// ([toX], [toY]), in the same coordinate space as its arguments.
  static List<({double x, double y})> barbs({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required double strokeWidth,
  }) {
    final angle = math.atan2(toY - fromY, toX - fromX);
    final length = lengthFor(strokeWidth);

    return [
      for (final direction in [angle - spread, angle + spread])
        (
          x: toX - length * math.cos(direction),
          y: toY - length * math.sin(direction),
        ),
    ];
  }
}
