import 'dart:math' as math;

import '../../models/calibration.dart';
import '../../models/enums.dart';
import '../../models/geometry.dart';
import '../../models/measurement.dart';

/// Turns geometry into a measurement (Build Specification section 37,
/// Functional MES-002..006).
///
/// The single rule this class exists to enforce: a physical value is produced
/// **only** when a usable calibration is supplied. Without one the measurement
/// carries a pixel value and no unit, so nothing downstream can render
/// centimetres (Build Specification section 2.9, Data Model section 50).
abstract final class MeasurementCalculator {
  /// Builds a measurement from placed points.
  ///
  /// [calibration] null, or not usable, yields a pixel-only measurement rather
  /// than a failure: recording the geometry is still worth doing, and the user
  /// can calibrate afterwards and recalculate.
  static Measurement build({
    required String id,
    required String photoId,
    required MeasurementType type,
    required Geometry geometry,
    Calibration? calibration,
    LengthUnit? displayUnit,
    String? label,
    DateTime? now,
  }) {
    final pixelValue = pixelValueFor(type, geometry);
    final timestamp = now ?? DateTime.now();

    final usable = calibration != null && calibration.isUsable;
    final unit = displayUnit ?? calibration?.unit ?? LengthUnit.centimetre;

    return Measurement(
      id: id,
      photoId: photoId,
      calibrationId: usable ? calibration.id : null,
      type: type,
      unit: usable ? unit : null,
      value: usable ? convert(pixelValue, type, calibration, unit) : null,
      pixelValue: pixelValue,
      geometry: geometry,
      label: label,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Recomputes a measurement after its geometry or calibration changed
  /// (Data Model section 21: geometry is stored so values can be re-derived).
  static Measurement recalculate(
    Measurement measurement, {
    Geometry? geometry,
    Calibration? calibration,
    LengthUnit? displayUnit,
    DateTime? now,
  }) {
    final newGeometry = geometry ?? measurement.geometry;
    final pixelValue = pixelValueFor(measurement.type, newGeometry);
    final usable = calibration != null && calibration.isUsable;
    final unit = displayUnit ?? calibration?.unit ?? measurement.unit;

    if (!usable || unit == null) {
      return measurement.copyWith(
        geometry: newGeometry,
        pixelValue: pixelValue,
        clearCalibration: true,
        updatedAt: now ?? DateTime.now(),
      );
    }

    return measurement.copyWith(
      geometry: newGeometry,
      pixelValue: pixelValue,
      calibrationId: calibration.id,
      unit: unit,
      value: convert(pixelValue, measurement.type, calibration, unit),
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// The measurement in pixels, by type.
  static double pixelValueFor(MeasurementType type, Geometry geometry) =>
      switch (type) {
        // A two-point distance. Length, width and diameter are geometrically
        // identical and differ only in clinical labelling
        // (SPECIFICATION_CONFLICTS C-009).
        MeasurementType.length ||
        MeasurementType.width ||
        MeasurementType.diameter =>
          geometry.points.length < 2
              ? 0
              : geometry.points.first.distanceTo(geometry.points[1]),
        MeasurementType.perimeter => Geometry(
          geometry.points,
          closed: true,
        ).pixelPathLength(),
        MeasurementType.area => geometry.pixelArea(),
        MeasurementType.angle => angleDegrees(geometry),
      };

  /// Converts a pixel value to physical units.
  ///
  /// Distances divide by pixels-per-unit once; areas divide twice, because an
  /// area scales with the square of the linear scale.
  static double convert(
    double pixelValue,
    MeasurementType type,
    Calibration calibration,
    LengthUnit unit,
  ) {
    if (type.isAngular) return pixelValue;

    final pixelsPerUnit =
        calibration.pixelsPerMillimetre * unit.millimetresPerUnit;
    if (!pixelsPerUnit.isFinite || pixelsPerUnit <= 0) return 0;

    return type.isAreal
        ? pixelValue / (pixelsPerUnit * pixelsPerUnit)
        : pixelValue / pixelsPerUnit;
  }

  /// Interior angle at the middle of three points, in degrees.
  ///
  /// Present for future posture work; not offered in the V1 toolbar
  /// (Build Specification section 37).
  static double angleDegrees(Geometry geometry) {
    if (geometry.points.length < 3) return 0;
    final a = geometry.points[0];
    final vertex = geometry.points[1];
    final c = geometry.points[2];

    final v1x = a.x - vertex.x;
    final v1y = a.y - vertex.y;
    final v2x = c.x - vertex.x;
    final v2y = c.y - vertex.y;

    final magnitude =
        math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y);
    if (magnitude == 0) return 0;

    final cosine = ((v1x * v2x + v1y * v2y) / magnitude).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }

  /// How many points a type needs before it can be calculated.
  static int minimumPoints(MeasurementType type) => switch (type) {
    MeasurementType.length ||
    MeasurementType.width ||
    MeasurementType.diameter => 2,
    MeasurementType.angle => 3,
    MeasurementType.perimeter || MeasurementType.area => 3,
  };

  static bool hasEnoughPoints(MeasurementType type, Geometry geometry) =>
      geometry.points.length >= minimumPoints(type);
}
