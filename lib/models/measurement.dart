import 'enums.dart';
import 'geometry.dart';

/// A measurement on a photograph (Data Model section 20).
///
/// Geometry and calculated value are stored separately, so changing the
/// calibration recalculates the value without touching the points the clinician
/// placed (Data Model section 21).
///
/// [calibrationId] null means the measurement exists only in pixels. In that
/// state the application must never present a physical unit (Data Model
/// section 50, Build Specification section 38).
class Measurement {
  const Measurement({
    required this.id,
    required this.photoId,
    required this.type,
    required this.geometry,
    required this.pixelValue,
    required this.createdAt,
    required this.updatedAt,
    this.calibrationId,
    this.unit,
    this.value,
    this.label,
    this.visible = true,
    this.deletedAt,
  });

  final String id;
  final String photoId;

  /// Null when uncalibrated.
  final String? calibrationId;

  final MeasurementType type;

  /// Display unit, only set when [calibrationId] is set.
  final LengthUnit? unit;

  /// Physical value in [unit]. Null when uncalibrated.
  final double? value;

  /// The measurement in pixels. Always available.
  final double pixelValue;

  final Geometry geometry;
  final String? label;
  final bool visible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// True only when a physical value may be displayed.
  bool get hasPhysicalValue =>
      calibrationId != null && value != null && unit != null;

  /// The string shown to the clinician.
  ///
  /// Falls back to pixels rather than inventing a physical figure, which is the
  /// behaviour Testing section 24 checks: "the application must not invent a
  /// physical measurement".
  String get displayValue {
    if (type.isAngular) return '${_format(pixelValue)}°';
    if (!hasPhysicalValue) {
      return type.isAreal
          ? '${_format(pixelValue)} px²'
          : '${_format(pixelValue)} px';
    }
    final symbol = type.isAreal ? unit!.areaSymbol : unit!.symbol;
    return '${_format(value!)} $symbol';
  }

  static String _format(double v) {
    final abs = v.abs();
    if (abs >= 1000) return v.toStringAsFixed(0);
    if (abs >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  Measurement copyWith({
    String? calibrationId,
    LengthUnit? unit,
    double? value,
    double? pixelValue,
    Geometry? geometry,
    String? label,
    bool? visible,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearCalibration = false,
    bool clearDeletedAt = false,
  }) => Measurement(
    id: id,
    photoId: photoId,
    calibrationId: clearCalibration
        ? null
        : (calibrationId ?? this.calibrationId),
    type: type,
    unit: clearCalibration ? null : (unit ?? this.unit),
    value: clearCalibration ? null : (value ?? this.value),
    pixelValue: pixelValue ?? this.pixelValue,
    geometry: geometry ?? this.geometry,
    label: label ?? this.label,
    visible: visible ?? this.visible,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'calibration_id': calibrationId,
    'type': type.wireName,
    'unit': unit?.wireName,
    'value': value,
    'pixel_value': pixelValue,
    'geometry_json': geometry.toJson(),
    'label': label,
    'visible': visible ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  static Measurement fromRow(Map<String, Object?> row) => Measurement(
    id: row['id']! as String,
    photoId: row['photo_id']! as String,
    calibrationId: row['calibration_id'] as String?,
    type: MeasurementType.fromWire(row['type']! as String),
    unit: row['unit'] == null
        ? null
        : LengthUnit.fromWire(row['unit']! as String),
    value: (row['value'] as num?)?.toDouble(),
    pixelValue: (row['pixel_value']! as num).toDouble(),
    geometry: Geometry.fromJson(row['geometry_json']! as String),
    label: row['label'] as String?,
    visible: (row['visible'] as num?)?.toInt() != 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (row['deleted_at']! as num).toInt(),
          ),
  );
}
