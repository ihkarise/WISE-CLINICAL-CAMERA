import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/database/database_service.dart';

import '../support/test_harness.dart';

/// Schema shape and integrity settings (Data Model sections 35, 47, 63).
void main() {
  late TestHarness harness;

  setUp(() async => harness = await TestHarness.create());
  tearDown(() async => harness.dispose());

  test('creates every table the V1 data model specifies', () async {
    final tables = await harness.database.tableNames();

    // Data Model section 63, "Recommended SQLite Table Set".
    const expected = <String>[
      'users',
      'user_preferences',
      'cases',
      'protocols',
      'photos',
      'photo_metadata',
      'calibrations',
      'measurements',
      'annotations',
      'alignments',
      'quality_checks',
      'derived_assets',
      'comparisons',
      'exports',
      'gallery_exports',
      'events',
    ];

    for (final table in expected) {
      expect(tables, contains(table), reason: '$table is missing');
    }
  });

  test('foreign key enforcement is on', () async {
    // Data Model section 35. sqflite disables this per connection, so it must
    // be set on every open, not once at creation.
    expect(await harness.database.foreignKeysEnabled(), isTrue);
  });

  test('reports the expected schema version', () {
    expect(DatabaseService.schemaVersion, 4);
  });

  test('creates the indexes the data model lists', () async {
    final rows = await harness.database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexes = rows.map((r) => r['name']! as String).toSet();

    // Data Model section 47.
    for (final index in const <String>[
      'idx_photos_case_id',
      'idx_photos_type',
      'idx_photos_reference',
      'idx_photos_captured_at',
      'idx_photos_body_part',
      'idx_measurements_photo',
      'idx_annotations_photo',
      'idx_calibrations_photo',
      'idx_alignments_reference',
      'idx_alignments_target',
      'idx_derived_source',
    ]) {
      expect(indexes, contains(index), reason: '$index is missing');
    }
  });

  test('migrations are numbered contiguously from 1', () {
    final versions = DatabaseService.migrations
        .map((m) => m.version)
        .toList(growable: false);

    expect(versions, [1, 2, 3, 4]);
    for (final migration in DatabaseService.migrations) {
      expect(migration.description, isNotEmpty);
    }
  });
}
