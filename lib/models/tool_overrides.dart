import 'dart:collection';

import 'enums.dart';

/// The optional tools a user can turn on (UX/UI sections 11, 15; PRD 22).
enum WiseTool {
  overlay('Ghost Overlay', 'Overlay'),
  alignment('Alignment', 'Align'),
  lighting('Lighting Check', 'Light'),
  focus('Focus Check', 'Focus'),
  grid('Grid', 'Grid'),
  level('Level', 'Level'),
  measurement('Measurement', 'Measure'),
  annotation('Annotation', 'Mark'),
  difference('Difference View', 'Difference');

  const WiseTool(this.label, this.shortLabel);

  /// Name in the Tools drawer (UX/UI section 15).
  final String label;

  /// Compact name on the camera tool bar (UX/UI section 11).
  final String shortLabel;

  static WiseTool? fromWire(String value) =>
      values.where((t) => t.name == value).firstOrNull;
}

/// A *partial* tool configuration: a tool absent from [enabled] defers to the
/// layer below it.
///
/// The same type serves both the protocol layer and the session layer of the
/// precedence chain (Functional PRO-004, Build Specification section 22), which
/// is what lets `EffectiveSettings` resolve them with one fold instead of two
/// special cases.
///
/// Backed by a map rather than a wall of nullable fields so that "clear this
/// one tool's override" is a map removal, not a nine-branch rebuild.
class ToolOverrides {
  const ToolOverrides({
    Map<WiseTool, bool> enabled = const <WiseTool, bool>{},
    this.overlayOpacity,
    this.gridType,
  }) : _enabled = enabled;

  factory ToolOverrides.fromMap(Map<String, Object?> map) {
    final enabled = <WiseTool, bool>{};
    final rawTools = map['tools'] as Map<String, Object?>? ?? const {};
    for (final entry in rawTools.entries) {
      final tool = WiseTool.fromWire(entry.key);
      final value = entry.value;
      if (tool != null && value is bool) enabled[tool] = value;
    }
    return ToolOverrides(
      enabled: enabled,
      overlayOpacity: (map['overlay_opacity'] as num?)?.toDouble(),
      gridType: map['grid_type'] == null
          ? null
          : GridType.fromWire(map['grid_type']! as String),
    );
  }

  static const ToolOverrides none = ToolOverrides();

  final Map<WiseTool, bool> _enabled;

  /// Read-only view of the per-tool overrides.
  Map<WiseTool, bool> get enabled => UnmodifiableMapView(_enabled);

  final double? overlayOpacity;
  final GridType? gridType;

  bool get isEmpty =>
      _enabled.isEmpty && overlayOpacity == null && gridType == null;

  bool get isNotEmpty => !isEmpty;

  bool? valueFor(WiseTool tool) => _enabled[tool];

  /// Sets one tool's state, leaving the rest untouched.
  ToolOverrides setting(WiseTool tool, {required bool value}) => ToolOverrides(
    enabled: {..._enabled, tool: value},
    overlayOpacity: overlayOpacity,
    gridType: gridType,
  );

  /// Removes one tool's override so it falls back to the layer below.
  ToolOverrides clearing(WiseTool tool) => ToolOverrides(
    enabled: {..._enabled}..remove(tool),
    overlayOpacity: overlayOpacity,
    gridType: gridType,
  );

  ToolOverrides withOverlayOpacity(double? opacity) => ToolOverrides(
    enabled: _enabled,
    overlayOpacity: opacity,
    gridType: gridType,
  );

  ToolOverrides withGridType(GridType? type) => ToolOverrides(
    enabled: _enabled,
    overlayOpacity: overlayOpacity,
    gridType: type,
  );

  /// Drops every override. Used when a capture session ends, so that a
  /// one-capture override cannot leak into the next capture (Functional
  /// SET-003, Build Specification section 2.7).
  ToolOverrides cleared() => none;

  Map<String, Object?> toMap() => {
    'tools': <String, Object?>{
      for (final entry in _enabled.entries) entry.key.name: entry.value,
    },
    if (overlayOpacity != null) 'overlay_opacity': overlayOpacity,
    if (gridType != null) 'grid_type': gridType!.wireName,
  };
}
