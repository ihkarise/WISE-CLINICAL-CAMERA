import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/providers.dart';
import 'package:wise_clinical_camera/core/storage/checksum.dart';
import 'package:wise_clinical_camera/features/annotation/markup_controller.dart';
import 'package:wise_clinical_camera/models/calibration.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/models/photo.dart';

import '../support/cv_dataset.dart';
import '../support/test_harness.dart';

/// The markup editor's state machine.
///
/// Phase 2 audit 5.7: 2/108 lines covered, so undo of a half-drawn shape, tool
/// switching, and the uncalibrated path were all unproven. Every one of them is
/// pure Dart over a real database — none of it needed a screen.
///
/// The invariant this file exists to defend is the one a clinician would be
/// harmed by: **no physical units without calibration**. An uncalibrated
/// measurement must stay in pixels rather than inventing millimetres, and a
/// calibration added afterwards must convert the geometry that was already
/// recorded rather than asking anyone to place the points again.
void main() {
  late TestHarness harness;
  late ProviderContainer container;
  late Photo photo;

  MarkupController controllerFor(Photo target) {
    container.listen(markupControllerProvider(target), (_, _) {});
    return container.read(markupControllerProvider(target).notifier);
  }

  setUp(() async {
    harness = await TestHarness.create();
    container = ProviderContainer(
      overrides: [
        storagePathsProvider.overrideWith((ref) async => harness.paths),
        databaseProvider.overrideWith((ref) async => harness.database),
        imageStorageProvider.overrideWith((ref) async => harness.storage),
      ],
    );

    final repository = await container.read(photoRepositoryProvider.future);
    final user = await container.read(currentUserProvider.future);
    photo = (await repository.createPhoto(
      bytes: CvDataset.toJpeg(CvDataset.texturedScene(width: 200, height: 200)),
      type: PhotoType.before,
      source: PhotoSource.camera,
      userId: user.id,
    )).valueOrNull!;
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  Future<Calibration> calibrate({double pixelsPerUnit = 10}) async {
    final clinical = await container.read(clinicalRepositoryProvider.future);
    final saved = await clinical.saveCalibration(
      photoId: photo.id,
      method: CalibrationMethod.manual,
      knownValue: 10,
      unit: LengthUnit.millimetre,
      pixelDistance: 10 * pixelsPerUnit,
    );
    return saved.valueOrNull!;
  }

  group('tool selection', () {
    test('choosing a tool abandons whatever was half drawn', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(10, 10));

      controller.selectTool(const AnnotationTool(AnnotationType.arrow));

      expect(
        controller.state.pendingPoints,
        isEmpty,
        reason: 'a point placed for one tool must not leak into the next',
      );
    });

    test('the select tool places nothing', () async {
      final controller = controllerFor(photo);

      controller
        ..selectTool(const SelectTool())
        ..addPoint(const ImagePoint(10, 10));

      expect(controller.state.pendingPoints, isEmpty);
    });

    test('a length needs two points before it can be committed', () async {
      final controller = controllerFor(photo);
      controller.selectTool(const MeasurementTool(MeasurementType.length));

      controller.addPoint(const ImagePoint(10, 10));
      expect(controller.state.canCommit, isFalse);

      controller.addPoint(const ImagePoint(40, 10));
      expect(controller.state.canCommit, isTrue);
    });

    test('an area needs three', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.area))
        ..addPoint(const ImagePoint(10, 10))
        ..addPoint(const ImagePoint(40, 10));

      expect(controller.state.canCommit, isFalse);

      controller.addPoint(const ImagePoint(40, 40));
      expect(controller.state.canCommit, isTrue);
    });

    test('a text annotation needs only one', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const AnnotationTool(AnnotationType.text))
        ..addPoint(const ImagePoint(10, 10));

      expect(controller.state.canCommit, isTrue);
    });

    test('clearing the pending points is an undo of the current shape', () {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const AnnotationTool(AnnotationType.pen))
        ..addPoint(const ImagePoint(1, 1))
        ..addPoint(const ImagePoint(2, 2))
        ..clearPending();

      expect(controller.state.pendingPoints, isEmpty);
      expect(controller.state.annotations, isEmpty);
    });
  });

  group('committing', () {
    test('too few points commits nothing at all', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(10, 10));

      await controller.commit();

      expect(controller.state.measurements, isEmpty);
      final clinical = await container.read(clinicalRepositoryProvider.future);
      expect(await clinical.getMeasurements(photo.id), isEmpty);
    });

    test('a measurement reaches the database, not just the state', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(10, 10))
        ..addPoint(const ImagePoint(40, 10));

      await controller.commit();

      expect(controller.state.measurements, hasLength(1));
      final clinical = await container.read(clinicalRepositoryProvider.future);
      expect(await clinical.getMeasurements(photo.id), hasLength(1));
    });

    test('the pending points are cleared once committed', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(10, 10))
        ..addPoint(const ImagePoint(40, 10));

      await controller.commit();

      expect(controller.state.pendingPoints, isEmpty);
      expect(controller.state.saving, isFalse);
    });

    test('an annotation is stacked above the one before it', () async {
      final controller = controllerFor(photo);
      for (var index = 0; index < 2; index++) {
        controller
          ..selectTool(const AnnotationTool(AnnotationType.arrow))
          ..addPoint(ImagePoint(index * 10, 0))
          ..addPoint(ImagePoint(index * 10 + 5, 20));
        await controller.commit();
      }

      expect(
        controller.state.annotations.map((a) => a.zIndex),
        [0, 1],
        reason: 'z-order is what makes the later arrow draw on top',
      );
    });

    test('a rectangle is closed and a line is not', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const AnnotationTool(AnnotationType.rectangle))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(10, 10));
      await controller.commit();

      controller
        ..selectTool(const AnnotationTool(AnnotationType.line))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(10, 10));
      await controller.commit();

      final byType = {
        for (final a in controller.state.annotations) a.type: a.geometry.closed,
      };
      expect(byType[AnnotationType.rectangle], isTrue);
      expect(byType[AnnotationType.line], isFalse);
    });
  });

  group('no physical units without calibration', () {
    test('an uncalibrated measurement stays in pixels', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(30, 40));

      await controller.commit();

      final measurement = controller.state.measurements.single;
      expect(measurement.pixelValue, closeTo(50, 0.001));
      expect(
        measurement.hasPhysicalValue,
        isFalse,
        reason: 'inventing a millimetre value here would be a clinical error',
      );
      expect(measurement.value, isNull);
      expect(measurement.unit, isNull);
    });

    test('a calibration present at commit produces physical units', () async {
      await calibrate();
      final controller = controllerFor(photo);
      await controller.load();

      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(0, 100));
      await controller.commit();

      final measurement = controller.state.measurements.single;
      expect(measurement.hasPhysicalValue, isTrue);
      expect(measurement.unit, LengthUnit.millimetre);
      expect(measurement.value, closeTo(10, 0.001));
    });

    test('a later calibration converts what was already measured', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(0, 100));
      await controller.commit();
      expect(controller.state.measurements.single.hasPhysicalValue, isFalse);

      await controller.applyCalibration(await calibrate());

      // The point of storing geometry separately from the value: nobody has to
      // place the points again (Data Model §21).
      final measurement = controller.state.measurements.single;
      expect(measurement.hasPhysicalValue, isTrue);
      expect(measurement.value, closeTo(10, 0.001));

      final clinical = await container.read(clinicalRepositoryProvider.future);
      final stored = (await clinical.getMeasurements(photo.id)).single;
      expect(
        stored.value,
        closeTo(10, 0.001),
        reason: 'the recalculation has to be persisted, not only shown',
      );
    });

    test('recalibration rescales every existing measurement', () async {
      final controller = controllerFor(photo);
      for (final length in [100.0, 50.0]) {
        controller
          ..selectTool(const MeasurementTool(MeasurementType.length))
          ..addPoint(const ImagePoint(0, 0))
          ..addPoint(ImagePoint(0, length));
        await controller.commit();
      }

      await controller.applyCalibration(await calibrate());

      expect(
        controller.state.measurements.map((m) => m.value),
        everyElement(isNotNull),
      );
    });
  });

  group('editing what is already there', () {
    test('load brings back what was saved', () async {
      final first = controllerFor(photo);
      first
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(0, 20));
      await first.commit();

      // A second editor session over the same photograph.
      final reopened = MarkupController(ref: _RefOf(container), photo: photo);
      await reopened.load();

      expect(reopened.state.measurements, hasLength(1));
    });

    test('hiding is not deleting', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(0, 20));
      await controller.commit();
      final id = controller.state.measurements.single.id;

      await controller.toggleVisibility(id);

      expect(controller.state.measurements.single.visible, isFalse);
      final clinical = await container.read(clinicalRepositoryProvider.future);
      expect(
        await clinical.getMeasurements(photo.id),
        hasLength(1),
        reason: 'Functional MES-008 hides; it must not destroy',
      );
    });

    test('hiding an annotation works the same way', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const AnnotationTool(AnnotationType.circle))
        ..addPoint(const ImagePoint(10, 10))
        ..addPoint(const ImagePoint(20, 20));
      await controller.commit();
      final id = controller.state.annotations.single.id;

      await controller.toggleVisibility(id);

      expect(controller.state.annotations.single.visible, isFalse);
    });

    test('deleting removes it from the editor and the database', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(0, 20));
      await controller.commit();

      await controller.delete(controller.state.measurements.single.id);

      expect(controller.state.measurements, isEmpty);
      final clinical = await container.read(clinicalRepositoryProvider.future);
      expect(await clinical.getMeasurements(photo.id), isEmpty);
    });

    test('deleting an unknown id changes nothing', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(0, 20));
      await controller.commit();

      await controller.delete('not-a-real-id');

      expect(controller.state.measurements, hasLength(1));
    });
  });

  test('nothing the editor does touches the original', () async {
    final before = await Checksum.ofFile(File(photo.originalPath));
    final controller = controllerFor(photo);

    controller
      ..selectTool(const MeasurementTool(MeasurementType.area))
      ..addPoint(const ImagePoint(0, 0))
      ..addPoint(const ImagePoint(20, 0))
      ..addPoint(const ImagePoint(20, 20));
    await controller.commit();
    controller
      ..selectTool(const AnnotationTool(AnnotationType.arrow))
      ..addPoint(const ImagePoint(0, 0))
      ..addPoint(const ImagePoint(10, 10));
    await controller.commit();
    await controller.applyCalibration(await calibrate());

    // Editing a committed object (ANN-003) is equally non-destructive.
    controller.select(controller.state.measurements.single.id);
    await controller.moveSelected(3, 4);
    await controller.resizeSelected(1.5);

    await controller.delete(controller.state.annotations.single.id);

    // PRD §33, Privacy PRI-004. Markup is a separate record referencing the
    // photograph; the editor has no code path that could open it for writing,
    // and this is the assertion that keeps it that way.
    expect(await Checksum.ofFile(File(photo.originalPath)), before);
  });

  group('editing a committed object (ANN-003)', () {
    test('selecting sets, and a null id clears, the selection', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const AnnotationTool(AnnotationType.arrow))
        ..addPoint(const ImagePoint(0, 0))
        ..addPoint(const ImagePoint(10, 10));
      await controller.commit();
      final id = controller.state.annotations.single.id;

      controller.select(id);
      expect(controller.state.selectedId, id);
      expect(controller.state.tool, isA<SelectTool>());

      controller.select(null);
      expect(controller.state.selectedId, isNull);
    });

    test('moving a measurement shifts it without changing its value', () async {
      final controller = controllerFor(photo);
      await controller.applyCalibration(await calibrate());
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(10, 10))
        ..addPoint(const ImagePoint(40, 10));
      await controller.commit();
      final before = controller.state.measurements.single;

      controller.select(before.id);
      await controller.moveSelected(5, 7);

      final after = controller.state.measurements.single;
      expect(after.geometry.points.first.x, before.geometry.points.first.x + 5);
      expect(after.geometry.points.first.y, before.geometry.points.first.y + 7);
      // A rigid move preserves the measured length.
      expect(after.pixelValue, closeTo(before.pixelValue, 1e-9));
      expect(after.value, closeTo(before.value!, 1e-9));

      final clinical = await container.read(clinicalRepositoryProvider.future);
      final reloaded = await clinical.getMeasurements(photo.id);
      expect(
        reloaded.single.geometry.points.first.x,
        before.geometry.points.first.x + 5,
      );
    });

    test('resizing a measurement scales it and recomputes the value', () async {
      final controller = controllerFor(photo);
      await controller.applyCalibration(await calibrate());
      controller
        ..selectTool(const MeasurementTool(MeasurementType.length))
        ..addPoint(const ImagePoint(10, 10))
        ..addPoint(const ImagePoint(30, 10)); // 20 px
      await controller.commit();
      final before = controller.state.measurements.single;

      controller.select(before.id);
      await controller.resizeSelected(2);

      final after = controller.state.measurements.single;
      expect(after.pixelValue, closeTo(before.pixelValue * 2, 1e-6));
      expect(after.value, closeTo(before.value! * 2, 1e-6));
    });

    test('editing text updates a text annotation and persists it', () async {
      final controller = controllerFor(photo);
      controller
        ..selectTool(const AnnotationTool(AnnotationType.text))
        ..addPoint(const ImagePoint(10, 10));
      await controller.commit();
      final id = controller.state.annotations.single.id;

      controller.select(id);
      await controller.editText(id, 'Lesion A');

      expect(controller.state.annotations.single.text, 'Lesion A');
      final clinical = await container.read(clinicalRepositoryProvider.future);
      final reloaded = await clinical.getAnnotations(photo.id);
      expect(reloaded.single.text, 'Lesion A');
    });
  });
}

/// Adapts a container to the `Ref` a controller constructed outside the
/// provider graph expects, so a second editor session over the same photograph
/// can be opened without going through `autoDispose`.
class _RefOf implements Ref<Object?> {
  _RefOf(this.container);

  @override
  final ProviderContainer container;

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('only read() is used by MarkupController');
}
