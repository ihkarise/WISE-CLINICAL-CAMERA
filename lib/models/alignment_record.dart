import 'dart:convert';

import 'enums.dart';

/// A persisted alignment result (Data Model section 27, CV section 52).
///
/// Stored so a comparison can reuse a transform that was already computed
/// rather than deriving a second, possibly conflicting one (Functional CMP-006,
/// CV section 50).
///
/// [engineVersion] is recorded on every row so results can be reprocessed when
/// the algorithm improves (CV section 53).
class AlignmentRecord {
  const AlignmentRecord({
    required this.id,
    required this.referencePhotoId,
    required this.method,
    required this.status,
    required this.confidence,
    required this.createdAt,
    required this.engineVersion,
    this.targetPhotoId,
    this.score,
    this.translationX = 0,
    this.translationY = 0,
    this.rotation = 0,
    this.scale = 1,
    this.transformMatrix,
  });

  final String id;
  final String referencePhotoId;

  /// Null for a live-preview estimate that was recorded before the After photo
  /// existed.
  final String? targetPhotoId;

  final AlignmentMethod method;
  final double? score;

  /// Normalised horizontal offset, in units of reference image width.
  final double translationX;

  /// Normalised vertical offset, in units of reference image height.
  final double translationY;

  /// Degrees. Positive is counter-clockwise.
  final double rotation;

  /// Ratio of target subject size to reference subject size.
  final double scale;

  /// Row-major 3x3 transform.
  final List<double>? transformMatrix;

  final double confidence;
  final AlignmentStatus status;
  final DateTime createdAt;
  final String engineVersion;

  /// Whether this record may be reused to drive a comparison.
  ///
  /// A poor or unavailable alignment is deliberately not reused: rendering a
  /// difference view from an untrustworthy transform would manufacture apparent
  /// change that is not there (CV sections 49, 51).
  bool get isReusable => status.isUsable && transformMatrix != null;

  Map<String, Object?> toRow() => {
    'id': id,
    'reference_photo_id': referencePhotoId,
    'target_photo_id': targetPhotoId,
    'method': method.wireName,
    'score': score,
    'translation_x': translationX,
    'translation_y': translationY,
    'rotation': rotation,
    'scale': scale,
    'transform_matrix_json': transformMatrix == null
        ? null
        : jsonEncode(transformMatrix),
    'confidence': confidence,
    'status': status.wireName,
    'created_at': createdAt.millisecondsSinceEpoch,
    'engine_version': engineVersion,
  };

  static AlignmentRecord fromRow(Map<String, Object?> row) => AlignmentRecord(
    id: row['id']! as String,
    referencePhotoId: row['reference_photo_id']! as String,
    targetPhotoId: row['target_photo_id'] as String?,
    method: AlignmentMethod.fromWire(row['method']! as String),
    score: (row['score'] as num?)?.toDouble(),
    translationX: (row['translation_x'] as num?)?.toDouble() ?? 0,
    translationY: (row['translation_y'] as num?)?.toDouble() ?? 0,
    rotation: (row['rotation'] as num?)?.toDouble() ?? 0,
    scale: (row['scale'] as num?)?.toDouble() ?? 1,
    transformMatrix: row['transform_matrix_json'] == null
        ? null
        : (jsonDecode(row['transform_matrix_json']! as String) as List<Object?>)
              .map((e) => (e! as num).toDouble())
              .toList(growable: false),
    confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
    status: AlignmentStatus.fromWire(row['status']! as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    engineVersion: row['engine_version'] as String? ?? 'unknown',
  );
}
