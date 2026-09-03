import 'dart:convert';

import 'enums.dart';
import 'geometry.dart';

/// Visual properties of an annotation object (Data Model section 23).
///
/// Kept as a free-form block so the visual language can evolve without a
/// schema migration.
class AnnotationProperties {
  const AnnotationProperties({
    this.strokeWidth = 4,
    this.fontSize = 18,
    this.rotation = 0,
    this.opacity = 1,
    this.colorValue = 0xFFD61F4B,
    this.filled = false,
  });

  factory AnnotationProperties.fromJson(String? json) {
    if (json == null) return const AnnotationProperties();
    final map = jsonDecode(json) as Map<String, Object?>;
    return AnnotationProperties(
      strokeWidth: (map['stroke_width'] as num?)?.toDouble() ?? 4,
      fontSize: (map['font_size'] as num?)?.toDouble() ?? 18,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1,
      colorValue: (map['color'] as num?)?.toInt() ?? 0xFFD61F4B,
      filled: map['filled'] as bool? ?? false,
    );
  }

  final double strokeWidth;
  final double fontSize;
  final double rotation;
  final double opacity;

  /// ARGB. Defaults to Wise Red, the specified emphasis colour (UX/UI 2.1).
  final int colorValue;

  final bool filled;

  AnnotationProperties copyWith({
    double? strokeWidth,
    double? fontSize,
    double? rotation,
    double? opacity,
    int? colorValue,
    bool? filled,
  }) => AnnotationProperties(
    strokeWidth: strokeWidth ?? this.strokeWidth,
    fontSize: fontSize ?? this.fontSize,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    colorValue: colorValue ?? this.colorValue,
    filled: filled ?? this.filled,
  );

  String toJson() => jsonEncode({
    'stroke_width': strokeWidth,
    'font_size': fontSize,
    'rotation': rotation,
    'opacity': opacity,
    'color': colorValue,
    'filled': filled,
  });
}

/// A non-destructive vector object drawn over a photograph (Data Model 22,
/// Functional ANN-001..004).
///
/// An annotation never touches the original image. Rendering happens at export
/// time onto a copy (Privacy PRI-004).
class Annotation {
  const Annotation({
    required this.id,
    required this.photoId,
    required this.type,
    required this.geometry,
    required this.createdAt,
    required this.updatedAt,
    this.text,
    this.properties = const AnnotationProperties(),
    this.zIndex = 0,
    this.visible = true,
    this.deletedAt,
  });

  final String id;
  final String photoId;
  final AnnotationType type;
  final Geometry geometry;
  final String? text;
  final AnnotationProperties properties;
  final int zIndex;
  final bool visible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Annotation copyWith({
    Geometry? geometry,
    String? text,
    AnnotationProperties? properties,
    int? zIndex,
    bool? visible,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Annotation(
    id: id,
    photoId: photoId,
    type: type,
    geometry: geometry ?? this.geometry,
    text: text ?? this.text,
    properties: properties ?? this.properties,
    zIndex: zIndex ?? this.zIndex,
    visible: visible ?? this.visible,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'type': type.wireName,
    'geometry_json': geometry.toJson(),
    'text': text,
    'properties_json': properties.toJson(),
    'z_index': zIndex,
    'visible': visible ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  static Annotation fromRow(Map<String, Object?> row) => Annotation(
    id: row['id']! as String,
    photoId: row['photo_id']! as String,
    type: AnnotationType.fromWire(row['type']! as String),
    geometry: Geometry.fromJson(row['geometry_json']! as String),
    text: row['text'] as String?,
    properties: AnnotationProperties.fromJson(
      row['properties_json'] as String?,
    ),
    zIndex: (row['z_index'] as num?)?.toInt() ?? 0,
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
