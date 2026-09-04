import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 001 — core entities (Data Model section 46).
///
/// `users`, `user_preferences`, `cases`, `photos`, `photo_metadata`.
///
/// Data Model section 46 sketches migration 001 as "users, cases, photos,
/// user_preferences" and does not say where `photo_metadata` belongs. It is
/// created here because it is a 1:1 extension of `photos` written inside the
/// same transaction as the photo row, so it must exist wherever `photos` does.
///
/// Foreign keys are declared but no relationship uses unrestricted
/// `ON DELETE CASCADE`: one Before photograph may be referenced by many After
/// photographs and comparisons, so deletion is decided by application policy,
/// not by SQL (Data Model sections 35, 67).
class Migration001Core extends Migration {
  const Migration001Core();

  @override
  int get version => 1;

  @override
  String get description =>
      'core: users, user_preferences, cases, photos, photo_metadata';

  @override
  Future<void> apply(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE users (
        id            TEXT PRIMARY KEY NOT NULL,
        display_name  TEXT,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL,
        version       INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await txn.execute('''
      CREATE TABLE user_preferences (
        user_id              TEXT PRIMARY KEY NOT NULL
                             REFERENCES users(id) ON DELETE RESTRICT,
        overlay_enabled      INTEGER NOT NULL DEFAULT 1,
        overlay_opacity      REAL    NOT NULL DEFAULT 0.5,
        alignment_enabled    INTEGER NOT NULL DEFAULT 1,
        lighting_enabled     INTEGER NOT NULL DEFAULT 1,
        focus_enabled        INTEGER NOT NULL DEFAULT 1,
        grid_enabled         INTEGER NOT NULL DEFAULT 0,
        grid_type            TEXT    NOT NULL DEFAULT '3x3',
        level_enabled        INTEGER NOT NULL DEFAULT 0,
        measurement_enabled  INTEGER NOT NULL DEFAULT 0,
        annotation_enabled   INTEGER NOT NULL DEFAULT 0,
        difference_enabled   INTEGER NOT NULL DEFAULT 0,
        comparison_mode      TEXT    NOT NULL DEFAULT 'SIDE_BY_SIDE',
        gallery_save_mode    TEXT    NOT NULL DEFAULT 'ASK',
        privacy_mode         INTEGER NOT NULL DEFAULT 1,
        measurement_unit     TEXT    NOT NULL DEFAULT 'cm',
        show_alignment_score INTEGER NOT NULL DEFAULT 0,
        updated_at           INTEGER NOT NULL,
        version              INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await txn.execute('''
      CREATE TABLE cases (
        id              TEXT PRIMARY KEY NOT NULL,
        user_id         TEXT REFERENCES users(id) ON DELETE SET NULL,
        local_reference TEXT,
        title           TEXT,
        notes           TEXT,
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL,
        deleted_at      INTEGER,
        version         INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await txn.execute('''
      CREATE TABLE photos (
        id                  TEXT PRIMARY KEY NOT NULL,
        user_id             TEXT REFERENCES users(id) ON DELETE SET NULL,
        case_id             TEXT REFERENCES cases(id) ON DELETE SET NULL,
        type                TEXT NOT NULL
                            CHECK (type IN ('BEFORE', 'AFTER', 'PHOTO')),
        original_path       TEXT NOT NULL,
        thumbnail_path      TEXT,
        captured_at         INTEGER NOT NULL,
        imported_at         INTEGER,
        body_part           TEXT,
        laterality          TEXT,
        reference_photo_id  TEXT REFERENCES photos(id) ON DELETE RESTRICT,
        protocol_id         TEXT,
        width_px            INTEGER NOT NULL CHECK (width_px > 0),
        height_px           INTEGER NOT NULL CHECK (height_px > 0),
        file_size_bytes     INTEGER NOT NULL,
        mime_type           TEXT NOT NULL,
        checksum            TEXT,
        source              TEXT NOT NULL
                            CHECK (source IN ('CAMERA', 'IMPORT')),
        metadata_json       TEXT,
        capture_recipe_json TEXT,
        status              TEXT NOT NULL
                            CHECK (status IN ('PROCESSING', 'ACTIVE',
                                              'FAILED', 'DELETED')),
        created_at          INTEGER NOT NULL,
        updated_at          INTEGER NOT NULL,
        deleted_at          INTEGER,
        version             INTEGER NOT NULL DEFAULT 1,
        -- A photograph cannot be its own reference (Data Model section 49).
        CHECK (reference_photo_id IS NULL OR reference_photo_id <> id)
      )
    ''');

    // Every column is nullable: camera APIs differ between iOS and Android and
    // between devices, so an absent value means "not reported" rather than
    // zero (Data Model section 13). There is deliberately no GPS column
    // (Privacy PRI-001).
    await txn.execute('''
      CREATE TABLE photo_metadata (
        id                TEXT PRIMARY KEY NOT NULL,
        photo_id          TEXT NOT NULL UNIQUE
                          REFERENCES photos(id) ON DELETE RESTRICT,
        camera_position   TEXT,
        lens_identifier   TEXT,
        focal_length      REAL,
        zoom_factor       REAL,
        exposure_time     REAL,
        iso               REAL,
        aperture          REAL,
        flash_mode        TEXT,
        white_balance     TEXT,
        orientation       TEXT,
        device_model      TEXT,
        os_version        TEXT,
        app_version       TEXT,
        raw_metadata_json TEXT,
        created_at        INTEGER NOT NULL
      )
    ''');

    // Data Model section 47.
    await txn.execute('CREATE INDEX idx_photos_case_id ON photos(case_id)');
    await txn.execute('CREATE INDEX idx_photos_type ON photos(type)');
    await txn.execute(
      'CREATE INDEX idx_photos_reference ON photos(reference_photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_photos_captured_at ON photos(captured_at)',
    );
    await txn.execute('CREATE INDEX idx_photos_body_part ON photos(body_part)');
    // Supports the "recent, not deleted" listing that every screen opens with.
    await txn.execute(
      'CREATE INDEX idx_photos_deleted_at ON photos(deleted_at)',
    );
  }
}
