import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/local_alignment_engine.dart';
import 'package:wise_clinical_camera/core/database/database_ids.dart';
import 'package:wise_clinical_camera/core/imaging/layer_renderer.dart';
import 'package:wise_clinical_camera/core/imaging/thumbnail_generator.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_calculator.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_change.dart';
import 'package:wise_clinical_camera/core/storage/checksum.dart';
import 'package:wise_clinical_camera/features/capture/capture_readiness.dart';
import 'package:wise_clinical_camera/features/export/export_service.dart';
import 'package:wise_clinical_camera/models/alignment_record.dart';
import 'package:wise_clinical_camera/models/annotation.dart';
import 'package:wise_clinical_camera/models/comparison.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/repositories/clinical_repository.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';

import '../support/cv_dataset.dart';
import '../support/test_harness.dart';

/// The end-to-end clinical workflow.
///
/// Build Specification section 81 and Testing section 69 both name this
/// sequence explicitly, and Build Specification section 81 says the coding
/// agent "must implement and verify" it:
///
/// ```text
/// Create Before -> Save -> Select Before -> Enable Overlay ->
/// Enable Alignment -> Capture After -> Review -> Calibrate -> Measure ->
/// Annotate -> Compare -> Export
/// ```
///
/// This runs the whole thing against a real database and a real filesystem.
/// What it cannot cover is the parts that need a camera and a screen: those are
/// listed in docs/testing/DEVICE_TEST_PLAN.md.
void main() {
  late TestHarness harness;
  late PhotoRepository photos;
  late ClinicalRepository clinical;
  late ExportService exports;
  late String userId;

  setUp(() async {
    harness = await TestHarness.create();
    userId = await harness.seedUser();
    photos = PhotoRepository(
      database: harness.database,
      storage: harness.storage,
      ids: DatabaseIds.sequential('photo'),
    );
    clinical = ClinicalRepository(
      database: harness.database,
      ids: DatabaseIds.sequential('clin'),
    );
    exports = ExportService(
      storage: harness.storage,
      clinical: clinical,
      ids: DatabaseIds.sequential('exp'),
    );
  });

  tearDown(() async => harness.dispose());

  test('runs the full Before to Export workflow', () async {
    final scene = CvDataset.texturedScene();
    final beforeBytes = CvDataset.toJpeg(scene);
    // The After is the same subject from a slightly different position, which
    // is what a real follow-up visit produces.
    final afterBytes = CvDataset.toJpeg(
      CvDataset.transform(scene, translateX: 8, translateY: 5),
    );

    // ---- 1. Create BEFORE ---------------------------------------------------
    final beforeResult = await photos.createPhoto(
      bytes: beforeBytes,
      type: PhotoType.before,
      source: PhotoSource.camera,
      userId: userId,
      bodyPart: BodyPart.forearm,
      laterality: Laterality.left,
    );
    expect(beforeResult.isOk, isTrue, reason: '${beforeResult.failureOrNull}');
    final before = beforeResult.valueOrNull!;
    final beforeChecksum = await Checksum.ofFile(File(before.originalPath));

    // ---- 2. Save: thumbnail, then ACTIVE ------------------------------------
    final thumbnail = const ThumbnailGenerator().generate(beforeBytes);
    expect(thumbnail.isOk, isTrue);
    final storedThumbnail = await harness.storage.storeDerived(
      assetId: before.id,
      directory: harness.paths.thumbnails,
      bytes: thumbnail.valueOrNull!,
    );
    expect(storedThumbnail.isOk, isTrue);
    await photos.markProcessed(
      before.id,
      thumbnailPath: storedThumbnail.valueOrNull!.path,
    );

    final savedBefore = await photos.getPhoto(before.id);
    expect(savedBefore!.status, PhotoStatus.active);
    expect(savedBefore.thumbnailPath, isNotNull);

    // ---- 3. Select BEFORE as the reference ----------------------------------
    final candidates = await photos.getReferenceCandidates();
    expect(candidates.map((p) => p.id), contains(before.id));

    // ---- 4-5. Overlay and alignment enabled; prepare the reference ---------
    final engine = LocalAlignmentEngine();
    final prepared = await engine.prepareReference(
      photoId: before.id,
      imageBytes: beforeBytes,
    );
    expect(prepared.isOk, isTrue, reason: '${prepared.failureOrNull}');

    final alignment = await engine.analyzeFrame(
      frame: CvDataset.toWorking(
        CvDataset.transform(scene, translateX: 8, translateY: 5),
      ),
      reference: prepared.valueOrNull!,
    );
    expect(alignment.isAvailable, isTrue);

    // Readiness is computed but never blocks (Functional MOD-023).
    final readiness = CaptureReadiness.evaluate(alignment: alignment);
    expect(readiness.canCapture, isTrue);

    // ---- 6. Capture AFTER ---------------------------------------------------
    final afterResult = await photos.createPhoto(
      bytes: afterBytes,
      type: PhotoType.after,
      source: PhotoSource.camera,
      userId: userId,
      referencePhotoId: before.id,
      bodyPart: BodyPart.forearm,
      laterality: Laterality.left,
    );
    expect(afterResult.isOk, isTrue, reason: '${afterResult.failureOrNull}');
    final after = afterResult.valueOrNull!;
    await photos.markProcessed(after.id);

    // The Before/After relationship is retrievable both ways.
    expect(after.referencePhotoId, before.id);
    expect((await photos.getAfterPhotosFor(before.id)).map((p) => p.id), [
      after.id,
    ]);

    // The alignment is stored so the comparison can reuse it (CMP-006).
    await clinical.saveAlignment(
      AlignmentRecord(
        id: clinical.newId(),
        referencePhotoId: before.id,
        targetPhotoId: after.id,
        method: AlignmentMethod.featureMatch,
        status: alignment.status,
        confidence: alignment.confidence,
        transformMatrix: alignment.transform?.toMatrix(),
        rotation: alignment.rotationDegrees,
        scale: alignment.scale,
        createdAt: DateTime.now(),
        engineVersion: alignment.engineVersion,
      ),
    );

    // ---- 7. Review ----------------------------------------------------------
    expect(await photos.verifyIntegrity(after.id), isTrue);

    // ---- 8. Calibrate -------------------------------------------------------
    // Each photograph is calibrated separately: a calibration is never borrowed
    // from another image (Data Model section 19).
    final beforeCalibration = await clinical.saveCalibration(
      photoId: before.id,
      method: CalibrationMethod.manual,
      knownValue: 5,
      unit: LengthUnit.centimetre,
      pixelDistance: 500,
      referenceGeometry: const Geometry([
        ImagePoint(10, 10),
        ImagePoint(510, 10),
      ]),
    );
    expect(beforeCalibration.isOk, isTrue);

    final afterCalibration = await clinical.saveCalibration(
      photoId: after.id,
      method: CalibrationMethod.manual,
      knownValue: 5,
      unit: LengthUnit.centimetre,
      pixelDistance: 500,
    );
    expect(afterCalibration.isOk, isTrue);

    // ---- 9. Measure ---------------------------------------------------------
    // A 420 px lesion at 100 px/cm is 4.2 cm, shrinking to 2.8 cm.
    final beforeMeasurement = MeasurementCalculator.build(
      id: clinical.newId(),
      photoId: before.id,
      type: MeasurementType.length,
      geometry: const Geometry([ImagePoint(20, 40), ImagePoint(440, 40)]),
      calibration: beforeCalibration.valueOrNull,
    );
    await clinical.saveMeasurement(beforeMeasurement);

    final afterMeasurement = MeasurementCalculator.build(
      id: clinical.newId(),
      photoId: after.id,
      type: MeasurementType.length,
      geometry: const Geometry([ImagePoint(20, 40), ImagePoint(300, 40)]),
      calibration: afterCalibration.valueOrNull,
    );
    await clinical.saveMeasurement(afterMeasurement);

    expect(beforeMeasurement.displayValue, '4.2 cm');
    expect(afterMeasurement.displayValue, '2.8 cm');

    // The specification's own worked example (Testing section 25).
    final change = MeasurementChange.between(
      before: beforeMeasurement,
      after: afterMeasurement,
    );
    expect(change.comparable, isTrue);
    expect(change.absolute, closeTo(-1.4, 1e-9));
    expect(change.percentage, closeTo(-33.333333, 1e-4));

    // ---- 10. Annotate -------------------------------------------------------
    final annotation = Annotation(
      id: clinical.newId(),
      photoId: after.id,
      type: AnnotationType.arrow,
      geometry: const Geometry([ImagePoint(60, 60), ImagePoint(180, 140)]),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect((await clinical.saveAnnotation(annotation)).isOk, isTrue);
    expect(await clinical.getAnnotations(after.id), hasLength(1));

    // ---- 11. Compare --------------------------------------------------------
    final reusable = await clinical.getReusableAlignment(
      referencePhotoId: before.id,
      targetPhotoId: after.id,
    );
    expect(
      reusable,
      isNotNull,
      reason:
          'the comparison must reuse the stored alignment, not derive '
          'a second one',
    );

    final comparison = await clinical.saveComparison(
      Comparison(
        id: clinical.newId(),
        beforePhotoId: before.id,
        afterPhotoId: after.id,
        mode: ComparisonMode.sideBySide,
        alignmentId: reusable!.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    expect(comparison.isOk, isTrue);

    final pair = const LayerRenderer().renderPair(
      beforeBytes: beforeBytes,
      afterBytes: afterBytes,
    );
    expect(pair.isOk, isTrue);

    // ---- 12. Export ---------------------------------------------------------
    for (final preset in const [
      ExportPreset.original,
      ExportPreset.annotated,
      ExportPreset.measured,
      ExportPreset.anonymized,
      ExportPreset.reportReady,
    ]) {
      final exported = await exports.export(photo: after, preset: preset);
      expect(
        exported.isOk,
        isTrue,
        reason: '${preset.wireName} failed: ${exported.failureOrNull}',
      );
      expect(File(exported.valueOrNull!.outputPath).existsSync(), isTrue);
    }

    final pairExport = await exports.export(
      photo: before,
      preset: ExportPreset.beforeAfterMeasurements,
      pairedWith: after,
    );
    expect(pairExport.isOk, isTrue);

    // ---- The invariant that must survive all of it -------------------------
    expect(
      await Checksum.ofFile(File(before.originalPath)),
      beforeChecksum,
      reason: 'the Before original changed during the workflow',
    );
    expect(await photos.verifyIntegrity(before.id), isTrue);
    expect(await photos.verifyIntegrity(after.id), isTrue);

    // Exports are derived assets recorded against their source, never
    // replacements for it (Build Specification section 48).
    final derived = await clinical.getDerivedAssets(after.id);
    expect(derived, isNotEmpty);
    for (final asset in derived) {
      expect(asset.sourcePhotoId, after.id);
      expect(asset.filePath, isNot(after.originalPath));
    }
  });

  test('a PHOTO capture needs no reference and no calibration', () async {
    // PRD section 3.3: ordinary documentation photography must stay simple.
    final result = await photos.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.photo,
      source: PhotoSource.camera,
      userId: userId,
    );

    expect(result.isOk, isTrue);
    final photo = result.valueOrNull!;
    expect(photo.referencePhotoId, isNull);

    // Exportable immediately.
    final exported = await exports.export(
      photo: photo,
      preset: ExportPreset.original,
    );
    expect(exported.isOk, isTrue);
  });

  test('an uncalibrated photograph exports without inventing units', () async {
    final result = await photos.createPhoto(
      bytes: sampleJpeg(width: 300, height: 200),
      type: PhotoType.photo,
      source: PhotoSource.camera,
      userId: userId,
    );
    final photo = result.valueOrNull!;

    final measurement = MeasurementCalculator.build(
      id: clinical.newId(),
      photoId: photo.id,
      type: MeasurementType.length,
      geometry: const Geometry([ImagePoint(10, 10), ImagePoint(110, 10)]),
    );
    await clinical.saveMeasurement(measurement);

    expect(measurement.displayValue, endsWith('px'));
    expect(measurement.displayValue, isNot(contains('cm')));

    final exported = await exports.export(
      photo: photo,
      preset: ExportPreset.measured,
    );
    expect(exported.isOk, isTrue);
  });

  test(
    'a reference that is deleted is reported, not silently broken',
    () async {
      // Testing REF-T003.
      final before = (await photos.createPhoto(
        bytes: sampleJpeg(),
        type: PhotoType.before,
        source: PhotoSource.camera,
        userId: userId,
      )).valueOrNull!;

      await photos.createPhoto(
        bytes: sampleJpeg(seed: 3),
        type: PhotoType.after,
        source: PhotoSource.camera,
        userId: userId,
        referencePhotoId: before.id,
      );

      final impact = await photos.analyseDeletion(before.id);
      expect(impact.hasReferences, isTrue);

      final refused = await photos.deletePhoto(before.id);
      expect(refused.isFailure, isTrue);
      expect(refused.failureOrNull!.userMessage, contains('After'));
    },
  );
}
