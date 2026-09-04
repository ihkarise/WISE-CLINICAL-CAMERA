import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/camera/camera_capabilities.dart';
import 'package:wise_clinical_camera/core/camera/fake_camera_engine.dart';
import 'package:wise_clinical_camera/core/errors/failures.dart';
import 'package:wise_clinical_camera/models/enums.dart';

import '../support/test_harness.dart';

/// Camera abstraction behaviour (Functional CAM-001..006, Build Specification
/// sections 11-12, Technical Architecture section 6).
///
/// Phase 2 section 10 asks for a camera reality check, and specifically warns:
/// "Do not assume that preview dimensions and captured image dimensions are
/// identical." The regression for that is here.
void main() {
  group('capability detection', () {
    test('reports nothing before initialization', () {
      final engine = FakeCameraEngine();

      expect(engine.isInitialized, isFalse);
      expect(engine.capabilities.hasCamera, isFalse);
      expect(engine.activeCamera, isNull);
    });

    test(
      'detects cameras, zoom range and flash modes after initialize',
      () async {
        final engine = FakeCameraEngine();
        expect((await engine.initialize()).isOk, isTrue);

        expect(engine.capabilities.hasCamera, isTrue);
        expect(engine.capabilities.hasRearCamera, isTrue);
        expect(engine.capabilities.hasFrontCamera, isTrue);
        expect(engine.capabilities.supportsZoom, isTrue);
        expect(engine.capabilities.supportsFlash, isTrue);
      },
    );

    test('defaults to the rear camera for clinical photography', () async {
      // Functional CAM-002.
      final engine = FakeCameraEngine();
      await engine.initialize();

      expect(engine.activeCamera!.position, CameraPosition.rear);
    });

    test('a device without zoom reports no zoom support', () async {
      // supportsZoom needs an actual range to move through, not just a value.
      final engine = FakeCameraEngine(
        capabilities: const CameraCapabilities(
          cameras: [CameraDescription(id: 'r', position: CameraPosition.rear)],
        ),
      );
      await engine.initialize();

      expect(engine.capabilities.supportsZoom, isFalse);
      expect((await engine.setZoom(2)).isFailure, isTrue);
    });

    test(
      'an unsupported flash mode is refused, not silently ignored',
      () async {
        // UX/UI section 74: never present a control that silently does nothing.
        final engine = FakeCameraEngine(
          capabilities: const CameraCapabilities(
            cameras: [
              CameraDescription(id: 'r', position: CameraPosition.rear),
            ],
            supportedFlashModes: [WiseFlashMode.off],
          ),
        );
        await engine.initialize();

        final result = await engine.setFlashMode(WiseFlashMode.always);

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<CameraCapabilityUnsupported>());
        expect(engine.currentFlashMode, WiseFlashMode.off);
      },
    );

    test('zoom is clamped into the supported range, not rejected', () async {
      // A protocol written on one device must not fail on another.
      final engine = FakeCameraEngine();
      await engine.initialize();

      await engine.setZoom(1000);
      expect(engine.currentZoom, engine.capabilities.maxZoom);

      await engine.setZoom(-5);
      expect(engine.currentZoom, engine.capabilities.minZoom);
    });
  });

  group('captured image dimensions', () {
    test('CapturedImage carries no pixel dimensions at all', () async {
      // Phase 2 section 10. Preview resolution is not still resolution, and on
      // Android the preview is often reported in sensor (landscape)
      // orientation regardless of how the device is held. Carrying a preview
      // size onto a still would put a plausible but wrong number into a
      // clinical record, so the field does not exist.
      final engine = FakeCameraEngine()..captureBytes = sampleJpeg();
      await engine.initialize();

      final captured = await engine.capture();
      expect(captured.isOk, isTrue);

      final image = captured.valueOrNull!;
      // The type exposes bytes, orientation and mimeType — and nothing that
      // claims a size the camera does not actually know.
      expect(image.bytes, isNotEmpty);
      expect(image.orientation, isA<CaptureOrientation>());
    });

    test(
      'the stored record takes dimensions from the bytes, not the camera',
      () async {
        // ImageStorageService decodes and verifies before any row is committed,
        // which is what makes photos.width_px trustworthy.
        final harness = await TestHarness.create();
        addTearDown(harness.dispose);

        final stored = await harness.storage.storeOriginal(
          photoId: 'p1',
          bytes: sampleJpeg(width: 137, height: 91),
        );

        expect(stored.isOk, isTrue);
        expect(stored.valueOrNull!.widthPx, 137);
        expect(stored.valueOrNull!.heightPx, 91);
      },
    );
  });

  group('orientation', () {
    test('reports the orientation actually in force', () async {
      final engine = FakeCameraEngine();
      await engine.initialize();

      expect(engine.currentOrientation, CaptureOrientation.portrait);

      engine.orientation = CaptureOrientation.landscape;
      expect(engine.currentOrientation, CaptureOrientation.landscape);
    });

    test('a capture records the orientation it was taken in', () async {
      // The regression for a hard-coded portrait: a landscape capture must not
      // record portrait, or the AFTER guidance compares against a wrong value
      // (Functional CAM-005).
      final engine = FakeCameraEngine()..captureBytes = sampleJpeg();
      await engine.initialize();
      engine.orientation = CaptureOrientation.landscape;

      final captured = await engine.capture();

      expect(
        captured.valueOrNull!.orientation,
        CaptureOrientation.landscape,
        reason: 'the capture must record the orientation actually in force',
      );
    });
  });

  group('failure paths', () {
    test('capture before initialize fails cleanly', () async {
      final engine = FakeCameraEngine()..captureBytes = sampleJpeg();

      final result = await engine.capture();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<CameraUnavailable>());
    });

    test('an initialization failure surfaces as a typed failure', () async {
      final engine = FakeCameraEngine(
        failOnInitialize: const CameraPermissionDenied(),
      );

      final result = await engine.initialize();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<CameraPermissionDenied>());
      expect(engine.isInitialized, isFalse);
      // And capabilities stay empty, so no UI offers a control.
      expect(engine.capabilities.hasCamera, isFalse);
    });

    test('a capture failure surfaces as a typed failure', () async {
      final engine = FakeCameraEngine(failOnCapture: const CameraUnavailable())
        ..captureBytes = sampleJpeg();
      await engine.initialize();

      expect((await engine.capture()).failureOrNull, isA<CameraUnavailable>());
    });

    test('switching to a camera the device lacks is refused', () async {
      final engine = FakeCameraEngine(
        capabilities: const CameraCapabilities(
          cameras: [CameraDescription(id: 'r', position: CameraPosition.rear)],
        ),
      );
      await engine.initialize();

      final result = await engine.switchCamera(CameraPosition.front);

      expect(result.isFailure, isTrue);
      expect(engine.activeCamera!.position, CameraPosition.rear);
    });
  });
}
