import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wise_clinical_camera/core/database/database_ids.dart';
import 'package:wise_clinical_camera/core/database/database_service.dart';
import 'package:wise_clinical_camera/core/storage/image_storage_service.dart';
import 'package:wise_clinical_camera/core/storage/storage_paths.dart';

/// A real database and a real filesystem tree for tests.
///
/// Uses `sqflite_common_ffi`, which runs the actual SQLite engine on the test
/// host. Migrations, foreign keys, CHECK constraints and transactions are
/// therefore exercised for real rather than mocked, which is what Data Model
/// section 74 asks for.
class TestHarness {
  TestHarness._({
    required this.directory,
    required this.paths,
    required this.database,
    required this.storage,
    required this.ids,
  });

  static Future<TestHarness> create({String idPrefix = 'id'}) async {
    sqfliteFfiInit();

    final directory = await Directory.systemTemp.createTemp('wise_test_');
    final paths = StoragePaths.forRoot(Directory('${directory.path}/WISE'));
    await paths.ensureCreated();

    final database = DatabaseService(factory: databaseFactoryFfi);
    final opened = await database.open(path: inMemoryDatabasePath);
    if (opened.isFailure) {
      throw StateError('test database failed to open: ${opened.failureOrNull}');
    }

    return TestHarness._(
      directory: directory,
      paths: paths,
      database: database,
      storage: ImageStorageService(paths),
      ids: DatabaseIds.sequential(idPrefix),
    );
  }

  final Directory directory;
  final StoragePaths paths;
  final DatabaseService database;
  final ImageStorageService storage;
  final DatabaseIds ids;

  Future<void> dispose() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  /// Inserts the local user and default preferences that a first launch
  /// creates, so repository tests have a valid owner to reference.
  Future<String> seedUser({String id = 'user-1'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.database.insert('users', {
      'id': id,
      'display_name': null,
      'created_at': now,
      'updated_at': now,
      'version': 1,
    });
    await database.database.insert('user_preferences', {
      'user_id': id,
      'updated_at': now,
      'version': 1,
    });
    return id;
  }
}

/// Builds a small deterministic JPEG.
///
/// Deterministic so a checksum assertion is stable, and textured so the CV
/// feature detector has something to find (uniform images are the low-texture
/// failure case, tested separately).
Uint8List sampleJpeg({
  int width = 64,
  int height = 64,
  int seed = 7,
  int quality = 90,
}) {
  final image = img.Image(width: width, height: height);
  var state = seed;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
      final value = (state >> 16) & 0xFF;
      image.setPixelRgb(x, y, value, (value * 3) % 256, (value * 7) % 256);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

/// A flat grey image: the low-texture case that must NOT produce a confident
/// alignment (Computer Vision section 60, Testing ALG-T006).
Uint8List flatJpeg({int width = 64, int height = 64, int level = 128}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(level, level, level));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}
