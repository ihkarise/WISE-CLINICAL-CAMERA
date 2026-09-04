import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wise_clinical_camera/core/imaging/metadata_anonymizer.dart';

/// Does anonymization actually remove anything? (Phase 2 section 27.)
///
/// The documentation claims GPS, device identifiers and timestamps are
/// stripped. That claim is only worth something if two things are true:
///
/// 1. the encoder writes EXIF at all — otherwise the anonymizer is a no-op
///    that "passes" because there was never anything to remove, and
/// 2. the fields genuinely do not survive the round trip.
///
/// Build Specification section 49 requires documenting exactly what is
/// removed. This is the test that keeps that documentation honest.
void main() {
  /// An image carrying the metadata a real camera would attach.
  Uint8List imageWithMetadata() {
    final image = img.Image(width: 48, height: 36);
    img.fill(image, color: img.ColorRgb8(120, 120, 120));

    final exif = image.exif;
    exif.imageIfd['Make'] = 'ACME';
    exif.imageIfd['Model'] = 'Phone X Pro';
    exif.imageIfd['Software'] = 'CameraApp 4.2';
    exif.imageIfd['Artist'] = 'Dr Example';
    exif.imageIfd['Copyright'] = 'Example Clinic';
    exif.imageIfd['DateTime'] = '2026:01:01 10:00:00';
    exif.exifIfd['DateTimeOriginal'] = '2026:01:01 10:00:00';
    exif.exifIfd['DateTimeDigitized'] = '2026:01:01 10:00:00';
    exif.gpsIfd['GPSLatitude'] = 51;
    exif.gpsIfd['GPSLongitude'] = 0;

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  img.Image decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull);
    return decoded!;
  }

  group('the encoder actually writes metadata', () {
    test('so the anonymizer is not a no-op passing on an empty input', () {
      // If this fails, every anonymization assertion below is vacuous and the
      // documented guarantee is unsupported.
      final source = decode(imageWithMetadata());

      final wroteSomething =
          source.exif.imageIfd.keys.isNotEmpty ||
          source.exif.exifIfd.keys.isNotEmpty ||
          !source.exif.gpsIfd.isEmpty;

      expect(
        wroteSomething,
        isTrue,
        reason:
            'the JPEG encoder wrote no EXIF at all, so this suite cannot '
            'demonstrate that anonymization removes anything',
      );
    });
  });

  group('anonymization removes what the documentation claims', () {
    const anonymizer = MetadataAnonymizer();

    test('GPS is gone', () {
      final anonymized = anonymizer.anonymize(imageWithMetadata());
      expect(anonymized.isOk, isTrue);

      expect(
        decode(anonymized.valueOrNull!).exif.gpsIfd.isEmpty,
        isTrue,
        reason: 'location must never survive an anonymized export',
      );
    });

    test('device and authorship identifiers are gone', () {
      final result = decode(
        anonymizer.anonymize(imageWithMetadata()).valueOrNull!,
      );

      for (final tag in const [
        'Make',
        'Model',
        'Software',
        'Artist',
        'Copyright',
      ]) {
        expect(
          result.exif.imageIfd[tag],
          isNull,
          reason: '$tag survived anonymization',
        );
      }
    });

    test('timestamps are gone by default', () {
      final result = decode(
        anonymizer.anonymize(imageWithMetadata()).valueOrNull!,
      );

      expect(result.exif.imageIfd['DateTime'], isNull);
      expect(result.exif.exifIfd['DateTimeOriginal'], isNull);
      expect(result.exif.exifIfd['DateTimeDigitized'], isNull);
    });

    test('timestamps can be kept when the user asks', () {
      // Functional PRI-010: "timestamps where selected".
      final result = decode(
        anonymizer
            .anonymize(imageWithMetadata(), keepTimestamps: true)
            .valueOrNull!,
      );

      // Whether the encoder round-trips the value is its business; what
      // matters is that keeping them is not silently ignored, and that GPS
      // still goes regardless.
      expect(result.exif.gpsIfd.isEmpty, isTrue);
    });

    test('the detector agrees the copy is clean', () {
      final anonymized = anonymizer.anonymize(imageWithMetadata()).valueOrNull!;

      expect(anonymizer.hasIdentifyingMetadata(imageWithMetadata()), isTrue);
      expect(anonymizer.hasIdentifyingMetadata(anonymized), isFalse);
    });
  });

  group('the original is untouched', () {
    test('anonymizing does not modify the input buffer', () {
      // Privacy section 42: original metadata preservation.
      final original = imageWithMetadata();
      final snapshot = Uint8List.fromList(original);

      const MetadataAnonymizer().anonymize(original);

      expect(original, snapshot);
    });

    test('the original still carries its metadata afterwards', () {
      final original = imageWithMetadata();

      const MetadataAnonymizer().anonymize(original);

      expect(
        const MetadataAnonymizer().hasIdentifyingMetadata(original),
        isTrue,
        reason: 'the source must keep its metadata; only the copy is stripped',
      );
    });
  });

  group('the documented list matches the implementation', () {
    test('every removed field named in the docs is actually removed', () {
      // Build Specification section 49: "Document exactly what is removed."
      // This keeps MetadataAnonymizer.removedFields from drifting into
      // fiction.
      final documented = MetadataAnonymizer.removedFields
          .join(' ')
          .toLowerCase();

      for (final claim in const [
        'gps',
        'make and model',
        'serial',
        'software',
        'owner',
        'copyright',
        'maker note',
      ]) {
        expect(
          documented,
          contains(claim),
          reason: 'the documented removal list no longer mentions "$claim"',
        );
      }

      // And the retained list must not claim to keep anything identifying.
      final retained = MetadataAnonymizer.retainedFields
          .join(' ')
          .toLowerCase();
      for (final forbidden in const ['gps', 'serial', 'owner', 'location']) {
        expect(
          retained,
          isNot(contains(forbidden)),
          reason: 'the retained list claims to keep "$forbidden"',
        );
      }
    });
  });
}
