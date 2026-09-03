import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../errors/failures.dart';
import '../errors/result.dart';
import 'image_codec.dart';

/// Strips identifying metadata from an exported copy (Privacy sections 40-41,
/// Functional PRI-010, Build Specification section 49).
///
/// Operates on a **copy**. The original file and its metadata are untouched
/// (Privacy section 42: original metadata preservation).
///
/// Build Specification section 49 requires documenting exactly what is removed,
/// so [removedFields] is the authoritative list and is asserted by
/// `test/privacy/anonymization_test.dart`.
class MetadataAnonymizer {
  const MetadataAnonymizer();

  /// Exactly what an anonymized export drops.
  static const List<String> removedFields = <String>[
    'GPS latitude, longitude and altitude',
    'GPS timestamp and processing method',
    'Camera make and model',
    'Camera serial number and lens serial number',
    'Software and firmware identifiers',
    'Owner and artist name',
    'Copyright',
    'User comment and image description',
    'Original and digitised timestamps (when the date option is off)',
    'Maker note (vendor-specific block)',
  ];

  /// What is kept, because it describes the photograph rather than the person
  /// or device, and is useful for reproducibility.
  static const List<String> retainedFields = <String>[
    'Pixel dimensions',
    'Orientation',
    'Exposure time, ISO and aperture',
    'Focal length',
    'Flash state',
  ];

  /// Re-encodes [bytes] without identifying metadata.
  ///
  /// [keepTimestamps] false also drops the capture date, which the user chooses
  /// per export (Functional PRI-010: "timestamps where selected").
  Result<Uint8List> anonymize(
    Uint8List bytes, {
    bool keepTimestamps = false,
    int quality = 92,
  }) {
    final decoded = ImageCodec.decode(bytes);
    if (decoded == null) {
      return const Result.failed(
        UnreadableImage(technicalDetail: 'anonymization source failed'),
      );
    }

    final exif = decoded.exif;

    // GPS is removed unconditionally. Location is never needed for reproducible
    // clinical photography, so it has no place in a shared copy
    // (Privacy PRI-001, Data Model section 52).
    exif.gpsIfd.data.clear();
    exif.gpsIfd.sub.directories.clear();

    for (final tag in const <String>[
      'Make',
      'Model',
      'Software',
      'Artist',
      'Copyright',
      'ImageDescription',
      'HostComputer',
      'CameraOwnerName',
      'BodySerialNumber',
      'LensSerialNumber',
      'LensMake',
      'LensModel',
      'MakerNote',
      'UserComment',
    ]) {
      exif.imageIfd[tag] = null;
      exif.exifIfd[tag] = null;
    }

    if (!keepTimestamps) {
      for (final tag in const <String>[
        'DateTime',
        'DateTimeOriginal',
        'DateTimeDigitized',
        'SubSecTime',
        'SubSecTimeOriginal',
        'SubSecTimeDigitized',
      ]) {
        exif.imageIfd[tag] = null;
        exif.exifIfd[tag] = null;
      }
    }

    return Result.ok(
      Uint8List.fromList(img.encodeJpg(decoded, quality: quality)),
    );
  }

  /// Whether an encoded image still carries any identifying metadata.
  /// Used by the privacy test rather than by the app.
  bool hasIdentifyingMetadata(Uint8List bytes) {
    final decoded = ImageCodec.decode(bytes);
    if (decoded == null) return false;
    final exif = decoded.exif;

    if (!exif.gpsIfd.isEmpty) return true;
    for (final tag in const <String>[
      'Make',
      'Model',
      'Software',
      'Artist',
      'CameraOwnerName',
      'BodySerialNumber',
    ]) {
      if (exif.imageIfd[tag] != null || exif.exifIfd[tag] != null) return true;
    }
    return false;
  }
}
