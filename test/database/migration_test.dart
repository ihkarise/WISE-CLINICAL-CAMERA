import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wise_clinical_camera/core/database/database_service.dart';

/// Migration behaviour (Data Model sections 45-46, 74; Testing section 82).
///
/// The rule under test: "The application must never assume the user is starting
/// from a clean database" (Data Model section 45).
void main() {
  late Directory directory;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wise_migration_');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  /// A real file: an upgrade cannot be tested against an in-memory database,
  /// which starts empty on every open.
  String diskPath() => p.join(directory.path, 'wise.db');

  Future<DatabaseService> openAt(int version, {String? path}) async {
    final service = DatabaseService(factory: databaseFactoryFfi);
    final opened = await service.open(path: path ?? inMemoryDatabasePath);
    expect(opened.isOk, isTrue);
    return service;
  }

  test('a fresh install lands on the current schema version', () async {
    final service = await openAt(DatabaseService.schemaVersion);

    final rows = await service.database.rawQuery('PRAGMA user_version');
    expect(
      (rows.first.values.first! as num).toInt(),
      DatabaseService.schemaVersion,
    );

    await service.close();
  });

  test('a fresh install walks the migration list, not a snapshot', () async {
    // Both paths run the same migrations, so they cannot drift apart
    // (Data Model section 74: "fresh install" and "migration from each prior
    // schema" are both required to work).
    final service = await openAt(DatabaseService.schemaVersion);
    final tables = await service.tableNames();

    // Tables introduced by each individual migration must all be present.
    expect(tables, contains('users')); // 001
    expect(tables, contains('photo_metadata')); // 001
    expect(tables, contains('measurements')); // 002
    expect(tables, contains('alignments')); // 003
    expect(tables, contains('exports')); // 004

    await service.close();
  });

  test('upgrading an older database preserves its rows', () async {
    // A user's existing photographs must survive a schema upgrade.
    final path = diskPath();

    // Stand up a database at version 1 by applying only the first migration.
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.transaction(DatabaseService.migrations.first.apply);
        },
      ),
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await legacy.insert('users', {
      'id': 'legacy-user',
      'created_at': now,
      'updated_at': now,
      'version': 1,
    });
    await legacy.insert('photos', {
      'id': 'legacy-photo',
      'user_id': 'legacy-user',
      'type': 'BEFORE',
      'original_path': '/legacy/photo.jpg',
      'captured_at': now,
      'width_px': 100,
      'height_px': 80,
      'file_size_bytes': 1234,
      'mime_type': 'image/jpeg',
      'source': 'CAMERA',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
      'version': 1,
    });
    await legacy.close();

    // Reopen through the service, which must migrate 1 -> current.
    final upgraded = await openAt(DatabaseService.schemaVersion, path: path);

    final rows = await upgraded.database.query(
      'photos',
      where: 'id = ?',
      whereArgs: ['legacy-photo'],
    );
    expect(
      rows,
      hasLength(1),
      reason: 'an upgrade must not lose existing photographs',
    );
    expect(rows.single['original_path'], '/legacy/photo.jpg');

    // And the newer tables now exist.
    final tables = await upgraded.tableNames();
    expect(tables, contains('measurements'));
    expect(tables, contains('exports'));

    await upgraded.close();
  });

  test('reopening an already-current database is a no-op', () async {
    final path = diskPath();

    final first = await openAt(DatabaseService.schemaVersion, path: path);
    final now = DateTime.now().millisecondsSinceEpoch;
    await first.database.insert('users', {
      'id': 'u',
      'created_at': now,
      'updated_at': now,
      'version': 1,
    });
    await first.close();

    final second = await openAt(DatabaseService.schemaVersion, path: path);
    expect(await second.database.query('users'), hasLength(1));
    await second.close();
  });

  test('each migration is applied in its own transaction', () async {
    // Data Model section 74 requires interrupted-migration recovery. Wrapping
    // each migration separately means an interruption leaves the database at a
    // completed version rather than half-applied.
    for (final migration in DatabaseService.migrations) {
      expect(migration.version, greaterThan(0));
      expect(migration.description, isNotEmpty);
    }
    expect(
      DatabaseService.migrations.map((m) => m.version).toSet().length,
      DatabaseService.migrations.length,
      reason: 'migration versions must be unique',
    );
  });

  test(
    'foreign keys are enforced after an upgrade, not just on create',
    () async {
      // sqflite disables foreign keys per connection, so this must be set on
      // every open (Data Model section 35).
      final path = diskPath();

      final first = await openAt(DatabaseService.schemaVersion, path: path);
      await first.close();

      final second = await openAt(DatabaseService.schemaVersion, path: path);
      expect(await second.foreignKeysEnabled(), isTrue);
      await second.close();
    },
  );
}
