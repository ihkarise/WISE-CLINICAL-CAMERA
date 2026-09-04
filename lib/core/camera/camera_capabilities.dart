import '../../models/enums.dart';

/// One physical camera the device exposes.
class CameraDescription {
  const CameraDescription({
    required this.id,
    required this.position,
    this.sensorOrientation = 0,
    this.lensIdentifier,
  });

  final String id;
  final CameraPosition position;
  final int sensorOrientation;
  final String? lensIdentifier;
}

/// What this device's camera can actually do.
///
/// Detected at initialisation, never assumed. Technical Architecture section 6
/// and Build Specification section 12 both insist devices differ, and UX/UI
/// section 74 requires that an unavailable control is either hidden or shown as
/// unavailable with a reason — never presented as a control that silently does
/// nothing.
class CameraCapabilities {
  const CameraCapabilities({
    this.cameras = const <CameraDescription>[],
    this.minZoom = 1,
    this.maxZoom = 1,
    this.supportedFlashModes = const <WiseFlashMode>[WiseFlashMode.off],
    this.supportsFocusPoint = false,
    this.supportsExposurePoint = false,
    this.supportsLensSelection = false,
    this.maxPreviewWidth = 0,
    this.maxPreviewHeight = 0,
    this.maxCaptureWidth = 0,
    this.maxCaptureHeight = 0,
  });

  /// Nothing available. The state before initialisation, and after a failure.
  static const CameraCapabilities none = CameraCapabilities();

  final List<CameraDescription> cameras;
  final double minZoom;
  final double maxZoom;
  final List<WiseFlashMode> supportedFlashModes;
  final bool supportsFocusPoint;
  final bool supportsExposurePoint;
  final bool supportsLensSelection;
  final int maxPreviewWidth;
  final int maxPreviewHeight;
  final int maxCaptureWidth;
  final int maxCaptureHeight;

  bool get hasCamera => cameras.isNotEmpty;

  bool get hasRearCamera =>
      cameras.any((c) => c.position == CameraPosition.rear);

  bool get hasFrontCamera =>
      cameras.any((c) => c.position == CameraPosition.front);

  /// Zoom is only meaningfully supported when there is a range to move through.
  bool get supportsZoom => maxZoom > minZoom + 0.01;

  bool get supportsFlash =>
      supportedFlashModes.any((mode) => mode != WiseFlashMode.off);

  bool supportsFlashMode(WiseFlashMode mode) =>
      supportedFlashModes.contains(mode);

  /// The rear camera is the clinical default (Functional CAM-002).
  CameraDescription? get defaultCamera {
    if (cameras.isEmpty) return null;
    return cameras.firstWhere(
      (c) => c.position == CameraPosition.rear,
      orElse: () => cameras.first,
    );
  }

  CameraDescription? cameraAt(CameraPosition position) {
    for (final camera in cameras) {
      if (camera.position == position) return camera;
    }
    return null;
  }

  /// Clamps a requested zoom into the supported range rather than failing.
  double clampZoom(double requested) => requested.clamp(minZoom, maxZoom);
}
