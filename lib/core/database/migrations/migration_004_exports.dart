import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 004 — exports (Data Model section 46).
///
/// `derived_assets`, `comparisons`, `exports`, `gallery_exports`, `events`.
class Migration004Exports extends Migration {
  const Migration004Exports();

  @override
  int get version => 4;

  @override
  String get description =>
      'exports: derived_assets, comparisons, exports, gallery_exports, events';

  @override
  Future<void> apply(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE derived_assets (
        id                 TEXT PRIMARY KEY NOT NULL,
        source_photo_id    TEXT NOT NULL
                           REFERENCES photos(id) ON DELETE RESTRICT,
        asset_type         TEXT NOT NULL,
        file_path          TEXT NOT NULL,
        width_px           INTEGER NOT NULL,
        height_px          INTEGER NOT NULL,
        file_size_bytes    INTEGER NOT NULL,
        checksum           TEXT,
        configuration_json TEXT,
        created_at         INTEGER NOT NULL,
        version            INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await txn.execute('''
      CREATE TABLE comparisons (
        id                 TEXT PRIMARY KEY NOT NULL,
        before_photo_id    TEXT NOT NULL
                           REFERENCES photos(id) ON DELETE RESTRICT,
        after_photo_id     TEXT NOT NULL
                           REFERENCES photos(id) ON DELETE RESTRICT,
        mode               TEXT NOT NULL,
        alignment_json     TEXT,
        opacity            REAL NOT NULL DEFAULT 0.5,
        configuration_json TEXT,
        derived_asset_id   TEXT REFERENCES derived_assets(id)
                           ON DELETE SET NULL,
        created_at         INTEGER NOT NULL,
        updated_at         INTEGER NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE exports (
        id                 TEXT PRIMARY KEY NOT NULL,
        photo_id           TEXT REFERENCES photos(id) ON DELETE RESTRICT,
        comparison_id      TEXT REFERENCES comparisons(id) ON DELETE SET NULL,
        preset             TEXT NOT NULL,
        output_path        TEXT NOT NULL,
        configuration_json TEXT,
        anonymized         INTEGER NOT NULL DEFAULT 0,
        created_at         INTEGER NOT NULL,
        status             TEXT NOT NULL
      )
    ''');

    // A Gallery copy is an independent file. Deleting a WISE photograph must
    // not silently delete it, so this row is a record, not an owner
    // (Data Model sections 32, 37).
    await txn.execute('''
      CREATE TABLE gallery_exports (
        id                        TEXT PRIMARY KEY NOT NULL,
        photo_id                  TEXT NOT NULL
                                  REFERENCES photos(id) ON DELETE RESTRICT,
        derived_asset_id          TEXT REFERENCES derived_assets(id)
                                  ON DELETE SET NULL,
        platform_asset_identifier TEXT,
        album_name                TEXT,
        created_at                INTEGER NOT NULL,
        status                    TEXT NOT NULL
      )
    ''');

    // Optional and disabled by default: writes only happen when the eventLog
    // feature flag is on (Data Model section 33, Privacy section 24).
    await txn.execute('''
      CREATE TABLE events (
        id           TEXT PRIMARY KEY NOT NULL,
        entity_type  TEXT NOT NULL,
        entity_id    TEXT NOT NULL,
        event_type   TEXT NOT NULL,
        payload_json TEXT,
        created_at   INTEGER NOT NULL
      )
    ''');

    await txn.execute(
      'CREATE INDEX idx_derived_source ON derived_assets(source_photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_comparisons_before ON comparisons(before_photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_comparisons_after ON comparisons(after_photo_id)',
    );
    await txn.execute('CREATE INDEX idx_exports_photo ON exports(photo_id)');
    await txn.execute(
      'CREATE INDEX idx_gallery_exports_photo ON gallery_exports(photo_id)',
    );
  }
}
