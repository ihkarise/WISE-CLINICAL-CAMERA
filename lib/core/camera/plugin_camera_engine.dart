import 'dart:async';

import 'package:camera/camera.dart' as plugin;
import 'package:flutter/services.dart';

import '../../models/enums.dart';
import '../errors/failures.dart';
import '../errors/result.dart';
import '../logging/app_logger.dart';
import 'camera_capabilities.dart';
import 'camera_engine.dart';

/// The production [CameraEngine], backed by the `camera` plugin.
///
/// The only file in the application that imports a camera plugin. Everything
/// platform-specific — capability probing, `PlatformException` translation,
/// the YUV/BGRA difference between Android and iOS preview frames — is
/// contained here (Technical Architecture section 4, Build Specification 11).
///
/// **Unverified on hardware.** This build environment has no Android SDK, no
/// Xcode and no device, so nothing below has been exercised against a real
/// camera. See SPECIFICATION_CONFLICTS C-017 and
/// docs/testing/DEVICE_TEST_PLAN.md.
class PluginCameraEngine implements CameraEngine {
  PluginCameraEngine({
    this.frameSampleInterval = const Duration(milliseconds: 100),
  });

  /// Minimum gap between frames handed to the CV layer.
  ///
  /// CV sections 56-57: process selected frames, not every frame, and never
  /// sacrifice preview smoothness to maintain CV throughput. 100 ms is a
  /// provisional starting point pending device benchmarking.
  final Duration frameSampleInterval;

  final AppLogger _log = const AppLogger('camera');
  final StreamController<CameraFrame> _frames =
      StreamController<CameraFrame>.broadcast();

  plugin.CameraController? _controller;
  List<plugin.CameraDescription> _pluginCameras = const [];
  CameraCapabilities _capabilities = CameraCapabilities.none;
  CameraDescription? _activeCamera;
  double _zoom = 1;
  WiseFlashMode _flashMode = WiseFlashMode.off;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _streaming = false;

  /// The underlying controller, for the preview widget only.
  plugin.CameraController? get controller => _controller;

  @override
  CameraCapabilities get capabilities => _capabilities;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  CameraDescription? get activeCamera => _activeCamera;

  @override
  double get currentZoom => _zoom;

  @override
  WiseFlashMode get currentFlashMode => _flashMode;

  @override
  CaptureOrientation get currentOrientation {
    final orientation = _controller?.value.deviceOrientation;
    if (orientation == null) return CaptureOrientation.portrait;
    return switch (orientation) {
      DeviceOrientation.landscapeLeft ||
      DeviceOrientation.landscapeRight => CaptureOrientation.landscape,
      DeviceOrientation.portraitUp ||
      DeviceOrientation.portraitDown => CaptureOrientation.portrait,
    };
  }

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  Future<Result<void>> initialize({CameraPosition? preferred}) async {
    try {
      _pluginCameras = await plugin.availableCameras();
      if (_pluginCameras.isEmpty) {
        return const Result.failed(
          CameraUnavailable(technicalDetail: 'no cameras reported'),
        );
      }

      final descriptions = _pluginCameras
          .map(
            (camera) => CameraDescription(
              id: camera.name,
              position: _positionOf(camera.lensDirection),
              sensorOrientation: camera.sensorOrientation,
            ),
          )
          .toList(growable: false);

      // Rear by default for clinical photography (Functional CAM-002).
      final target = preferred ?? CameraPosition.rear;
      final index = _pluginCameras.indexWhere(
        (c) => _positionOf(c.lensDirection) == target,
      );
      final selected = index >= 0
          ? _pluginCameras[index]
          : _pluginCameras.first;

      return _startController(selected, descriptions);
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    } on PlatformException catch (error) {
      return Result.failed(
        CameraUnavailable(technicalDetail: '${error.code}: ${error.message}'),
      );
    }
  }

  Future<Result<void>> _startController(
    plugin.CameraDescription camera,
    List<CameraDescription> descriptions,
  ) async {
    await _controller?.dispose();

    final controller = plugin.CameraController(
      camera,
      // High rather than max: clinical detail matters, but a maximum-resolution
      // preview costs memory on every frame for no diagnostic benefit
      // (Technical Architecture section 42).
      plugin.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: plugin.ImageFormatGroup.yuv420,
    );
    _controller = controller;

    try {
      await controller.initialize();
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }

    // Probe what this device actually supports. Never assumed
    // (Build Specification section 12).
    final minZoom = await controller.getMinZoomLevel();
    final maxZoom = await controller.getMaxZoomLevel();
    final flashModes = await _probeFlashModes(controller);

    _capabilities = CameraCapabilities(
      cameras: descriptions,
      minZoom: minZoom,
      maxZoom: maxZoom,
      supportedFlashModes: flashModes,
      supportsFocusPoint: true,
      supportsExposurePoint: true,
      supportsLensSelection: descriptions.length > 1,
      maxPreviewWidth: controller.value.previewSize?.width.round() ?? 0,
      maxPreviewHeight: controller.value.previewSize?.height.round() ?? 0,
    );

    _activeCamera = CameraDescription(
      id: camera.name,
      position: _positionOf(camera.lensDirection),
      sensorOrientation: camera.sensorOrientation,
    );
    _zoom = minZoom;

    _log.info('camera initialized', {
      'position': _activeCamera?.position.wireName,
      'min_zoom': minZoom,
      'max_zoom': maxZoom,
      'flash_modes': flashModes.length,
    });

    return const Result.ok(null);
  }

  /// Determines flash support by attempting each mode.
  ///
  /// There is no capability query in the plugin API, and assuming support
  /// produces a control that silently does nothing — which UX/UI section 74
  /// forbids.
  Future<List<WiseFlashMode>> _probeFlashModes(
    plugin.CameraController controller,
  ) async {
    final supported = <WiseFlashMode>[WiseFlashMode.off];
    for (final mode in const [
      WiseFlashMode.auto,
      WiseFlashMode.always,
      WiseFlashMode.torch,
    ]) {
      try {
        await controller.setFlashMode(_toPluginFlash(mode));
        supported.add(mode);
      } on plugin.CameraException {
        // Not supported on this device.
      }
    }
    try {
      await controller.setFlashMode(plugin.FlashMode.off);
    } on plugin.CameraException {
      // Leave it wherever the probe left it.
    }
    return supported;
  }

  /// Starts delivering sampled preview frames to the CV layer.
  Future<Result<void>> startFrameStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Result.failed(CameraUnavailable());
    }
    if (_streaming) return const Result.ok(null);

    try {
      await controller.startImageStream(_onImage);
      _streaming = true;
      return const Result.ok(null);
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }
  }

  Future<void> stopFrameStream() async {
    if (!_streaming) return;
    try {
      await _controller?.stopImageStream();
    } on plugin.CameraException {
      // Already stopped.
    }
    _streaming = false;
  }

  void _onImage(plugin.CameraImage image) {
    // Drop frames rather than queue them. A backlog would make guidance lag
    // behind what the clinician is seeing, which is worse than a lower rate.
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < frameSampleInterval) return;
    _lastFrameAt = now;

    final luminance = _extractLuminance(image);
    if (luminance == null) return;

    if (!_frames.isClosed) {
      _frames.add(
        CameraFrame(
          width: image.width,
          height: image.height,
          luminance: luminance,
          timestamp: now,
          rotationDegrees: _activeCamera?.sensorOrientation ?? 0,
        ),
      );
    }
  }

  /// Extracts the luminance plane.
  ///
  /// On Android the format is YUV420 and plane 0 is already luma, so this is a
  /// row-stride copy. On iOS it is BGRA8888 and luma must be computed. Handling
  /// both here is exactly the platform difference the abstraction exists to
  /// contain.
  Uint8List? _extractLuminance(plugin.CameraImage image) {
    if (image.planes.isEmpty) return null;

    if (image.format.group == plugin.ImageFormatGroup.bgra8888) {
      final source = image.planes.first.bytes;
      final pixels = image.width * image.height;
      if (source.length < pixels * 4) return null;

      final result = Uint8List(pixels);
      for (var i = 0; i < pixels; i++) {
        final offset = i * 4;
        // Rec. 601 luma from BGRA.
        result[i] =
            (source[offset + 2] * 299 +
                source[offset + 1] * 587 +
                source[offset] * 114) ~/
            1000;
      }
      return result;
    }

    // YUV420: plane 0 is luma, but rows may be padded to a stride wider than
    // the image, so a straight copy would shear the image.
    final plane = image.planes.first;
    final stride = plane.bytesPerRow;
    if (stride == image.width) {
      return Uint8List.fromList(plane.bytes);
    }

    final result = Uint8List(image.width * image.height);
    for (var y = 0; y < image.height; y++) {
      final sourceStart = y * stride;
      if (sourceStart + image.width > plane.bytes.length) break;
      result.setRange(
        y * image.width,
        y * image.width + image.width,
        plane.bytes,
        sourceStart,
      );
    }
    return result;
  }

  @override
  Future<Result<CapturedImage>> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Result.failed(CameraUnavailable());
    }

    try {
      // The image stream competes with still capture for the sensor on some
      // devices, so it is paused for the shot and resumed afterwards.
      final wasStreaming = _streaming;
      if (wasStreaming) await stopFrameStream();

      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      if (wasStreaming) await startFrameStream();

      // No dimensions are reported here: the preview size is not the still
      // size. They are read from the encoded bytes at storage time. See
      // CapturedImage.dimensionsNote.
      return Result.ok(
        CapturedImage(bytes: bytes, orientation: currentOrientation),
      );
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }
  }

  @override
  Future<Result<void>> setZoom(double value) async {
    final controller = _controller;
    if (controller == null) return const Result.failed(CameraUnavailable());
    if (!_capabilities.supportsZoom) {
      return const Result.failed(CameraCapabilityUnsupported('zoom'));
    }
    try {
      final clamped = _capabilities.clampZoom(value);
      await controller.setZoomLevel(clamped);
      _zoom = clamped;
      return const Result.ok(null);
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }
  }

  @override
  Future<Result<void>> setFlashMode(WiseFlashMode mode) async {
    final controller = _controller;
    if (controller == null) return const Result.failed(CameraUnavailable());
    if (!_capabilities.supportsFlashMode(mode)) {
      return const Result.failed(CameraCapabilityUnsupported('flash'));
    }
    try {
      await controller.setFlashMode(_toPluginFlash(mode));
      _flashMode = mode;
      return const Result.ok(null);
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }
  }

  @override
  Future<Result<void>> setFocusPoint(double x, double y) async {
    final controller = _controller;
    if (controller == null) return const Result.failed(CameraUnavailable());
    try {
      await controller.setFocusPoint(Offset(x, y));
      return const Result.ok(null);
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }
  }

  @override
  Future<Result<void>> setExposurePoint(double x, double y) async {
    final controller = _controller;
    if (controller == null) return const Result.failed(CameraUnavailable());
    try {
      await controller.setExposurePoint(Offset(x, y));
      return const Result.ok(null);
    } on plugin.CameraException catch (error) {
      return Result.failed(_translate(error));
    }
  }

  @override
  Future<Result<void>> switchCamera(CameraPosition position) async {
    final index = _pluginCameras.indexWhere(
      (c) => _positionOf(c.lensDirection) == position,
    );
    if (index < 0) {
      return const Result.failed(CameraCapabilityUnsupported('camera'));
    }
    await stopFrameStream();
    return _startController(_pluginCameras[index], _capabilities.cameras);
  }

  @override
  Future<Map<String, Object?>> readMetadata() async {
    final controller = _controller;
    // Absent keys mean the device did not report the value; they never mean
    // zero (Data Model section 13).
    return <String, Object?>{
      'camera_position': _activeCamera?.position.wireName,
      'lens_identifier': _activeCamera?.id,
      'zoom_factor': _zoom,
      'flash_mode': _flashMode.wireName,
      'orientation': controller?.value.deviceOrientation.name,
    };
  }

  @override
  Future<void> dispose() async {
    await stopFrameStream();
    await _controller?.dispose();
    _controller = null;
    _capabilities = CameraCapabilities.none;
    if (!_frames.isClosed) await _frames.close();
  }

  static CameraPosition _positionOf(plugin.CameraLensDirection direction) =>
      switch (direction) {
        plugin.CameraLensDirection.back => CameraPosition.rear,
        plugin.CameraLensDirection.front => CameraPosition.front,
        plugin.CameraLensDirection.external => CameraPosition.external,
      };

  static plugin.FlashMode _toPluginFlash(WiseFlashMode mode) => switch (mode) {
    WiseFlashMode.off => plugin.FlashMode.off,
    WiseFlashMode.auto => plugin.FlashMode.auto,
    WiseFlashMode.always => plugin.FlashMode.always,
    WiseFlashMode.torch => plugin.FlashMode.torch,
  };

  /// Maps a plugin exception onto a typed failure, so no
  /// `CameraException(...)` string ever reaches a user
  /// (Build Specification section 91).
  static Failure _translate(plugin.CameraException error) =>
      switch (error.code) {
        'CameraAccessDenied' ||
        'cameraPermission' ||
        'CameraAccessDeniedWithoutPrompt' => CameraPermissionDenied(
          technicalDetail: error.code,
        ),
        'CameraAccessRestricted' => CameraPermanentlyDenied(
          technicalDetail: error.code,
        ),
        _ => CameraUnavailable(
          technicalDetail: '${error.code}: ${error.description}',
        ),
      };
}
