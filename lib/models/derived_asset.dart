import 'dart:convert';

import 'enums.dart';

/// A file generated *from* an original (Data Model section 25).
///
/// Thumbnails, annotated renders, measured renders, comparison images and
/// exports are all derived assets. They can always be regenerated from the
/// original plus the stored configuration, which is why losing one is
/// recoverable and losing an original is not (Data Model section 25, Build
/// Specification section 105).
class DerivedAsset {
  const DerivedAsset({
    required this.id,
    required this.sourcePhotoId,
    required this.assetType,
    required this.filePath,
    required this.widthPx,
    required this.heightPx,
    required this.fileSizeBytes,
    required this.createdAt,
    this.checksum,
    this.configuration,
    this.version = 1,
  });

  final String id;
  final String sourcePhotoId;
  final DerivedAssetType assetType;
  final String filePath;
  final int widthPx;
  final int heightPx;
  final int fileSizeBytes;
  final String? checksum;
  final Map<String, Object?>? configuration;
  final DateTime createdAt;
  final int version;

  Map<String, Object?> toRow() => {
    'id': id,
    'source_photo_id': sourcePhotoId,
    'asset_type': assetType.wireName,
    'file_path': filePath,
    'width_px': widthPx,
    'height_px': heightPx,
    'file_size_bytes': fileSizeBytes,
    'checksum': checksum,
    'configuration_json': configuration == null
        ? null
        : jsonEncode(configuration),
    'created_at': createdAt.millisecondsSinceEpoch,
    'version': version,
  };

  static DerivedAsset fromRow(Map<String, Object?> row) => DerivedAsset(
    id: row['id']! as String,
    sourcePhotoId: row['source_photo_id']! as String,
    assetType: DerivedAssetType.fromWire(row['asset_type']! as String),
    filePath: row['file_path']! as String,
    widthPx: (row['width_px']! as num).toInt(),
    heightPx: (row['height_px']! as num).toInt(),
    fileSizeBytes: (row['file_size_bytes']! as num).toInt(),
    checksum: row['checksum'] as String?,
    configuration: row['configuration_json'] == null
        ? null
        : jsonDecode(row['configuration_json']! as String)
              as Map<String, Object?>,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    version: (row['version'] as num?)?.toInt() ?? 1,
  );
}
