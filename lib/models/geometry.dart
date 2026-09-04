import 'dart:convert';
import 'dart:math' as math;

/// A point in **original-image pixel coordinates**.
///
/// Geometry is always stored against the original image, never against whatever
/// the screen happened to be showing. That is what lets a measurement survive a
/// device rotation, a zoom, or a later recalculation with a different
/// calibration (Data Model section 21).
class ImagePoint {
  const ImagePoint(this.x, this.y);

  factory ImagePoint.fromMap(Map<String, Object?> map) =>
      ImagePoint((map['x']! as num).toDouble(), (map['y']! as num).toDouble());

  final double x;
  final double y;

  double distanceTo(ImagePoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Map<String, Object?> toMap() => {'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      other is ImagePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ImagePoint($x, $y)';
}

/// The point list behind a measurement or annotation.
///
/// Stored separately from any calculated display value so the value can be
/// recomputed if calibration changes (Data Model section 21).
class Geometry {
  const Geometry(this.points, {this.closed = false});

  factory Geometry.fromJson(String json) {
    final decoded = jsonDecode(json) as Map<String, Object?>;
    return Geometry(
      (decoded['points']! as List<Object?>)
          .map((e) => ImagePoint.fromMap(e! as Map<String, Object?>))
          .toList(growable: false),
      closed: decoded['closed'] as bool? ?? false,
    );
  }

  final List<ImagePoint> points;

  /// True for polygons used by area and perimeter measurements.
  final bool closed;

  bool get isEmpty => points.isEmpty;

  String toJson() => jsonEncode({
    'points': points.map((p) => p.toMap()).toList(growable: false),
    'closed': closed,
  });

  Geometry copyWith({List<ImagePoint>? points, bool? closed}) =>
      Geometry(points ?? this.points, closed: closed ?? this.closed);

  /// The average of the points; the natural origin for scaling.
  ImagePoint get centroid {
    if (points.isEmpty) return const ImagePoint(0, 0);
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in points) {
      sumX += point.x;
      sumY += point.y;
    }
    return ImagePoint(sumX / points.length, sumY / points.length);
  }

  /// Every point shifted by (dx, dy) in image pixels. A rigid move: it changes
  /// position but not length or area (Functional ANN-003 move).
  Geometry translated(double dx, double dy) => Geometry(
    points
        .map((p) => ImagePoint(p.x + dx, p.y + dy))
        .toList(growable: false),
    closed: closed,
  );

  /// Every point scaled by [factor] about [origin] (the centroid by default),
  /// which resizes the object in place (Functional ANN-003 resize).
  Geometry scaled(double factor, {ImagePoint? origin}) {
    final o = origin ?? centroid;
    return Geometry(
      points
          .map(
            (p) => ImagePoint(
              o.x + (p.x - o.x) * factor,
              o.y + (p.y - o.y) * factor,
            ),
          )
          .toList(growable: false),
      closed: closed,
    );
  }

  /// Sum of segment lengths in pixels. For a closed shape the closing segment
  /// is included.
  double pixelPathLength() {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += points[i].distanceTo(points[i + 1]);
    }
    if (closed) total += points.last.distanceTo(points.first);
    return total;
  }

  /// Shoelace area in square pixels. Zero for fewer than three points.
  ///
  /// The absolute value is taken so winding order does not matter.
  double pixelArea() {
    if (points.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum.abs() / 2;
  }
}
