import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../core/database/database_ids.dart';
import '../core/database/database_service.dart';
import '../core/errors/failures.dart';
import '../core/errors/result.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/image_storage_service.dart';
import '../models/capture_recipe.dart';
import '../models/enums.dart';
import '../models/photo.dart';
import '../models/photo_metadata.dart';

/// What happens if a photograph is deleted (Data Model section 37).
class DeletionImpact {
  const DeletionImpact({
    required this.photoId,
    required this.referencingPhotoIds,
    required this.measurementCount,
    required this.annotationCount,
    required this.derivedAssetCount,
    required this.comparisonCount,
    required this.galleryCopyCount,
  });

  final String photoId;

  /// After photographs that use this photo as their reference. The user must be
  /// warned before those relationships are broken (Data Model section 37.5-6).
  final List<String> referencingPhotoIds;

  final int measurementCount;
  final int annotationCount;
  final int derivedAssetCount;
  final int comparisonCount;

  /// Independent Gallery copies. These are **not** deleted (Data Model 37.7,
  /// Functional section 34).
  final int galleryCopyCount;

  bool get hasReferences => referencingPhotoIds.isNotEmpty;

  bool get hasDependentData =>
      measurementCount > 0 ||
      annotationCount > 0 ||
      derivedAssetCount > 0 ||
      comparisonCount > 0;
}

/// Photograph persistence (Data Model section 66).
///
/// Owns the file-plus-row transaction: the image is written and verified first,
/// then the rows are committed, and the file is discarded if the commit fails
/// (Data Model section 44, Build Specification section 57).
class PhotoRepository {
  PhotoRepository({
    required DatabaseService database,
    required ImageStorageService storage,
    DatabaseIds ids = const DatabaseIds(),
  }) : _db = database,
       _storage = storage,
       _ids = ids;

  final DatabaseService _db;
  final ImageStorageService _storage;
  final DatabaseIds _ids;
  final AppLogger _log = const AppLogger('photos');

  /// Stores an image and its record together.
  ///
  /// Sequence (Data Model section 44):
  /// 1. generate the id
  /// 2. write the temporary file
  /// 3. verify it
  /// 4. move it into `originals/`
  /// 5. commit the rows
  ///
  /// If step 5 fails the file from step 4 is removed, so the tree cannot
  /// accumulate originals with no record.
  Future<Result<Photo>> createPhoto({
    required Uint8List bytes,
    required PhotoType type,
    required PhotoSource source,
    String? userId,
    String? caseId,
    BodyPart? bodyPart,
    Laterality? laterality,
    String? referencePhotoId,
    String? protocolId,
    CaptureRecipe? captureRecipe,
    PhotoMetadata? metadata,
    String extension = '.jpg',
    DateTime? capturedAt,
    DateTime? now,
  }) async {
    final validation = _validateNewPhoto(
      type: type,
      referencePhotoId: referencePhotoId,
    );
    if (validation != null) return Result.failed(validation);

    final photoId = _ids.newId();
    final stored = await _storage.storeOriginal(
      photoId: photoId,
      bytes: bytes,
      extension: extension,
    );

    return stored.fold(
      onFailure: Result.failed,
      onOk: (original) async {
        final timestamp = now ?? DateTime.now();
        final photo = Photo(
          id: photoId,
          userId: userId,
          caseId: caseId,
          type: type,
          originalPath: original.path,
          capturedAt: capturedAt ?? timestamp,
          importedAt: source == PhotoSource.import ? timestamp : null,
          bodyPart: bodyPart,
          laterality: laterality,
          referencePhotoId: referencePhotoId,
          protocolId: protocolId,
          widthPx: original.widthPx,
          heightPx: original.heightPx,
          fileSizeBytes: original.fileSizeBytes,
          mimeType: original.mimeType,
          checksum: original.checksum,
          source: source,
          captureRecipe: captureRecipe,
          // PROCESSING until the thumbnail and quality checks land; a partially
          // processed image stays recoverable (Data Model section 42).
          status: PhotoStatus.processing,
          createdAt: timestamp,
          updatedAt: timestamp,
        );

        final committed = await _db.transaction((txn) async {
          await txn.insert('photos', photo.toRow());
          if (metadata != null) {
            await txn.insert(
              'photo_metadata',
              metadata.toRow(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          return photo;
        });

        if (committed.isFailure) {
          // Step 5 failed: remove the file written in step 4.
          await _storage.discardOrphan(original.path);
          return Result.failed(committed.failureOrNull!);
        }

        _log.info('photo created', {
          'photo_id': photoId,
          'type': type.wireName,
          'source': source.wireName,
        });
        return Result.ok(photo);
      },
    );
  }

  /// Validation from Data Model section 49.
  Failure? _validateNewPhoto({
    required PhotoType type,
    required String? referencePhotoId,
  }) {
    if (type == PhotoType.photo && referencePhotoId != null) {
      return const ValidationFailure(
        'A standalone photograph cannot have a reference.',
      );
    }
    return null;
  }

  Future<Photo?> getPhoto(String id, {bool includeDeleted = false}) async {
    final rows = await _db.database.query(
      'photos',
      where: includeDeleted ? 'id = ?' : 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Photo.fromRow(rows.first);
  }

  /// Library listing. Paginated and thumbnail-oriented: full originals are
  /// never loaded to browse (Data Model section 70, Build Specification 107).
  Future<List<Photo>> getPhotos({
    PhotoType? type,
    String? caseId,
    BodyPart? bodyPart,
    Laterality? laterality,
    String? protocolId,
    String? referencePhotoId,
    DateTime? capturedAfter,
    DateTime? capturedBefore,
    int limit = 100,
    int offset = 0,
    bool descending = true,
  }) async {
    final where = <String>['deleted_at IS NULL'];
    final args = <Object?>[];

    void filter(String clause, Object? value) {
      if (value == null) return;
      where.add(clause);
      args.add(value);
    }

    filter('type = ?', type?.wireName);
    filter('case_id = ?', caseId);
    filter('body_part = ?', bodyPart?.wireName);
    filter('laterality = ?', laterality?.wireName);
    filter('protocol_id = ?', protocolId);
    filter('reference_photo_id = ?', referencePhotoId);
    filter('captured_at >= ?', capturedAfter?.millisecondsSinceEpoch);
    filter('captured_at <= ?', capturedBefore?.millisecondsSinceEpoch);

    final rows = await _db.database.query(
      'photos',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'captured_at ${descending ? 'DESC' : 'ASC'}',
      limit: limit,
      offset: offset,
    );
    return rows.map(Photo.fromRow).toList(growable: false);
  }

  /// Before photographs eligible to act as a reference (Data Model 48).
  Future<List<Photo>> getReferenceCandidates({int limit = 100}) =>
      getPhotos(type: PhotoType.before, limit: limit);

  /// After photographs taken against a given Before (Data Model 48).
  Future<List<Photo>> getAfterPhotosFor(String referencePhotoId) => getPhotos(
    type: PhotoType.after,
    referencePhotoId: referencePhotoId,
    descending: false,
  );

  Future<Result<Photo>> updatePhoto(Photo photo, {DateTime? now}) async {
    final updated = photo.copyWith(
      updatedAt: now ?? DateTime.now(),
      version: photo.version + 1,
    );
    final result = await _db.transaction((txn) async {
      await txn.update(
        'photos',
        updated.toRow(),
        where: 'id = ?',
        whereArgs: [photo.id],
      );
      return updated;
    });
    return result;
  }

  /// Records the thumbnail path and promotes the photo to ACTIVE.
  Future<Result<Photo>> markProcessed(
    String photoId, {
    String? thumbnailPath,
    DateTime? now,
  }) async {
    final photo = await getPhoto(photoId);
    if (photo == null) return const Result.failed(PhotoNotFound());
    return updatePhoto(
      photo.copyWith(thumbnailPath: thumbnailPath, status: PhotoStatus.active),
      now: now,
    );
  }

  /// Marks a photo FAILED without losing it.
  ///
  /// A processing failure must never cost the original (Build Specification
  /// section 105), so the row stays and the file stays.
  Future<Result<Photo>> markProcessingFailed(
    String photoId, {
    DateTime? now,
  }) async {
    final photo = await getPhoto(photoId);
    if (photo == null) return const Result.failed(PhotoNotFound());
    return updatePhoto(photo.copyWith(status: PhotoStatus.failed), now: now);
  }

  /// What a deletion would affect. Callers must show this before deleting
  /// (Data Model section 37).
  Future<DeletionImpact> analyseDeletion(String photoId) async {
    final db = _db.database;

    Future<int> count(String table, String column) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table WHERE $column = ?',
        [photoId],
      );
      return (rows.first['c']! as num).toInt();
    }

    final referencing = await db.query(
      'photos',
      columns: ['id'],
      where: 'reference_photo_id = ? AND deleted_at IS NULL',
      whereArgs: [photoId],
    );

    final comparisons = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM comparisons '
      'WHERE before_photo_id = ? OR after_photo_id = ?',
      [photoId, photoId],
    );

    return DeletionImpact(
      photoId: photoId,
      referencingPhotoIds: referencing
          .map((row) => row['id']! as String)
          .toList(growable: false),
      measurementCount: await count('measurements', 'photo_id'),
      annotationCount: await count('annotations', 'photo_id'),
      derivedAssetCount: await count('derived_assets', 'source_photo_id'),
      comparisonCount: (comparisons.first['c']! as num).toInt(),
      galleryCopyCount: await count('gallery_exports', 'photo_id'),
    );
  }

  /// Soft-deletes a photograph (Data Model sections 36-37).
  ///
  /// The row is marked, not removed, and the original file stays on disk so the
  /// deletion is recoverable. Dependent measurements and annotations are
  /// soft-deleted with it; derived assets are marked for cleanup. Gallery
  /// copies are never touched.
  ///
  /// Refuses while another photograph still references this one unless
  /// [force] is set, which callers pass only after showing [DeletionImpact].
  Future<Result<void>> deletePhoto(
    String photoId, {
    bool force = false,
    DateTime? now,
  }) async {
    final photo = await getPhoto(photoId);
    if (photo == null) return const Result.failed(PhotoNotFound());

    final impact = await analyseDeletion(photoId);
    if (impact.hasReferences && !force) {
      return Result.failed(
        ValidationFailure(
          'This Before photograph is used by '
          '${impact.referencingPhotoIds.length} After '
          '${impact.referencingPhotoIds.length == 1 ? 'photograph' : 'photographs'}. '
          'Deleting it will break that link.',
        ),
      );
    }

    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      await txn.update(
        'photos',
        {
          'deleted_at': timestamp,
          'status': PhotoStatus.deleted.wireName,
          'updated_at': timestamp,
          'version': photo.version + 1,
        },
        where: 'id = ?',
        whereArgs: [photoId],
      );
      await txn.update(
        'measurements',
        {'deleted_at': timestamp, 'updated_at': timestamp},
        where: 'photo_id = ? AND deleted_at IS NULL',
        whereArgs: [photoId],
      );
      await txn.update(
        'annotations',
        {'deleted_at': timestamp, 'updated_at': timestamp},
        where: 'photo_id = ? AND deleted_at IS NULL',
        whereArgs: [photoId],
      );
      // Gallery copies are deliberately untouched: they are independent files
      // the user chose to place outside WISE (Data Model section 37.7).
    });
  }

  /// Reverses a soft delete.
  Future<Result<Photo>> restorePhoto(String photoId, {DateTime? now}) async {
    final photo = await getPhoto(photoId, includeDeleted: true);
    if (photo == null) return const Result.failed(PhotoNotFound());
    return updatePhoto(
      photo.copyWith(clearDeletedAt: true, status: PhotoStatus.active),
      now: now,
    );
  }

  /// Confirms the original on disk still matches its recorded checksum
  /// (Data Model section 39, Testing "data integrity").
  Future<bool> verifyIntegrity(String photoId) async {
    final photo = await getPhoto(photoId, includeDeleted: true);
    if (photo?.checksum == null) return false;
    return _storage.verifyOriginal(photo!.originalPath, photo.checksum!);
  }

  Future<PhotoMetadata?> getMetadata(String photoId) async {
    final rows = await _db.database.query(
      'photo_metadata',
      where: 'photo_id = ?',
      whereArgs: [photoId],
      limit: 1,
    );
    return rows.isEmpty ? null : PhotoMetadata.fromRow(rows.first);
  }
}
