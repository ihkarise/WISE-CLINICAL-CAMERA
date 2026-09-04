import 'dart:async';
import 'dart:typed_data';

import '../../models/enums.dart';
import '../errors/failures.dart';
import '../errors/result.dart';
import 'camera_capabilities.dart';
import 'camera_engine.dart';

/// A scriptable [CameraEngine] for tests and the development build.
///
/// Exists so the capture workflow — BEFORE, AFTER, PHOTO, review, save — can be
/// exercised end to end without a device, and so failure paths (permission
/// denied, camera unavailable, capture failure) can be tested deliberately
/// rather than hoped for.
///
/// Not used in production builds.
class FakeCameraEngine implements CameraEngine {
  FakeCameraEngine({
    CameraCapabilities? capabilities,
    this.captureBytes,
    this.failOnInitialize,
    this.failOnCapture,
  }) : _capabilities =
           capabilities ??
           const CameraCapabilities(
             cameras: [
               CameraDescription(id: 'rear', position: CameraPosition.rear),
               CameraDescription(id: 'front', position: CameraPosition.front),
             ],
             maxZoom: 8,
             supportedFlashModes: [
               WiseFlashMode.off,
               WiseFlashMode.auto,
               WiseFlashMode.always,
             ],
             supportsFocusPoint: true,
             supportsExposurePoint: true,
             maxCaptureWidth: 1024,
             maxCaptureHeight: 768,
           );

  final CameraCapabilities _capabilities;

  /// The bytes [capture] returns. Tests supply a real encoded image.
  Uint8List? captureBytes;

  final Failure? failOnInitialize;
  final Failure? failOnCapture;

  final StreamController<CameraFrame> _frames =
      StreamController<CameraFrame>.broadcast();

  /// Settable so a test can exercise the orientation-mismatch path.
  CaptureOrientation orientation = CaptureOrientation.portrait;

  bool _initialized = false;
  CameraDescription? _activeCamera;
  double _zoom = 1;
  WiseFlashMode _flashMode = WiseFlashMode.off;

  /// Calls recorded for assertions.
  final List<String> calls = <String>[];

  @override
  CameraCapabilities get capabilities =>
      _initialized ? _capabilities : CameraCapabilities.none;

  @override
  bool get isInitialized => _initialized;

  @override
  CameraDescription? get activeCamera => _activeCamera;

  @override
  double get currentZoom => _zoom;

  @override
  WiseFlashMode get currentFlashMode => _flashMode;

  @override
  CaptureOrientation get currentOrientation => orientation;

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  Future<Result<void>> initialize({CameraPosition? preferred}) async {
    calls.add('initialize');
    if (failOnInitialize != null) return Result.failed(failOnInitialize!);

    _initialized = true;
    _activeCamera = preferred == null
        ? _capabilities.defaultCamera
        : _capabilities.cameraAt(preferred) ?? _capabilities.defaultCamera;
    return const Result.ok(null);
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    _initialized = false;
    await _frames.close();
  }

  @override
  Future<Result<CapturedImage>> capture() async {
    calls.add('capture');
    if (!_initialized) return const Result.failed(CameraUnavailable());
    if (failOnCapture != null) return Result.failed(failOnCapture!);

    final bytes = captureBytes;
    if (bytes == null) {
      return const Result.failed(
        CameraUnavailable(technicalDetail: 'FakeCameraEngine has no bytes set'),
      );
    }
    return Result.ok(CapturedImage(bytes: bytes, orientation: orientation));
  }

  @override
  Future<Result<void>> setZoom(double value) async {
    calls.add('setZoom');
    if (!_capabilities.supportsZoom) {
      return const Result.failed(CameraCapabilityUnsupported('zoom'));
    }
    _zoom = _capabilities.clampZoom(value);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setFlashMode(WiseFlashMode mode) async {
    calls.add('setFlashMode');
    if (!_capabilities.supportsFlashMode(mode)) {
      return const Result.failed(CameraCapabilityUnsupported('flash'));
    }
    _flashMode = mode;
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setFocusPoint(double x, double y) async {
    calls.add('setFocusPoint');
    if (!_capabilities.supportsFocusPoint) {
      return const Result.failed(CameraCapabilityUnsupported('focus'));
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setExposurePoint(double x, double y) async {
    calls.add('setExposurePoint');
    if (!_capabilities.supportsExposurePoint) {
      return const Result.failed(CameraCapabilityUnsupported('exposure'));
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> switchCamera(CameraPosition position) async {
    calls.add('switchCamera');
    final camera = _capabilities.cameraAt(position);
    if (camera == null) {
      return const Result.failed(CameraCapabilityUnsupported('camera'));
    }
    _activeCamera = camera;
    return const Result.ok(null);
  }

  @override
  Future<Map<String, Object?>> readMetadata() async => <String, Object?>{
    'camera_position': _activeCamera?.position.wireName,
    'zoom_factor': _zoom,
    'flash_mode': _flashMode.wireName,
  };

  /// Pushes a frame to listeners, for driving CV tests.
  void emitFrame(CameraFrame frame) {
    if (!_frames.isClosed) _frames.add(frame);
  }
}
