import 'dart:typed_data';

import '../../models/enums.dart';
import '../errors/result.dart';
import 'camera_capabilities.dart';

/// One preview frame, at preview resolution.
///
/// Carries raw luminance rather than an encoded image so the CV layer can build
/// a `WorkingImage` without a decode step in the frame loop.
class CameraFrame {
  const CameraFrame({
    required this.width,
    required this.height,
    required this.luminance,
    required this.timestamp,
    this.rotationDegrees = 0,
  });

  final int width;
  final int height;

  /// Single-channel 8-bit luminance, `width * height` bytes.
  final Uint8List luminance;

  final DateTime timestamp;

  /// Rotation needed to bring the frame upright, used for the orientation
  /// normalisation CV section 9 requires.
  final int rotationDegrees;
}

/// A full-resolution capture, before it is stored.
class CapturedImage {
  const CapturedImage({
    required this.bytes,
    required this.width,
    required this.height,
    this.mimeType = 'image/jpeg',
    this.orientation = CaptureOrientation.portrait,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String mimeType;
  final CaptureOrientation orientation;
}

/// The platform-independent camera interface (Build Specification section 11,
/// Technical Architecture section 5).
///
/// No feature screen imports a camera plugin. Everything goes through this, for
/// three reasons the specifications give:
///
/// - iOS and Android camera behaviour differs and must not leak into feature
///   code (Technical Architecture section 4)
/// - the camera engine should be reusable by other WISE applications
///   (Technical Architecture section 57, master prompt Phase 54)
/// - a fake implementation makes the capture workflow testable without a device
abstract class CameraEngine {
  /// Capabilities detected at initialisation. [CameraCapabilities.none] before.
  CameraCapabilities get capabilities;

  bool get isInitialized;

  /// The camera currently in use, or null before initialisation.
  CameraDescription? get activeCamera;

  Future<Result<void>> initialize({CameraPosition? preferred});

  Future<void> dispose();

  /// Preview frames for the CV layer.
  ///
  /// Sampled rather than exhaustive: the engine may drop frames to keep the
  /// preview smooth, which CV sections 56-57 explicitly prefer over maintaining
  /// CV throughput.
  Stream<CameraFrame> get frames;

  Future<Result<CapturedImage>> capture();

  /// Sets zoom. Values outside the supported range are clamped rather than
  /// rejected, so a protocol written for one device does not fail on another.
  Future<Result<void>> setZoom(double value);

  double get currentZoom;

  Future<Result<void>> setFlashMode(WiseFlashMode mode);

  WiseFlashMode get currentFlashMode;

  /// Focuses at a normalised point (0-1 in each axis). Returns
  /// [CameraCapabilityUnsupported] where the platform has no such control.
  Future<Result<void>> setFocusPoint(double x, double y);

  Future<Result<void>> setExposurePoint(double x, double y);

  Future<Result<void>> switchCamera(CameraPosition position);

  /// Whatever camera metadata the platform reports. Absent keys mean the
  /// device did not report the value (Data Model section 13).
  Future<Map<String, Object?>> readMetadata();
}
