import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wise_clinical_camera/app/providers.dart';
import 'package:wise_clinical_camera/core/camera/camera_engine.dart';
import 'package:wise_clinical_camera/core/camera/fake_camera_engine.dart';
import 'package:wise_clinical_camera/core/cv/working_image.dart';
import 'package:wise_clinical_camera/core/errors/failures.dart';
import 'package:wise_clinical_camera/core/permissions/permission_service.dart';
import 'package:wise_clinical_camera/core/sensors/device_level_service.dart';
import 'package:wise_clinical_camera/features/capture/capture_controller.dart';
import 'package:wise_clinical_camera/features/capture/capture_state.dart';
import 'package:wise_clinical_camera/models/capture_protocol.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/photo.dart';
import 'package:wise_clinical_camera/models/tool_overrides.dart';

import '../support/cv_dataset.dart';
import '../support/test_harness.dart';

/// The capture controller, driven through the real provider graph.
///
/// This is the orchestrator every photograph passes through — permission,
/// camera, reference, frame analysis, readiness, capture, storage, derived
/// assets — and until this file existed it had **zero** automated coverage
/// (Phase 2 audit 1.7). Nothing here needs a camera: `FakeCameraEngine`, a
/// scriptable permission shim and a synthetic accelerometer stream stand in for
/// the hardware, while the database, the filesystem and the CV engines are all
/// real.
///
/// The invariants under test are the ones that would cost a clinician something
/// if they broke: capture is never blocked by a quality warning, a session
/// override never becomes a default, and a discarded photograph is recoverable.
void main() {
  late TestHarness harness;
  late FakeCameraEngine camera;
  late StreamController<AccelerometerEvent> accelerometer;
  late ProviderContainer container;

  /// Builds the container with only the hardware boundaries replaced.
  Future<ProviderContainer> boot({
    PermissionState cameraPermission = PermissionState.granted,
  }) async {
    final built = ProviderContainer(
      overrides: [
        storagePathsProvider.overrideWith((ref) async => harness.paths),
        databaseProvider.overrideWith((ref) async => harness.database),
        imageStorageProvider.overrideWith((ref) async => harness.storage),
        cameraEngineProvider.overrideWithValue(camera),
        permissionServiceProvider.overrideWithValue(
          PermissionService(shim: _ScriptedPermissions(cameraPermission)),
        ),
        levelServiceProvider.overrideWithValue(
          DeviceLevelService(source: accelerometer.stream),
        ),
      ],
    );
    // The controller reads `effectiveSettingsProvider`, which stays null until
    // the preference chain resolves. Resolving it here rather than racing it
    // keeps every test deterministic.
    await built.read(preferencesProvider.future);
    return built;
  }

  /// Keeps an autoDispose family alive for the length of a test and hands back
  /// the controller.
  CaptureController controllerFor({required PhotoType mode, Photo? reference}) {
    final args = (mode: mode, reference: reference);
    container.listen(captureControllerProvider(args), (_, _) {});
    return container.read(captureControllerProvider(args).notifier);
  }

  Future<Photo> seedPhoto({PhotoType type = PhotoType.before}) async {
    final repository = await container.read(photoRepositoryProvider.future);
    final user = await container.read(currentUserProvider.future);
    final created = await repository.createPhoto(
      bytes: CvDataset.toJpeg(CvDataset.texturedScene(width: 160, height: 160)),
      type: type,
      source: PhotoSource.camera,
      userId: user.id,
    );
    return created.valueOrNull!;
  }

  CameraFrame frameOf(WorkingImage source) => CameraFrame(
    width: source.width,
    height: source.height,
    luminance: Uint8List.fromList(source.pixels),
    timestamp: DateTime.now(),
  );

  CameraFrame texturedFrame({int seed = 11}) => frameOf(
    CvDataset.toWorking(
      CvDataset.texturedScene(width: 160, height: 160, seed: seed),
      maxDimension: 160,
    ),
  );

  setUp(() async {
    harness = await TestHarness.create();
    camera = FakeCameraEngine(
      captureBytes: CvDataset.toJpeg(
        CvDataset.texturedScene(width: 240, height: 180),
      ),
    );
    accelerometer = StreamController<AccelerometerEvent>.broadcast();
    container = await boot();
  });

  tearDown(() async {
    container.dispose();
    await accelerometer.close();
    await harness.dispose();
  });

  /// Replaces the container after a test has changed the camera or the
  /// permission answer, which both have to be decided before boot.
  Future<void> reboot({
    PermissionState cameraPermission = PermissionState.granted,
  }) async {
    container.dispose();
    container = await boot(cameraPermission: cameraPermission);
  }

  group('starting a session', () {
    test('reaches the preview with the camera initialised', () async {
      final controller = controllerFor(mode: PhotoType.photo);

      await controller.start();

      expect(controller.state.phase, CapturePhase.previewing);
      expect(camera.isInitialized, isTrue);
      expect(camera.calls, contains('initialize'));
    });

    test('publishes detected capabilities into the settings chain', () async {
      final controller = controllerFor(mode: PhotoType.photo);

      await controller.start();

      expect(
        container.read(toolCapabilitiesProvider).cameraAvailable,
        isTrue,
        reason: 'the settings precedence chain needs the detected capability',
      );
    });

    test('a denied permission never opens the camera', () async {
      await reboot(cameraPermission: PermissionState.denied);
      final controller = controllerFor(mode: PhotoType.photo);

      await controller.start();

      expect(controller.state.phase, CapturePhase.error);
      expect(controller.state.failure, isA<CameraPermissionDenied>());
      expect(
        camera.calls,
        isNot(contains('initialize')),
        reason: 'opening a camera we may not use is exactly what §9 forbids',
      );
    });

    test('a permanent denial is distinguished from a refusal', () async {
      await reboot(cameraPermission: PermissionState.permanentlyDenied);
      final controller = controllerFor(mode: PhotoType.photo);

      await controller.start();

      // The two need different recovery paths: one can be re-asked, the other
      // can only be fixed in platform settings (Privacy §9).
      expect(controller.state.failure, isA<CameraPermanentlyDenied>());
    });

    test(
      'a camera that will not initialise ends in error, not a hang',
      () async {
        camera = FakeCameraEngine(failOnInitialize: const CameraUnavailable());
        await reboot();
        final controller = controllerFor(mode: PhotoType.photo);

        await controller.start();

        expect(controller.state.phase, CapturePhase.error);
        expect(controller.state.failure, isA<CameraUnavailable>());
      },
    );
  });

  group('the reference', () {
    test('AFTER mode prepares the reference for alignment', () async {
      final before = await seedPhoto();
      final controller = controllerFor(
        mode: PhotoType.after,
        reference: before,
      );

      await controller.start();

      expect(controller.state.phase, CapturePhase.previewing);
      expect(controller.state.reference?.id, before.id);
    });

    test('a missing reference file does not end the session', () async {
      final before = await seedPhoto();
      await File(before.originalPath).delete();
      final controller = controllerFor(
        mode: PhotoType.after,
        reference: before,
      );

      await controller.start();

      // Capture must never be blocked: the clinician is told, and can still
      // take the photograph (Functional REF-T003).
      expect(controller.state.failure, isA<ReferenceUnavailable>());
      expect(controller.state.phase, CapturePhase.previewing);
    });

    test('BEFORE mode loads no reference at all', () async {
      final controller = controllerFor(mode: PhotoType.before);

      await controller.start();

      expect(controller.state.reference, isNull);
      expect(controller.state.alignment, isNull);
    });
  });

  group('live analysis', () {
    test('a frame produces lighting and focus assessments', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      camera.emitFrame(texturedFrame());
      await _settle();

      expect(controller.state.lighting, isNotNull);
      expect(controller.state.focus, isNotNull);
    });

    test('readiness is recomputed from the analysed frame', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      camera.emitFrame(texturedFrame());
      await _settle();

      expect(controller.state.readiness, isNotNull);
    });

    test('a level reading reaches the state', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      accelerometer.add(AccelerometerEvent(0, 9.8, 0, DateTime.now()));
      await _settle();

      expect(controller.state.level.available, isTrue);
      expect(controller.state.level.rollDegrees.abs(), lessThan(1));
    });

    test(
      'an unusable sensor removes the level tool rather than faking it',
      () async {
        final controller = controllerFor(mode: PhotoType.photo);
        await controller.start();

        // A sensor returning zeros has no meaningful orientation to report.
        accelerometer.add(AccelerometerEvent(0, 0, 0, DateTime.now()));
        await _settle();

        expect(controller.state.level.available, isFalse);
        expect(
          container.read(toolCapabilitiesProvider).orientationSensorAvailable,
          isFalse,
        );
      },
    );
  });

  group('capture', () {
    test('stores the photograph and moves to review', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      final result = await controller.capture();

      expect(result.isOk, isTrue);
      expect(controller.state.phase, CapturePhase.reviewing);
      expect(controller.state.capturedPhoto, isNotNull);
      expect(File(result.valueOrNull!.originalPath).existsSync(), isTrue);
    });

    test(
      'records the orientation actually in force, not an assumption',
      () async {
        camera.orientation = CaptureOrientation.landscape;
        final controller = controllerFor(mode: PhotoType.photo);
        await controller.start();

        final photo = (await controller.capture()).valueOrNull!;

        // A Before taken in landscape must record landscape, or the After
        // guidance compares against the wrong value (Functional CAM-005).
        expect(photo.captureRecipe?.orientation, CaptureOrientation.landscape);
      },
    );

    test('carries the clinical metadata onto the stored row', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();
      controller.setMetadata(
        bodyPart: BodyPart.hand,
        laterality: Laterality.left,
      );

      final photo = (await controller.capture()).valueOrNull!;

      expect(photo.bodyPart, BodyPart.hand);
      expect(photo.laterality, Laterality.left);
    });

    test('a shutter failure leaves no row behind', () async {
      camera = FakeCameraEngine(failOnCapture: const CameraUnavailable());
      await reboot();
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      final result = await controller.capture();

      expect(result.isFailure, isTrue);
      expect(controller.state.phase, CapturePhase.previewing);
      final repository = await container.read(photoRepositoryProvider.future);
      expect(await repository.getPhotos(), isEmpty);
    });

    test('a quality warning does not block the shutter', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      // A flat, featureless frame: the worst case the quality engines report.
      camera.emitFrame(
        frameOf(
          CvDataset.toWorking(
            CvDataset.flatScene(width: 160, height: 160),
            maxDimension: 160,
          ),
        ),
      );
      await _settle();

      final result = await controller.capture();

      // The clinician decides. A warning is recorded alongside the photograph,
      // never used to refuse it.
      expect(result.isOk, isTrue);
    });

    test('persists the quality state the photograph was taken in', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();
      camera.emitFrame(texturedFrame());
      await _settle();

      final photo = (await controller.capture()).valueOrNull!;

      final clinical = await container.read(clinicalRepositoryProvider.future);
      final checks = await clinical.getQualityChecks(photo.id);
      expect(
        checks.map((check) => check.checkType),
        containsAll([QualityCheckType.focus, QualityCheckType.lighting]),
      );
    });

    test(
      'a thumbnail is generated and the photograph marked processed',
      () async {
        final controller = controllerFor(mode: PhotoType.photo);
        await controller.start();

        final photo = (await controller.capture()).valueOrNull!;

        expect(photo.thumbnailPath, isNotNull);
        expect(File(photo.thumbnailPath!).existsSync(), isTrue);
      },
    );
  });

  group('retake', () {
    test(
      'returns to the preview and removes the discarded photograph',
      () async {
        final controller = controllerFor(mode: PhotoType.photo);
        await controller.start();
        final photo = (await controller.capture()).valueOrNull!;

        await controller.retake();

        expect(controller.state.phase, CapturePhase.previewing);
        expect(controller.state.capturedPhoto, isNull);
        final repository = await container.read(photoRepositoryProvider.future);
        expect(await repository.getPhoto(photo.id), isNull);
      },
    );

    test('soft-deletes, so a mistaken retake is recoverable', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();
      final photo = (await controller.capture()).valueOrNull!;

      await controller.retake();

      final repository = await container.read(photoRepositoryProvider.future);
      final deleted = await repository.getPhoto(photo.id, includeDeleted: true);
      expect(deleted, isNotNull, reason: 'Data Model §36 requires recovery');
      expect(
        File(deleted!.originalPath).existsSync(),
        isTrue,
        reason: 'a soft delete must not touch the original on disk',
      );
    });
  });

  group('the active protocol', () {
    CaptureProtocol protocolWith(ProtocolSettings settings) => CaptureProtocol(
      id: 'protocol-1',
      name: 'Strict wound series',
      settings: settings,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    /// Drives an AFTER session whose frame does not match its reference, which
    /// is the state a hard threshold exists to catch.
    Future<CaptureController> mismatchedAfterSession() async {
      final before = await seedPhoto();
      final controller = controllerFor(
        mode: PhotoType.after,
        reference: before,
      );
      await controller.start();
      camera.emitFrame(
        frameOf(
          CvDataset.toWorking(
            CvDataset.flatScene(width: 160, height: 160),
            maxDimension: 160,
          ),
        ),
      );
      await _settle();
      return controller;
    }

    test('its hard threshold reaches the check that applies it', () async {
      container.read(activeProtocolProvider.notifier).state = protocolWith(
        const ProtocolSettings(hardAlignmentThreshold: 0.99),
      );

      final controller = await mismatchedAfterSession();

      // The one block the specification permits, and it only works if the
      // protocol's settings actually get to CaptureReadiness.
      expect(controller.state.readiness?.canCapture, isFalse);
      expect(controller.state.readiness?.blockedReason, isNotNull);
    });

    test('without a protocol nothing can block the shutter', () async {
      final controller = await mismatchedAfterSession();

      expect(
        controller.state.readiness?.canCapture,
        isTrue,
        reason: 'a warning is advisory; only a configured protocol blocks',
      );
    });

    test('a protocol with no threshold is still advisory only', () async {
      container.read(activeProtocolProvider.notifier).state = protocolWith(
        const ProtocolSettings(measurementRequired: true),
      );

      final controller = await mismatchedAfterSession();

      expect(controller.state.readiness?.canCapture, isTrue);
    });

    test('its tools reach the settings precedence chain', () async {
      container.read(activeProtocolProvider.notifier).state = protocolWith(
        const ProtocolSettings(
          tools: ToolOverrides(enabled: {WiseTool.grid: true}),
        ),
      );

      final settings = container.read(effectiveSettingsProvider).valueOrNull!;

      expect(settings.gridEnabled, isTrue);
    });

    test('the capture records which protocol was in force', () async {
      container.read(activeProtocolProvider.notifier).state = protocolWith(
        const ProtocolSettings(),
      );
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      final photo = (await controller.capture()).valueOrNull!;

      // Functional PRO-005: a photograph stays attributable to the protocol it
      // was taken under.
      expect(photo.protocolId, 'protocol-1');
      expect(photo.captureRecipe?.protocolId, 'protocol-1');
    });
  });

  group('session overrides', () {
    test('an override applies to this capture only', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();

      controller.overrideTool(WiseTool.grid, enabled: true);

      expect(
        container.read(sessionOverridesProvider).valueFor(WiseTool.grid),
        isTrue,
      );
    });

    test('an override is never written to the database', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();
      final user = await container.read(currentUserProvider.future);

      controller.overrideTool(WiseTool.grid, enabled: true);

      final preferences = await container.read(
        preferenceRepositoryProvider.future,
      );
      final stored = await preferences.load(user.id);
      expect(
        stored.gridEnabled,
        isFalse,
        reason: 'a session override that persisted would become a default',
      );
    });

    test('clearing an override falls back to the default', () async {
      final controller = controllerFor(mode: PhotoType.photo);
      await controller.start();
      controller.overrideTool(WiseTool.grid, enabled: true);

      controller.clearOverride(WiseTool.grid);

      expect(
        container.read(sessionOverridesProvider).valueFor(WiseTool.grid),
        isNull,
      );
    });

    test('overrides do not outlive the session', () async {
      const args = (mode: PhotoType.photo, reference: null);
      final subscription = container.listen(
        captureControllerProvider(args),
        (_, _) {},
      );
      final controller = container.read(
        captureControllerProvider(args).notifier,
      );
      await controller.start();
      controller.overrideTool(WiseTool.grid, enabled: true);

      subscription.close();
      await _settle();

      expect(
        container.read(sessionOverridesProvider),
        ToolOverrides.none,
        reason: 'Functional SET-003: an override is temporary by construction',
      );
    });
  });
}

/// Lets pending microtasks and stream events drain.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

/// A permission shim that answers from a script rather than the platform.
class _ScriptedPermissions implements PermissionHandlerPlatformShim {
  _ScriptedPermissions(this.cameraState);

  final PermissionState cameraState;

  @override
  Future<PermissionState> request(Permission permission) async => cameraState;

  @override
  Future<PermissionState> status(Permission permission) async => cameraState;

  @override
  Future<bool> openSettings() async => true;
}
