import 'tool_overrides.dart';

/// What this device and build can actually do.
///
/// The top of the precedence chain: "a platform limitation always wins"
/// (Build Specification section 22, Functional PRO-004). A tool the platform
/// cannot support is off no matter what the user, the protocol or the session
/// asked for, and the UI shows it as unavailable with a reason rather than as a
/// control that silently does nothing (UX/UI section 74).
class ToolCapabilities {
  const ToolCapabilities({
    this.cameraAvailable = true,
    this.orientationSensorAvailable = true,
    this.alignmentSupported = true,
    this.lightingCheckSupported = true,
    this.focusCheckSupported = true,
    this.differenceViewSupported = true,
    this.unavailableReasons = const {},
  });

  /// Everything supported. Used by tests and as the starting point before
  /// device detection completes.
  static const ToolCapabilities full = ToolCapabilities();

  final bool cameraAvailable;

  /// Accelerometer/gyroscope for the level tool (Functional LVL-002).
  final bool orientationSensorAvailable;

  /// Whether the alignment feature flag and device tier permit live analysis
  /// (CV section 58).
  final bool alignmentSupported;

  final bool lightingCheckSupported;
  final bool focusCheckSupported;
  final bool differenceViewSupported;

  /// Human-readable reason per unsupported tool, shown in the Tools drawer.
  final Map<WiseTool, String> unavailableReasons;

  bool supports(WiseTool tool) => switch (tool) {
    WiseTool.overlay => true,
    WiseTool.alignment => alignmentSupported,
    WiseTool.lighting => lightingCheckSupported,
    WiseTool.focus => focusCheckSupported,
    WiseTool.grid => true,
    WiseTool.level => orientationSensorAvailable,
    WiseTool.measurement => true,
    WiseTool.annotation => true,
    WiseTool.difference => differenceViewSupported,
  };

  String? reasonFor(WiseTool tool) =>
      supports(tool) ? null : unavailableReasons[tool] ?? _defaultReason(tool);

  static String _defaultReason(WiseTool tool) => switch (tool) {
    WiseTool.level => 'This device does not report orientation.',
    WiseTool.alignment =>
      'Automatic alignment is unavailable on this device. '
          'Ghost Overlay remains available.',
    _ => 'This device does not support this feature.',
  };

  ToolCapabilities copyWith({
    bool? cameraAvailable,
    bool? orientationSensorAvailable,
    bool? alignmentSupported,
    bool? lightingCheckSupported,
    bool? focusCheckSupported,
    bool? differenceViewSupported,
    Map<WiseTool, String>? unavailableReasons,
  }) => ToolCapabilities(
    cameraAvailable: cameraAvailable ?? this.cameraAvailable,
    orientationSensorAvailable:
        orientationSensorAvailable ?? this.orientationSensorAvailable,
    alignmentSupported: alignmentSupported ?? this.alignmentSupported,
    lightingCheckSupported:
        lightingCheckSupported ?? this.lightingCheckSupported,
    focusCheckSupported: focusCheckSupported ?? this.focusCheckSupported,
    differenceViewSupported:
        differenceViewSupported ?? this.differenceViewSupported,
    unavailableReasons: unavailableReasons ?? this.unavailableReasons,
  );
}
