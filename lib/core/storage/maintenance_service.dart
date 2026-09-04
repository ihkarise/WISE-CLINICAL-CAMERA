import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/database_service.dart';
import '../logging/app_logger.dart';
import 'image_storage_service.dart';

/// One inconsistency between the database and the filesystem.
class ConsistencyIssue {
  const ConsistencyIssue({
    required this.kind,
    required this.description,
    required this.severity,
    this.photoId,
    this.path,
  });

  final ConsistencyIssueKind kind;
  final String description;
  final IssueSeverity severity;
  final String? photoId;
  final String? path;
}

enum ConsistencyIssueKind {
  /// A photo row whose original file is gone. The most serious case: clinical
  /// evidence has been lost outside the application's control.
  missingOriginal,

  /// An original whose checksum no longer matches the one recorded at capture.
  corruptedOriginal,

  /// A file in `originals/` with no photo row. **Never deleted automatically**
  /// (Data Model section 68).
  unreferencedOriginal,

  /// A photo row whose thumbnail is gone. Harmless; regenerable.
  missingThumbnail,

  /// A derived asset row whose file is gone. Harmless; regenerable.
  missingDerivedAsset,

  /// A derived asset whose source photo no longer exists.
  orphanedDerivedAsset,

  /// An AFTER photo whose reference row is gone.
  brokenReference,

  /// A leftover file in `temp/`.
  staleTemporaryFile,
}

enum IssueSeverity {
  /// Clinical data is affected. Requires the user to be told.
  critical,

  /// Something is inconsistent but nothing irreplaceable is at risk.
  warning,

  /// Housekeeping.
  info,
}

/// The outcome of a scan.
class ConsistencyReport {
  const ConsistencyReport({
    required this.issues,
    required this.photosChecked,
    required this.filesChecked,
    required this.scannedAt,
  });

  final List<ConsistencyIssue> issues;
  final int photosChecked;
  final int filesChecked;
  final DateTime scannedAt;

  bool get isClean => issues.isEmpty;

  List<ConsistencyIssue> get critical =>
      issues.where((i) => i.severity == IssueSeverity.critical).toList();

  List<ConsistencyIssue> ofKind(ConsistencyIssueKind kind) =>
      issues.where((i) => i.kind == kind).toList();

  /// A one-line summary for the settings screen.
  String get summary {
    if (isClean) return 'No problems found.';
    final criticalCount = critical.length;
    if (criticalCount > 0) {
      return '$criticalCount ${criticalCount == 1 ? 'photograph needs' : 'photographs need'} '
          'attention, ${issues.length - criticalCount} minor '
          '${issues.length - criticalCount == 1 ? 'issue' : 'issues'}.';
    }
    return '${issues.length} minor ${issues.length == 1 ? 'issue' : 'issues'} found.';
  }
}

/// What a repair pass actually did.
class RepairOutcome {
  const RepairOutcome({
    required this.temporaryFilesRemoved,
    required this.derivedAssetRowsRemoved,
    required this.thumbnailsCleared,
    required this.leftForTheUser,
  });

  final int temporaryFilesRemoved;
  final int derivedAssetRowsRemoved;
  final int thumbnailsCleared;

  /// Issues that were deliberately **not** repaired because doing so would
  /// risk clinical data.
  final List<ConsistencyIssue> leftForTheUser;
}

/// Detects and safely repairs database/filesystem inconsistency
/// (Data Model section 68, Build Specification section 106).
///
/// The governing rule, stated directly by Data Model section 68:
///
/// > "The repair service should never delete an original automatically merely
/// > because it appears orphaned."
///
/// So this class is asymmetric on purpose. It **reports** anything touching an
/// original — missing, corrupted, or unreferenced — and leaves the decision to
/// the user. It only **removes** things that are definitively regenerable: a
/// stale temporary file, a derived-asset row whose file is gone, a thumbnail
/// path pointing at nothing.
///
/// An unreferenced file in `originals/` is the case worth being most careful
/// about: it looks like garbage, but it may be a photograph whose database row
/// was lost, which makes it the *only* remaining copy of clinical evidence.
class MaintenanceService {
  MaintenanceService({
    required DatabaseService database,
    required ImageStorageService storage,
  }) : _db = database,
       _storage = storage;

  final DatabaseService _db;
  final ImageStorageService _storage;
  final AppLogger _log = const AppLogger('maintenance');

  /// Scans for inconsistency. Read-only: it changes nothing.
  Future<ConsistencyReport> scan({
    bool verifyChecksums = false,
    DateTime? now,
  }) async {
    final issues = <ConsistencyIssue>[];
    final timestamp = now ?? DateTime.now();

    final photos = await _db.database.query(
      'photos',
      columns: [
        'id',
        'original_path',
        'thumbnail_path',
        'checksum',
        'reference_photo_id',
        'deleted_at',
      ],
    );

    final knownOriginals = <String>{};

    for (final row in photos) {
      final id = row['id']! as String;
      final originalPath = row['original_path']! as String;
      knownOriginals.add(p.normalize(originalPath));

      if (!File(originalPath).existsSync()) {
        issues.add(
          ConsistencyIssue(
            kind: ConsistencyIssueKind.missingOriginal,
            severity: IssueSeverity.critical,
            photoId: id,
            path: originalPath,
            description:
                'The original photograph file is missing. The record and any '
                'measurements are intact, but the image itself cannot be found.',
          ),
        );
        continue;
      }

      // Checksum verification reads every original, so it is opt-in.
      final checksum = row['checksum'] as String?;
      if (verifyChecksums && checksum != null) {
        final matches = await _storage.verifyOriginal(originalPath, checksum);
        if (!matches) {
          issues.add(
            ConsistencyIssue(
              kind: ConsistencyIssueKind.corruptedOriginal,
              severity: IssueSeverity.critical,
              photoId: id,
              path: originalPath,
              description:
                  'The original photograph no longer matches the checksum '
                  'recorded when it was captured.',
            ),
          );
        }
      }

      final thumbnailPath = row['thumbnail_path'] as String?;
      if (thumbnailPath != null && !File(thumbnailPath).existsSync()) {
        issues.add(
          ConsistencyIssue(
            kind: ConsistencyIssueKind.missingThumbnail,
            severity: IssueSeverity.info,
            photoId: id,
            path: thumbnailPath,
            description: 'The thumbnail is missing and can be regenerated.',
          ),
        );
      }

      final referenceId = row['reference_photo_id'] as String?;
      if (referenceId != null) {
        final reference = photos.where((r) => r['id'] == referenceId);
        if (reference.isEmpty) {
          issues.add(
            ConsistencyIssue(
              kind: ConsistencyIssueKind.brokenReference,
              severity: IssueSeverity.warning,
              photoId: id,
              description:
                  'This After photograph points at a Before that no longer '
                  'exists.',
            ),
          );
        }
      }
    }

    // Files in originals/ with no row. Reported, never removed.
    var filesChecked = 0;
    if (_storage.paths.originals.existsSync()) {
      for (final entity in _storage.paths.originals.listSync()) {
        if (entity is! File) continue;
        filesChecked++;
        if (!knownOriginals.contains(p.normalize(entity.path))) {
          issues.add(
            ConsistencyIssue(
              kind: ConsistencyIssueKind.unreferencedOriginal,
              severity: IssueSeverity.warning,
              path: entity.path,
              description:
                  'An image file exists with no matching record. It has NOT '
                  'been deleted: it may be the only remaining copy of a '
                  'photograph whose record was lost.',
            ),
          );
        }
      }
    }

    issues.addAll(await _scanDerivedAssets(photos));
    issues.addAll(_scanTemporaryFiles(timestamp));

    _log.info('consistency scan complete', {
      'photos': photos.length,
      'files': filesChecked,
      'issues': issues.length,
      'critical': issues
          .where((i) => i.severity == IssueSeverity.critical)
          .length,
    });

    return ConsistencyReport(
      issues: issues,
      photosChecked: photos.length,
      filesChecked: filesChecked,
      scannedAt: timestamp,
    );
  }

  Future<List<ConsistencyIssue>> _scanDerivedAssets(
    List<Map<String, Object?>> photos,
  ) async {
    final issues = <ConsistencyIssue>[];
    final photoIds = photos.map((r) => r['id']! as String).toSet();

    final assets = await _db.database.query(
      'derived_assets',
      columns: ['id', 'source_photo_id', 'file_path', 'asset_type'],
    );

    for (final row in assets) {
      final sourceId = row['source_photo_id']! as String;
      final path = row['file_path']! as String;

      if (!photoIds.contains(sourceId)) {
        issues.add(
          ConsistencyIssue(
            kind: ConsistencyIssueKind.orphanedDerivedAsset,
            severity: IssueSeverity.info,
            photoId: sourceId,
            path: path,
            description:
                'A generated file refers to a photograph that no longer '
                'exists.',
          ),
        );
        continue;
      }

      if (!File(path).existsSync()) {
        issues.add(
          ConsistencyIssue(
            kind: ConsistencyIssueKind.missingDerivedAsset,
            severity: IssueSeverity.info,
            photoId: sourceId,
            path: path,
            description:
                'A generated file is missing and can be recreated from the '
                'original.',
          ),
        );
      }
    }
    return issues;
  }

  List<ConsistencyIssue> _scanTemporaryFiles(DateTime now) {
    final issues = <ConsistencyIssue>[];
    if (!_storage.paths.temp.existsSync()) return issues;

    final cutoff = now.subtract(const Duration(hours: 6));
    for (final entity in _storage.paths.temp.listSync()) {
      if (entity is! File) continue;
      try {
        if (entity.statSync().modified.isBefore(cutoff)) {
          issues.add(
            ConsistencyIssue(
              kind: ConsistencyIssueKind.staleTemporaryFile,
              severity: IssueSeverity.info,
              path: entity.path,
              description: 'A leftover working file can be removed.',
            ),
          );
        }
      } on FileSystemException {
        // Unreadable entries are simply skipped.
      }
    }
    return issues;
  }

  /// Repairs only what is definitively safe to repair.
  ///
  /// Never touches a file in `originals/`, and never deletes a photo row. Every
  /// issue involving an original is returned in
  /// [RepairOutcome.leftForTheUser] instead (Data Model section 68).
  Future<RepairOutcome> repair(ConsistencyReport report) async {
    var temporaryRemoved = 0;
    var derivedRowsRemoved = 0;
    var thumbnailsCleared = 0;
    final left = <ConsistencyIssue>[];

    for (final issue in report.issues) {
      switch (issue.kind) {
        case ConsistencyIssueKind.staleTemporaryFile:
          if (issue.path != null) {
            await _storage.deleteDerived(issue.path!);
            temporaryRemoved++;
          }

        case ConsistencyIssueKind.missingDerivedAsset:
        case ConsistencyIssueKind.orphanedDerivedAsset:
          // The row describes a file that is gone, or a photograph that is
          // gone. Either way the row is meaningless; the asset is regenerable.
          if (issue.path != null) {
            await _db.database.delete(
              'derived_assets',
              where: 'file_path = ?',
              whereArgs: [issue.path],
            );
            derivedRowsRemoved++;
          }

        case ConsistencyIssueKind.missingThumbnail:
          // Clear the dangling path so the library falls back to the original
          // and the thumbnail can be regenerated.
          if (issue.photoId != null) {
            await _db.database.update(
              'photos',
              {'thumbnail_path': null},
              where: 'id = ?',
              whereArgs: [issue.photoId],
            );
            thumbnailsCleared++;
          }

        // Everything below touches clinical evidence. Reported, never acted on.
        case ConsistencyIssueKind.missingOriginal:
        case ConsistencyIssueKind.corruptedOriginal:
        case ConsistencyIssueKind.unreferencedOriginal:
        case ConsistencyIssueKind.brokenReference:
          left.add(issue);
      }
    }

    _log.info('repair complete', {
      'temp_removed': temporaryRemoved,
      'derived_rows_removed': derivedRowsRemoved,
      'thumbnails_cleared': thumbnailsCleared,
      'left_for_user': left.length,
    });

    return RepairOutcome(
      temporaryFilesRemoved: temporaryRemoved,
      derivedAssetRowsRemoved: derivedRowsRemoved,
      thumbnailsCleared: thumbnailsCleared,
      leftForTheUser: left,
    );
  }
}
