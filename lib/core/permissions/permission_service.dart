import 'package:permission_handler/permission_handler.dart';

import '../errors/failures.dart';
import '../errors/result.dart';
import '../logging/app_logger.dart';

/// What the platform says about one permission.
enum PermissionState { granted, denied, permanentlyDenied, restricted }

/// Contextual, least-privilege permission requests (Privacy sections 5-9).
///
/// Three rules the specification states plainly:
///
/// - Ask only when the action needs it. Never request everything at startup
///   (Privacy section 8).
/// - Never re-prompt a permanently denied permission without a user action;
///   route to Settings instead (Privacy section 9).
/// - Continue with whatever still works when a permission is refused. Denying
///   Gallery access must not stop the camera (Privacy section 9,
///   Technical Architecture section 35).
///
/// Gallery access is deliberately not requested to *save a photograph into
/// WISE*: originals live in application-private storage, so a clinician who
/// never exports is never asked (Privacy section 7).
class PermissionService {
  const PermissionService({PermissionHandlerPlatformShim? shim})
    : _shim = shim ?? const PermissionHandlerPlatformShim();

  final PermissionHandlerPlatformShim _shim;
  static const AppLogger _log = AppLogger('permissions');

  /// Requests camera access, immediately before opening the camera.
  Future<Result<void>> requestCamera() async {
    final state = await _shim.request(Permission.camera);
    _log.info('camera permission', {'state': state.name});

    return switch (state) {
      PermissionState.granted => const Result.ok(null),
      PermissionState.permanentlyDenied || PermissionState.restricted =>
        const Result.failed(CameraPermanentlyDenied()),
      PermissionState.denied => const Result.failed(CameraPermissionDenied()),
    };
  }

  /// Requests photo-library access, only for an explicit import or export.
  Future<Result<void>> requestPhotoLibrary() async {
    final state = await _shim.request(Permission.photos);
    _log.info('photos permission', {'state': state.name});

    return state == PermissionState.granted
        ? const Result.ok(null)
        : const Result.failed(GalleryPermissionDenied());
  }

  Future<PermissionState> cameraStatus() => _shim.status(Permission.camera);

  Future<PermissionState> photoLibraryStatus() =>
      _shim.status(Permission.photos);

  /// Opens the platform settings screen. The only route forward from a
  /// permanent denial (Privacy section 9).
  Future<bool> openSettings() => _shim.openSettings();
}

/// Wraps `permission_handler` so [PermissionService] can be tested without a
/// platform channel.
class PermissionHandlerPlatformShim {
  const PermissionHandlerPlatformShim();

  Future<PermissionState> request(Permission permission) async =>
      _map(await permission.request());

  Future<PermissionState> status(Permission permission) async =>
      _map(await permission.status);

  Future<bool> openSettings() => openAppSettings();

  static PermissionState _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => PermissionState.granted,
    PermissionStatus.permanentlyDenied => PermissionState.permanentlyDenied,
    PermissionStatus.restricted => PermissionState.restricted,
    PermissionStatus.denied => PermissionState.denied,
  };
}
