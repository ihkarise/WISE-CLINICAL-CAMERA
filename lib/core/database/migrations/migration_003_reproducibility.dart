import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 003 — reproducibility (Data Model section 46).
///
/// `protocols`, `alignments`, `quality_checks`, plus the deferred foreign key
/// from `photos.protocol_id`.
class Migration003Reproducibility extends Migration {
  const Migration003Reproducibility();

  @override
  int get version => 3;

  @override
  String get description =>
      'reproducibility: protocols, alignments, quality_checks';

  @override
  Future<void> apply(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE protocols (
        id            TEXT PRIMARY KEY NOT NULL,
        user_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
        name          TEXT NOT NULL,
        description   TEXT,
        settings_json TEXT NOT NULL,
        version       INTEGER NOT NULL DEFAULT 1,
        is_system     INTEGER NOT NULL DEFAULT 0,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL,
        deleted_at    INTEGER
      )
    ''');

    await txn.execute('''
      CREATE TABLE alignments (
        id                    TEXT PRIMARY KEY NOT NULL,
        reference_photo_id    TEXT NOT NULL
                              REFERENCES photos(id) ON DELETE RESTRICT,
        target_photo_id       TEXT REFERENCES photos(id) ON DELETE RESTRICT,
        method                TEXT NOT NULL,
        score                 REAL,
        translation_x         REAL NOT NULL DEFAULT 0,
        translation_y         REAL NOT NULL DEFAULT 0,
        rotation              REAL NOT NULL DEFAULT 0,
        scale                 REAL NOT NULL DEFAULT 1,
        transform_matrix_json TEXT,
        confidence            REAL NOT NULL DEFAULT 0,
        status                TEXT NOT NULL,
        created_at            INTEGER NOT NULL,
        -- Recorded so results can be reprocessed when the algorithm improves
        -- (Computer Vision section 53).
        engine_version        TEXT NOT NULL
      )
    ''');

    await txn.execute('''
      CREATE TABLE quality_checks (
        id             TEXT PRIMARY KEY NOT NULL,
        photo_id       TEXT NOT NULL
                       REFERENCES photos(id) ON DELETE RESTRICT,
        check_type     TEXT NOT NULL,
        score          REAL,
        status         TEXT NOT NULL,
        details_json   TEXT,
        engine_version TEXT NOT NULL,
        created_at     INTEGER NOT NULL
      )
    ''');

    await txn.execute(
      'CREATE INDEX idx_alignments_reference ON alignments(reference_photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_alignments_target ON alignments(target_photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_quality_checks_photo ON quality_checks(photo_id)',
    );
    await txn.execute('CREATE INDEX idx_protocols_user ON protocols(user_id)');
  }
}
