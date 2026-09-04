import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/database/database_ids.dart';
import 'package:wise_clinical_camera/core/imaging/image_codec.dart';
import 'package:wise_clinical_camera/core/imaging/layer_renderer.dart';
import 'package:wise_clinical_camera/core/imaging/layer_stack.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_calculator.dart';
import 'package:wise_clinical_camera/core/storage/checksum.dart';
import 'package:wise_clinical_camera/features/comparison/difference_view.dart';
import 'package:wise_clinical_camera/features/export/export_service.dart';
import 'package:wise_clinical_camera/models/annotation.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/export_record.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/models/photo.dart';
import 'package:wise_clinical_camera/repositories/clinical_repository.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';

import '../support/test_harness.dart';

/// Annotation, comparison and export validation (Phase 2 sections 24-26).
void main() {
  late TestHarness harness;
  late PhotoRepository photos;
  late ClinicalRepository clinical;
  late ExportService exports;

  setUp(() async {
    harness = await TestHarness.create();
    await harness.seedUser();
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

  Future<Photo> createPhoto({
    PhotoType type = PhotoType.before,
    int width = 200,
    int height = 150,
    int seed = 7,
    String? referenceId,
  }) async {
    final result = await photos.createPhoto(
      bytes: sampleJpeg(width: width, height: height, seed: seed),
      type: type,
      source: PhotoSource.camera,
      referencePhotoId: referenceId,
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.valueOrNull!;
  }

  Annotation annotationOf(AnnotationType type, String photoId) => Annotation(
    id: clinical.newId(),
    photoId: photoId,
    type: type,
    geometry: Geometry(
      type == AnnotationType.point || type == AnnotationType.text
          ? const [ImagePoint(40, 40)]
          : const [ImagePoint(20, 20), ImagePoint(90, 70)],
    ),
    text: type == AnnotationType.text ? 'Lesion' : null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('annotation lifecycle, every type (section 24)', () {
    for (final type in AnnotationType.values) {
      test(
        '${type.wireName}: create, edit, move, hide, delete, export',
        () async {
          final photo = await createPhoto();
          final annotation = annotationOf(type, photo.id);

          // Create.
          expect((await clinical.saveAnnotation(annotation)).isOk, isTrue);
          expect(await clinical.getAnnotations(photo.id), hasLength(1));

          // Move: geometry replaced, identity kept.
          final moved = annotation.copyWith(
            geometry: const Geometry([
              ImagePoint(60, 60),
              ImagePoint(150, 120),
            ]),
            updatedAt: DateTime(2026, 2),
          );
          expect((await clinical.updateAnnotation(moved)).isOk, isTrue);
          final afterMove = (await clinical.getAnnotations(photo.id)).single;
          expect(afterMove.id, annotation.id);
          expect(afterMove.geometry.points.first.x, 60);

          // Edit properties.
          final restyled = afterMove.copyWith(
            properties: const AnnotationProperties(strokeWidth: 9),
            updatedAt: DateTime(2026, 3),
          );
          await clinical.updateAnnotation(restyled);
          expect(
            (await clinical.getAnnotations(
              photo.id,
            )).single.properties.strokeWidth,
            9,
          );

          // Hide: excluded from the visible set but still present.
          await clinical.updateAnnotation(
            restyled.copyWith(visible: false, updatedAt: DateTime(2026, 4)),
          );
          expect(
            await clinical.getAnnotations(photo.id, visibleOnly: true),
            isEmpty,
          );
          expect(await clinical.getAnnotations(photo.id), hasLength(1));

          // Show again.
          await clinical.updateAnnotation(
            restyled.copyWith(visible: true, updatedAt: DateTime(2026, 5)),
          );
          expect(
            await clinical.getAnnotations(photo.id, visibleOnly: true),
            hasLength(1),
          );

          // Export renders without error.
          final originalBytes = await File(photo.originalPath).readAsBytes();
          final rendered = const LayerRenderer().render(
            originalBytes: originalBytes,
            stack: LayerStack(
              originalPath: photo.originalPath,
              widthPx: photo.widthPx,
              heightPx: photo.heightPx,
              annotations: [restyled],
            ),
          );
          expect(
            rendered.isOk,
            isTrue,
            reason: '${type.wireName} failed to render',
          );
          expect(ImageCodec.decode(rendered.valueOrNull!), isNotNull);

          // Delete: soft, so it leaves the visible set.
          expect((await clinical.deleteAnnotation(restyled.id)).isOk, isTrue);
          expect(await clinical.getAnnotations(photo.id), isEmpty);
        },
      );
    }

    test('hidden annotations are excluded from a render', () async {
      final photo = await createPhoto();
      final visible = annotationOf(AnnotationType.arrow, photo.id);
      final hidden = annotationOf(
        AnnotationType.circle,
        photo.id,
      ).copyWith(visible: false);

      final bytes = await File(photo.originalPath).readAsBytes();
      final stack = LayerStack(
        originalPath: photo.originalPath,
        widthPx: photo.widthPx,
        heightPx: photo.heightPx,
        annotations: [visible, hidden],
      );

      expect(stack.visibleAnnotations, hasLength(1));
      expect(
        const LayerRenderer().render(originalBytes: bytes, stack: stack).isOk,
        isTrue,
      );
    });

    test('annotations render in z-order', () async {
      final photo = await createPhoto();
      final stack = LayerStack(
        originalPath: photo.originalPath,
        widthPx: photo.widthPx,
        heightPx: photo.heightPx,
        annotations: [
          annotationOf(AnnotationType.circle, photo.id).copyWith(zIndex: 5),
          annotationOf(AnnotationType.arrow, photo.id).copyWith(zIndex: 1),
        ],
      );

      expect(
        stack.visibleAnnotations.map((a) => a.zIndex),
        [1, 5],
        reason: 'lower z-index must be drawn first',
      );
    });
  });

  group('comparison robustness (section 25)', () {
    test('handles images of different dimensions', () async {
      final before = await createPhoto(width: 400, height: 300);
      final after = await createPhoto(width: 200, height: 400, seed: 11);

      final result = const LayerRenderer().renderPair(
        beforeBytes: await File(before.originalPath).readAsBytes(),
        afterBytes: await File(after.originalPath).readAsBytes(),
      );

      expect(result.isOk, isTrue);
      final decoded = ImageCodec.decode(result.valueOrNull!)!;
      expect(decoded.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
    });

    test('handles a portrait/landscape mismatch', () async {
      final portrait = await createPhoto(width: 150, height: 400);
      final landscape = await createPhoto(width: 400, height: 150, seed: 13);

      expect(
        const LayerRenderer()
            .renderPair(
              beforeBytes: await File(portrait.originalPath).readAsBytes(),
              afterBytes: await File(landscape.originalPath).readAsBytes(),
            )
            .isOk,
        isTrue,
      );
    });

    test('the difference view tolerates mismatched dimensions', () async {
      final before = await createPhoto(width: 300, height: 200);
      final after = await createPhoto(width: 150, height: 300, seed: 17);

      final difference = computeDifference((
        before: await File(before.originalPath).readAsBytes(),
        after: await File(after.originalPath).readAsBytes(),
      ));

      expect(difference, isNotNull);
      expect(ImageCodec.decode(difference!), isNotNull);
    });

    test('a comparison with no stored alignment still renders', () async {
      // Functional CMP-006 says reuse alignment where it exists. Where it does
      // not, the comparison must still work rather than refusing.
      final before = await createPhoto();
      final after = await createPhoto(
        type: PhotoType.after,
        seed: 19,
        referenceId: before.id,
      );

      expect(
        await clinical.getReusableAlignment(
          referencePhotoId: before.id,
          targetPhotoId: after.id,
        ),
        isNull,
      );

      expect(
        const LayerRenderer()
            .renderPair(
              beforeBytes: await File(before.originalPath).readAsBytes(),
              afterBytes: await File(after.originalPath).readAsBytes(),
            )
            .isOk,
        isTrue,
      );
    });

    test('a 1x1 image does not crash the difference view', () async {
      final tiny = await createPhoto(width: 1, height: 1, seed: 23);

      expect(
        () => computeDifference((
          before: File(tiny.originalPath).readAsBytesSync(),
          after: File(tiny.originalPath).readAsBytesSync(),
        )),
        returnsNormally,
      );
    });
  });

  group('export presets (section 26)', () {
    test('every single-photo preset produces a decodable file', () async {
      final photo = await createPhoto();
      final calibration = await clinical.saveCalibration(
        photoId: photo.id,
        method: CalibrationMethod.manual,
        knownValue: 5,
        unit: LengthUnit.centimetre,
        pixelDistance: 500,
      );
      await clinical.saveMeasurement(
        MeasurementCalculator.build(
          id: clinical.newId(),
          photoId: photo.id,
          type: MeasurementType.length,
          geometry: const Geometry([ImagePoint(10, 10), ImagePoint(90, 10)]),
          calibration: calibration.valueOrNull,
        ),
      );
      await clinical.saveAnnotation(
        annotationOf(AnnotationType.arrow, photo.id),
      );

      for (final preset in ExportPreset.values.where((p) => !p.isPair)) {
        final result = await exports.export(photo: photo, preset: preset);

        expect(
          result.isOk,
          isTrue,
          reason: '${preset.wireName}: ${result.failureOrNull}',
        );

        final file = File(result.valueOrNull!.outputPath);
        expect(file.existsSync(), isTrue, reason: preset.wireName);
        expect(await file.length(), greaterThan(0), reason: preset.wireName);

        // The file must actually open as an image.
        final decoded = ImageCodec.decode(await file.readAsBytes());
        expect(
          decoded,
          isNotNull,
          reason: '${preset.wireName} is not readable',
        );
        expect(decoded!.width, greaterThan(0));
      }
    });

    test('ORIGINAL preserves the source bytes exactly', () async {
      // Functional EXP-004: an original export must not re-encode.
      final photo = await createPhoto();
      final sourceHash = await Checksum.ofFile(File(photo.originalPath));

      final result = await exports.export(
        photo: photo,
        preset: ExportPreset.original,
      );

      final exported = File(result.valueOrNull!.outputPath);
      expect(
        await Checksum.ofFile(exported),
        sourceHash,
        reason: 'an ORIGINAL export must be byte-identical, not re-encoded',
      );
    });

    test('a pair preset without a partner fails cleanly', () async {
      final photo = await createPhoto();

      final result = await exports.export(
        photo: photo,
        preset: ExportPreset.beforeAfter,
      );

      expect(result.isFailure, isTrue);
    });

    test('a pair preset renders a wider image than either source', () async {
      final before = await createPhoto(width: 200, height: 200);
      final after = await createPhoto(
        width: 200,
        height: 200,
        seed: 29,
        type: PhotoType.after,
        referenceId: before.id,
      );

      final result = await exports.export(
        photo: before,
        preset: ExportPreset.beforeAfter,
        pairedWith: after,
      );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final decoded = ImageCodec.decode(
        await File(result.valueOrNull!.outputPath).readAsBytes(),
      )!;
      expect(
        decoded.width,
        greaterThan(200),
        reason: 'a side-by-side export must be wider than one photograph',
      );
    });

    test('maxDimension actually bounds the output', () async {
      final photo = await createPhoto(width: 800, height: 600);

      final result = await exports.export(
        photo: photo,
        preset: ExportPreset.measured,
        configuration: const ExportConfiguration(maxDimension: 200),
      );

      final decoded = ImageCodec.decode(
        await File(result.valueOrNull!.outputPath).readAsBytes(),
      )!;
      expect(decoded.width <= 200 && decoded.height <= 200, isTrue);
    });

    test('every export leaves the original byte-identical', () async {
      final photo = await createPhoto();
      final hashBefore = await Checksum.ofFile(File(photo.originalPath));

      for (final preset in ExportPreset.values.where((p) => !p.isPair)) {
        await exports.export(photo: photo, preset: preset);
      }

      expect(
        await Checksum.ofFile(File(photo.originalPath)),
        hashBefore,
        reason: 'exporting must never modify the original',
      );
      expect(await photos.verifyIntegrity(photo.id), isTrue);
    });

    test('exports are recorded as derived assets of their source', () async {
      final photo = await createPhoto();
      await exports.export(photo: photo, preset: ExportPreset.measured);

      final assets = await clinical.getDerivedAssets(photo.id);
      expect(assets, isNotEmpty);
      expect(assets.first.sourcePhotoId, photo.id);
      expect(assets.first.filePath, isNot(photo.originalPath));
    });

    test('a missing original fails cleanly rather than throwing', () async {
      final photo = await createPhoto();
      await File(photo.originalPath).delete();

      final result = await exports.export(
        photo: photo,
        preset: ExportPreset.measured,
      );

      expect(result.isFailure, isTrue);
    });
  });
}
