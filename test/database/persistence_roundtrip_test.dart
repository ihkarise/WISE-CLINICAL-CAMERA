import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/database/database_ids.dart';
import 'package:wise_clinical_camera/models/capture_protocol.dart';
import 'package:wise_clinical_camera/models/clinical_case.dart';
import 'package:wise_clinical_camera/models/comparison.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/export_record.dart';
import 'package:wise_clinical_camera/models/tool_overrides.dart';
import 'package:wise_clinical_camera/repositories/case_repository.dart';
import 'package:wise_clinical_camera/repositories/clinical_repository.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';
import 'package:wise_clinical_camera/repositories/protocol_repository.dart';

import '../support/test_harness.dart';

/// Everything that is written to SQLite and later read back.
///
/// Phase 2 audit 4.6-4.8: three repositories had no coverage at all, and
/// several models were only ever serialised — `toRow` exercised by a write,
/// `fromRow` by nothing. A serialisation bug of that shape is quiet: the write
/// succeeds, and the value only comes back wrong, or not at all, later.
///
/// So every test here writes through the real schema and reads back through the
/// real parser. Nothing asserts against a map it built itself.
void main() {
  late TestHarness harness;
  late CaseRepository cases;
  late ProtocolRepository protocols;
  late PhotoRepository photos;
  late ClinicalRepository clinical;
  late String userId;

  setUp(() async {
    harness = await TestHarness.create();
    userId = await harness.seedUser();
    cases = CaseRepository(
      database: harness.database,
      ids: DatabaseIds.sequential('case'),
    );
    protocols = ProtocolRepository(
      database: harness.database,
      ids: DatabaseIds.sequential('proto'),
    );
    photos = PhotoRepository(
      database: harness.database,
      storage: harness.storage,
      ids: DatabaseIds.sequential('photo'),
    );
    clinical = ClinicalRepository(
      database: harness.database,
      ids: DatabaseIds.sequential('clin'),
    );
  });

  tearDown(() async => harness.dispose());

  Future<String> photoIn({String? caseId, String? protocolId}) async {
    final created = await photos.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.before,
      source: PhotoSource.camera,
      userId: userId,
      caseId: caseId,
      protocolId: protocolId,
    );
    return created.valueOrNull!.id;
  }

  group('cases', () {
    test('a case survives the round trip intact', () async {
      final created = await cases.createCase(
        userId: userId,
        title: 'Left forearm ulcer',
        localReference: 'WARD-3',
        notes: 'Reviewed weekly',
      );

      final loaded = await cases.getCase(created.valueOrNull!.id);

      expect(loaded, isNotNull);
      expect(loaded!.title, 'Left forearm ulcer');
      expect(loaded.localReference, 'WARD-3');
      expect(loaded.notes, 'Reviewed weekly');
      expect(loaded.userId, userId);
      expect(loaded.version, 1);
    });

    test('a case with nothing filled in is still valid', () async {
      // Cases are optional grouping, so every descriptive field is optional.
      final created = await cases.createCase();

      final loaded = await cases.getCase(created.valueOrNull!.id);

      expect(loaded, isNotNull);
      expect(loaded!.title, isNull);
      expect(loaded.notes, isNull);
    });

    test('an update bumps the version', () async {
      final created = (await cases.createCase(title: 'Old')).valueOrNull!;

      final updated = (await cases.updateCase(
        created.copyWith(title: 'New'),
      )).valueOrNull!;

      expect(updated.version, 2);
      expect((await cases.getCase(created.id))!.title, 'New');
    });

    test('listing is newest first and excludes deleted cases', () async {
      final first = (await cases.createCase(
        title: 'A',
        now: DateTime(2026, 1, 1),
      )).valueOrNull!;
      final second = (await cases.createCase(
        title: 'B',
        now: DateTime(2026, 2, 1),
      )).valueOrNull!;

      expect((await cases.getCases()).map((c) => c.id), [second.id, first.id]);

      await cases.deleteCase(second.id);
      expect((await cases.getCases()).map((c) => c.id), [first.id]);
    });

    test('deleting a case does not delete its photographs', () async {
      final record = (await cases.createCase(title: 'Series')).valueOrNull!;
      final photoId = await photoIn(caseId: record.id);
      expect(await cases.photoCount(record.id), 1);

      await cases.deleteCase(record.id);

      // Data Model §35 states this outright: the photographs become
      // uncategorised, they do not disappear with the folder.
      final photo = await photos.getPhoto(photoId);
      expect(photo, isNotNull);
      expect(photo!.caseId, isNull);
    });

    test('deleting a case that is already gone reports it', () async {
      final result = await cases.deleteCase('no-such-case');

      expect(result.isFailure, isTrue);
    });

    test('the photo count ignores deleted photographs', () async {
      final record = (await cases.createCase()).valueOrNull!;
      final first = await photoIn(caseId: record.id);
      await photoIn(caseId: record.id);

      await photos.deletePhoto(first);

      expect(await cases.photoCount(record.id), 1);
    });
  });

  group('protocols', () {
    test('the seeded protocols are readable back', () async {
      await protocols.seedSystemProtocols(userId: userId);

      final list = await protocols.getProtocols();

      expect(list, isNotEmpty);
      expect(list.every((p) => p.isSystem), isTrue);
    });

    test('no seeded protocol blocks capture', () async {
      await protocols.seedSystemProtocols(userId: userId);

      final thresholds = (await protocols.getProtocols()).map(
        (p) => p.settings.hardAlignmentThreshold,
      );

      // SPECIFICATION_CONFLICTS C-018: only a deliberately configured protocol
      // may impose a hard requirement. Nothing shipped may.
      expect(thresholds, everyElement(isNull));
    });

    test('seeding twice does not duplicate', () async {
      await protocols.seedSystemProtocols(userId: userId);
      final first = (await protocols.getProtocols()).length;

      await protocols.seedSystemProtocols(userId: userId);

      expect((await protocols.getProtocols()).length, first);
    });

    test('every settings field survives the round trip', () async {
      const settings = ProtocolSettings(
        tools: ToolOverrides(
          enabled: {WiseTool.grid: true, WiseTool.level: false},
          overlayOpacity: 0.35,
          gridType: GridType.thirds,
        ),
        preferredOrientation: CaptureOrientation.landscape,
        preferredFlash: WiseFlashMode.always,
        measurementRequired: true,
        hardAlignmentThreshold: 0.85,
        exportPreset: ExportPreset.reportReady,
        exportFooter: false,
      );

      final created = (await protocols.createProtocol(
        name: 'Everything set',
        settings: settings,
        description: 'Exercises every field',
      )).valueOrNull!;

      final loaded = (await protocols.getProtocol(created.id))!.settings;

      expect(loaded.tools.valueFor(WiseTool.grid), isTrue);
      expect(loaded.tools.valueFor(WiseTool.level), isFalse);
      expect(loaded.tools.overlayOpacity, closeTo(0.35, 0.0001));
      expect(loaded.tools.gridType, GridType.thirds);
      expect(loaded.preferredOrientation, CaptureOrientation.landscape);
      expect(loaded.preferredFlash, WiseFlashMode.always);
      expect(loaded.measurementRequired, isTrue);
      expect(loaded.hardAlignmentThreshold, closeTo(0.85, 0.0001));
      expect(loaded.exportPreset, ExportPreset.reportReady);
      expect(loaded.exportFooter, isFalse);
    });

    test('an unset threshold comes back unset, not zero', () async {
      final created = (await protocols.createProtocol(
        name: 'Advisory',
        settings: const ProtocolSettings(),
      )).valueOrNull!;

      final loaded = (await protocols.getProtocol(created.id))!;

      // A zero here would block every capture, which is the opposite of what
      // "no threshold" means.
      expect(loaded.settings.hardAlignmentThreshold, isNull);
    });

    test('a nameless protocol is refused', () async {
      final result = await protocols.createProtocol(
        name: '   ',
        settings: const ProtocolSettings(),
      );

      expect(result.isFailure, isTrue);
    });

    test(
      'an edit bumps the version so earlier captures stay attributable',
      () async {
        final created = (await protocols.createProtocol(
          name: 'Wound series',
          settings: const ProtocolSettings(),
        )).valueOrNull!;

        final edited = (await protocols.updateProtocol(
          created,
          settings: const ProtocolSettings(measurementRequired: true),
        )).valueOrNull!;

        expect(edited.version, created.version + 1);
        final loaded = (await protocols.getProtocol(created.id))!;
        expect(loaded.version, 2);
        expect(loaded.settings.measurementRequired, isTrue);
      },
    );

    test('a duplicate is a separate protocol with the same settings', () async {
      final source = (await protocols.createProtocol(
        name: 'Wound series',
        settings: const ProtocolSettings(measurementRequired: true),
      )).valueOrNull!;

      final copy = (await protocols.duplicateProtocol(source)).valueOrNull!;

      expect(copy.id, isNot(source.id));
      expect(copy.name, 'Wound series copy');
      expect(copy.settings.measurementRequired, isTrue);
    });

    test('deleting a protocol leaves historical captures naming it', () async {
      final protocol = (await protocols.createProtocol(
        name: 'Retired',
        settings: const ProtocolSettings(),
      )).valueOrNull!;
      final photoId = await photoIn(protocolId: protocol.id);

      await protocols.deleteProtocol(protocol.id);

      expect(await protocols.getProtocol(protocol.id), isNull);
      // Functional PRO-005: what a photograph was taken under is historical
      // fact, and retiring the protocol does not change it.
      expect((await photos.getPhoto(photoId))!.protocolId, protocol.id);
    });

    test('an inactive protocol is hidden unless asked for', () async {
      final protocol = (await protocols.createProtocol(
        name: 'Paused',
        settings: const ProtocolSettings(),
      )).valueOrNull!;

      await protocols.updateProtocol(protocol, isActive: false);

      expect(await protocols.getProtocols(), isEmpty);
      expect(await protocols.getProtocols(activeOnly: false), hasLength(1));
    });
  });

  group('exports', () {
    test('an export record reads back with its configuration', () async {
      final photoId = await photoIn();
      final record = ExportRecord(
        id: clinical.newId(),
        photoId: photoId,
        preset: ExportPreset.reportReady,
        outputPath: '/exports/one.jpg',
        configuration: const ExportConfiguration(
          includeAnnotations: false,
          includeGrid: true,
          includeMetadata: true,
          footerText: 'Ward 3',
          maxDimension: 1600,
        ),
        anonymized: true,
        createdAt: DateTime(2026, 3, 1),
        status: 'COMPLETED',
      );

      await clinical.saveExport(record);
      final loaded = (await clinical.getExports(photoId)).single;

      expect(loaded.preset, ExportPreset.reportReady);
      expect(loaded.outputPath, '/exports/one.jpg');
      expect(loaded.anonymized, isTrue);
      expect(loaded.configuration.includeAnnotations, isFalse);
      expect(loaded.configuration.includeGrid, isTrue);
      expect(loaded.configuration.includeMetadata, isTrue);
      expect(loaded.configuration.footerText, 'Ward 3');
      expect(loaded.configuration.maxDimension, 1600);
    });

    test('the anonymised flag is not lost to an integer round trip', () async {
      final photoId = await photoIn();
      for (final anonymized in [true, false]) {
        await clinical.saveExport(
          ExportRecord(
            id: clinical.newId(),
            photoId: photoId,
            preset: ExportPreset.original,
            outputPath: '/exports/$anonymized.jpg',
            anonymized: anonymized,
            createdAt: DateTime(2026, 3, 1),
            status: 'COMPLETED',
          ),
        );
      }

      final loaded = await clinical.getExports(photoId);
      expect(
        loaded.map((e) => e.anonymized).toSet(),
        {true, false},
        reason: 'SQLite has no boolean; a broken cast would collapse these',
      );
    });

    test('a gallery export reads back', () async {
      final photoId = await photoIn();

      await clinical.saveGalleryExport(
        GalleryExport(
          id: clinical.newId(),
          photoId: photoId,
          platformAssetIdentifier: 'asset-42',
          albumName: 'WISE',
          createdAt: DateTime(2026, 3, 1),
          status: 'COMPLETED',
        ),
      );

      final rows = await harness.database.database.query('gallery_exports');
      final loaded = GalleryExport.fromRow(rows.single);
      expect(loaded.platformAssetIdentifier, 'asset-42');
      expect(loaded.albumName, 'WISE');
    });
  });

  group('comparisons', () {
    test('a comparison reads back with its mode and opacity', () async {
      final before = await photoIn();
      final afterCreated = await photos.createPhoto(
        bytes: sampleJpeg(seed: 9),
        type: PhotoType.after,
        source: PhotoSource.camera,
        userId: userId,
        referencePhotoId: before,
      );
      final after = afterCreated.valueOrNull!.id;

      final comparison = Comparison(
        id: clinical.newId(),
        beforePhotoId: before,
        afterPhotoId: after,
        mode: ComparisonMode.overlay,
        opacity: 0.3,
        configuration: const {'note': 'week 2'},
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );

      await clinical.saveComparison(comparison);
      final loaded = await clinical.getComparison(
        beforePhotoId: before,
        afterPhotoId: after,
      );

      expect(loaded, isNotNull);
      expect(loaded!.mode, ComparisonMode.overlay);
      expect(loaded.opacity, closeTo(0.3, 0.0001));
      expect(loaded.configuration?['note'], 'week 2');
    });

    test('updating a comparison keeps its identity', () async {
      final before = await photoIn();
      final after = (await photos.createPhoto(
        bytes: sampleJpeg(seed: 9),
        type: PhotoType.after,
        source: PhotoSource.camera,
        userId: userId,
        referencePhotoId: before,
      )).valueOrNull!.id;
      final comparison = Comparison(
        id: clinical.newId(),
        beforePhotoId: before,
        afterPhotoId: after,
        mode: ComparisonMode.sideBySide,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      await clinical.saveComparison(comparison);

      await clinical.updateComparison(
        comparison.copyWith(mode: ComparisonMode.difference, opacity: 0.9),
      );

      final loaded = (await clinical.getComparison(
        beforePhotoId: before,
        afterPhotoId: after,
      ))!;
      expect(loaded.id, comparison.id);
      expect(loaded.mode, ComparisonMode.difference);
      expect(loaded.opacity, closeTo(0.9, 0.0001));
    });
  });

  group('the models parse what the database actually stores', () {
    test('a clinical case rebuilt from its own row is unchanged', () async {
      final created = (await cases.createCase(
        title: 'Round trip',
        notes: 'n',
      )).valueOrNull!;

      final row = (await harness.database.database.query(
        'cases',
        where: 'id = ?',
        whereArgs: [created.id],
      )).single;
      final rebuilt = ClinicalCase.fromRow(row);

      expect(rebuilt.id, created.id);
      expect(rebuilt.title, created.title);
      expect(rebuilt.notes, created.notes);
      expect(
        rebuilt.createdAt.millisecondsSinceEpoch,
        created.createdAt.millisecondsSinceEpoch,
      );
    });

    test('a protocol rebuilt from its own row is unchanged', () async {
      final created = (await protocols.createProtocol(
        name: 'Round trip',
        settings: const ProtocolSettings(hardAlignmentThreshold: 0.7),
      )).valueOrNull!;

      final row = (await harness.database.database.query(
        'protocols',
        where: 'id = ?',
        whereArgs: [created.id],
      )).single;
      final rebuilt = CaptureProtocol.fromRow(row);

      expect(rebuilt.name, 'Round trip');
      expect(rebuilt.settings.hardAlignmentThreshold, closeTo(0.7, 0.0001));
      expect(rebuilt.isSystem, isFalse);
      expect(rebuilt.isActive, isTrue);
    });
  });
}
