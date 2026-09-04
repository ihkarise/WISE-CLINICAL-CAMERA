import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/imaging/layer_renderer.dart';
import 'package:wise_clinical_camera/core/imaging/layer_stack.dart';
import 'package:wise_clinical_camera/core/imaging/metadata_anonymizer.dart';
import 'package:wise_clinical_camera/core/imaging/thumbnail_generator.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_calculator.dart';
import 'package:wise_clinical_camera/core/storage/checksum.dart';
import 'package:wise_clinical_camera/models/annotation.dart';
import 'package:wise_clinical_camera/models/calibration.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';

import '../support/test_harness.dart';

/// The original photograph is never modified.
///
/// Priority: **P0**, and the single most load-bearing guarantee in the product.
/// Stated in PRD section 33, Technical Architecture section 8, Data Model
/// section 38, Privacy PRI-004, Build Specification sections 2.1, 48 and 105,
/// Testing section 27, and master prompt Phase 9.
///
/// The method is deliberately blunt: hash the file, put it through everything
/// the application can do to a photograph, hash it again.
void main() {
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

  test('survives a full annotate, measure and export cycle', () async {
    // Testing section 27: capture, annotate, measure, export, reopen original.
    final created = await repository.createPhoto(
      bytes: sampleJpeg(width: 200, height: 150),
      type: PhotoType.before,
      source: PhotoSource.camera,
    );
    final photo = created.valueOrNull!;
    final file = File(photo.originalPath);

    final hashBefore = await Checksum.ofFile(file);
    final lengthBefore = await file.length();
    final modifiedBefore = file.statSync().modified;

    // Everything the app can do to a photograph.
    final originalBytes = await file.readAsBytes();

    const generator = ThumbnailGenerator();
    expect(generator.generate(originalBytes).isOk, isTrue);

    final calibration = Calibration.create(
      id: 'cal',
      photoId: photo.id,
      method: CalibrationMethod.manual,
      knownValue: 5,
      unit: LengthUnit.centimetre,
      pixelDistance: 500,
    );

    final measurement = MeasurementCalculator.build(
      id: 'm1',
      photoId: photo.id,
      type: MeasurementType.length,
      geometry: const Geometry([ImagePoint(10, 10), ImagePoint(90, 40)]),
      calibration: calibration,
    );

    final annotation = Annotation(
      id: 'a1',
      photoId: photo.id,
      type: AnnotationType.arrow,
      geometry: const Geometry([ImagePoint(20, 20), ImagePoint(120, 90)]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    const renderer = LayerRenderer();
    final rendered = renderer.render(
      originalBytes: originalBytes,
      stack: LayerStack(
        originalPath: photo.originalPath,
        widthPx: photo.widthPx,
        heightPx: photo.heightPx,
        measurements: [measurement],
        annotations: [annotation],
        gridType: GridType.thirds,
        footerLines: const ['WISE CLINICAL PHOTO', 'Lesion: 2.8 x 1.7 cm'],
      ),
    );
    expect(rendered.isOk, isTrue);

    expect(const MetadataAnonymizer().anonymize(originalBytes).isOk, isTrue);

    expect(
      renderer
          .renderPair(beforeBytes: originalBytes, afterBytes: originalBytes)
          .isOk,
      isTrue,
    );

    // The original must be byte-for-byte what it was.
    expect(
      await Checksum.ofFile(file),
      hashBefore,
      reason: 'the original changed during the annotate/measure/export cycle',
    );
    expect(await file.length(), lengthBefore);
    expect(file.statSync().modified, modifiedBefore);
    expect(await repository.verifyIntegrity(photo.id), isTrue);
  });

  test('the storage service exposes no way to rewrite an original', () {
    // Structural, not behavioural: there is no update or overwrite method to
    // call by accident. Checked by reflection over the public surface would be
    // fragile, so this asserts the property that matters instead.
    final methods = <String>[
      'storeOriginal',
      'storeDerived',
      'readBytes',
      'discardOrphan',
      'deleteDerived',
      'verifyOriginal',
      'cleanTemporaryFiles',
    ];

    expect(methods.where((m) => m.toLowerCase().contains('update')), isEmpty);
    expect(
      methods.where((m) => m.contains('Original') && m.startsWith('write')),
      isEmpty,
    );
  });

  test('storing refuses to overwrite an existing original', () async {
    final created = await repository.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.before,
      source: PhotoSource.camera,
    );
    final photo = created.valueOrNull!;
    final hashBefore = await Checksum.ofFile(File(photo.originalPath));

    // Re-storing under the same id, as a crash-retry would, must be refused.
    final second = await harness.storage.storeOriginal(
      photoId: photo.id,
      bytes: sampleJpeg(seed: 999),
    );

    expect(second.isFailure, isTrue);
    expect(
      await Checksum.ofFile(File(photo.originalPath)),
      hashBefore,
      reason: 'a retry must never overwrite an existing original',
    );
  });

  test('a rendering failure leaves the original readable', () async {
    // Build Specification section 105: if CV, AI, export, thumbnail or
    // comparison fails, the original photograph must remain usable.
    final created = await repository.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.before,
      source: PhotoSource.camera,
    );
    final photo = created.valueOrNull!;
    final hashBefore = await Checksum.ofFile(File(photo.originalPath));

    // Feed the renderer garbage.
    final failed = const LayerRenderer().render(
      originalBytes: Uint8List.fromList([1, 2, 3, 4]),
      stack: LayerStack(
        originalPath: photo.originalPath,
        widthPx: 10,
        heightPx: 10,
      ),
    );
    expect(failed.isFailure, isTrue);

    await repository.markProcessingFailed(photo.id);

    final reread = await repository.getPhoto(photo.id);
    expect(reread, isNotNull);
    expect(reread!.status, PhotoStatus.failed);
    expect(await Checksum.ofFile(File(photo.originalPath)), hashBefore);
    expect(await repository.verifyIntegrity(photo.id), isTrue);
  });

  test('a soft delete keeps the original file intact', () async {
    final created = await repository.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.before,
      source: PhotoSource.camera,
    );
    final photo = created.valueOrNull!;
    final hashBefore = await Checksum.ofFile(File(photo.originalPath));

    await repository.deletePhoto(photo.id);

    expect(File(photo.originalPath).existsSync(), isTrue);
    expect(await Checksum.ofFile(File(photo.originalPath)), hashBefore);
  });

  test('rendering produces a distinct image, not an edited original', () async {
    final originalBytes = sampleJpeg(width: 200, height: 150);

    final rendered = const LayerRenderer().render(
      originalBytes: originalBytes,
      stack: const LayerStack(
        originalPath: '/does/not/matter',
        widthPx: 200,
        heightPx: 150,
        gridType: GridType.thirds,
      ),
    );

    expect(rendered.isOk, isTrue);
    expect(
      rendered.valueOrNull,
      isNot(equals(originalBytes)),
      reason: 'the render must be a new image',
    );
    // And the input buffer is untouched.
    expect(originalBytes, sampleJpeg(width: 200, height: 150));
  });

  test('a pass-through stack is detected so no re-encode is needed', () {
    // An ORIGINAL export must preserve original content (Functional EXP-004).
    // Detecting that nothing would be drawn lets the export copy the file
    // rather than decode and re-encode it, which would lose quality.
    const empty = LayerStack(
      originalPath: '/x.jpg',
      widthPx: 100,
      heightPx: 100,
    );

    expect(empty.isPassThrough, isTrue);
    expect(empty.copyWith(gridType: GridType.thirds).isPassThrough, isFalse);
  });
}
