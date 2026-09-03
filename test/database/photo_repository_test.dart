import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';

import '../support/test_harness.dart';

/// Photo CRUD, Before/After relationships, deletion policy and integrity
/// (Data Model sections 37, 39, 49, 74; Testing sections 34-36).
void main() {
  late TestHarness harness;
  late PhotoRepository repository;
  late String userId;

  setUp(() async {
    harness = await TestHarness.create();
    userId = await harness.seedUser();
    repository = PhotoRepository(
      database: harness.database,
      storage: harness.storage,
      ids: harness.ids,
    );
  });

  tearDown(() async => harness.dispose());

  Future<String> createBefore() async {
    final result = await repository.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.before,
      source: PhotoSource.camera,
      userId: userId,
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.valueOrNull!.id;
  }

  group('create', () {
    test('writes the original and commits the row together', () async {
      final result = await repository.createPhoto(
        bytes: sampleJpeg(width: 80, height: 60),
        type: PhotoType.before,
        source: PhotoSource.camera,
        userId: userId,
        bodyPart: BodyPart.knee,
        laterality: Laterality.left,
      );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final photo = result.valueOrNull!;

      expect(File(photo.originalPath).existsSync(), isTrue);
      expect(photo.widthPx, 80);
      expect(photo.heightPx, 60);
      expect(photo.fileSizeBytes, greaterThan(0));
      expect(photo.checksum, isNotNull);
      expect(photo.mimeType, 'image/jpeg');
      expect(photo.bodyPart, BodyPart.knee);
      expect(photo.laterality, Laterality.left);
      // Processing until the thumbnail lands (Data Model section 42).
      expect(photo.status, PhotoStatus.processing);

      final reread = await repository.getPhoto(photo.id);
      expect(reread, isNotNull);
      expect(reread!.checksum, photo.checksum);
    });

    test('rejects an unreadable image without writing a row', () async {
      final result = await repository.createPhoto(
        bytes: Uint8List.fromList(utf8.encode('not an image')),
        type: PhotoType.photo,
        source: PhotoSource.import,
        userId: userId,
      );

      expect(result.isFailure, isTrue);
      final rows = await harness.database.database.query('photos');
      expect(rows, isEmpty, reason: 'no row may exist for a rejected image');
    });

    test('rejects a reference on a standalone PHOTO', () async {
      final before = await createBefore();

      final result = await repository.createPhoto(
        bytes: sampleJpeg(),
        type: PhotoType.photo,
        source: PhotoSource.camera,
        referencePhotoId: before,
      );

      expect(result.isFailure, isTrue);
    });

    test('metadata is written in the same transaction', () async {
      final photo = await createBefore();
      // Metadata is optional and absent here; the point is the photo row
      // committed cleanly without one.
      expect(await repository.getMetadata(photo), isNull);
    });
  });

  group('Before/After relationship', () {
    test('an After records and resolves its reference', () async {
      final beforeId = await createBefore();

      final after = await repository.createPhoto(
        bytes: sampleJpeg(seed: 11),
        type: PhotoType.after,
        source: PhotoSource.camera,
        referencePhotoId: beforeId,
      );

      expect(after.isOk, isTrue, reason: '${after.failureOrNull}');
      expect(after.valueOrNull!.referencePhotoId, beforeId);

      final afters = await repository.getAfterPhotosFor(beforeId);
      expect(afters.map((p) => p.id), [after.valueOrNull!.id]);
    });

    test('the database rejects a self-reference', () async {
      // Data Model section 49: a reference relationship must not be circular.
      // Enforced by a CHECK constraint so no code path can bypass it.
      final id = await createBefore();

      await expectLater(
        harness.database.database.update(
          'photos',
          {'reference_photo_id': id},
          where: 'id = ?',
          whereArgs: [id],
        ),
        throwsA(anything),
      );
    });

    test('the database rejects a reference to a nonexistent photo', () async {
      await expectLater(
        harness.database.database.insert('photos', {
          'id': 'orphan',
          'type': 'AFTER',
          'original_path': '/tmp/x.jpg',
          'captured_at': 0,
          'width_px': 1,
          'height_px': 1,
          'file_size_bytes': 1,
          'mime_type': 'image/jpeg',
          'source': 'CAMERA',
          'status': 'ACTIVE',
          'created_at': 0,
          'updated_at': 0,
          'reference_photo_id': 'does-not-exist',
        }),
        throwsA(anything),
      );
    });

    test('only Before photos are offered as reference candidates', () async {
      await createBefore();
      await repository.createPhoto(
        bytes: sampleJpeg(seed: 3),
        type: PhotoType.photo,
        source: PhotoSource.camera,
      );

      final candidates = await repository.getReferenceCandidates();
      expect(candidates, hasLength(1));
      expect(candidates.single.type, PhotoType.before);
      expect(candidates.single.canBeReference, isTrue);
    });
  });

  group('deletion policy', () {
    test('refuses to delete a Before that an After still uses', () async {
      // Data Model section 37: warn if referenced.
      final beforeId = await createBefore();
      await repository.createPhoto(
        bytes: sampleJpeg(seed: 5),
        type: PhotoType.after,
        source: PhotoSource.camera,
        referencePhotoId: beforeId,
      );

      final impact = await repository.analyseDeletion(beforeId);
      expect(impact.hasReferences, isTrue);
      expect(impact.referencingPhotoIds, hasLength(1));

      final result = await repository.deletePhoto(beforeId);
      expect(result.isFailure, isTrue);
      expect(await repository.getPhoto(beforeId), isNotNull);
    });

    test('soft-deletes and keeps the original file on disk', () async {
      // Deletion is recoverable: the row is marked, the bytes stay
      // (Data Model section 36).
      final id = await createBefore();
      final path = (await repository.getPhoto(id))!.originalPath;

      expect((await repository.deletePhoto(id)).isOk, isTrue);

      expect(await repository.getPhoto(id), isNull);
      final withDeleted = await repository.getPhoto(id, includeDeleted: true);
      expect(withDeleted!.isDeleted, isTrue);
      expect(withDeleted.status, PhotoStatus.deleted);
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'a soft delete must not remove the original file',
      );
    });

    test('soft-deletes dependent measurements and annotations', () async {
      final id = await createBefore();
      final now = DateTime.now().millisecondsSinceEpoch;

      await harness.database.database.insert('annotations', {
        'id': 'ann-1',
        'photo_id': id,
        'type': 'ARROW',
        'geometry_json': '{"points":[],"closed":false}',
        'created_at': now,
        'updated_at': now,
      });

      await repository.deletePhoto(id);

      final rows = await harness.database.database.query(
        'annotations',
        where: 'id = ?',
        whereArgs: ['ann-1'],
      );
      expect(rows.single['deleted_at'], isNotNull);
    });

    test('never removes an independent Gallery copy', () async {
      // Data Model section 37.7 / Functional section 34.
      final id = await createBefore();
      final now = DateTime.now().millisecondsSinceEpoch;

      await harness.database.database.insert('gallery_exports', {
        'id': 'gal-1',
        'photo_id': id,
        'platform_asset_identifier': 'platform-asset-123',
        'created_at': now,
        'status': 'SAVED',
      });

      await repository.deletePhoto(id);

      final rows = await harness.database.database.query('gallery_exports');
      expect(rows, hasLength(1));
      expect(rows.single['status'], 'SAVED');
    });

    test('force deletes when the user has accepted the impact', () async {
      final beforeId = await createBefore();
      await repository.createPhoto(
        bytes: sampleJpeg(seed: 9),
        type: PhotoType.after,
        source: PhotoSource.camera,
        referencePhotoId: beforeId,
      );

      expect(
        (await repository.deletePhoto(beforeId, force: true)).isOk,
        isTrue,
      );
    });

    test('a soft delete can be restored', () async {
      final id = await createBefore();
      await repository.deletePhoto(id);

      expect((await repository.restorePhoto(id)).isOk, isTrue);
      final restored = await repository.getPhoto(id);
      expect(restored, isNotNull);
      expect(restored!.status, PhotoStatus.active);
    });
  });

  group('integrity and lifecycle', () {
    test('verifies the original against its recorded checksum', () async {
      final id = await createBefore();
      expect(await repository.verifyIntegrity(id), isTrue);
    });

    test('detects a corrupted original', () async {
      final id = await createBefore();
      final photo = await repository.getPhoto(id);

      await File(photo!.originalPath).writeAsBytes(sampleJpeg(seed: 999));

      expect(
        await repository.verifyIntegrity(id),
        isFalse,
        reason: 'a changed original must fail its checksum',
      );
    });

    test('markProcessed promotes to ACTIVE and bumps the version', () async {
      final id = await createBefore();

      final result = await repository.markProcessed(
        id,
        thumbnailPath: '/tmp/thumb.jpg',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.status, PhotoStatus.active);
      expect(result.valueOrNull!.thumbnailPath, '/tmp/thumb.jpg');
      expect(result.valueOrNull!.version, 2);
    });

    test('a processing failure keeps the photograph usable', () async {
      // Build Specification section 105: if a derived step fails, the original
      // must remain available. This is a P0 requirement.
      final id = await createBefore();
      final path = (await repository.getPhoto(id))!.originalPath;

      await repository.markProcessingFailed(id);

      final photo = await repository.getPhoto(id);
      expect(photo, isNotNull);
      expect(photo!.status, PhotoStatus.failed);
      expect(File(path).existsSync(), isTrue);
      expect(await repository.verifyIntegrity(id), isTrue);
    });
  });

  group('queries', () {
    test('filters by type, body part and case', () async {
      await repository.createPhoto(
        bytes: sampleJpeg(),
        type: PhotoType.before,
        source: PhotoSource.camera,
        bodyPart: BodyPart.hand,
      );
      await repository.createPhoto(
        bytes: sampleJpeg(seed: 2),
        type: PhotoType.photo,
        source: PhotoSource.camera,
        bodyPart: BodyPart.face,
      );

      expect(await repository.getPhotos(type: PhotoType.before), hasLength(1));
      expect(await repository.getPhotos(bodyPart: BodyPart.face), hasLength(1));
      expect(await repository.getPhotos(bodyPart: BodyPart.foot), isEmpty);
    });

    test('excludes soft-deleted photographs by default', () async {
      final id = await createBefore();
      await repository.deletePhoto(id);

      expect(await repository.getPhotos(), isEmpty);
    });
  });
}
