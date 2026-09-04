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
import 'package:wise_clinical_camera/features/annotation/markup_screen.dart';
import 'package:wise_clinical_camera/features/calibration/calibration_screen.dart';
import 'package:wise_clinical_camera/features/capture/capture_screen.dart';
import 'package:wise_clinical_camera/features/cases/cases_screen.dart';
import 'package:wise_clinical_camera/features/comparison/comparison_screen.dart';
import 'package:wise_clinical_camera/features/overlay/ghost_overlay.dart';
import 'package:wise_clinical_camera/features/protocols/protocols_screen.dart';
import 'package:wise_clinical_camera/features/reference/reference_picker_screen.dart';
import 'package:wise_clinical_camera/features/settings/settings_screen.dart';
import 'package:wise_clinical_camera/features/settings/tools_drawer.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/photo.dart';
import 'package:wise_clinical_camera/models/reference_transform.dart';

import '../support/test_harness.dart';

/// Does every screen actually render?
///
/// A blunt question, and worth asking blindly: the library grid handed its
/// thumbnail an unbounded height and threw on every build, which meant the
/// library had never once displayed a photograph. Nothing caught it because
/// nothing had ever pumped the screen.
///
/// So this file pumps all of them, with realistic data behind them, and fails
/// on any exception the framework raises. It asserts almost nothing about what
/// appears — `screens_test.dart` does that — because the value here is entirely
/// in the fact that a screen was built at all.
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

  /// Builds a screen and fails on anything the framework threw doing it.
  Future<void> renders(
    WidgetTester tester,
    Widget Function() screen, {
    Future<void> Function()? prepare,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    if (prepare != null) await tester.runAsync(prepare);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: WiseTheme.light(),
          onGenerateRoute: generateWiseRoute,
          home: screen(),
        ),
      ),
    );
    await tester.pump();

    // Several of these screens start loading in `initState`. Give that work a
    // moment on the real event loop, then paint again, so what is checked is
    // the screen with its data rather than the screen with its spinner.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'still loading after its data arrived',
    );
  }

  testWidgets('settings', (tester) async {
    await renders(
      tester,
      SettingsScreen.new,
      prepare: () => container.read(preferencesProvider.future),
    );
  });

  testWidgets('the tools drawer', (tester) async {
    await renders(
      tester,
      () => const Scaffold(body: SingleChildScrollView(child: ToolsDrawer())),
      prepare: () => container.read(preferencesProvider.future),
    );
  });

  testWidgets('cases, empty and populated', (tester) async {
    await renders(
      tester,
      CasesScreen.new,
      prepare: () => container.read(casesProvider.future),
    );

    await renders(
      tester,
      CasesScreen.new,
      prepare: () async {
        final repository = await container.read(caseRepositoryProvider.future);
        await repository.createCase(userId: userId, title: 'Series A');
        container.invalidate(casesProvider);
        await container.read(casesProvider.future);
      },
    );
  });

  testWidgets('protocols', (tester) async {
    await renders(
      tester,
      ProtocolsScreen.new,
      prepare: () async {
        final repository = await container.read(
          protocolRepositoryProvider.future,
        );
        await repository.seedSystemProtocols(userId: userId);
        container.invalidate(protocolsProvider);
        await container.read(protocolsProvider.future);
      },
    );
  });

  testWidgets('the reference picker, empty and populated', (tester) async {
    await renders(
      tester,
      ReferencePickerScreen.new,
      prepare: () => container.read(referenceCandidatesProvider.future),
    );

    await renders(
      tester,
      ReferencePickerScreen.new,
      prepare: () async {
        await addPhoto();
        container.invalidate(referenceCandidatesProvider);
        await container.read(referenceCandidatesProvider.future);
      },
    );
  });

  testWidgets('calibration', (tester) async {
    late Photo photo;
    await renders(
      tester,
      () => CalibrationScreen(photo: photo),
      prepare: () async => photo = await addPhoto(),
    );
  });

  testWidgets('markup', (tester) async {
    late Photo photo;
    await renders(
      tester,
      () => MarkupScreen(photo: photo),
      prepare: () async => photo = await addPhoto(),
    );
  });

  testWidgets('comparison', (tester) async {
    late Photo before;
    late Photo after;
    await renders(
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
  });

  testWidgets('the ghost overlay', (tester) async {
    late Photo photo;
    await renders(
      tester,
      () => Scaffold(
        body: GhostOverlay(
          imagePath: photo.originalPath,
          opacity: 0.4,
          transform: ReferenceTransform.identity,
        ),
      ),
      prepare: () async => photo = await addPhoto(),
    );
  });

  testWidgets('capture, in each of the three modes', (tester) async {
    for (final type in PhotoType.values) {
      Photo? reference;
      await renders(
        tester,
        () => CaptureScreen(
          arguments: CaptureArguments(type: type, referencePhoto: reference),
        ),
        prepare: () async {
          // AFTER cannot start without a reference (Functional MOD-020).
          if (type == PhotoType.after) reference = await addPhoto();
          await container.read(preferencesProvider.future);
        },
      );
    }
  });
}

/// A permission shim that grants, so a screen under test is never blocked on a
/// dialog that does not exist in a test binding.
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
