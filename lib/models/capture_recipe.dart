import 'dart:convert';

import 'enums.dart';

/// What a Before photograph remembers about how it was taken, so an After can
/// be set up the same way (Data Model sections 11-12, Build Specification
/// section 13, master prompt Phase 13).
///
/// Every camera field is nullable. Camera APIs differ between iOS and Android
/// and between devices on the same platform, so an absent value means "this
/// device did not report it", never "zero" (Data Model section 13, Technical
/// Architecture section 6).
///
/// The recipe is informational. The system must not assume a later device can
/// reproduce every parameter exactly (Data Model section 11).
class CaptureRecipe {
  const CaptureRecipe({
    this.version = currentVersion,
    this.cameraPosition,
    this.lensIdentifier,
    this.zoom,
    this.flashMode,
    this.focusMode,
    this.orientation,
    this.previewAspectRatio,
    this.gridType,
    this.levelEnabled = false,
    this.overlayEnabled = false,
    this.alignmentEnabled = false,
    this.lightingCheckEnabled = false,
    this.focusCheckEnabled = false,
    this.measurementEnabled = false,
    this.annotationEnabled = false,
    this.deviceTiltDegrees,
    this.protocolId,
    this.protocolVersion,
  });

  factory CaptureRecipe.fromJson(String json) =>
      CaptureRecipe.fromMap(jsonDecode(json) as Map<String, Object?>);

  factory CaptureRecipe.fromMap(Map<String, Object?> map) {
    final camera = map['camera'] as Map<String, Object?>? ?? const {};
    return CaptureRecipe(
      version: (map['version'] as num?)?.toInt() ?? 1,
      cameraPosition: camera['position'] == null
          ? null
          : CameraPosition.fromWire(camera['position']! as String),
      lensIdentifier: camera['lens'] as String?,
      zoom: (camera['zoom'] as num?)?.toDouble(),
      flashMode: camera['flash'] == null
          ? null
          : WiseFlashMode.fromWire(camera['flash']! as String),
      focusMode: camera['focus_mode'] as String?,
      orientation: map['orientation'] == null
          ? null
          : CaptureOrientation.fromWire(map['orientation']! as String),
      previewAspectRatio: (map['preview_aspect_ratio'] as num?)?.toDouble(),
      gridType: map['grid'] == null
          ? null
          : GridType.fromWire(map['grid']! as String),
      levelEnabled: map['level_enabled'] as bool? ?? false,
      overlayEnabled: map['overlay_enabled'] as bool? ?? false,
      alignmentEnabled: map['alignment_enabled'] as bool? ?? false,
      lightingCheckEnabled: map['lighting_check_enabled'] as bool? ?? false,
      focusCheckEnabled: map['focus_check_enabled'] as bool? ?? false,
      measurementEnabled: map['measurement_enabled'] as bool? ?? false,
      annotationEnabled: map['annotation_enabled'] as bool? ?? false,
      deviceTiltDegrees: (map['device_tilt_degrees'] as num?)?.toDouble(),
      protocolId: map['protocol_id'] as String?,
      protocolVersion: (map['protocol_version'] as num?)?.toInt(),
    );
  }

  /// Data Model section 12. Bump when fields are added; older recipes stay
  /// readable because every field is optional.
  static const int currentVersion = 1;

  final int version;
  final CameraPosition? cameraPosition;
  final String? lensIdentifier;
  final double? zoom;
  final WiseFlashMode? flashMode;
  final String? focusMode;
  final CaptureOrientation? orientation;
  final double? previewAspectRatio;
  final GridType? gridType;
  final bool levelEnabled;
  final bool overlayEnabled;
  final bool alignmentEnabled;
  final bool lightingCheckEnabled;
  final bool focusCheckEnabled;
  final bool measurementEnabled;
  final bool annotationEnabled;

  /// Device tilt at capture, in degrees from level, when a sensor reported it.
  final double? deviceTiltDegrees;

  /// The protocol in force, captured with its version so that editing the
  /// protocol later cannot rewrite this record (Data Model section 46,
  /// Functional PRO-005).
  final String? protocolId;
  final int? protocolVersion;

  Map<String, Object?> toMap() => {
    'version': version,
    'camera': <String, Object?>{
      'position': cameraPosition?.wireName,
      'lens': lensIdentifier,
      'zoom': zoom,
      'flash': flashMode?.wireName,
      'focus_mode': focusMode,
    },
    'orientation': orientation?.wireName,
    'preview_aspect_ratio': previewAspectRatio,
    'grid': gridType?.wireName,
    'level_enabled': levelEnabled,
    'overlay_enabled': overlayEnabled,
    'alignment_enabled': alignmentEnabled,
    'lighting_check_enabled': lightingCheckEnabled,
    'focus_check_enabled': focusCheckEnabled,
    'measurement_enabled': measurementEnabled,
    'annotation_enabled': annotationEnabled,
    'device_tilt_degrees': deviceTiltDegrees,
    'protocol_id': protocolId,
    'protocol_version': protocolVersion,
  };

  String toJson() => jsonEncode(toMap());

  CaptureRecipe copyWith({
    CameraPosition? cameraPosition,
    String? lensIdentifier,
    double? zoom,
    WiseFlashMode? flashMode,
    String? focusMode,
    CaptureOrientation? orientation,
    double? previewAspectRatio,
    GridType? gridType,
    bool? levelEnabled,
    bool? overlayEnabled,
    bool? alignmentEnabled,
    bool? lightingCheckEnabled,
    bool? focusCheckEnabled,
    bool? measurementEnabled,
    bool? annotationEnabled,
    double? deviceTiltDegrees,
    String? protocolId,
    int? protocolVersion,
  }) => CaptureRecipe(
    version: version,
    cameraPosition: cameraPosition ?? this.cameraPosition,
    lensIdentifier: lensIdentifier ?? this.lensIdentifier,
    zoom: zoom ?? this.zoom,
    flashMode: flashMode ?? this.flashMode,
    focusMode: focusMode ?? this.focusMode,
    orientation: orientation ?? this.orientation,
    previewAspectRatio: previewAspectRatio ?? this.previewAspectRatio,
    gridType: gridType ?? this.gridType,
    levelEnabled: levelEnabled ?? this.levelEnabled,
    overlayEnabled: overlayEnabled ?? this.overlayEnabled,
    alignmentEnabled: alignmentEnabled ?? this.alignmentEnabled,
    lightingCheckEnabled: lightingCheckEnabled ?? this.lightingCheckEnabled,
    focusCheckEnabled: focusCheckEnabled ?? this.focusCheckEnabled,
    measurementEnabled: measurementEnabled ?? this.measurementEnabled,
    annotationEnabled: annotationEnabled ?? this.annotationEnabled,
    deviceTiltDegrees: deviceTiltDegrees ?? this.deviceTiltDegrees,
    protocolId: protocolId ?? this.protocolId,
    protocolVersion: protocolVersion ?? this.protocolVersion,
  );

  /// Differences a user can act on when reproducing this photograph.
  ///
  /// Only fields present in *both* recipes are compared: an absent value means
  /// unknown, and reporting "flash differs" because the current device does not
  /// report flash state would be a false warning.
  List<String> differencesFrom(CaptureRecipe current) {
    final differences = <String>[];

    if (orientation != null &&
        current.orientation != null &&
        orientation != current.orientation) {
      differences.add('Reference was taken in ${orientation!.wireName}.');
    }
    if (flashMode != null &&
        current.flashMode != null &&
        flashMode != current.flashMode) {
      differences.add('Reference used flash ${flashMode!.wireName}.');
    }
    if (zoom != null && current.zoom != null) {
      final ratio = current.zoom! / (zoom! == 0 ? 1 : zoom!);
      if (ratio > 1.1) {
        differences.add('Reference was taken at a wider zoom.');
      } else if (ratio < 0.9) {
        differences.add('Reference was taken at a closer zoom.');
      }
    }
    if (cameraPosition != null &&
        current.cameraPosition != null &&
        cameraPosition != current.cameraPosition) {
      differences.add(
        'Reference was taken with the ${cameraPosition!.wireName} camera.',
      );
    }
    return differences;
  }
}
