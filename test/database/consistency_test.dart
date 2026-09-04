import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/storage/maintenance_service.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';

import '../support/test_harness.dart';

/// Database/filesystem consistency (Phase 2 section 35, Data Model section 68,
/// Build Specification section 106).
///
/// The rule that shapes every assertion here, from Data Model section 68:
///
/// > "The repair service should never delete an original automatically merely
/// > because it appears orphaned."
void main() {
  late TestHarness harness;
  late PhotoRepository photos;
  late MaintenanceService maintenance;

  setUp(() async {
    harness = await TestHarness.create();
    await harness.seedUser();
    photos = PhotoRepository(
      database: harness.database,
      storage: harness.storage,
      ids: harness.ids,
    );
    maintenance = MaintenanceService(
      database: harness.database,
      storage: harness.storage,
    );
  });

  tearDown(() async => harness.dispose());

  Future<String> createPhoto({PhotoType type = PhotoType.before}) async {
    final result = await photos.createPhoto(
      bytes: sampleJpeg(),
      type: type,
      source: PhotoSource.camera,
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.valueOrNull!.id;
  }

  group('a healthy library', () {
    test('scans clean', () async {
      await createPhoto();
      final report = await maintenance.scan(verifyChecksums: true);

      expect(report.isClean, isTrue, reason: report.summary);
      expect(report.photosChecked, 1);
      expect(report.summary, 'No problems found.');
    });
  });

  group('record exists, file missing', () {
    test('is reported as critical', () async {
      final id = await createPhoto();
      final photo = await photos.getPhoto(id);
      await File(photo!.originalPath).delete();

      final report = await maintenance.scan();

      final issues = report.ofKind(ConsistencyIssueKind.missingOriginal);
      expect(issues, hasLength(1));
      expect(issues.single.severity, IssueSeverity.critical);
      expect(issues.single.photoId, id);
      expect(report.critical, isNotEmpty);
    });

    test('repair does not delete the record', () async {
      // The measurements and annotations attached to it are still meaningful,
      // and the file may be restorable from a backup.
      final id = await createPhoto();
      await File((await photos.getPhoto(id))!.originalPath).delete();

      final outcome = await maintenance.repair(await maintenance.scan());

      expect(outcome.leftForTheUser, hasLength(1));
      expect(
        await photos.getPhoto(id),
        isNotNull,
        reason: 'the record must survive for the user to decide about',
      );
    });
  });

  group('file exists, record missing', () {
    test('is reported but never deleted', () async {
      // The most dangerous case: this file may be the only remaining copy of a
      // photograph whose row was lost.
      final stray = File('${harness.paths.originals.path}/photo_stray.jpg')
        ..writeAsBytesSync(sampleJpeg());

      final report = await maintenance.scan();

      final issues = report.ofKind(ConsistencyIssueKind.unreferencedOriginal);
      expect(issues, hasLength(1));
      expect(issues.single.description, contains('NOT been deleted'));

      await maintenance.repair(report);

      expect(
        stray.existsSync(),
        isTrue,
        reason: 'an unreferenced original must never be deleted automatically',
      );
    });
  });

  group('corrupted original', () {
    test('is detected only when checksums are verified', () async {
      final id = await createPhoto();
      final photo = await photos.getPhoto(id);
      await File(photo!.originalPath).writeAsBytes(sampleJpeg(seed: 999));

      // A cheap scan does not read every file.
      expect(
        (await maintenance.scan()).ofKind(
          ConsistencyIssueKind.corruptedOriginal,
        ),
        isEmpty,
      );

      final deep = await maintenance.scan(verifyChecksums: true);
      expect(deep.ofKind(ConsistencyIssueKind.corruptedOriginal), hasLength(1));
      expect(deep.critical, isNotEmpty);
    });

    test('repair leaves the corrupted file alone', () async {
      final id = await createPhoto();
      final photo = await photos.getPhoto(id);
      await File(photo!.originalPath).writeAsBytes(sampleJpeg(seed: 999));

      final report = await maintenance.scan(verifyChecksums: true);
      final outcome = await maintenance.repair(report);

      expect(outcome.leftForTheUser, isNotEmpty);
      expect(File(photo.originalPath).existsSync(), isTrue);
    });
  });

  group('missing thumbnail', () {
    test('is minor and safely repaired by clearing the path', () async {
      final id = await createPhoto();
      final thumbnail = File(harness.paths.thumbnailFile(id))
        ..writeAsBytesSync(sampleJpeg(width: 32, height: 32));
      await photos.markProcessed(id, thumbnailPath: thumbnail.path);
      await thumbnail.delete();

      final report = await maintenance.scan();
      expect(
        report.ofKind(ConsistencyIssueKind.missingThumbnail),
        hasLength(1),
      );
      expect(report.critical, isEmpty);

      final outcome = await maintenance.repair(report);

      expect(outcome.thumbnailsCleared, 1);
      // The dangling path is gone, so the library falls back to the original.
      expect((await photos.getPhoto(id))!.thumbnailPath, isNull);
      // And a rescan is clean.
      expect(
        (await maintenance.scan()).ofKind(
          ConsistencyIssueKind.missingThumbnail,
        ),
        isEmpty,
      );
    });
  });

  group('derived assets', () {
    test('a missing derived file has its row removed', () async {
      final id = await createPhoto();
      final now = DateTime.now().millisecondsSinceEpoch;

      await harness.database.database.insert('derived_assets', {
        'id': 'asset-1',
        'source_photo_id': id,
        'asset_type': 'EXPORT',
        'file_path': '${harness.paths.exports.path}/gone.jpg',
        'width_px': 10,
        'height_px': 10,
        'file_size_bytes': 10,
        'created_at': now,
        'version': 1,
      });

      final report = await maintenance.scan();
      expect(
        report.ofKind(ConsistencyIssueKind.missingDerivedAsset),
        hasLength(1),
      );

      final outcome = await maintenance.repair(report);
      expect(outcome.derivedAssetRowsRemoved, 1);
      expect(await harness.database.database.query('derived_assets'), isEmpty);
    });
  });

  group('stale temporary files', () {
    test('are reported and removed', () async {
      final stale = File('${harness.paths.temp.path}/tmp_old.jpg')
        ..writeAsBytesSync(sampleJpeg());
      stale.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final report = await maintenance.scan();
      expect(
        report.ofKind(ConsistencyIssueKind.staleTemporaryFile),
        hasLength(1),
      );

      final outcome = await maintenance.repair(report);
      expect(outcome.temporaryFilesRemoved, 1);
      expect(stale.existsSync(), isFalse);
    });

    test('a recent temporary file is left alone', () async {
      // It may belong to a capture in flight.
      File(
        '${harness.paths.temp.path}/tmp_active.jpg',
      ).writeAsBytesSync(sampleJpeg());

      expect(
        (await maintenance.scan()).ofKind(
          ConsistencyIssueKind.staleTemporaryFile,
        ),
        isEmpty,
      );
    });
  });

  group('reporting', () {
    test('the summary distinguishes critical from minor', () async {
      final id = await createPhoto();
      await File((await photos.getPhoto(id))!.originalPath).delete();

      final report = await maintenance.scan();

      expect(report.summary, contains('needs attention'));
    });

    test('scanning changes nothing', () async {
      final id = await createPhoto();
      final path = (await photos.getPhoto(id))!.originalPath;
      final before = File(path).readAsBytesSync();

      await maintenance.scan(verifyChecksums: true);

      expect(File(path).readAsBytesSync(), before);
      expect(await photos.getPhoto(id), isNotNull);
    });
  });
}
