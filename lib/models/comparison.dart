import 'dart:convert';

import 'enums.dart';

/// A saved Before/After comparison configuration (Data Model section 26).
class Comparison {
  const Comparison({
    required this.id,
    required this.beforePhotoId,
    required this.afterPhotoId,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.alignmentId,
    this.opacity = 0.5,
    this.configuration,
    this.derivedAssetId,
  });

  final String id;
  final String beforePhotoId;
  final String afterPhotoId;
  final ComparisonMode mode;

  /// The alignment record reused for overlay and difference rendering
  /// (Functional CMP-006).
  final String? alignmentId;

  final double opacity;
  final Map<String, Object?>? configuration;
  final String? derivedAssetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comparison copyWith({
    ComparisonMode? mode,
    String? alignmentId,
    double? opacity,
    Map<String, Object?>? configuration,
    String? derivedAssetId,
    DateTime? updatedAt,
  }) => Comparison(
    id: id,
    beforePhotoId: beforePhotoId,
    afterPhotoId: afterPhotoId,
    mode: mode ?? this.mode,
    alignmentId: alignmentId ?? this.alignmentId,
    opacity: opacity ?? this.opacity,
    configuration: configuration ?? this.configuration,
    derivedAssetId: derivedAssetId ?? this.derivedAssetId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'before_photo_id': beforePhotoId,
    'after_photo_id': afterPhotoId,
    'mode': mode.wireName,
    'alignment_json': alignmentId == null
        ? null
        : jsonEncode({'alignment_id': alignmentId}),
    'opacity': opacity,
    'configuration_json': configuration == null
        ? null
        : jsonEncode(configuration),
    'derived_asset_id': derivedAssetId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static Comparison fromRow(Map<String, Object?> row) {
    String? alignmentId;
    final alignmentJson = row['alignment_json'] as String?;
    if (alignmentJson != null) {
      final decoded = jsonDecode(alignmentJson) as Map<String, Object?>;
      alignmentId = decoded['alignment_id'] as String?;
    }
    return Comparison(
      id: row['id']! as String,
      beforePhotoId: row['before_photo_id']! as String,
      afterPhotoId: row['after_photo_id']! as String,
      mode: ComparisonMode.fromWire(row['mode']! as String),
      alignmentId: alignmentId,
      opacity: (row['opacity'] as num?)?.toDouble() ?? 0.5,
      configuration: row['configuration_json'] == null
          ? null
          : jsonDecode(row['configuration_json']! as String)
                as Map<String, Object?>,
      derivedAssetId: row['derived_asset_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at']! as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at']! as num).toInt(),
      ),
    );
  }
}
