import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/local_alignment_engine.dart';
import 'package:wise_clinical_camera/core/cv/working_image.dart';
import 'package:wise_clinical_camera/core/imaging/image_codec.dart';
import 'package:wise_clinical_camera/core/imaging/layer_renderer.dart';
import 'package:wise_clinical_camera/core/imaging/layer_stack.dart';
import 'package:wise_clinical_camera/core/imaging/metadata_anonymizer.dart';
import 'package:wise_clinical_camera/core/imaging/thumbnail_generator.dart';
import 'package:wise_clinical_camera/features/comparison/difference_view.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/photo.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';

import '../support/test_harness.dart';

/// Malformed input must fail cleanly, never throw (Phase 2 section 13,
/// Build Specification sections 91-92).
///
/// This is a regression suite for a real defect: `package:image`'s
/// `decodeImage` probes each format in turn, and several probes read past the
/// end of a short buffer and throw `RangeError` rather than returning null. A
/// truncated download, a partially written file or a mislabelled extension
/// would have crashed the application.
///
/// Every decode in `lib/` now routes through `ImageCodec`, which cannot throw.
/// These tests hold that true at every call site, not just at the codec.
void main() {
  /// Input that cannot yield an image under any decoder.
  ///
  /// For these the contract is strict: decoding returns null and every
  /// consumer produces a typed failure.
  final undecodable = <String, Uint8List>{
    'empty': Uint8List(0),
    'one byte': Uint8List.fromList([0xFF]),
    'JPEG magic only': Uint8List.fromList([0xFF, 0xD8, 0xFF]),
    'truncated JPEG header': sampleJpeg().sublist(0, 8),
    'PNG magic only': Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]),
    'truncated PNG': Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
    ]),
    'plain text': Uint8List.fromList(utf8.encode('this is not an image')),
    'all zeroes': Uint8List(512),
    'all 0xFF': Uint8List.fromList(List<int>.filled(512, 0xFF)),
    'JPEG header, garbage body': Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      ...List<int>.filled(256, 0x7F),
    ]),
  };

  /// Input that is damaged but that a tolerant decoder may still turn into a
  /// (partial, wrong-looking) image.
  ///
  /// JPEG decoders are deliberately forgiving — a truncated scan yields the
  /// rows that arrived. That is legitimate behaviour, not a defect, so the
  /// contract here is only the universal one: **it must never throw**. Whether
  /// it decodes is the decoder's business.
  ///
  /// Truncation is caught where it actually matters instead: `storeOriginal`
  /// compares the bytes written against the bytes supplied, and the SHA-256
  /// recorded at capture detects later corruption on disk.
  final damagedButPossiblyDecodable = <String, Uint8List>{
    'truncated JPEG body': sampleJpeg().sublist(0, sampleJpeg().length ~/ 3),
    'valid JPEG with the middle zeroed': () {
      final bytes = Uint8List.fromList(sampleJpeg(width: 64, height: 64));
      for (var i = bytes.length ~/ 3; i < bytes.length ~/ 2; i++) {
        bytes[i] = 0x00;
      }
      return bytes;
    }(),
  };

  final everything = <String, Uint8List>{
    ...undecodable,
    ...damagedButPossiblyDecodable,
  };

  group('ImageCodec never throws, whatever it is handed', () {
    everything.forEach((name, bytes) {
      test(name, () {
        expect(() => ImageCodec.decode(bytes), returnsNormally);
        expect(() => ImageCodec.probeDimensions(bytes), returnsNormally);
      });
    });

    test('a valid image still decodes', () {
      final decoded = ImageCodec.decode(sampleJpeg(width: 40, height: 30));

      expect(decoded, isNotNull);
      expect(ImageCodec.probeDimensions(sampleJpeg(width: 40, height: 30)), (
        width: 40,
        height: 30,
      ));
    });
  });

  group('every consumer degrades to a typed failure', () {
    const generator = ThumbnailGenerator();
    const renderer = LayerRenderer();
    const anonymizer = MetadataAnonymizer();

    undecodable.forEach((name, bytes) {
      test('thumbnail generation: $name', () {
        expect(generator.generate(bytes).isFailure, isTrue);
      });

      test('layer rendering: $name', () {
        final result = renderer.render(
          originalBytes: bytes,
          stack: const LayerStack(
            originalPath: '/x.jpg',
            widthPx: 10,
            heightPx: 10,
            gridType: GridType.thirds,
          ),
        );
        expect(result.isFailure, isTrue);
      });

      test('anonymization: $name', () {
        expect(anonymizer.anonymize(bytes).isFailure, isTrue);
      });

      test('CV working image: $name', () {
        expect(WorkingImage.fromBytes(bytes), isNull);
      });

      test('difference view: $name', () {
        expect(computeDifference((before: bytes, after: sampleJpeg())), isNull);
        expect(computeDifference((before: sampleJpeg(), after: bytes)), isNull);
      });
    });

    damagedButPossiblyDecodable.forEach((name, bytes) {
      test('damaged input never throws anywhere: \$name', () {
        expect(() => generator.generate(bytes), returnsNormally);
        expect(
          () => renderer.render(
            originalBytes: bytes,
            stack: const LayerStack(
              originalPath: '/x.jpg',
              widthPx: 10,
              heightPx: 10,
            ),
          ),
          returnsNormally,
        );
        expect(() => anonymizer.anonymize(bytes), returnsNormally);
        expect(() => WorkingImage.fromBytes(bytes), returnsNormally);
        expect(
          () => computeDifference((before: bytes, after: sampleJpeg())),
          returnsNormally,
        );
      });
    });

    test('a paired render with one corrupt side fails, not throws', () {
      final result = renderer.renderPair(
        beforeBytes: sampleJpeg(),
        afterBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('alignment engine', () {
    test('refuses an undecodable reference without throwing', () async {
      final engine = LocalAlignmentEngine();

      for (final entry in undecodable.entries) {
        final result = await engine.prepareReference(
          photoId: 'p',
          imageBytes: entry.value,
        );
        expect(
          result.isFailure,
          isTrue,
          reason: '${entry.key} must fail, not succeed',
        );
      }
    });

    test('a corrupt target yields unavailable, not a match', () async {
      final engine = LocalAlignmentEngine();

      final result = await engine.align(
        referenceBytes: sampleJpeg(width: 200, height: 200),
        targetBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      );

      expect(result.status, AlignmentStatus.unavailable);
      expect(result.confidence, 0);
    });
  });

  group('storage rejects unreadable input before any row is written', () {
    late TestHarness harness;
    late PhotoRepository repository;

    setUp(() async {
      harness = await TestHarness.create();
      await harness.seedUser();
      repository = PhotoRepository(
        database: harness.database,
        storage: harness.storage,
        ids: harness.ids,
      );
    });

    tearDown(() async => harness.dispose());

    test('no photo row survives an undecodable capture', () async {
      for (final entry in undecodable.entries) {
        final result = await repository.createPhoto(
          bytes: entry.value,
          type: PhotoType.photo,
          source: PhotoSource.camera,
        );
        expect(
          result.isFailure,
          isTrue,
          reason: '${entry.key} must be rejected',
        );
      }

      final rows = await harness.database.database.query('photos');
      expect(
        rows,
        isEmpty,
        reason: 'a rejected image must leave no row behind',
      );
    });

    test('no orphaned file survives a corrupt capture', () async {
      await repository.createPhoto(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        type: PhotoType.photo,
        source: PhotoSource.camera,
      );

      final originals = harness.paths.originals
          .listSync()
          .whereType<Object>()
          .toList();
      final temporary = harness.paths.temp.listSync().toList();

      expect(originals, isEmpty, reason: 'no original may be written');
      expect(temporary, isEmpty, reason: 'no temporary file may be left');
    });

    test('a valid capture still succeeds afterwards', () async {
      // The failure path must not leave the service in a broken state.
      await repository.createPhoto(
        bytes: Uint8List(4),
        type: PhotoType.photo,
        source: PhotoSource.camera,
      );

      final good = await repository.createPhoto(
        bytes: sampleJpeg(),
        type: PhotoType.before,
        source: PhotoSource.camera,
      );

      expect(good.isOk, isTrue);
      expect(await repository.verifyIntegrity(good.valueOrNull!.id), isTrue);
    });
  });

  group('a corrupted original on disk is detected, never silently used', () {
    test('integrity verification fails and reports it', () async {
      final harness = await TestHarness.create();
      addTearDown(harness.dispose);
      await harness.seedUser();

      final repository = PhotoRepository(
        database: harness.database,
        storage: harness.storage,
        ids: harness.ids,
      );

      final created = await repository.createPhoto(
        bytes: sampleJpeg(),
        type: PhotoType.before,
        source: PhotoSource.camera,
      );
      final photo = created.valueOrNull!;
      expect(await repository.verifyIntegrity(photo.id), isTrue);

      // Corrupt the file on disk, as a failing card or a bad sector would.
      await _writeCorrupt(photo);

      expect(
        await repository.verifyIntegrity(photo.id),
        isFalse,
        reason: 'a changed original must fail its checksum',
      );

      // And the record is still readable, so the user can be told rather than
      // the app crashing.
      expect(await repository.getPhoto(photo.id), isNotNull);
    });
  });
}

Future<void> _writeCorrupt(Photo photo) => File(
  photo.originalPath,
).writeAsBytes(Uint8List.fromList([0xFF, 0xD8, 0x00, 0x00]));
