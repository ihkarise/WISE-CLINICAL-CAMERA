import 'capture_recipe.dart';
import 'enums.dart';

/// The central entity (Data Model section 8).
///
/// A `Photo` is a *record about* an image file; it never holds pixels. The
/// image at [originalPath] is written once and never rewritten
/// (Data Model section 38, Privacy PRI-004).
class Photo {
  const Photo({
    required this.id,
    required this.type,
    required this.originalPath,
    required this.capturedAt,
    required this.widthPx,
    required this.heightPx,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.caseId,
    this.thumbnailPath,
    this.importedAt,
    this.bodyPart,
    this.laterality,
    this.referencePhotoId,
    this.protocolId,
    this.checksum,
    this.metadataJson,
    this.captureRecipe,
    this.deletedAt,
    this.version = 1,
  });

  final String id;
  final String? userId;
  final String? caseId;
  final PhotoType type;

  /// Path to the immutable original. Never opened for writing after capture.
  final String originalPath;

  final String? thumbnailPath;
  final DateTime capturedAt;
  final DateTime? importedAt;
  final BodyPart? bodyPart;
  final Laterality? laterality;

  /// For an AFTER photo, the Before it reproduces (Data Model section 10).
  final String? referencePhotoId;

  final String? protocolId;
  final int widthPx;
  final int heightPx;
  final int fileSizeBytes;
  final String mimeType;

  /// SHA-256 of the original, for integrity and duplicate detection
  /// (Data Model section 39).
  final String? checksum;

  final PhotoSource source;
  final String? metadataJson;
  final CaptureRecipe? captureRecipe;
  final PhotoStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;

  bool get isDeleted => deletedAt != null;

  /// A Before that is not deleted may be offered as a reference
  /// (Data Model section 9).
  bool get canBeReference => type.isReferenceCapable && !isDeleted;

  /// Aspect ratio of the original. Guarded because a zero would only arise from
  /// a corrupt row, and dividing by it would crash the library grid.
  double get aspectRatio => heightPx == 0 ? 1 : widthPx / heightPx;

  Photo copyWith({
    String? userId,
    String? caseId,
    String? thumbnailPath,
    BodyPart? bodyPart,
    Laterality? laterality,
    String? referencePhotoId,
    String? protocolId,
    String? checksum,
    String? metadataJson,
    CaptureRecipe? captureRecipe,
    PhotoStatus? status,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? version,
    bool clearCaseId = false,
    bool clearDeletedAt = false,
  }) => Photo(
    id: id,
    userId: userId ?? this.userId,
    caseId: clearCaseId ? null : (caseId ?? this.caseId),
    type: type,
    originalPath: originalPath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    capturedAt: capturedAt,
    importedAt: importedAt,
    bodyPart: bodyPart ?? this.bodyPart,
    laterality: laterality ?? this.laterality,
    referencePhotoId: referencePhotoId ?? this.referencePhotoId,
    protocolId: protocolId ?? this.protocolId,
    widthPx: widthPx,
    heightPx: heightPx,
    fileSizeBytes: fileSizeBytes,
    mimeType: mimeType,
    checksum: checksum ?? this.checksum,
    source: source,
    metadataJson: metadataJson ?? this.metadataJson,
    captureRecipe: captureRecipe ?? this.captureRecipe,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    version: version ?? this.version,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'case_id': caseId,
    'type': type.wireName,
    'original_path': originalPath,
    'thumbnail_path': thumbnailPath,
    'captured_at': capturedAt.millisecondsSinceEpoch,
    'imported_at': importedAt?.millisecondsSinceEpoch,
    'body_part': bodyPart?.wireName,
    'laterality': laterality?.wireName,
    'reference_photo_id': referencePhotoId,
    'protocol_id': protocolId,
    'width_px': widthPx,
    'height_px': heightPx,
    'file_size_bytes': fileSizeBytes,
    'mime_type': mimeType,
    'checksum': checksum,
    'source': source.wireName,
    'metadata_json': metadataJson,
    'capture_recipe_json': captureRecipe?.toJson(),
    'status': status.wireName,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'version': version,
  };

  static Photo fromRow(Map<String, Object?> row) => Photo(
    id: row['id']! as String,
    userId: row['user_id'] as String?,
    caseId: row['case_id'] as String?,
    type: PhotoType.fromWire(row['type']! as String),
    originalPath: row['original_path']! as String,
    thumbnailPath: row['thumbnail_path'] as String?,
    capturedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['captured_at']! as num).toInt(),
    ),
    importedAt: _dateOrNull(row['imported_at']),
    bodyPart: BodyPart.fromWire(row['body_part'] as String?),
    laterality: Laterality.fromWire(row['laterality'] as String?),
    referencePhotoId: row['reference_photo_id'] as String?,
    protocolId: row['protocol_id'] as String?,
    widthPx: (row['width_px']! as num).toInt(),
    heightPx: (row['height_px']! as num).toInt(),
    fileSizeBytes: (row['file_size_bytes']! as num).toInt(),
    mimeType: row['mime_type']! as String,
    checksum: row['checksum'] as String?,
    source: PhotoSource.fromWire(row['source']! as String),
    metadataJson: row['metadata_json'] as String?,
    captureRecipe: row['capture_recipe_json'] == null
        ? null
        : CaptureRecipe.fromJson(row['capture_recipe_json']! as String),
    status: PhotoStatus.fromWire(row['status']! as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
    deletedAt: _dateOrNull(row['deleted_at']),
    version: (row['version'] as num?)?.toInt() ?? 1,
  );

  static DateTime? _dateOrNull(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch((value as num).toInt());
}
