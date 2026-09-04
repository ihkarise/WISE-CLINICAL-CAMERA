import '../../core/cv/alignment_result.dart';
import '../../core/cv/focus_engine.dart';
import '../../core/cv/lighting_engine.dart';
import '../../models/capture_protocol.dart';
import '../../models/enums.dart';

/// Severity of a pre-capture warning.
enum WarningSeverity {
  /// Informational. Capture proceeds normally.
  advisory,

  /// Worth reading before capturing. Capture still proceeds.
  caution,
}

/// One thing the clinician might want to fix before capturing.
class CaptureWarning {
  const CaptureWarning({
    required this.message,
    required this.severity,
    this.action,
  });

  /// Plain language, explaining rather than scolding (UX/UI section 71).
  final String message;

  final WarningSeverity severity;

  /// What to do about it, when there is a useful next step.
  final String? action;
}

/// Whether capture may proceed, and what to warn about first.
///
/// The rule every specification states, and which is easy to get backwards:
/// **warnings are advisory**. Capture stays available unless a deliberately
/// configured protocol sets a hard threshold, and no protocol shipped with the
/// application does (PRD section 6, Functional MOD-023, CV section 40, UX/UI
/// sections 24 and 72, Build Specification sections 2.8 and 30).
///
/// The reason is clinical rather than technical: a clinician may have one
/// chance at a photograph, and software that refuses to take it has failed at
/// its job (UX/UI section 72, "clinical reality wins").
///
/// See SPECIFICATION_CONFLICTS C-018.
class CaptureReadiness {
  const CaptureReadiness({
    required this.canCapture,
    required this.isReady,
    required this.warnings,
    this.blockedReason,
  });

  /// Evaluates the current state.
  ///
  /// [protocol] may impose the only hard block that exists, via
  /// `hardAlignmentThreshold`.
  factory CaptureReadiness.evaluate({
    AlignmentResult? alignment,
    LightingAssessment? lighting,
    FocusAssessment? focus,
    ProtocolSettings? protocol,
    CaptureOrientation? referenceOrientation,
    CaptureOrientation? preferredOrientation,
    CaptureOrientation? currentOrientation,
    bool cameraAvailable = true,
  }) {
    // The one genuine block: with no camera there is nothing to capture.
    if (!cameraAvailable) {
      return const CaptureReadiness(
        canCapture: false,
        isReady: false,
        warnings: <CaptureWarning>[],
        blockedReason: 'Camera unavailable. Check device permissions.',
      );
    }

    final warnings = <CaptureWarning>[];

    if (referenceOrientation != null &&
        currentOrientation != null &&
        referenceOrientation != currentOrientation) {
      warnings.add(
        CaptureWarning(
          message:
              'The Before photograph was taken in '
              '${referenceOrientation.wireName}.',
          severity: WarningSeverity.caution,
          action: 'Rotate the device',
        ),
      );
    }

    // The active protocol may prefer an orientation (Functional PRO-002). It is
    // only ever advisory (C-018), and is suppressed when a reference already
    // pins the same orientation so the clinician is not warned twice.
    if (preferredOrientation != null &&
        currentOrientation != null &&
        preferredOrientation != currentOrientation &&
        preferredOrientation != referenceOrientation) {
      warnings.add(
        CaptureWarning(
          message:
              'This protocol is usually captured in '
              '${preferredOrientation.wireName}.',
          severity: WarningSeverity.advisory,
          action: 'Rotate the device',
        ),
      );
    }

    if (alignment != null) {
      if (!alignment.isAvailable) {
        warnings.add(
          CaptureWarning(
            message: 'Automatic alignment unavailable.',
            severity: WarningSeverity.advisory,
            action: 'Use Ghost Overlay to position manually',
          ),
        );
      } else if (alignment.status == AlignmentStatus.poor) {
        warnings.add(
          const CaptureWarning(
            message: 'Alignment poor',
            severity: WarningSeverity.caution,
          ),
        );
      } else if (alignment.status == AlignmentStatus.fair) {
        warnings.add(
          const CaptureWarning(
            message: 'Alignment fair',
            severity: WarningSeverity.advisory,
          ),
        );
      }
    }

    if (lighting != null && lighting.isWarning) {
      warnings.add(
        CaptureWarning(
          message: lighting.message,
          severity: WarningSeverity.advisory,
        ),
      );
    }

    if (focus != null && focus.isWarning) {
      warnings.add(
        const CaptureWarning(
          message: 'Image may be blurred',
          severity: WarningSeverity.caution,
          action: 'Retake',
        ),
      );
    }

    // The only configurable block, and null on every shipped protocol.
    final hardThreshold = protocol?.hardAlignmentThreshold;
    final blocked =
        hardThreshold != null &&
        alignment != null &&
        (!alignment.isAvailable || alignment.confidence < hardThreshold);

    return CaptureReadiness(
      canCapture: !blocked,
      isReady: warnings.isEmpty && (alignment?.isReady ?? true),
      warnings: warnings,
      blockedReason: blocked
          ? 'This protocol requires a closer match before capturing.'
          : null,
    );
  }

  /// True unless the camera is unavailable or a protocol blocks capture.
  final bool canCapture;

  /// True when everything enabled is satisfied. Drives "READY TO CAPTURE"
  /// (UX/UI section 22).
  final bool isReady;

  final List<CaptureWarning> warnings;

  final String? blockedReason;

  bool get hasWarnings => warnings.isNotEmpty;

  /// The warning to surface. One at a time (UX/UI sections 20, 63).
  CaptureWarning? get primaryWarning {
    if (warnings.isEmpty) return null;
    for (final warning in warnings) {
      if (warning.severity == WarningSeverity.caution) return warning;
    }
    return warnings.first;
  }

  /// The capture button's label.
  ///
  /// "Capture anyway" is offered whenever warnings exist, which is the
  /// affordance the specifications require (UX/UI section 24).
  String get captureLabel => hasWarnings ? 'Capture anyway' : 'Capture';
}
