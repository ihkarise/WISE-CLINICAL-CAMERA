import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wise_clinical_camera/app/providers.dart';
import 'package:wise_clinical_camera/app/routes.dart';
import 'package:wise_clinical_camera/app/theme/wise_theme.dart';
import 'package:wise_clinical_camera/core/camera/fake_camera_engine.dart';
import 'package:wise_clinical_camera/core/permissions/permission_service.dart';
import 'package:wise_clinical_camera/core/sensors/device_level_service.dart';
import 'package:wise_clinical_camera/features/calibration/calibration_screen.dart';
import 'package:wise_clinical_camera/features/capture/capture_screen.dart';
import 'package:wise_clinical_camera/features/comparison/comparison_screen.dart';
import 'package:wise_clinical_camera/features/export/export_service.dart';
import 'package:wise_clinical_camera/features/export/export_sheet.dart';
import 'package:wise_clinical_camera/features/library/library_screen.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/photo.dart';
import 'package:wise_clinical_camera/shared/widgets/clinical_image.dart';

import '../support/test_harness.dart';

/// Accessibility of the clinical workflow screens (UX/UI section 55, Build
/// Specification section 93).
///
/// `accessibility_test.dart` covers the shared status widgets, the home screen
/// and the design tokens. This file extends that outward to the screens a
/// clinician actually works in — capture, comparison, calibration, export and
/// the library — and asserts the two things a colour-only or unlabelled control
/// silently fails:
///
/// - a slider must announce *what it controls*, not merely its percentage; and
/// - a status that changes in response to an action (an export result, a
///   rejected calibration) must be announced, because the colour that carries
///   it visually is invisible to a screen reader and to a colour deficiency.
///
/// These are not "the widget exists" tests. Each drives a real workflow screen,
/// backed by real SQLite and a real filesystem, to the state under test and
/// reads back the semantics a VoiceOver/TalkBack user would hear.
void main() {
  late TestHarness harness;
  late ProviderContainer container;
  late FakeCameraEngine camera;
  late StreamController<AccelerometerEvent> accelerometer;
  late String userId;

  setUp(() async {
    harness = await TestHarness.create();
    camera = FakeCameraEngine(captureBytes: sampleJpeg());
    accelerometer = StreamController<AccelerometerEvent>.broadcast();
    container = ProviderContainer(
      overrides: [
        storagePathsProvider.overrideWith((ref) async => harness.paths),
        databaseProvider.overrideWith((ref) async => harness.database),
        imageStorageProvider.overrideWith((ref) async => harness.storage),
        cameraEngineProvider.overrideWithValue(camera),
        permissionServiceProvider.overrideWithValue(
          const PermissionService(shim: _GrantingPermissions()),
        ),
        levelServiceProvider.overrideWithValue(
          DeviceLevelService(source: accelerometer.stream),
        ),
      ],
    );
    userId = (await container.read(currentUserProvider.future)).id;
  });

  tearDown(() async {
    container.dispose();
    await accelerometer.close();
    await harness.dispose();
  });

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: WiseTheme.light(),
      onGenerateRoute: generateWiseRoute,
      home: child,
    ),
  );

  Future<Photo> addPhoto({
    PhotoType type = PhotoType.before,
    String? referencePhotoId,
  }) async {
    final repository = await container.read(photoRepositoryProvider.future);
    return (await repository.createPhoto(
      bytes: sampleJpeg(),
      type: type,
      source: PhotoSource.camera,
      userId: userId,
      referencePhotoId: referencePhotoId,
    )).valueOrNull!;
  }

  /// Runs real I/O outside the fake clock, then paints, then lets any
  /// `initState` loading finish so a screen builds into its data state.
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
  }

  group('a slider announces what it controls, not just a percentage', () {
    testWidgets('the comparison reveal slider is named (CMP-002)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      late Photo before;
      late Photo after;
      await show(
        tester,
        () => ComparisonScreen(
          arguments: ComparisonArguments(before: before, after: after),
        ),
        prepare: () async {
          before = await addPhoto();
          after = await addPhoto(
            type: PhotoType.after,
            referencePhotoId: before.id,
          );
        },
      );

      // Switch to the slider comparison, whose reveal control is the slider.
      await tester.tap(find.text(ComparisonMode.slider.label));
      await tester.pump();

      final node = tester.getSemantics(find.byType(Slider));
      expect(
        node.label,
        contains('Reveal position'),
        reason: 'the reveal slider must say what it reveals',
      );
      expect(node.value, contains('before'));
      handle.dispose();
    });

    testWidgets('the comparison overlay-opacity slider is named (CMP-003)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      late Photo before;
      late Photo after;
      await show(
        tester,
        () => ComparisonScreen(
          arguments: ComparisonArguments(before: before, after: after),
        ),
        prepare: () async {
          before = await addPhoto();
          after = await addPhoto(
            type: PhotoType.after,
            referencePhotoId: before.id,
          );
        },
      );

      await tester.tap(find.text(ComparisonMode.overlay.label));
      await tester.pump();

      final node = tester.getSemantics(find.byType(Slider));
      expect(node.label, contains('Before opacity'));
      expect(node.value, contains('percent'));
      handle.dispose();
    });

    testWidgets('the capture reference-opacity slider is named (OVR-001)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      late Photo reference;
      await show(
        tester,
        () => CaptureScreen(
          arguments: CaptureArguments(
            type: PhotoType.after,
            referencePhoto: reference,
          ),
        ),
        prepare: () async {
          // AFTER carries a reference; the ghost-overlay opacity control only
          // appears when there is one to fade (Functional MOD-020, OVR-001).
          reference = await addPhoto();
          await container.read(preferencesProvider.future);
        },
      );

      final node = tester.getSemantics(find.byType(Slider));
      expect(node.label, contains('Reference opacity'));
      expect(node.value, contains('percent'));
      handle.dispose();
    });
  });

  group('a status change is announced, never carried by colour alone', () {
    testWidgets('a rejected calibration is spoken, not just reddened', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      late Photo photo;
      await show(
        tester,
        () => CalibrationScreen(photo: photo),
        prepare: () async => photo = await addPhoto(),
      );

      // Draw a distance so the Calibrate button enables: two taps at different
      // points inside the image. A square photograph is centred in the
      // viewport, so the gesture area's centre is inside the fitted image and
      // a small horizontal offset stays inside it.
      final imageArea = find.ancestor(
        of: find.byType(ClinicalImage),
        matching: find.byType(GestureDetector),
      );
      final centre = tester.getCenter(imageArea.first);
      await tester.tapAt(centre - const Offset(40, 0));
      await tester.pump();
      await tester.tapAt(centre + const Offset(40, 0));
      await tester.pump();

      // Clear the known-distance field so the value cannot parse.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      await tester.tap(find.text('Calibrate'));
      await tester.pump();

      final message = find.text('Enter a number greater than zero.');
      expect(message, findsOneWidget, reason: 'an invalid value is refused');
      expect(
        tester.getSemantics(message),
        containsSemantics(isLiveRegion: true),
        reason: 'the rejection must be announced, not only shown in red',
      );
      handle.dispose();
    });

    testWidgets('the export outcome is announced (EXP-001)', (tester) async {
      final handle = tester.ensureSemantics();
      late Photo photo;
      await show(
        tester,
        () => Scaffold(body: ExportSheet(photo: photo)),
        prepare: () async {
          photo = await addPhoto();
          // Warm the export service so the tap does not also pay for it.
          await container.read(exportServiceProvider.future);
        },
      );

      await tester.tap(find.text(ExportPreset.original.label));

      // The export writes a derived asset on the real filesystem; poll on the
      // real event loop until the outcome message appears.
      final outcome = find.text('Export created.');
      for (var i = 0; i < 40 && outcome.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }

      expect(outcome, findsOneWidget, reason: 'the export completes');
      expect(
        tester.getSemantics(outcome),
        containsSemantics(isLiveRegion: true),
        reason: 'a screen reader hears the result without re-reading the sheet',
      );
      handle.dispose();
    });
  });

  group('every actionable control carries a label', () {
    testWidgets('the comparison controls are all labelled', (tester) async {
      final handle = tester.ensureSemantics();
      late Photo before;
      late Photo after;
      await show(
        tester,
        () => ComparisonScreen(
          arguments: ComparisonArguments(before: before, after: after),
        ),
        prepare: () async {
          before = await addPhoto();
          after = await addPhoto(
            type: PhotoType.after,
            referencePhotoId: before.id,
          );
        },
      );

      // No mode chip, no navigation control reaches a screen reader as an
      // unlabelled tap target.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the export presets are all labelled', (tester) async {
      final handle = tester.ensureSemantics();
      late Photo photo;
      await show(
        tester,
        () => Scaffold(body: ExportSheet(photo: photo)),
        prepare: () async => photo = await addPhoto(),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the library filters are all labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await show(
        tester,
        LibraryScreen.new,
        prepare: () async {
          await addPhoto();
          await container.read(libraryPhotosProvider.future);
        },
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}

/// Grants every permission, so a screen under test is never blocked on a
/// platform dialog that does not exist in a test binding.
class _GrantingPermissions implements PermissionHandlerPlatformShim {
  const _GrantingPermissions();

  @override
  Future<PermissionState> request(Permission permission) async =>
      PermissionState.granted;

  @override
  Future<PermissionState> status(Permission permission) async =>
      PermissionState.granted;

  @override
  Future<bool> openSettings() async => true;
}
