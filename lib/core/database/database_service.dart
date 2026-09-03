import 'package:sqflite/sqflite.dart';

import '../errors/failures.dart';
import '../errors/result.dart';
import '../logging/app_logger.dart';
import 'migrations/migration.dart';
import 'migrations/migration_001_core.dart';
import 'migrations/migration_002_clinical_tools.dart';
import 'migrations/migration_003_reproducibility.dart';
import 'migrations/migration_004_exports.dart';

/// Opens and migrates the local SQLite database (Data Model sections 2, 45).
///
/// The only class that talks to sqflite directly. Repositories go through it
/// and the UI goes through repositories (Data Model section 65, Build
/// Specification section 102).
class DatabaseService {
  DatabaseService({DatabaseFactory? factory, this.databaseName = 'wise.db'})
    : _factory = factory;

  /// Every migration, in order. Adding one here is the only step needed to
  /// extend the schema; [schemaVersion] follows from the list.
  static const List<Migration> migrations = <Migration>[
    Migration001Core(),
    Migration002ClinicalTools(),
    Migration003Reproducibility(),
    Migration004Exports(),
  ];

  static int get schemaVersion => migrations.length;

  final DatabaseFactory? _factory;
  final String databaseName;
  final AppLogger _log = const AppLogger('database');

  Database? _database;

  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('DatabaseService.open() must be called before use.');
    }
    return db;
  }

  bool get isOpen => _database?.isOpen ?? false;

  /// Opens the database, running any outstanding migrations.
  ///
  /// [path] is resolved by the caller so tests can use an in-memory database
  /// and the app can use its private directory.
  Future<Result<void>> open({required String path}) async {
    try {
      final factory = _factory ?? databaseFactory;
      _database = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: _configure,
          onCreate: _create,
          onUpgrade: _upgrade,
          onDowngrade: onDatabaseDowngradeDelete,
        ),
      );
      _log.info('database opened', {'schema_version': schemaVersion});
      return const Result.ok(null);
    } on DatabaseException catch (error) {
      _log.error('database open failed', {'error': error.toString()});
      return Result.failed(
        DatabaseFailure(technicalDetail: 'open failed: $error'),
      );
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Referential integrity is required by Data Model section 35.
  ///
  /// sqflite disables foreign keys per connection, so this must run on every
  /// open, not once at creation.
  Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _create(Database db, int version) async {
    // A fresh install still walks the migration list rather than applying a
    // snapshot schema, so the two paths cannot drift apart (Data Model 74:
    // "fresh install" and "migration from each prior schema" are both tested).
    await _runMigrations(db, from: 0, to: version);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    _log.info('migrating', {'from': oldVersion, 'to': newVersion});
    await _runMigrations(db, from: oldVersion, to: newVersion);
  }

  Future<void> _runMigrations(
    Database db, {
    required int from,
    required int to,
  }) async {
    for (final migration in migrations) {
      if (migration.version <= from || migration.version > to) continue;
      // Each migration is its own transaction, so an interruption leaves the
      // database at a completed version rather than half-applied
      // (Data Model section 74: "interrupted migration recovery").
      await db.transaction(migration.apply);
      _log.info('migration applied', {
        'version': migration.version,
        'description': migration.description,
      });
    }
  }

  /// Runs [action] in a transaction, mapping database errors to a typed
  /// failure (Data Model section 43).
  Future<Result<T>> transaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    try {
      final value = await database.transaction(action);
      return Result.ok(value);
    } on DatabaseException catch (error) {
      _log.error('transaction failed', {'error': error.toString()});
      return Result.failed(DatabaseFailure(technicalDetail: error.toString()));
    }
  }

  /// The names of every table the current schema defines. Used by the schema
  /// test and by the maintenance/orphan scan.
  Future<List<String>> tableNames() async {
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name <> 'android_metadata' "
      'ORDER BY name',
    );
    return rows.map((row) => row['name']! as String).toList(growable: false);
  }

  /// Whether foreign key enforcement is actually on for this connection.
  Future<bool> foreignKeysEnabled() async {
    final rows = await database.rawQuery('PRAGMA foreign_keys');
    if (rows.isEmpty) return false;
    return (rows.first.values.first! as num).toInt() == 1;
  }
}
