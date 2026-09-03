/// User-facing text held in one place.
///
/// Centralised for three reasons: the specifications prescribe exact wording in
/// several places, disclaimers must be identical everywhere they appear, and
/// the same strings are asserted by tests.
abstract final class WiseStrings {
  // --- Product --------------------------------------------------------------

  static const String appName = 'WISE Clinical Camera';

  /// PRD section 1 and UX/UI section 6.
  static const String tagline = 'Take the same photograph again.';

  static const String onboardingBody =
      'Create a Before reference and use WISE to reproduce its position, '
      'angle, scale and lighting later.';

  // --- Modes (UX/UI section 8) ---------------------------------------------

  static const String modePrompt = 'What would you like to capture?';
  static const String beforeTitle = 'Before';
  static const String beforeSubtitle = 'Reference';
  static const String afterTitle = 'After';
  static const String afterSubtitle = 'Match it';
  static const String photoTitle = 'Photo';
  static const String photoSubtitle = 'Simple';

  // --- Disclaimers ----------------------------------------------------------

  /// Must appear on the difference view (Functional CMP-005, UX/UI section 39,
  /// PRD section 18, Build Specification section 42).
  static const String differenceDisclaimer =
      'Visual difference only. This does not provide a medical diagnosis.';

  /// Build Specification section 112, Functional section 45.
  static const String measurementDisclaimer =
      'Photographic measurement. Accuracy depends on calibration and capture '
      'geometry.';

  /// Technical Architecture section 20, Functional CAL-007.
  static const String perspectiveWarning =
      'A scale reference on one plane does not guarantee accuracy for objects '
      'at a different depth or angle.';

  /// Shown beside any AI output (Build Specification section 113).
  static const String aiAssistanceLabel = 'AI-generated assistance';

  // --- Errors (Functional ERR-001..005, UX/UI section 53) -------------------

  static const String cameraPermissionRequired =
      'Camera access is required to take a photograph.';
  static const String galleryUnavailable =
      'Gallery access is unavailable. You can continue using WISE storage.';
  static const String alignmentUnavailable =
      'Automatic alignment is unavailable. Ghost Overlay remains available.';
  static const String calibrationRequired =
      'Set a scale before measuring in centimetres.';
  static const String storageLow =
      'Device storage is low. Free some space before saving additional '
      'photographs.';

  // --- Empty states (UX/UI section 51) --------------------------------------

  static const String emptyLibrary =
      'Your clinical photographs will appear here.';
  static const String emptyReference =
      'Select a Before photograph to begin an After capture.';
  static const String emptyCalibration = calibrationRequired;

  // --- Actions --------------------------------------------------------------

  static const String capture = 'Capture';
  static const String captureAnyway = 'Capture anyway';
  static const String retake = 'Retake';
  static const String usePhoto = 'Use photo';
  static const String saveToWise = 'Save to WISE';
  static const String saveToGallery = 'Save to Gallery';
  static const String openSettings = 'Open Settings';
  static const String chooseBefore = 'Choose Before';
  static const String useAsReference = 'Use as reference';
  static const String openCamera = 'Open camera';
  static const String skipDetails = 'Skip details';
  static const String readyToCapture = 'Ready to capture';

  // --- Tools ----------------------------------------------------------------

  static const String toolsTitle = 'Camera tools';
  static const String yourCameraTools = 'Your camera tools';
  static const String offForThisCapture = 'Off for this capture';
  static const String onForThisCapture = 'On for this capture';
  static const String changeDefault = 'Change my default';
  static const String referenceLocked = 'Reference locked';
  static const String referenceUnlocked = 'Reference unlocked';
}
