/// Typed failures required by Build Specification section 90.
///
/// Services return `Result<T>` carrying one of these rather than throwing, and
/// the UI maps `userMessage` to the screen. A raw `PlatformException` must never
/// reach a user (Build Specification section 91, UX/UI section 53).
sealed class Failure {
  const Failure({required this.userMessage, this.technicalDetail});

  /// Shown to the user. Plain language, says what to do next (UX/UI section 71:
  /// explain, do not scold).
  final String userMessage;

  /// Developer-facing context. Never contains image pixels, patient information
  /// or secrets (Privacy section 20).
  final String? technicalDetail;

  @override
  String toString() =>
      '$runtimeType($userMessage${technicalDetail == null ? '' : '; $technicalDetail'})';
}

// --- Camera -----------------------------------------------------------------

class CameraPermissionDenied extends Failure {
  const CameraPermissionDenied({super.technicalDetail})
    : super(userMessage: 'Camera access is required to take a photograph.');
}

class CameraPermanentlyDenied extends Failure {
  const CameraPermanentlyDenied({super.technicalDetail})
    : super(
        userMessage:
            'Camera access is turned off for WISE. Open Settings to allow it.',
      );
}

class CameraUnavailable extends Failure {
  const CameraUnavailable({super.technicalDetail})
    : super(userMessage: 'Camera unavailable. Check device permissions.');
}

class CameraCapabilityUnsupported extends Failure {
  const CameraCapabilityUnsupported(this.capability, {super.technicalDetail})
    : super(userMessage: 'This device does not support this camera feature.');

  final String capability;
}

// --- Storage ----------------------------------------------------------------

class StorageUnavailable extends Failure {
  const StorageUnavailable({super.technicalDetail})
    : super(userMessage: 'WISE storage is unavailable on this device.');
}

class InsufficientStorage extends Failure {
  const InsufficientStorage({super.technicalDetail})
    : super(
        userMessage:
            'Device storage is low. Free some space before saving more '
            'photographs.',
      );
}

class UnreadableImage extends Failure {
  const UnreadableImage({super.technicalDetail})
    : super(userMessage: 'This image could not be read.');
}

class PhotoNotFound extends Failure {
  const PhotoNotFound({super.technicalDetail})
    : super(userMessage: 'This photograph is no longer available.');
}

// --- Reference and alignment ------------------------------------------------

class ReferenceUnavailable extends Failure {
  const ReferenceUnavailable({super.technicalDetail})
    : super(
        userMessage:
            'The Before photograph could not be loaded. Choose another '
            'reference.',
      );
}

class AlignmentUnavailable extends Failure {
  const AlignmentUnavailable({super.technicalDetail})
    : super(
        userMessage:
            'Automatic alignment is unavailable. Ghost Overlay remains '
            'available.',
      );
}

// --- Clinical tools ---------------------------------------------------------

class CalibrationInvalid extends Failure {
  const CalibrationInvalid({String? reason, super.technicalDetail})
    : super(
        userMessage:
            reason ?? 'Add a scale reference before measuring in centimetres.',
      );
}

class MeasurementInvalid extends Failure {
  const MeasurementInvalid({String? reason, super.technicalDetail})
    : super(userMessage: reason ?? 'This measurement could not be calculated.');
}

// --- Output -----------------------------------------------------------------

class ExportFailed extends Failure {
  const ExportFailed({super.technicalDetail})
    : super(
        userMessage:
            'The export could not be created. Your original photograph is '
            'unchanged.',
      );
}

class GalleryPermissionDenied extends Failure {
  const GalleryPermissionDenied({super.technicalDetail})
    : super(
        userMessage:
            'Gallery access is unavailable. You can continue using WISE '
            'storage.',
      );
}

class GallerySaveFailed extends Failure {
  const GallerySaveFailed({super.technicalDetail})
    : super(
        userMessage:
            'The photograph could not be saved to your Gallery. It remains '
            'saved in WISE.',
      );
}

// --- Data -------------------------------------------------------------------

class DatabaseFailure extends Failure {
  const DatabaseFailure({super.technicalDetail})
    : super(userMessage: 'WISE could not save this change. Please try again.');
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message, {super.technicalDetail})
    : super(userMessage: message);
}

// --- Optional services ------------------------------------------------------

class AiUnavailable extends Failure {
  const AiUnavailable({super.technicalDetail})
    : super(
        userMessage:
            'AI assistance is unavailable. Core camera features continue '
            'normally.',
      );
}

class NetworkUnavailable extends Failure {
  const NetworkUnavailable({super.technicalDetail})
    : super(
        userMessage:
            'No network connection. Core camera features continue '
            'normally.',
      );
}

/// Raised when code attempts a network call that the current privacy
/// configuration forbids (Privacy PRI-003).
class NetworkBlockedByPolicy extends Failure {
  const NetworkBlockedByPolicy(this.reason, {super.technicalDetail})
    : super(
        userMessage:
            'This action needs to send data off the device, which is turned '
            'off in your privacy settings.',
      );

  final String reason;
}
