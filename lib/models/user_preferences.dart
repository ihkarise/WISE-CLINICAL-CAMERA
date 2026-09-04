import 'enums.dart';

/// Persistent per-user tool defaults (Data Model section 16, Functional
/// SET-001).
///
/// These survive app close, app restart and device restart (Functional
/// SET-002). They are stored in SQLite rather than in session memory (Build
/// Specification section 20) and are only ever changed by an explicit user
/// action (PRD section 2).
class UserPreferences {
  const UserPreferences({
    required this.userId,
    required this.updatedAt,
    this.overlayEnabled = true,
    this.overlayOpacity = 0.5,
    this.alignmentEnabled = true,
    this.lightingEnabled = true,
    this.focusEnabled = true,
    this.gridEnabled = false,
    this.gridType = GridType.thirds,
    this.levelEnabled = false,
    this.measurementEnabled = false,
    this.annotationEnabled = false,
    this.differenceEnabled = false,
    this.comparisonMode = ComparisonMode.sideBySide,
    this.gallerySaveMode = GallerySaveMode.ask,
    this.privacyMode = true,
    this.measurementUnit = LengthUnit.centimetre,
    this.showAlignmentScore = false,
    this.version = 1,
  });

  /// Defaults for a brand-new user.
  ///
  /// Privacy Mode is **on** and Gallery saving is **ask**: privacy is a default,
  /// not an advanced configuration (Build Specification section 2.10, Privacy
  /// section 69 "privacy by default"). Overlay, alignment, lighting and focus
  /// start on because they are the product's reason to exist; measurement,
  /// annotation, grid, level and difference start off so the camera stays
  /// simple (PRD sections 2, 22).
  factory UserPreferences.initial(String userId, {DateTime? now}) =>
      UserPreferences(userId: userId, updatedAt: now ?? DateTime.now());

  final String userId;
  final bool overlayEnabled;

  /// 0.1-1.0. The UI presents 10%-100% (Functional OVR-002).
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

  /// Whether the numeric alignment score is shown alongside the status
  /// (Functional ALG-005; normal users should not need to read it).
  final bool showAlignmentScore;

  final DateTime updatedAt;
  final int version;

  UserPreferences copyWith({
    bool? overlayEnabled,
    double? overlayOpacity,
    bool? alignmentEnabled,
    bool? lightingEnabled,
    bool? focusEnabled,
    bool? gridEnabled,
    GridType? gridType,
    bool? levelEnabled,
    bool? measurementEnabled,
    bool? annotationEnabled,
    bool? differenceEnabled,
    ComparisonMode? comparisonMode,
    GallerySaveMode? gallerySaveMode,
    bool? privacyMode,
    LengthUnit? measurementUnit,
    bool? showAlignmentScore,
    DateTime? updatedAt,
    int? version,
  }) => UserPreferences(
    userId: userId,
    overlayEnabled: overlayEnabled ?? this.overlayEnabled,
    overlayOpacity: overlayOpacity ?? this.overlayOpacity,
    alignmentEnabled: alignmentEnabled ?? this.alignmentEnabled,
    lightingEnabled: lightingEnabled ?? this.lightingEnabled,
    focusEnabled: focusEnabled ?? this.focusEnabled,
    gridEnabled: gridEnabled ?? this.gridEnabled,
    gridType: gridType ?? this.gridType,
    levelEnabled: levelEnabled ?? this.levelEnabled,
    measurementEnabled: measurementEnabled ?? this.measurementEnabled,
    annotationEnabled: annotationEnabled ?? this.annotationEnabled,
    differenceEnabled: differenceEnabled ?? this.differenceEnabled,
    comparisonMode: comparisonMode ?? this.comparisonMode,
    gallerySaveMode: gallerySaveMode ?? this.gallerySaveMode,
    privacyMode: privacyMode ?? this.privacyMode,
    measurementUnit: measurementUnit ?? this.measurementUnit,
    showAlignmentScore: showAlignmentScore ?? this.showAlignmentScore,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );

  Map<String, Object?> toRow() => {
    'user_id': userId,
    'overlay_enabled': overlayEnabled ? 1 : 0,
    'overlay_opacity': overlayOpacity,
    'alignment_enabled': alignmentEnabled ? 1 : 0,
    'lighting_enabled': lightingEnabled ? 1 : 0,
    'focus_enabled': focusEnabled ? 1 : 0,
    'grid_enabled': gridEnabled ? 1 : 0,
    'grid_type': gridType.wireName,
    'level_enabled': levelEnabled ? 1 : 0,
    'measurement_enabled': measurementEnabled ? 1 : 0,
    'annotation_enabled': annotationEnabled ? 1 : 0,
    'difference_enabled': differenceEnabled ? 1 : 0,
    'comparison_mode': comparisonMode.wireName,
    'gallery_save_mode': gallerySaveMode.wireName,
    'privacy_mode': privacyMode ? 1 : 0,
    'measurement_unit': measurementUnit.wireName,
    'show_alignment_score': showAlignmentScore ? 1 : 0,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'version': version,
  };

  static UserPreferences fromRow(Map<String, Object?> row) => UserPreferences(
    userId: row['user_id']! as String,
    overlayEnabled: _bool(row['overlay_enabled']),
    overlayOpacity: (row['overlay_opacity'] as num?)?.toDouble() ?? 0.5,
    alignmentEnabled: _bool(row['alignment_enabled']),
    lightingEnabled: _bool(row['lighting_enabled']),
    focusEnabled: _bool(row['focus_enabled']),
    gridEnabled: _bool(row['grid_enabled']),
    gridType: GridType.fromWire(row['grid_type'] as String? ?? '3x3'),
    levelEnabled: _bool(row['level_enabled']),
    measurementEnabled: _bool(row['measurement_enabled']),
    annotationEnabled: _bool(row['annotation_enabled']),
    differenceEnabled: _bool(row['difference_enabled']),
    comparisonMode: ComparisonMode.fromWire(
      row['comparison_mode'] as String? ?? 'SIDE_BY_SIDE',
    ),
    gallerySaveMode: GallerySaveMode.fromWire(
      row['gallery_save_mode'] as String? ?? 'ASK',
    ),
    privacyMode: _bool(row['privacy_mode']),
    measurementUnit: LengthUnit.fromWire(
      row['measurement_unit'] as String? ?? 'cm',
    ),
    showAlignmentScore: _bool(row['show_alignment_score']),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
    version: (row['version'] as num?)?.toInt() ?? 1,
  );

  /// SQLite stores booleans as INTEGER 0/1 (Data Model section 16).
  static bool _bool(Object? value) => (value as num?)?.toInt() == 1;
}
