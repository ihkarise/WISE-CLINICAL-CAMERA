import 'app_environment.dart';

/// Feature flags required by Build Specification section 89 and AI section 56.
///
/// Experimental functionality must be separable from stable core functionality,
/// so nothing here gates the core capture path: with every flag `false` the
/// application still runs BEFORE, AFTER and PHOTO end to end.
class FeatureFlags {
  const FeatureFlags({
    this.alignment = true,
    this.homography = false,
    this.opticalFlow = false,
    this.lightingCheck = true,
    this.focusCheck = true,
    this.differenceView = true,
    this.protocols = true,
    this.onDeviceAi = false,
    this.cloudAi = false,
    this.aiBodyRegionDetection = false,
    this.aiLandmarkDetection = false,
    this.aiOcr = false,
    this.aiReportAssistance = false,
    this.cvDebugOverlay = false,
    this.eventLog = false,
  });

  /// Defaults for the running build.
  ///
  /// Cloud AI is off (AI section 65). On-device ML is off because no model is
  /// shipped in V1 (AI section 66). Homography and optical flow are off because
  /// CV section 73 places them at stages 4 and 7, after benchmarking that has
  /// not happened. The event log is off by default (Data Model section 33,
  /// Privacy section 24).
  factory FeatureFlags.forEnvironment(AppEnvironment environment) =>
      FeatureFlags(cvDebugOverlay: environment.allowsCvDebugOverlay);

  /// Live alignment analysis against the reference (CV section 2).
  final bool alignment;

  /// Projective transform estimation. Stage 4 of CV section 73; requires
  /// benchmarking before it is enabled by default (CV section 22).
  final bool homography;

  /// Stage 7 of CV section 73. Not implemented in V1.
  final bool opticalFlow;

  final bool lightingCheck;
  final bool focusCheck;
  final bool differenceView;
  final bool protocols;

  /// Tier 2 of AI section 4. No model ships in V1.
  final bool onDeviceAi;

  /// Tier 4 of AI section 4. Must stay false unless the user explicitly
  /// configures a provider (AI sections 65, 67).
  final bool cloudAi;

  final bool aiBodyRegionDetection;
  final bool aiLandmarkDetection;
  final bool aiOcr;
  final bool aiReportAssistance;

  /// Keypoint/match/inlier overlay. Forced off outside development.
  final bool cvDebugOverlay;

  /// Local event table writes (Data Model section 33).
  final bool eventLog;

  FeatureFlags copyWith({
    bool? alignment,
    bool? homography,
    bool? opticalFlow,
    bool? lightingCheck,
    bool? focusCheck,
    bool? differenceView,
    bool? protocols,
    bool? onDeviceAi,
    bool? cloudAi,
    bool? aiBodyRegionDetection,
    bool? aiLandmarkDetection,
    bool? aiOcr,
    bool? aiReportAssistance,
    bool? cvDebugOverlay,
    bool? eventLog,
  }) => FeatureFlags(
    alignment: alignment ?? this.alignment,
    homography: homography ?? this.homography,
    opticalFlow: opticalFlow ?? this.opticalFlow,
    lightingCheck: lightingCheck ?? this.lightingCheck,
    focusCheck: focusCheck ?? this.focusCheck,
    differenceView: differenceView ?? this.differenceView,
    protocols: protocols ?? this.protocols,
    onDeviceAi: onDeviceAi ?? this.onDeviceAi,
    cloudAi: cloudAi ?? this.cloudAi,
    aiBodyRegionDetection: aiBodyRegionDetection ?? this.aiBodyRegionDetection,
    aiLandmarkDetection: aiLandmarkDetection ?? this.aiLandmarkDetection,
    aiOcr: aiOcr ?? this.aiOcr,
    aiReportAssistance: aiReportAssistance ?? this.aiReportAssistance,
    cvDebugOverlay: cvDebugOverlay ?? this.cvDebugOverlay,
    eventLog: eventLog ?? this.eventLog,
  );

  /// Every AI capability off. The state the core product is specified to work
  /// in (AI section 3, Build Specification section 2.4).
  bool get aiFullyDisabled =>
      !onDeviceAi &&
      !cloudAi &&
      !aiBodyRegionDetection &&
      !aiLandmarkDetection &&
      !aiOcr &&
      !aiReportAssistance;
}
