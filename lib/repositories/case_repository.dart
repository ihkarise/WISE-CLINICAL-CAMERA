import '../core/database/database_ids.dart';
import '../core/database/database_service.dart';
import '../core/errors/failures.dart';
import '../core/errors/result.dart';
import '../models/clinical_case.dart';

/// Optional case grouping (Data Model section 7, Functional CAS-001..003).
class CaseRepository {
  CaseRepository({
    required DatabaseService database,
    DatabaseIds ids = const DatabaseIds(),
  }) : _db = database,
       _ids = ids;

  final DatabaseService _db;
  final DatabaseIds _ids;

  Future<Result<ClinicalCase>> createCase({
    String? userId,
    String? title,
    String? localReference,
    String? notes,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final record = ClinicalCase(
      id: _ids.newId(),
      userId: userId,
      title: title,
      localReference: localReference,
      notes: notes,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    return _db.transaction((txn) async {
      await txn.insert('cases', record.toRow());
      return record;
    });
  }

  Future<ClinicalCase?> getCase(String id) async {
    final rows = await _db.database.query(
      'cases',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ClinicalCase.fromRow(rows.first);
  }

  Future<List<ClinicalCase>> getCases({int limit = 100, int offset = 0}) async {
    final rows = await _db.database.query(
      'cases',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ClinicalCase.fromRow).toList(growable: false);
  }

  Future<Result<ClinicalCase>> updateCase(
    ClinicalCase record, {
    DateTime? now,
  }) async {
    final updated = record.copyWith(
      updatedAt: now ?? DateTime.now(),
      version: record.version + 1,
    );
    return _db.transaction((txn) async {
      await txn.update(
        'cases',
        updated.toRow(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      return updated;
    });
  }

  /// Soft-deletes a case.
  ///
  /// Its photographs are deliberately left alone: "deleting a Case should not
  /// automatically delete its Photos" (Data Model section 35). They simply
  /// become uncategorised.
  Future<Result<void>> deleteCase(String id, {DateTime? now}) async {
    final record = await getCase(id);
    if (record == null) {
      return const Result.failed(
        ValidationFailure('This case is no longer available.'),
      );
    }
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      await txn.update(
        'cases',
        {'deleted_at': timestamp, 'updated_at': timestamp},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'photos',
        {'case_id': null, 'updated_at': timestamp},
        where: 'case_id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> photoCount(String caseId) async {
    final rows = await _db.database.rawQuery(
      'SELECT COUNT(*) AS c FROM photos '
      'WHERE case_id = ? AND deleted_at IS NULL',
      [caseId],
    );
    return (rows.first['c']! as num).toInt();
  }
}
