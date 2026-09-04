import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/providers.dart';
import 'package:wise_clinical_camera/app/routes.dart';
import 'package:wise_clinical_camera/app/theme/wise_theme.dart';
import 'package:wise_clinical_camera/features/comparison/measurement_change_table.dart';
import 'package:wise_clinical_camera/features/export/export_sheet.dart';
import 'package:wise_clinical_camera/features/grid/grid_overlay.dart';
import 'package:wise_clinical_camera/features/library/library_screen.dart';
import 'package:wise_clinical_camera/features/library/photo_detail_screen.dart';
import 'package:wise_clinical_camera/features/library/photo_thumbnail.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/models/measurement.dart';
import 'package:wise_clinical_camera/models/photo.dart';
import 'package:wise_clinical_camera/shared/constants/wise_strings.dart';

import '../support/test_harness.dart';

/// The screens a clinician reads results from.
///
/// Phase 2 audit 5.5, 5.13 and 7.2: the feature layer sat at 0-4% line
/// coverage. These are not screenshot tests. What they check is the handful of
/// statements the specifications require a screen to make, and the conditions
/// under which it must refuse to make them:
///
/// - no measurement in physical units unless a calibration exists
/// - the measurement disclaimer wherever a measurement appears
/// - the export sheet stating that the original is never changed
/// - the grid never intercepting the tap that takes the photograph
///
/// A screen that quietly stopped saying one of those would still look fine.
///
/// **On the plumbing:** a `testWidgets` body runs under a fake clock, so real
/// SQLite and real file I/O never complete inside it — a screen whose data
/// arrives that way sits on its spinner until `pumpAndSettle` gives up. All
/// database work therefore happens inside `tester.runAsync`, and the providers
/// a screen watches are resolved there too, so the widget builds straight into
/// the data state these tests are about.
void main() {
  late TestHarness harness;
  late ProviderContainer container;
  late String userId;

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: WiseTheme.light(),
      onGenerateRoute: generateWiseRoute,
      home: child,
    ),
  );

  setUp(() async {
    harness = await TestHarness.create();
    container = ProviderContainer(
      overrides: [
        storagePathsProvider.overrideWith((ref) async => harness.paths),
        databaseProvider.overrideWith((ref) async => harness.database),
        imageStorageProvider.overrideWith((ref) async => harness.storage),
      ],
    );
    userId = (await container.read(currentUserProvider.future)).id;
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  Future<Photo> addPhoto({
    PhotoType type = PhotoType.before,
    String? referencePhotoId,
    BodyPart? bodyPart,
  }) async {
    final repository = await container.read(photoRepositoryProvider.future);
    return (await repository.createPhoto(
      bytes: sampleJpeg(),
      type: type,
      source: PhotoSource.camera,
      userId: userId,
      referencePhotoId: referencePhotoId,
      bodyPart: bodyPart,
    )).valueOrNull!;
  }

  /// Runs real I/O outside the fake clock, then paints one frame.
  ///
  /// The surface is deliberately tall. These screens are scrolling lists, and a
  /// lazy list only builds what fits — on the default 800x600 surface the
  /// photograph fills the viewport and everything the tests assert on is never
  /// constructed at all.
  Future<void> show(
    WidgetTester tester,
    Widget Function() child, {
    Future<void> Function()? prepare,
    Size surface = const Size(1000, 2400),
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    if (prepare != null) await tester.runAsync(prepare);
    await tester.pumpWidget(host(child()));
    await tester.pump();
  }

  group('the library', () {
    testWidgets('says what will appear here when it is empty', (tester) async {
      await show(
        tester,
        LibraryScreen.new,
        prepare: () => container.read(libraryPhotosProvider.future),
      );

      expect(find.text(WiseStrings.emptyLibrary), findsOneWidget);
    });

    testWidgets('shows a thumbnail for each photograph', (tester) async {
      await show(
        tester,
        LibraryScreen.new,
        prepare: () async {
          await addPhoto();
          await addPhoto(type: PhotoType.photo);
          await container.read(libraryPhotosProvider.future);
        },
      );

      expect(find.byType(PhotoThumbnail), findsNWidgets(2));
      expect(find.text(WiseStrings.emptyLibrary), findsNothing);
    });

    testWidgets('a filter narrows the view without touching the data', (
      tester,
    ) async {
      var total = 0;
      await show(
        tester,
        LibraryScreen.new,
        prepare: () async {
          await addPhoto();
          await addPhoto(type: PhotoType.photo);
          container.read(libraryFilterProvider.notifier).state =
              const LibraryFilter(type: PhotoType.photo);
          await container.read(libraryPhotosProvider.future);

          final repository = await container.read(
            photoRepositoryProvider.future,
          );
          total = (await repository.getPhotos()).length;
        },
      );

      expect(find.byType(PhotoThumbnail), findsOneWidget);
      expect(total, 2, reason: 'filtering is a view, not a deletion');
    });

    testWidgets('filtering by body part narrows the view (MOD-030)', (
      tester,
    ) async {
      await show(
        tester,
        LibraryScreen.new,
        prepare: () async {
          await addPhoto(bodyPart: BodyPart.hand);
          await addPhoto(bodyPart: BodyPart.face);
          container.read(libraryFilterProvider.notifier).state =
              const LibraryFilter(bodyPart: BodyPart.hand);
          await container.read(libraryPhotosProvider.future);
        },
      );

      // Both photographs exist; only the hand matches the filter.
      expect(find.byType(PhotoThumbnail), findsOneWidget);
    });

    testWidgets('offers a body-part filter control listing the categories', (
      tester,
    ) async {
      await show(
        tester,
        LibraryScreen.new,
        prepare: () async {
          await addPhoto(bodyPart: BodyPart.hand);
          await container.read(libraryPhotosProvider.future);
        },
      );

      expect(find.byType(DropdownButton<BodyPart?>), findsOneWidget);

      // The grid is in its data state (no spinner), so opening the menu settles.
      await tester.tap(find.byType(DropdownButton<BodyPart?>));
      await tester.pumpAndSettle();
      expect(find.text('Hand'), findsWidgets);
      expect(find.text('Any body part'), findsWidgets);
    });

    testWidgets('a thumbnail is badged with its type', (tester) async {
      late Photo photo;
      await show(
        tester,
        () => Scaffold(body: PhotoThumbnail(photo: photo)),
        prepare: () async => photo = await addPhoto(),
      );

      // UX/UI section 45: BEFORE and AFTER distinguishable at a glance.
      expect(find.text(photo.type.wireName), findsOneWidget);
    });
  });

  group('photo detail', () {
    /// Seeds a photograph, optionally calibrated and measured, and resolves the
    /// detail provider so the screen builds with data.
    Future<Photo> detailFor({
      bool calibrated = false,
      bool measured = false,
      BodyPart? bodyPart,
    }) async {
      final photo = await addPhoto(bodyPart: bodyPart);
      final clinical = await container.read(clinicalRepositoryProvider.future);

      if (calibrated) {
        final calibration = (await clinical.saveCalibration(
          photoId: photo.id,
          method: CalibrationMethod.manual,
          knownValue: 10,
          unit: LengthUnit.millimetre,
          pixelDistance: 100,
        )).valueOrNull!;

        if (measured) {
          await clinical.saveMeasurement(
            Measurement(
              id: clinical.newId(),
              photoId: photo.id,
              calibrationId: calibration.id,
              type: MeasurementType.length,
              unit: LengthUnit.millimetre,
              value: 20,
              pixelValue: 200,
              geometry: const Geometry([ImagePoint(0, 0), ImagePoint(200, 0)]),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );
        }
      }

      await container.read(photoDetailProvider(photo).future);
      return photo;
    }

    testWidgets('refuses to offer measurement without a scale', (tester) async {
      late Photo photo;
      await show(
        tester,
        () => PhotoDetailScreen(photo: photo),
        prepare: () async => photo = await detailFor(),
      );

      expect(find.text(WiseStrings.calibrationRequired), findsOneWidget);
      expect(find.text('Set scale'), findsOneWidget);
      expect(find.text('Recalibrate'), findsNothing);
    });

    testWidgets('a calibrated photograph offers recalibration instead', (
      tester,
    ) async {
      late Photo photo;
      await show(
        tester,
        () => PhotoDetailScreen(photo: photo),
        prepare: () async => photo = await detailFor(calibrated: true),
      );

      expect(find.text('Recalibrate'), findsOneWidget);
      expect(find.text(WiseStrings.calibrationRequired), findsNothing);
    });

    testWidgets('a measurement never appears without its disclaimer', (
      tester,
    ) async {
      late Photo photo;
      await show(
        tester,
        () => PhotoDetailScreen(photo: photo),
        prepare: () async =>
            photo = await detailFor(calibrated: true, measured: true),
      );

      // Build Specification section 112: the disclaimer travels with the
      // number, because a photographic measurement is not a ruler.
      expect(find.text(WiseStrings.measurementDisclaimer), findsOneWidget);
      expect(find.text(MeasurementType.length.label), findsOneWidget);
    });

    testWidgets('comparison is offered only once an After exists', (
      tester,
    ) async {
      late Photo before;
      await show(
        tester,
        () => PhotoDetailScreen(photo: before),
        prepare: () async => before = await detailFor(),
      );
      expect(find.text('Compare'), findsNothing);

      await show(
        tester,
        () => PhotoDetailScreen(photo: before),
        prepare: () async {
          await addPhoto(type: PhotoType.after, referencePhotoId: before.id);
          container.invalidate(photoDetailProvider(before));
          await container.read(photoDetailProvider(before).future);
        },
      );

      expect(find.text('Compare'), findsOneWidget);
      expect(find.text('After photographs (1)'), findsOneWidget);
    });

    testWidgets('the metadata rows describe the photograph', (tester) async {
      late Photo photo;
      await show(
        tester,
        () => PhotoDetailScreen(photo: photo),
        prepare: () async => photo = await detailFor(bodyPart: BodyPart.hand),
      );

      expect(find.text('${photo.widthPx} x ${photo.heightPx}'), findsOneWidget);
      expect(find.text(BodyPart.hand.label), findsOneWidget);
    });
  });

  group('the export sheet', () {
    testWidgets('promises the original is never changed', (tester) async {
      late Photo photo;
      await show(
        tester,
        () => Scaffold(body: ExportSheet(photo: photo)),
        prepare: () async => photo = await addPhoto(),
      );

      // Functional SAV-004: every preset produces a derived asset.
      expect(
        find.text('Your original photograph is never changed.'),
        findsOneWidget,
      );
    });

    testWidgets('hides pair presets when there is only one photograph', (
      tester,
    ) async {
      late Photo photo;
      await show(
        tester,
        () => Scaffold(body: ExportSheet(photo: photo)),
        prepare: () async => photo = await addPhoto(),
      );

      expect(find.text(ExportPreset.original.label), findsOneWidget);
      expect(find.text(ExportPreset.beforeAfter.label), findsNothing);
    });

    testWidgets('offers pair presets once there are two', (tester) async {
      late Photo before;
      late Photo after;
      await show(
        tester,
        () => Scaffold(
          body: ExportSheet(photo: before, comparisonWith: after),
        ),
        prepare: () async {
          before = await addPhoto();
          after = await addPhoto(
            type: PhotoType.after,
            referencePhotoId: before.id,
          );
        },
      );

      expect(find.text(ExportPreset.beforeAfter.label), findsOneWidget);
    });
  });

  group('overlays are display layers only', () {
    testWidgets('the grid draws for every type and swallows no touches', (
      tester,
    ) async {
      for (final type in GridType.values) {
        await show(tester, () => Scaffold(body: GridOverlay(type: type)));

        expect(find.byType(CustomPaint), findsWidgets, reason: '$type');
        // Functional GRD-001: the grid is painted over the preview. It must
        // never intercept the tap that takes the photograph.
        expect(find.byType(IgnorePointer), findsWidgets, reason: '$type');
      }
    });
  });

  group('the measurement change table', () {
    Measurement measurement({
      required String id,
      required double value,
      bool calibrated = true,
    }) => Measurement(
      id: id,
      photoId: 'p',
      // Without a calibration a measurement has no physical value, so a
      // change between two of them cannot honestly be computed.
      calibrationId: calibrated ? 'cal-$id' : null,
      type: MeasurementType.length,
      unit: LengthUnit.millimetre,
      value: value,
      pixelValue: value * 10,
      geometry: const Geometry([ImagePoint(0, 0), ImagePoint(10, 0)]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('shows nothing when there is nothing to compare', (
      tester,
    ) async {
      await show(
        tester,
        () => const Scaffold(
          body: MeasurementChangeTable(before: [], after: []),
        ),
      );

      expect(find.text(MeasurementType.length.label), findsNothing);
    });

    testWidgets('pairs measurements of the same type across visits', (
      tester,
    ) async {
      await show(
        tester,
        () => Scaffold(
          body: MeasurementChangeTable(
            before: [measurement(id: 'b', value: 40)],
            after: [measurement(id: 'a', value: 30)],
          ),
        ),
      );

      expect(find.text(MeasurementType.length.label), findsOneWidget);
      // A shrinking wound is the point of the table; the reduction has to be
      // readable without arithmetic.
      expect(find.textContaining('25.0%'), findsOneWidget);
      // Build Specification section 112 again: a change is still a measurement.
      expect(find.text(WiseStrings.measurementDisclaimer), findsOneWidget);
    });

    testWidgets('refuses to compute a change without calibration on both', (
      tester,
    ) async {
      await show(
        tester,
        () => Scaffold(
          body: MeasurementChangeTable(
            before: [measurement(id: 'b', value: 40, calibrated: false)],
            after: [measurement(id: 'a', value: 30)],
          ),
        ),
      );

      // A percentage computed from a pixel count would look exactly as
      // authoritative as one computed from millimetres, and mean nothing.
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('scale calibration'), findsOneWidget);
    });
  });
}
