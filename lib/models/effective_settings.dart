import 'enums.dart';
import 'tool_capabilities.dart';
import 'tool_overrides.dart';
import 'user_preferences.dart';

/// Where an effective value came from. Lets the UI explain *why* a tool is off
/// ("your protocol turns this off") instead of leaving the user guessing.
enum SettingSource { platform, userDefault, protocol, session }

/// The resolved tool configuration for one capture.
///
/// Implements the precedence chain that five specifications state identically
/// (Functional PRO-004, Technical Architecture 27, Data Model 54, Build
/// Specification 22, PRD 22-23):
///
/// ```text
/// Platform capability  ->  User default  ->  Protocol  ->  Session override
///                                                              |
///                                                    Effective setting
/// ```
///
/// The platform layer is applied **last and as a veto**, not first as a value:
/// a device that cannot do something must end up off regardless of what the
/// layers below asked for.
///
/// Resolution is a pure function of its inputs. Nothing here writes to the
/// database, which is what guarantees a session override cannot silently become
/// a new default (Build Specification section 2.7).
class EffectiveSettings {
  const EffectiveSettings({
    required this.overlayEnabled,
    required this.overlayOpacity,
    required this.alignmentEnabled,
    required this.lightingEnabled,
    required this.focusEnabled,
    required this.gridEnabled,
    required this.gridType,
    required this.levelEnabled,
    required this.measurementEnabled,
    required this.annotationEnabled,
    required this.differenceEnabled,
    required this.comparisonMode,
    required this.gallerySaveMode,
    required this.privacyMode,
    required this.measurementUnit,
    required this.showAlignmentScore,
    required this.sources,
  });

  /// Resolves the effective configuration.
  ///
  /// [protocol] is the active capture protocol's tool block, or null when no
  /// protocol is selected. [session] holds one-capture overrides and is
  /// discarded when the capture session ends.
  factory EffectiveSettings.resolve({
    required UserPreferences defaults,
    ToolCapabilities capabilities = ToolCapabilities.full,
    ToolOverrides? protocol,
    ToolOverrides? session,
  }) {
    final sources = <WiseTool, SettingSource>{};

    bool resolveTool(WiseTool tool, {required bool userDefault}) {
      // Platform veto first, so an unsupported tool can never report a source
      // that suggests the user could turn it on.
      if (!capabilities.supports(tool)) {
        sources[tool] = SettingSource.platform;
        return false;
      }
      final sessionValue = session?.valueFor(tool);
      if (sessionValue != null) {
        sources[tool] = SettingSource.session;
        return sessionValue;
      }
      final protocolValue = protocol?.valueFor(tool);
      if (protocolValue != null) {
        sources[tool] = SettingSource.protocol;
        return protocolValue;
      }
      sources[tool] = SettingSource.userDefault;
      return userDefault;
    }

    final overlay = resolveTool(
      WiseTool.overlay,
      userDefault: defaults.overlayEnabled,
    );
    final alignment = resolveTool(
      WiseTool.alignment,
      userDefault: defaults.alignmentEnabled,
    );
    final lighting = resolveTool(
      WiseTool.lighting,
      userDefault: defaults.lightingEnabled,
    );
    final focus = resolveTool(
      WiseTool.focus,
      userDefault: defaults.focusEnabled,
    );
    final grid = resolveTool(WiseTool.grid, userDefault: defaults.gridEnabled);
    final level = resolveTool(
      WiseTool.level,
      userDefault: defaults.levelEnabled,
    );
    final measurement = resolveTool(
      WiseTool.measurement,
      userDefault: defaults.measurementEnabled,
    );
    final annotation = resolveTool(
      WiseTool.annotation,
      userDefault: defaults.annotationEnabled,
    );
    final difference = resolveTool(
      WiseTool.difference,
      userDefault: defaults.differenceEnabled,
    );

    final opacity =
        session?.overlayOpacity ??
        protocol?.overlayOpacity ??
        defaults.overlayOpacity;

    return EffectiveSettings(
      overlayEnabled: overlay,
      overlayOpacity: opacity.clamp(minOverlayOpacity, maxOverlayOpacity),
      alignmentEnabled: alignment,
      lightingEnabled: lighting,
      focusEnabled: focus,
      gridEnabled: grid,
      gridType: session?.gridType ?? protocol?.gridType ?? defaults.gridType,
      levelEnabled: level,
      measurementEnabled: measurement,
      annotationEnabled: annotation,
      differenceEnabled: difference,
      comparisonMode: defaults.comparisonMode,
      gallerySaveMode: defaults.privacyMode
          // Privacy Mode forbids automatic Gallery copies, so ALWAYS is
          // downgraded rather than obeyed (Functional PRI-004, Privacy 4).
          ? (defaults.gallerySaveMode == GallerySaveMode.always
                ? GallerySaveMode.ask
                : defaults.gallerySaveMode)
          : defaults.gallerySaveMode,
      privacyMode: defaults.privacyMode,
      measurementUnit: defaults.measurementUnit,
      showAlignmentScore: defaults.showAlignmentScore,
      sources: Map.unmodifiable(sources),
    );
  }

  /// Overlay opacity bounds (Functional OVR-002: 10%-100%).
  static const double minOverlayOpacity = 0.1;
  static const double maxOverlayOpacity = 1;

  final bool overlayEnabled;
  final double overlayOpacity;
  final bool alignmentEnabled;
  final bool lightingEnabled;
  final bool focusEnabled;
  final bool gridEnabled;
  final GridType gridType;
  final bool levelEnabled;
  final bool measurementEnabled;
  final bool annotationEnabled;
  final bool differenceEnabled;
  final ComparisonMode comparisonMode;
  final GallerySaveMode gallerySaveMode;
  final bool privacyMode;
  final LengthUnit measurementUnit;
  final bool showAlignmentScore;

  /// Which layer decided each tool.
  final Map<WiseTool, SettingSource> sources;

  bool isEnabled(WiseTool tool) => switch (tool) {
    WiseTool.overlay => overlayEnabled,
    WiseTool.alignment => alignmentEnabled,
    WiseTool.lighting => lightingEnabled,
    WiseTool.focus => focusEnabled,
    WiseTool.grid => gridEnabled,
    WiseTool.level => levelEnabled,
    WiseTool.measurement => measurementEnabled,
    WiseTool.annotation => annotationEnabled,
    WiseTool.difference => differenceEnabled,
  };

  SettingSource sourceOf(WiseTool tool) =>
      sources[tool] ?? SettingSource.userDefault;

  /// True when a one-capture override, not the saved default, decided this
  /// tool. The camera shows a compact "off for this capture" chip in that case
  /// (UX/UI section 14).
  bool isSessionOverridden(WiseTool tool) =>
      sourceOf(tool) == SettingSource.session;

  Iterable<WiseTool> get activeTools => WiseTool.values.where(isEnabled);

  /// True when no optional tool is on: the plain camera the PRD insists must
  /// keep working (PRD section 2, Functional section 2).
  bool get isPlainCamera => activeTools.isEmpty;
}
