import '../core/database/database_ids.dart';
import '../core/database/database_service.dart';
import '../core/errors/failures.dart';
import '../core/errors/result.dart';
import '../models/capture_protocol.dart';
import '../models/enums.dart';
import '../models/tool_overrides.dart';

/// Reusable capture protocols (Data Model section 14, Functional PRO-001..005).
///
/// Editing a protocol bumps its version. Historical capture recipes store the
/// protocol id *and* the version they were taken under, so an edit can never
/// rewrite what an old photograph was captured with (Data Model section 46,
/// Functional PRO-005).
class ProtocolRepository {
  ProtocolRepository({
    required DatabaseService database,
    DatabaseIds ids = const DatabaseIds(),
  }) : _db = database,
       _ids = ids;

  final DatabaseService _db;
  final DatabaseIds _ids;

  /// The five protocols the specifications name (Build Specification 45,
  /// PRD section 21).
  ///
  /// None sets `hardAlignmentThreshold`: no shipped configuration blocks
  /// capture (SPECIFICATION_CONFLICTS C-018).
  static List<({String name, String description, ProtocolSettings settings})>
  systemProtocolTemplates() => [
    (
      name: 'Dermatology Standard',
      description: 'Overlay, alignment, lighting, focus, grid and measurement.',
      settings: ProtocolSettings(
        tools: const ToolOverrides(
          enabled: {
            WiseTool.overlay: true,
            WiseTool.alignment: true,
            WiseTool.lighting: true,
            WiseTool.focus: true,
            WiseTool.grid: true,
            WiseTool.level: true,
            WiseTool.measurement: true,
            WiseTool.annotation: false,
          },
        ),
        preferredOrientation: CaptureOrientation.portrait,
        preferredFlash: WiseFlashMode.off,
        exportPreset: ExportPreset.reportReady,
      ),
    ),
    (
      name: 'Physiotherapy Standard',
      description: 'Whole-region framing with level and grid guidance.',
      settings: ProtocolSettings(
        tools: const ToolOverrides(
          enabled: {
            WiseTool.overlay: true,
            WiseTool.alignment: true,
            WiseTool.grid: true,
            WiseTool.level: true,
            WiseTool.lighting: true,
            WiseTool.focus: true,
            WiseTool.measurement: false,
          },
        ),
        preferredOrientation: CaptureOrientation.portrait,
        exportPreset: ExportPreset.beforeAfter,
      ),
    ),
    (
      name: 'Wound Documentation',
      description: 'Measurement and annotation with a scale reference.',
      settings: ProtocolSettings(
        tools: const ToolOverrides(
          enabled: {
            WiseTool.overlay: true,
            WiseTool.alignment: true,
            WiseTool.lighting: true,
            WiseTool.focus: true,
            WiseTool.measurement: true,
            WiseTool.annotation: true,
            WiseTool.grid: false,
          },
        ),
        measurementRequired: true,
        exportPreset: ExportPreset.beforeAfterMeasurements,
      ),
    ),
    (
      name: 'Posture Standard',
      description: 'Level and grid for standing whole-body views.',
      settings: ProtocolSettings(
        tools: const ToolOverrides(
          enabled: {
            WiseTool.overlay: true,
            WiseTool.alignment: true,
            WiseTool.grid: true,
            WiseTool.level: true,
            WiseTool.measurement: false,
            WiseTool.annotation: false,
          },
          gridType: GridType.quarters,
        ),
        preferredOrientation: CaptureOrientation.portrait,
        exportPreset: ExportPreset.beforeAfter,
      ),
    ),
    (
      name: 'General Clinical Photo',
      description: 'A plain camera with focus checking only.',
      settings: ProtocolSettings(
        tools: const ToolOverrides(
          enabled: {
            WiseTool.overlay: false,
            WiseTool.alignment: false,
            WiseTool.grid: false,
            WiseTool.level: false,
            WiseTool.measurement: false,
            WiseTool.annotation: false,
            WiseTool.focus: true,
          },
        ),
        exportPreset: ExportPreset.original,
      ),
    ),
  ];

  /// Creates the system protocols once. Idempotent: a second call is a no-op,
  /// so a user's edits to a seeded protocol are never overwritten on launch.
  Future<void> seedSystemProtocols({String? userId, DateTime? now}) async {
    final existing = await _db.database.query(
      'protocols',
      columns: ['id'],
      where: 'is_system = 1',
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final timestamp = now ?? DateTime.now();
    await _db.database.transaction((txn) async {
      for (final template in systemProtocolTemplates()) {
        final protocol = CaptureProtocol(
          id: _ids.newId(),
          userId: userId,
          name: template.name,
          description: template.description,
          settings: template.settings,
          isSystem: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        await txn.insert('protocols', protocol.toRow());
      }
    });
  }

  Future<Result<CaptureProtocol>> createProtocol({
    required String name,
    required ProtocolSettings settings,
    String? userId,
    String? description,
    DateTime? now,
  }) async {
    if (name.trim().isEmpty) {
      return const Result.failed(
        ValidationFailure('Give the protocol a name.'),
      );
    }
    final timestamp = now ?? DateTime.now();
    final protocol = CaptureProtocol(
      id: _ids.newId(),
      userId: userId,
      name: name.trim(),
      description: description,
      settings: settings,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    return _db.transaction((txn) async {
      await txn.insert('protocols', protocol.toRow());
      return protocol;
    });
  }

  Future<CaptureProtocol?> getProtocol(String id) async {
    final rows = await _db.database.query(
      'protocols',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CaptureProtocol.fromRow(rows.first);
  }

  Future<List<CaptureProtocol>> getProtocols({bool activeOnly = true}) async {
    final rows = await _db.database.query(
      'protocols',
      where: activeOnly
          ? 'deleted_at IS NULL AND is_active = 1'
          : 'deleted_at IS NULL',
      orderBy: 'is_system DESC, name ASC',
    );
    return rows.map(CaptureProtocol.fromRow).toList(growable: false);
  }

  /// Saves an edit as a new version.
  ///
  /// Always bumps the version so photographs captured under the previous
  /// version stay unambiguously attributable to it.
  ///
  /// A built-in (system) protocol is immutable: an edit is refused rather than
  /// applied, so the shipped configurations can never be altered by accident
  /// (Functional PRO-001, master prompt §7). To change one, duplicate it first
  /// and edit the copy.
  Future<Result<CaptureProtocol>> updateProtocol(
    CaptureProtocol protocol, {
    String? name,
    String? description,
    ProtocolSettings? settings,
    bool? isActive,
    DateTime? now,
  }) async {
    if (protocol.isSystem) {
      return const Result.failed(
        ValidationFailure(
          'Built-in protocols cannot be edited. Duplicate it to make changes.',
        ),
      );
    }
    final edited = protocol.edited(
      name: name,
      description: description,
      settings: settings,
      isActive: isActive,
      now: now,
    );
    return _db.transaction((txn) async {
      await txn.update(
        'protocols',
        edited.toRow(),
        where: 'id = ?',
        whereArgs: [protocol.id],
      );
      return edited;
    });
  }

  Future<Result<CaptureProtocol>> duplicateProtocol(
    CaptureProtocol source, {
    String? userId,
    DateTime? now,
  }) => createProtocol(
    name: '${source.name} copy',
    settings: source.settings,
    userId: userId,
    description: source.description,
    now: now,
  );

  /// Retires a user-created protocol (soft delete).
  ///
  /// A built-in (system) protocol is protected: deletion is refused so a
  /// shipped configuration cannot be removed by accident (master prompt §7).
  Future<Result<void>> deleteProtocol(String id, {DateTime? now}) async {
    final existing = await getProtocol(id);
    if (existing != null && existing.isSystem) {
      return const Result.failed(
        ValidationFailure('Built-in protocols cannot be deleted.'),
      );
    }
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      await txn.update(
        'protocols',
        {'deleted_at': timestamp, 'updated_at': timestamp, 'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      // photos.protocol_id is left in place: a historical capture keeps naming
      // the protocol it was taken under (Functional PRO-005).
    });
  }
}
