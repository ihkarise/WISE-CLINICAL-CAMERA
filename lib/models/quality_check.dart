import 'dart:convert';

import 'enums.dart';

/// A stored image-quality assessment (Data Model section 29).
///
/// Written alongside a captured photograph so the conditions it was taken under
/// are recoverable later, including when the user chose "Capture anyway"
/// (CV section 39).
class QualityCheck {
  const QualityCheck({
    required this.id,
    required this.photoId,
    required this.checkType,
    required this.status,
    required this.createdAt,
    required this.engineVersion,
    this.score,
    this.details,
  });

  final String id;
  final String photoId;
  final QualityCheckType checkType;
  final double? score;
  final QualityStatus status;
  final Map<String, Object?>? details;
  final String engineVersion;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'check_type': checkType.wireName,
    'score': score,
    'status': status.wireName,
    'details_json': details == null ? null : jsonEncode(details),
    'engine_version': engineVersion,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static QualityCheck fromRow(Map<String, Object?> row) => QualityCheck(
    id: row['id']! as String,
    photoId: row['photo_id']! as String,
    checkType: QualityCheckType.fromWire(row['check_type']! as String),
    score: (row['score'] as num?)?.toDouble(),
    status: QualityStatus.fromWire(row['status']! as String),
    details: row['details_json'] == null
        ? null
        : jsonDecode(row['details_json']! as String) as Map<String, Object?>,
    engineVersion: row['engine_version'] as String? ?? 'unknown',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
  );
}
