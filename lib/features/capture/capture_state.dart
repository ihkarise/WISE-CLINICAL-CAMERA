import '../../core/cv/alignment_result.dart';
import '../../core/cv/focus_engine.dart';
import '../../core/cv/guidance_engine.dart';
import '../../core/cv/lighting_engine.dart';
import '../../core/errors/failures.dart';
import '../../core/sensors/device_level_service.dart';
import '../../models/enums.dart';
import '../../models/photo.dart';
import '../../models/reference_transform.dart';
import 'capture_readiness.dart';

/// The application states the functional specification enumerates
/// (Functional section 46). Transitions must be deterministic.
enum CapturePhase {
  idle,
  cameraInitializing,
  referenceLoading,
  previewing,
  capturing,
  processing,
  reviewing,
  saving,
  error,
}

/// Everything the capture screen renders from.
///
/// Immutable, so a rebuild cannot observe a half-applied change while a frame
/// is being analysed.
class CaptureState {
  const CaptureState({
    required this.mode,
    this.phase = CapturePhase.idle,
    this.reference,
    this.referenceTransform = ReferenceTransform.identity,
    this.alignment,
    this.lighting,
    this.focus,
    this.level = LevelReading.unavailable,
    this.guidance,
    this.readiness,
    this.capturedPhoto,
    this.failure,
    this.bodyPart,
    this.laterality,
    this.caseId,
    this.protocolId,
  });

  final PhotoType mode;
  final CapturePhase phase;

  /// The Before being reproduced. Always null in BEFORE and PHOTO modes.
  final Photo? reference;

  final ReferenceTransform referenceTransform;
  final AlignmentResult? alignment;
  final LightingAssessment? lighting;
  final FocusAssessment? focus;
  final LevelReading level;
  final GuidanceInstruction? guidance;
  final CaptureReadiness? readiness;

  /// Set once a photograph has been taken and is awaiting review.
  final Photo? capturedPhoto;

  final Failure? failure;
  final BodyPart? bodyPart;
  final Laterality? laterality;
  final String? caseId;
  final String? protocolId;

  bool get isAfterMode => mode == PhotoType.after;

  bool get hasReference => reference != null;

  bool get isBusy =>
      phase == CapturePhase.capturing ||
      phase == CapturePhase.processing ||
      phase == CapturePhase.saving;

  bool get canCapture =>
      phase == CapturePhase.previewing && (readiness?.canCapture ?? true);

  CaptureState copyWith({
    CapturePhase? phase,
    Photo? reference,
    ReferenceTransform? referenceTransform,
    AlignmentResult? alignment,
    LightingAssessment? lighting,
    FocusAssessment? focus,
    LevelReading? level,
    GuidanceInstruction? guidance,
    CaptureReadiness? readiness,
    Photo? capturedPhoto,
    Failure? failure,
    BodyPart? bodyPart,
    Laterality? laterality,
    String? caseId,
    String? protocolId,
    bool clearGuidance = false,
    bool clearFailure = false,
    bool clearCapturedPhoto = false,
    bool clearAlignment = false,
    bool clearBodyPart = false,
    bool clearLaterality = false,
    bool clearCase = false,
  }) => CaptureState(
    mode: mode,
    phase: phase ?? this.phase,
    reference: reference ?? this.reference,
    referenceTransform: referenceTransform ?? this.referenceTransform,
    alignment: clearAlignment ? null : (alignment ?? this.alignment),
    lighting: lighting ?? this.lighting,
    focus: focus ?? this.focus,
    level: level ?? this.level,
    guidance: clearGuidance ? null : (guidance ?? this.guidance),
    readiness: readiness ?? this.readiness,
    capturedPhoto: clearCapturedPhoto
        ? null
        : (capturedPhoto ?? this.capturedPhoto),
    failure: clearFailure ? null : (failure ?? this.failure),
    bodyPart: clearBodyPart ? null : (bodyPart ?? this.bodyPart),
    laterality: clearLaterality ? null : (laterality ?? this.laterality),
    caseId: clearCase ? null : (caseId ?? this.caseId),
    protocolId: protocolId ?? this.protocolId,
  );
}
