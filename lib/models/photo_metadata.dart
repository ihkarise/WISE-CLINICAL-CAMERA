import 'dart:convert';

/// Camera metadata for one photograph (Data Model section 13).
///
/// Every field is nullable because camera APIs differ between iOS and Android
/// and between devices. A null means "this device did not report it", and the
/// UI shows such fields as unavailable rather than as a zero (PRD section 25,
/// Technical Architecture section 6).
///
/// Deliberately has no GPS field. Location is not needed for reproducible
/// clinical photography and storing it would be collecting more than the
/// workflow requires (Privacy PRI-001, Data Model section 52).
class PhotoMetadata {
  const PhotoMetadata({
    required this.id,
    required this.photoId,
    required this.createdAt,
    this.cameraPosition,
    this.lensIdentifier,
    this.focalLength,
    this.zoomFactor,
    this.exposureTime,
    this.iso,
    this.aperture,
    this.flashMode,
    this.whiteBalance,
    this.orientation,
    this.deviceModel,
    this.osVersion,
    this.appVersion,
    this.rawMetadata,
  });

  final String id;
  final String photoId;
  final String? cameraPosition;
  final String? lensIdentifier;
  final double? focalLength;
  final double? zoomFactor;
  final double? exposureTime;
  final double? iso;
  final double? aperture;
  final String? flashMode;
  final String? whiteBalance;
  final String? orientation;
  final String? deviceModel;
  final String? osVersion;
  final String? appVersion;
  final Map<String, Object?>? rawMetadata;
  final DateTime createdAt;

  /// Fields an anonymized export removes (Privacy sections 40-41,
  /// Functional PRI-010). Documented explicitly because Build Specification
  /// section 49 requires stating exactly what is stripped.
  static const List<String> anonymizedFields = <String>[
    'device_model',
    'os_version',
    'lens_identifier',
    'camera_position',
    'raw_metadata_json',
  ];

  PhotoMetadata anonymized() => PhotoMetadata(
    id: id,
    photoId: photoId,
    focalLength: focalLength,
    zoomFactor: zoomFactor,
    exposureTime: exposureTime,
    iso: iso,
    aperture: aperture,
    flashMode: flashMode,
    whiteBalance: whiteBalance,
    orientation: orientation,
    appVersion: appVersion,
    createdAt: createdAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'camera_position': cameraPosition,
    'lens_identifier': lensIdentifier,
    'focal_length': focalLength,
    'zoom_factor': zoomFactor,
    'exposure_time': exposureTime,
    'iso': iso,
    'aperture': aperture,
    'flash_mode': flashMode,
    'white_balance': whiteBalance,
    'orientation': orientation,
    'device_model': deviceModel,
    'os_version': osVersion,
    'app_version': appVersion,
    'raw_metadata_json': rawMetadata == null ? null : jsonEncode(rawMetadata),
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static PhotoMetadata fromRow(Map<String, Object?> row) => PhotoMetadata(
    id: row['id']! as String,
    photoId: row['photo_id']! as String,
    cameraPosition: row['camera_position'] as String?,
    lensIdentifier: row['lens_identifier'] as String?,
    focalLength: (row['focal_length'] as num?)?.toDouble(),
    zoomFactor: (row['zoom_factor'] as num?)?.toDouble(),
    exposureTime: (row['exposure_time'] as num?)?.toDouble(),
    iso: (row['iso'] as num?)?.toDouble(),
    aperture: (row['aperture'] as num?)?.toDouble(),
    flashMode: row['flash_mode'] as String?,
    whiteBalance: row['white_balance'] as String?,
    orientation: row['orientation'] as String?,
    deviceModel: row['device_model'] as String?,
    osVersion: row['os_version'] as String?,
    appVersion: row['app_version'] as String?,
    rawMetadata: row['raw_metadata_json'] == null
        ? null
        : jsonDecode(row['raw_metadata_json']! as String)
              as Map<String, Object?>,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
  );
}
