import 'package:sqflite/sqflite.dart';

import '../core/database/database_ids.dart';
import '../core/database/database_service.dart';
import '../core/errors/result.dart';
import '../models/user_preferences.dart';
import '../models/wise_user.dart';

/// The local user and their persistent tool defaults.
///
/// Preferences live in SQLite, not in session memory, which is what makes them
/// survive an app restart (Functional SET-002, Build Specification 20).
class PreferenceRepository {
  PreferenceRepository({
    required DatabaseService database,
    DatabaseIds ids = const DatabaseIds(),
  }) : _db = database,
       _ids = ids;

  final DatabaseService _db;
  final DatabaseIds _ids;

  /// Returns the local user, creating one on first launch.
  ///
  /// No credentials, no login. The row exists to own preferences and protocols
  /// and to give future synchronization a stable key (Data Model section 6,
  /// SPECIFICATION_CONFLICTS C-012).
  Future<WiseUser> ensureLocalUser({DateTime? now}) async {
    final existing = await _db.database.query(
      'users',
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (existing.isNotEmpty) return WiseUser.fromRow(existing.first);

    final timestamp = now ?? DateTime.now();
    final user = WiseUser(
      id: _ids.newId(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    await _db.database.transaction((txn) async {
      await txn.insert('users', user.toRow());
      await txn.insert(
        'user_preferences',
        UserPreferences.initial(user.id, now: timestamp).toRow(),
      );
    });
    return user;
  }

  /// Loads preferences, falling back to the documented defaults if the row is
  /// somehow missing rather than failing the launch.
  Future<UserPreferences> load(String userId) async {
    final rows = await _db.database.query(
      'user_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return UserPreferences.initial(userId);
    return UserPreferences.fromRow(rows.first);
  }

  /// Persists a new default. The only path by which a default ever changes
  /// (Functional SET-004: the user explicitly saves it).
  Future<Result<UserPreferences>> save(
    UserPreferences preferences, {
    DateTime? now,
  }) async {
    final updated = preferences.copyWith(
      updatedAt: now ?? DateTime.now(),
      version: preferences.version + 1,
    );
    return _db.transaction((txn) async {
      await txn.insert(
        'user_preferences',
        updated.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return updated;
    });
  }
}
