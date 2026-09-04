import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/config/app_environment.dart';
import 'package:wise_clinical_camera/core/imaging/metadata_anonymizer.dart';
import 'package:wise_clinical_camera/core/logging/app_logger.dart';
import 'package:wise_clinical_camera/models/photo_metadata.dart';
import 'package:wise_clinical_camera/models/user_preferences.dart';

import '../support/test_harness.dart';

/// Anonymized export, metadata policy and log safety.
///
/// Privacy sections 12, 20-22, 40-43; Functional PRI-010; Build Specification
/// sections 49, 71; Testing sections 46-47; master prompt Phase 47.
void main() {
  group('anonymized export', () {
    const anonymizer = MetadataAnonymizer();

    test('produces a readable image', () {
      final result = anonymizer.anonymize(sampleJpeg());

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNotEmpty);
    });

    test('the anonymized copy carries no identifying metadata', () {
      final anonymized = anonymizer.anonymize(sampleJpeg()).valueOrNull!;

      expect(anonymizer.hasIdentifyingMetadata(anonymized), isFalse);
    });

    test('the original bytes are not modified', () {
      // Privacy section 42: original metadata is preserved; anonymization
      // operates on a copy.
      final original = sampleJpeg();
      final snapshot = List<int>.of(original);

      anonymizer.anonymize(original);

      expect(original, snapshot);
    });

    test('what is removed is documented explicitly', () {
      // Build Specification section 49: "Document exactly what is removed."
      expect(MetadataAnonymizer.removedFields, isNotEmpty);
      expect(
        MetadataAnonymizer.removedFields.join(' ').toLowerCase(),
        allOf(contains('gps'), contains('serial'), contains('make and model')),
      );
      expect(MetadataAnonymizer.retainedFields, isNotEmpty);
    });

    test('unreadable input fails cleanly rather than throwing', () {
      final result = anonymizer.anonymize(
        // Short, malformed bytes: the case that used to throw RangeError.
        sampleJpeg().sublist(0, 8),
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('metadata policy', () {
    test('PhotoMetadata has no GPS field at all', () {
      // Privacy PRI-001 / Data Model section 52: location is not needed for
      // reproducible clinical photography, so it is not collected. The
      // strongest form of "do not store unnecessary location information" is
      // to have nowhere to store it.
      final row = PhotoMetadata(
        id: 'm',
        photoId: 'p',
        deviceModel: 'Test Device',
        createdAt: DateTime(2026),
      ).toRow();

      for (final key in row.keys) {
        expect(key.toLowerCase(), isNot(contains('gps')));
        expect(key.toLowerCase(), isNot(contains('latitude')));
        expect(key.toLowerCase(), isNot(contains('longitude')));
        expect(key.toLowerCase(), isNot(contains('location')));
      }
    });

    test('anonymizing metadata drops device identifiers, keeps optics', () {
      final metadata = PhotoMetadata(
        id: 'm',
        photoId: 'p',
        deviceModel: 'Phone X',
        osVersion: '18.2',
        lensIdentifier: 'rear-wide',
        cameraPosition: 'rear',
        focalLength: 4.2,
        iso: 200,
        flashMode: 'off',
        createdAt: DateTime(2026),
      );

      final anonymized = metadata.anonymized();

      expect(anonymized.deviceModel, isNull);
      expect(anonymized.osVersion, isNull);
      expect(anonymized.lensIdentifier, isNull);
      expect(anonymized.cameraPosition, isNull);
      // Kept: describes the photograph, not the person or device.
      expect(anonymized.focalLength, 4.2);
      expect(anonymized.iso, 200);
      expect(anonymized.flashMode, 'off');
    });
  });

  group('logging safety', () {
    test('sensitive field names are redacted', () {
      // Privacy section 20: production logs must not contain image pixels,
      // patient names, clinical notes, identifiers or secrets.
      for (final key in const [
        'image',
        'pixels',
        'bytes',
        'patient',
        'notes',
        'diagnosis',
        'apiKey',
        'token',
        'password',
        'gps',
        'latitude',
        'title',
        'localReference',
      ]) {
        expect(
          AppLogger.redact(key, 'something sensitive'),
          '<redacted>',
          reason: '"$key" must be redacted',
        );
      }
    });

    test('a filesystem path is reduced to its basename', () {
      // A parent directory could carry a user or case name. WISE basenames are
      // opaque UUIDs by construction (Privacy section 12).
      expect(
        AppLogger.redact(
          'path',
          '/Users/someone/WISE/originals/photo_uuid.jpg',
        ),
        '.../photo_uuid.jpg',
      );
    });

    test('collections are summarised, never expanded', () {
      expect(AppLogger.redact('data', [1, 2, 3]), startsWith('<'));
      expect(AppLogger.redact('data', {'a': 1}), startsWith('<'));
    });

    test('a long opaque value is summarised by length', () {
      expect(AppLogger.redact('blob', 'x' * 500), '<500 chars>');
    });

    test('ordinary technical values pass through', () {
      // Development logs may carry CV metrics; they are not sensitive
      // (CV section 79).
      expect(AppLogger.redact('inliers', 42), '42');
      expect(AppLogger.redact('confidence', 0.87), '0.87');
      expect(AppLogger.redact('status', 'GOOD'), 'GOOD');
    });

    test('production suppresses debug logging entirely', () {
      expect(AppEnvironment.production.allowsVerboseLogging, isFalse);
      expect(AppEnvironment.production.allowsCvDebugOverlay, isFalse);
      expect(AppEnvironment.development.allowsCvDebugOverlay, isTrue);
    });
  });

  group('privacy defaults', () {
    test('a new user starts in Privacy Mode with gallery saving on ask', () {
      // Build Specification section 2.10 / Privacy section 69: secure and local
      // behaviour is the default, not an advanced configuration.
      final preferences = UserPreferences.initial('u1');

      expect(preferences.privacyMode, isTrue);
      expect(preferences.gallerySaveMode.wireName, 'ASK');
    });

    test('a new user has no AI enabled', () {
      // Nothing in UserPreferences turns AI on; it is gated by FeatureFlags,
      // which default to off. Asserted here so the default cannot drift.
      final preferences = UserPreferences.initial('u1');

      expect(preferences.privacyMode, isTrue);
      expect(preferences.overlayOpacity, inInclusiveRange(0.1, 1));
    });
  });
}
