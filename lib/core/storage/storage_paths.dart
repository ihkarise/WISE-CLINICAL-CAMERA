import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The on-disk layout (Data Model section 3, Build Specification section 53).
///
/// ```text
/// WISE/
///   originals/
///   thumbnails/
///   derived/{annotated,measured,comparison,exports}/
///   temp/
///   backups/
/// ```
///
/// Everything sits inside application-private storage so originals are not
/// world-readable and do not appear in the device Gallery unless the user
/// explicitly exports them (Privacy sections 10-11).
class StoragePaths {
  StoragePaths._(this.root);

  /// Resolves the platform's application-private support directory.
  static Future<StoragePaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    return StoragePaths._(Directory(p.join(support.path, 'WISE')));
  }

  /// For tests: anchors the tree at an arbitrary directory.
  static StoragePaths forRoot(Directory root) => StoragePaths._(root);

  final Directory root;

  Directory get originals => Directory(p.join(root.path, 'originals'));
  Directory get thumbnails => Directory(p.join(root.path, 'thumbnails'));
  Directory get derived => Directory(p.join(root.path, 'derived'));
  Directory get annotated => Directory(p.join(derived.path, 'annotated'));
  Directory get measured => Directory(p.join(derived.path, 'measured'));
  Directory get comparison => Directory(p.join(derived.path, 'comparison'));
  Directory get exports => Directory(p.join(derived.path, 'exports'));
  Directory get temp => Directory(p.join(root.path, 'temp'));
  Directory get backups => Directory(p.join(root.path, 'backups'));

  String get databasePath => p.join(root.path, 'wise.db');

  List<Directory> get all => <Directory>[
    root,
    originals,
    thumbnails,
    derived,
    annotated,
    measured,
    comparison,
    exports,
    temp,
    backups,
  ];

  Future<void> ensureCreated() async {
    for (final directory in all) {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
    }
  }

  /// Opaque, non-identifying filenames (Privacy section 12, Data Model 32).
  ///
  /// A filename must never carry a patient name or diagnosis, so it is built
  /// only from the entity UUID.
  String originalFile(String photoId, String extension) =>
      p.join(originals.path, 'photo_$photoId$extension');

  String thumbnailFile(String photoId) =>
      p.join(thumbnails.path, 'thumb_$photoId.jpg');

  String derivedFile(Directory directory, String assetId, String extension) =>
      p.join(directory.path, 'asset_$assetId$extension');

  String tempFile(String token, String extension) =>
      p.join(temp.path, 'tmp_$token$extension');
}
