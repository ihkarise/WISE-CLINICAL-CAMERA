import 'dart:convert';

import 'enums.dart';
import 'tool_overrides.dart';

/// A reusable capture configuration (Data Model section 14, Functional
/// PRO-001..005).
///
/// Protocols are versioned. Editing a protocol bumps its version and must never
/// rewrite the capture recipes of photographs already taken under an earlier
/// version (Data Model section 46, Functional PRO-005).
class CaptureProtocol {
  const CaptureProtocol({
    required this.id,
    required this.name,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.description,
    this.version = 1,
    this.isSystem = false,
    this.isActive = true,
    this.deletedAt,
  });

  final String id;
  final String? userId;
  final String name;
  final String? description;
  final ProtocolSettings settings;

  /// Incremented on every edit (Functional PRO-005).
  final int version;

  /// True for the seeded protocols shipped with the app.
  final bool isSystem;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Produces the next version of this protocol.
  ///
  /// Always bumps [version] so historical capture recipes referencing the old
  /// version remain unambiguous.
  CaptureProtocol edited({
    String? name,
    String? description,
    ProtocolSettings? settings,
    bool? isActive,
    DateTime? now,
  }) => CaptureProtocol(
    id: id,
    userId: userId,
    name: name ?? this.name,
    description: description ?? this.description,
    settings: settings ?? this.settings,
    version: version + 1,
    isSystem: isSystem,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: now ?? DateTime.now(),
    deletedAt: deletedAt,
  );

  CaptureProtocol copyWith({
    bool? isActive,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => CaptureProtocol(
    id: id,
    userId: userId,
    name: name,
    description: description,
    settings: settings,
    version: version,
    isSystem: isSystem,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'description': description,
    'settings_json': jsonEncode(settings.toMap()),
    'version': version,
    'is_system': isSystem ? 1 : 0,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  static CaptureProtocol fromRow(Map<String, Object?> row) => CaptureProtocol(
    id: row['id']! as String,
    userId: row['user_id'] as String?,
    name: row['name']! as String,
    description: row['description'] as String?,
    settings: ProtocolSettings.fromMap(
      jsonDecode(row['settings_json']! as String) as Map<String, Object?>,
    ),
    version: (row['version'] as num?)?.toInt() ?? 1,
    isSystem: (row['is_system'] as num?)?.toInt() == 1,
    isActive: (row['is_active'] as num?)?.toInt() != 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (row['deleted_at']! as num).toInt(),
          ),
  );
}

/// The configuration a protocol carries (Data Model section 15, Functional
/// PRO-002).
class ProtocolSettings {
  const ProtocolSettings({
    this.tools = ToolOverrides.none,
    this.preferredOrientation,
    this.preferredFlash,
    this.measurementRequired = false,
    this.hardAlignmentThreshold,
    this.exportPreset,
    this.exportFooter = true,
  });

  factory ProtocolSettings.fromMap(Map<String, Object?> map) {
    final camera = map['camera'] as Map<String, Object?>? ?? const {};
    final export = map['export'] as Map<String, Object?>? ?? const {};
    return ProtocolSettings(
      tools: ToolOverrides.fromMap(map),
      preferredOrientation: camera['preferred_orientation'] == null
          ? null
          : CaptureOrientation.fromWire(
              camera['preferred_orientation']! as String,
            ),
      preferredFlash: camera['flash'] == null
          ? null
          : WiseFlashMode.fromWire(camera['flash']! as String),
      measurementRequired: map['measurement_required'] as bool? ?? false,
      hardAlignmentThreshold: (map['hard_alignment_threshold'] as num?)
          ?.toDouble(),
      exportPreset: export['preset'] == null
          ? null
          : ExportPreset.fromWire(export['preset']! as String),
      exportFooter: export['footer'] as bool? ?? true,
    );
  }

  final ToolOverrides tools;
  final CaptureOrientation? preferredOrientation;
  final WiseFlashMode? preferredFlash;
  final bool measurementRequired;

  /// The one mechanism permitted to block capture.
  ///
  /// Null on every seeded protocol. Only "a deliberately configured protocol"
  /// may impose a hard requirement; otherwise warnings stay advisory
  /// (CV section 40, Functional MOD-023, Build Specification section 30). See
  /// SPECIFICATION_CONFLICTS C-018.
  final double? hardAlignmentThreshold;

  final ExportPreset? exportPreset;
  final bool exportFooter;

  Map<String, Object?> toMap() => {
    ...tools.toMap(),
    'camera': <String, Object?>{
      if (preferredOrientation != null)
        'preferred_orientation': preferredOrientation!.wireName,
      if (preferredFlash != null) 'flash': preferredFlash!.wireName,
    },
    'measurement_required': measurementRequired,
    if (hardAlignmentThreshold != null)
      'hard_alignment_threshold': hardAlignmentThreshold,
    'export': <String, Object?>{
      if (exportPreset != null) 'preset': exportPreset!.wireName,
      'footer': exportFooter,
    },
  };
}
