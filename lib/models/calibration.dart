import 'dart:convert';

import 'enums.dart';
import 'geometry.dart';

/// The pixels-to-physical-units relationship for **one specific photograph**
/// (Data Model section 18).
///
/// Bound to a single photo on purpose. Data Model section 19 forbids reusing a
/// calibration on a different photograph unless the application can establish
/// the same scale relationship holds, and CV section 49 is blunt about why:
/// "alignment confidence is not measurement accuracy". A good alignment score
/// is not evidence that the scale carried over. See SPECIFICATION_CONFLICTS
/// C-011.
class Calibration {
  const Calibration({
    required this.id,
    required this.photoId,
    required this.method,
    required this.knownValue,
    required this.unit,
    required this.pixelDistance,
    required this.createdAt,
    required this.updatedAt,
    this.referenceGeometry,
    this.confidence,
    this.isValid = true,
  });

  /// Builds a calibration, validating the inputs.
  ///
  /// Returns null when the inputs cannot produce a meaningful scale
  /// (Functional CAL-006, Data Model section 49, Build Specification 36).
  /// Callers surface `CalibrationInvalid` rather than storing a nonsense scale.
  static Calibration? create({
    required String id,
    required String photoId,
    required CalibrationMethod method,
    required double knownValue,
    required LengthUnit unit,
    required double pixelDistance,
    Geometry? referenceGeometry,
    double? confidence,
    DateTime? now,
  }) {
    if (!knownValue.isFinite || knownValue <= 0) return null;
    if (!pixelDistance.isFinite || pixelDistance <= 0) return null;

    final timestamp = now ?? DateTime.now();
    return Calibration(
      id: id,
      photoId: photoId,
      method: method,
      knownValue: knownValue,
      unit: unit,
      pixelDistance: pixelDistance,
      referenceGeometry: referenceGeometry,
      confidence: confidence,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  final String id;
  final String photoId;
  final CalibrationMethod method;

  /// The physical length the user identified, in [unit].
  final double knownValue;

  final LengthUnit unit;

  /// The same length measured on the original image, in pixels.
  final double pixelDistance;

  /// The line or shape the user drew to establish the scale, kept so the
  /// calibration can be re-derived or shown back to them.
  final Geometry? referenceGeometry;

  final double? confidence;
  final bool isValid;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `pixelsPerUnit = pixelDistance / knownDistance` (Build Specification 36).
  double get pixelsPerUnit => pixelDistance / knownValue;

  /// Normalised to millimetres so a measurement can be displayed in any unit
  /// without re-deriving the calibration.
  double get pixelsPerMillimetre => pixelsPerUnit / unit.millimetresPerUnit;

  /// Whether this calibration may be used to produce physical units.
  ///
  /// The single gate for the "never show centimetres without calibration" rule
  /// (Build Specification 2.9, Functional CAL-001, Data Model section 50).
  bool get isUsable =>
      isValid &&
      knownValue > 0 &&
      pixelDistance > 0 &&
      pixelsPerMillimetre.isFinite &&
      pixelsPerMillimetre > 0;

  Calibration copyWith({
    bool? isValid,
    double? confidence,
    DateTime? updatedAt,
  }) => Calibration(
    id: id,
    photoId: photoId,
    method: method,
    knownValue: knownValue,
    unit: unit,
    pixelDistance: pixelDistance,
    referenceGeometry: referenceGeometry,
    confidence: confidence ?? this.confidence,
    isValid: isValid ?? this.isValid,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'method': method.wireName,
    'known_value': knownValue,
    'unit': unit.wireName,
    'pixel_distance': pixelDistance,
    'pixels_per_unit': pixelsPerUnit,
    'reference_geometry_json': referenceGeometry?.toJson(),
    'confidence': confidence,
    'is_valid': isValid ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static Calibration fromRow(Map<String, Object?> row) => Calibration(
    id: row['id']! as String,
    photoId: row['photo_id']! as String,
    method: CalibrationMethod.fromWire(row['method']! as String),
    knownValue: (row['known_value']! as num).toDouble(),
    unit: LengthUnit.fromWire(row['unit']! as String),
    pixelDistance: (row['pixel_distance']! as num).toDouble(),
    referenceGeometry: row['reference_geometry_json'] == null
        ? null
        : Geometry.fromJson(row['reference_geometry_json']! as String),
    confidence: (row['confidence'] as num?)?.toDouble(),
    isValid: (row['is_valid'] as num?)?.toInt() == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
  );
}

/// The standing accuracy caveat for photographic measurement (Build
/// Specification section 112, Functional section 45).
abstract final class MeasurementDisclaimer {
  static const String text =
      'Photographic measurement. Accuracy depends on calibration and capture '
      'geometry.';

  /// Shown when a calibration was established on one plane but the measured
  /// feature may sit at a different depth (Technical Architecture section 20,
  /// Functional CAL-007).
  static const String perspectiveWarning =
      'A scale reference on one plane does not guarantee accuracy for objects '
      'at a different depth or angle.';
}

/// Encodes an arbitrary key/value blob to JSON for the metadata columns, with
/// nulls dropped so an empty map stores as `null` rather than `{}`.
String? encodeOptionalJson(Map<String, Object?>? map) {
  if (map == null) return null;
  final filtered = <String, Object?>{
    for (final entry in map.entries)
      if (entry.value != null) entry.key: entry.value,
  };
  return filtered.isEmpty ? null : jsonEncode(filtered);
}
