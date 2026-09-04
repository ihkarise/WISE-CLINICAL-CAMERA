import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 002 — clinical tools (Data Model section 46).
///
/// `calibrations`, `measurements`, `annotations`.
class Migration002ClinicalTools extends Migration {
  const Migration002ClinicalTools();

  @override
  int get version => 2;

  @override
  String get description =>
      'clinical tools: calibrations, measurements, annotations';

  @override
  Future<void> apply(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE calibrations (
        id                      TEXT PRIMARY KEY NOT NULL,
        photo_id                TEXT NOT NULL
                                REFERENCES photos(id) ON DELETE RESTRICT,
        method                  TEXT NOT NULL
                                CHECK (method IN ('RULER', 'MARKER', 'MANUAL')),
        known_value             REAL NOT NULL CHECK (known_value > 0),
        unit                    TEXT NOT NULL,
        pixel_distance          REAL NOT NULL CHECK (pixel_distance > 0),
        pixels_per_unit         REAL NOT NULL,
        reference_geometry_json TEXT,
        confidence              REAL,
        is_valid                INTEGER NOT NULL DEFAULT 1,
        created_at              INTEGER NOT NULL,
        updated_at              INTEGER NOT NULL
      )
    ''');

    // The CHECK constraints above are the schema half of the rule that a
    // physical measurement is impossible without a usable scale; the
    // application half is Measurement.hasPhysicalValue (Data Model 49-50).
    await txn.execute('''
      CREATE TABLE measurements (
        id             TEXT PRIMARY KEY NOT NULL,
        photo_id       TEXT NOT NULL
                       REFERENCES photos(id) ON DELETE RESTRICT,
        calibration_id TEXT REFERENCES calibrations(id) ON DELETE SET NULL,
        type           TEXT NOT NULL,
        unit           TEXT,
        value          REAL,
        pixel_value    REAL NOT NULL,
        geometry_json  TEXT NOT NULL,
        label          TEXT,
        visible        INTEGER NOT NULL DEFAULT 1,
        created_at     INTEGER NOT NULL,
        updated_at     INTEGER NOT NULL,
        deleted_at     INTEGER,
        -- A physical value may exist only alongside a calibration and a unit.
        CHECK ((value IS NULL AND unit IS NULL)
               OR (calibration_id IS NOT NULL AND unit IS NOT NULL))
      )
    ''');

    await txn.execute('''
      CREATE TABLE annotations (
        id              TEXT PRIMARY KEY NOT NULL,
        photo_id        TEXT NOT NULL
                        REFERENCES photos(id) ON DELETE RESTRICT,
        type            TEXT NOT NULL,
        geometry_json   TEXT NOT NULL,
        text            TEXT,
        properties_json TEXT,
        z_index         INTEGER NOT NULL DEFAULT 0,
        visible         INTEGER NOT NULL DEFAULT 1,
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL,
        deleted_at      INTEGER
      )
    ''');

    await txn.execute(
      'CREATE INDEX idx_calibrations_photo ON calibrations(photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_measurements_photo ON measurements(photo_id)',
    );
    await txn.execute(
      'CREATE INDEX idx_annotations_photo ON annotations(photo_id)',
    );
  }
}
