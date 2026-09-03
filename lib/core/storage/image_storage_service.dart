import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../errors/failures.dart';
import '../errors/result.dart';
import '../imaging/image_codec.dart';
import '../logging/app_logger.dart';
import 'checksum.dart';
import 'storage_paths.dart';

/// A verified original, ready for a database row to be committed against it.
class StoredOriginal {
  const StoredOriginal({
    required this.path,
    required this.widthPx,
    required this.heightPx,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.checksum,
  });

  final String path;
  final int widthPx;
  final int heightPx;
  final int fileSizeBytes;
  final String mimeType;
  final String checksum;
}

/// Owns every write to the image tree.
///
/// Two guarantees, both P0:
///
/// 1. **The original is immutable.** After [storeOriginal] returns, nothing in
///    this class ever opens that path for writing again. There is no update, no
///    overwrite and no in-place edit method, by design (Privacy PRI-004, Data
///    Model section 38, Build Specification sections 2.1 and 105).
/// 2. **File and database stay consistent.** Writes follow the two-phase
///    sequence the specification prescribes: generate an id, write a temporary
///    file, verify it, move it into place, and only then let the caller commit
///    the row. If the row fails to commit, [discardOrphan] removes the file
///    (Data Model sections 43-44, Build Specification section 57).
class ImageStorageService {
  ImageStorageService(this.paths);

  final StoragePaths paths;
  final AppLogger _log = const AppLogger('storage');

  /// Writes an original and verifies it before it is considered stored.
  ///
  /// Verification decodes the image header, which is also how width and height
  /// are established. A file whose dimensions cannot be determined is rejected
  /// rather than stored with placeholder dimensions, so the non-null
  /// `photos.width_px` / `height_px` columns can never hold a fiction
  /// (SPECIFICATION_CONFLICTS C-008).
  Future<Result<StoredOriginal>> storeOriginal({
    required String photoId,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    File? temporary;
    try {
      await paths.ensureCreated();

      final decoded = ImageCodec.decode(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return const Result.failed(
          UnreadableImage(technicalDetail: 'decode returned no image'),
        );
      }

      // Phase 1: temporary file.
      temporary = File(paths.tempFile(photoId, extension));
      await temporary.writeAsBytes(bytes, flush: true);

      // Phase 2: verify what actually landed on disk, not what we intended to
      // write. A truncated write must fail here, not silently produce a
      // corrupt original.
      final writtenLength = await temporary.length();
      if (writtenLength != bytes.length) {
        return Result.failed(
          StorageUnavailable(
            technicalDetail:
                'short write: expected ${bytes.length}, got $writtenLength',
          ),
        );
      }
      final checksum = await Checksum.ofFile(temporary);

      // Phase 3: move into final storage.
      final finalPath = paths.originalFile(photoId, extension);
      final finalFile = File(finalPath);
      if (finalFile.existsSync()) {
        // A UUID collision is not credible; an existing file means a retry
        // after a crash. Refusing is safer than overwriting an original.
        return Result.failed(
          StorageUnavailable(
            technicalDetail: 'original already exists for photo $photoId',
          ),
        );
      }
      await temporary.rename(finalPath);
      temporary = null;

      _log.info('original stored', {
        'photo_id': photoId,
        'bytes': writtenLength,
        'width': decoded.width,
        'height': decoded.height,
      });

      return Result.ok(
        StoredOriginal(
          path: finalPath,
          widthPx: decoded.width,
          heightPx: decoded.height,
          fileSizeBytes: writtenLength,
          mimeType: _mimeTypeFor(extension),
          checksum: checksum,
        ),
      );
    } on FileSystemException catch (error) {
      _log.error('original write failed', {'error': error.message});
      return Result.failed(StorageUnavailable(technicalDetail: error.message));
    } finally {
      // Never leave a temporary file behind, whichever way we exited.
      if (temporary != null && temporary.existsSync()) {
        try {
          await temporary.delete();
        } on FileSystemException {
          // Cleanup is best-effort; the maintenance scan sweeps temp/.
        }
      }
    }
  }

  /// Writes a derived asset. Derived files are regenerable, so a failure here
  /// is recoverable and never touches the original (Data Model section 25).
  Future<Result<StoredOriginal>> storeDerived({
    required String assetId,
    required Directory directory,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    try {
      await paths.ensureCreated();
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      final decoded = ImageCodec.decode(bytes);
      if (decoded == null) {
        return const Result.failed(
          UnreadableImage(technicalDetail: 'derived asset failed to decode'),
        );
      }

      final path = paths.derivedFile(directory, assetId, extension);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      return Result.ok(
        StoredOriginal(
          path: path,
          widthPx: decoded.width,
          heightPx: decoded.height,
          fileSizeBytes: await file.length(),
          mimeType: _mimeTypeFor(extension),
          checksum: Checksum.ofBytes(bytes),
        ),
      );
    } on FileSystemException catch (error) {
      return Result.failed(ExportFailed(technicalDetail: error.message));
    }
  }

  /// Reads an original. Returns [PhotoNotFound] rather than throwing when the
  /// file has gone missing (Build Specification section 92).
  Future<Result<Uint8List>> readBytes(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return const Result.failed(PhotoNotFound());
      }
      return Result.ok(await file.readAsBytes());
    } on FileSystemException catch (error) {
      return Result.failed(StorageUnavailable(technicalDetail: error.message));
    }
  }

  /// Removes a file written moments ago whose database row failed to commit
  /// (Data Model section 44).
  Future<void> discardOrphan(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
      _log.warning('orphan discarded', {'path': path});
    } on FileSystemException catch (error) {
      _log.error('orphan cleanup failed', {'error': error.message});
    }
  }

  /// Deletes a derived asset. There is deliberately no equivalent for
  /// originals: originals are removed only by the deletion policy in
  /// `PhotoRepository`, never by a storage-level convenience method.
  Future<void> deleteDerived(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      _log.error('derived delete failed', {'error': error.message});
    }
  }

  /// Confirms an original still matches the checksum recorded at capture
  /// (Data Model section 39).
  Future<bool> verifyOriginal(String path, String expectedChecksum) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    return await Checksum.ofFile(file) == expectedChecksum;
  }

  /// Removes stale files from `temp/` (Privacy section 45, Build
  /// Specification section 106).
  ///
  /// Only ever touches `temp/`. Originals that look orphaned are reported by
  /// the maintenance scan but never deleted automatically (Data Model 68).
  Future<int> cleanTemporaryFiles({
    Duration olderThan = const Duration(hours: 6),
    DateTime? now,
  }) async {
    if (!paths.temp.existsSync()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(olderThan);
    var removed = 0;
    await for (final entity in paths.temp.list()) {
      if (entity is! File) continue;
      try {
        // statSync rather than stat(): the async dart:io variant is slower for
        // the small number of files temp/ ever holds.
        final stat = entity.statSync();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
          removed++;
        }
      } on FileSystemException {
        // Skip files we cannot stat or delete.
      }
    }
    if (removed > 0) _log.info('temporary files cleaned', {'count': removed});
    return removed;
  }

  static String _mimeTypeFor(String extension) =>
      switch (p.extension(extension).toLowerCase()) {
        '.png' => 'image/png',
        '.heic' || '.heif' => 'image/heic',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
