import '../core/database/database_ids.dart';
import '../core/database/database_service.dart';
import '../core/errors/failures.dart';
import '../core/errors/result.dart';
import '../models/alignment_record.dart';
import '../models/annotation.dart';
import '../models/calibration.dart';
import '../models/comparison.dart';
import '../models/derived_asset.dart';
import '../models/enums.dart';
import '../models/export_record.dart';
import '../models/geometry.dart';
import '../models/measurement.dart';
import '../models/quality_check.dart';

/// Persistence for the clinical tool layer: calibrations, measurements,
/// annotations, alignments, quality checks, derived assets, comparisons and
/// exports (Data Model sections 18-32).
///
/// Grouped into one class because these entities are almost always read and
/// written together for a single photograph, and splitting them into eight
/// near-identical repositories would add indirection without adding a boundary.
class ClinicalRepository {
  ClinicalRepository({
    required DatabaseService database,
    DatabaseIds ids = const DatabaseIds(),
  }) : _db = database,
       _ids = ids;

  final DatabaseService _db;
  final DatabaseIds _ids;

  String newId() => _ids.newId();

  // --- Calibration ----------------------------------------------------------

  /// Stores a calibration for one photograph.
  ///
  /// Validation happens in `Calibration.create`, which returns null for a
  /// non-positive known value or pixel distance. Rejecting here rather than
  /// storing a nonsense scale is what stops an invalid calibration from
  /// producing confident-looking centimetres (Functional CAL-006, Data
  /// Model 49).
  Future<Result<Calibration>> saveCalibration({
    required String photoId,
    required CalibrationMethod method,
    required double knownValue,
    required LengthUnit unit,
    required double pixelDistance,
    Geometry? referenceGeometry,
    double? confidence,
    DateTime? now,
  }) async {
    final calibration = Calibration.create(
      id: _ids.newId(),
      photoId: photoId,
      method: method,
      knownValue: knownValue,
      unit: unit,
      pixelDistance: pixelDistance,
      referenceGeometry: referenceGeometry,
      confidence: confidence,
      now: now,
    );

    if (calibration == null) {
      return const Result.failed(
        CalibrationInvalid(
          reason:
              'Enter a known distance greater than zero and draw a line across '
              'it.',
        ),
      );
    }

    return _db.transaction((txn) async {
      await txn.insert('calibrations', calibration.toRow());
      return calibration;
    });
  }

  /// The most recent usable calibration for a photograph, or null.
  ///
  /// Scoped to the photograph. A calibration is never borrowed from another
  /// image (Data Model section 19, CV section 49).
  Future<Calibration?> getCalibrationFor(String photoId) async {
    final rows = await _db.database.query(
      'calibrations',
      where: 'photo_id = ? AND is_valid = 1',
      whereArgs: [photoId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final calibration = Calibration.fromRow(rows.first);
    return calibration.isUsable ? calibration : null;
  }

  Future<Result<void>> invalidateCalibration(String id, {DateTime? now}) =>
      _db.transaction((txn) async {
        await txn.update(
          'calibrations',
          {
            'is_valid': 0,
            'updated_at': (now ?? DateTime.now()).millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  // --- Measurement ----------------------------------------------------------

  Future<Result<Measurement>> saveMeasurement(Measurement measurement) =>
      _db.transaction((txn) async {
        await txn.insert('measurements', measurement.toRow());
        return measurement;
      });

  Future<Result<Measurement>> updateMeasurement(Measurement measurement) =>
      _db.transaction((txn) async {
        await txn.update(
          'measurements',
          measurement.toRow(),
          where: 'id = ?',
          whereArgs: [measurement.id],
        );
        return measurement;
      });

  Future<List<Measurement>> getMeasurements(
    String photoId, {
    bool visibleOnly = false,
  }) async {
    final rows = await _db.database.query(
      'measurements',
      where: visibleOnly
          ? 'photo_id = ? AND deleted_at IS NULL AND visible = 1'
          : 'photo_id = ? AND deleted_at IS NULL',
      whereArgs: [photoId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Measurement.fromRow).toList(growable: false);
  }

  Future<Result<void>> deleteMeasurement(String id, {DateTime? now}) =>
      _db.transaction((txn) async {
        final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
        await txn.update(
          'measurements',
          {'deleted_at': timestamp, 'updated_at': timestamp},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  // --- Annotation -----------------------------------------------------------

  Future<Result<Annotation>> saveAnnotation(Annotation annotation) =>
      _db.transaction((txn) async {
        await txn.insert('annotations', annotation.toRow());
        return annotation;
      });

  Future<Result<Annotation>> updateAnnotation(Annotation annotation) =>
      _db.transaction((txn) async {
        await txn.update(
          'annotations',
          annotation.toRow(),
          where: 'id = ?',
          whereArgs: [annotation.id],
        );
        return annotation;
      });

  Future<List<Annotation>> getAnnotations(
    String photoId, {
    bool visibleOnly = false,
  }) async {
    final rows = await _db.database.query(
      'annotations',
      where: visibleOnly
          ? 'photo_id = ? AND deleted_at IS NULL AND visible = 1'
          : 'photo_id = ? AND deleted_at IS NULL',
      whereArgs: [photoId],
      orderBy: 'z_index ASC, created_at ASC',
    );
    return rows.map(Annotation.fromRow).toList(growable: false);
  }

  Future<Result<void>> deleteAnnotation(String id, {DateTime? now}) =>
      _db.transaction((txn) async {
        final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
        await txn.update(
          'annotations',
          {'deleted_at': timestamp, 'updated_at': timestamp},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

  // --- Alignment ------------------------------------------------------------

  Future<Result<AlignmentRecord>> saveAlignment(AlignmentRecord record) =>
      _db.transaction((txn) async {
        await txn.insert('alignments', record.toRow());
        return record;
      });

  /// The best reusable alignment between two photographs.
  ///
  /// Comparison reuses this rather than deriving a second transform
  /// (Functional CMP-006, CV section 50). Only GOOD/FAIR records with an
  /// actual matrix are returned, because rendering a difference view from an
  /// untrustworthy transform manufactures apparent change (CV section 51).
  Future<AlignmentRecord?> getReusableAlignment({
    required String referencePhotoId,
    required String targetPhotoId,
  }) async {
    final rows = await _db.database.query(
      'alignments',
      where:
          'reference_photo_id = ? AND target_photo_id = ? '
          'AND transform_matrix_json IS NOT NULL '
          "AND status IN ('GOOD', 'FAIR')",
      whereArgs: [referencePhotoId, targetPhotoId],
      orderBy: 'confidence DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final record = AlignmentRecord.fromRow(rows.first);
    return record.isReusable ? record : null;
  }

  // --- Quality checks -------------------------------------------------------

  Future<Result<void>> saveQualityChecks(List<QualityCheck> checks) =>
      _db.transaction((txn) async {
        for (final check in checks) {
          await txn.insert('quality_checks', check.toRow());
        }
      });

  Future<List<QualityCheck>> getQualityChecks(String photoId) async {
    final rows = await _db.database.query(
      'quality_checks',
      where: 'photo_id = ?',
      whereArgs: [photoId],
      orderBy: 'created_at DESC',
    );
    return rows.map(QualityCheck.fromRow).toList(growable: false);
  }

  // --- Derived assets -------------------------------------------------------

  Future<Result<DerivedAsset>> saveDerivedAsset(DerivedAsset asset) =>
      _db.transaction((txn) async {
        await txn.insert('derived_assets', asset.toRow());
        return asset;
      });

  Future<List<DerivedAsset>> getDerivedAssets(
    String photoId, {
    DerivedAssetType? type,
  }) async {
    final rows = await _db.database.query(
      'derived_assets',
      where: type == null
          ? 'source_photo_id = ?'
          : 'source_photo_id = ? AND asset_type = ?',
      whereArgs: type == null ? [photoId] : [photoId, type.wireName],
      orderBy: 'created_at DESC',
    );
    return rows.map(DerivedAsset.fromRow).toList(growable: false);
  }

  Future<Result<void>> deleteDerivedAsset(String id) =>
      _db.transaction((txn) async {
        await txn.delete('derived_assets', where: 'id = ?', whereArgs: [id]);
      });

  // --- Comparison -----------------------------------------------------------

  Future<Result<Comparison>> saveComparison(Comparison comparison) =>
      _db.transaction((txn) async {
        await txn.insert('comparisons', comparison.toRow());
        return comparison;
      });

  Future<Result<Comparison>> updateComparison(Comparison comparison) =>
      _db.transaction((txn) async {
        await txn.update(
          'comparisons',
          comparison.toRow(),
          where: 'id = ?',
          whereArgs: [comparison.id],
        );
        return comparison;
      });

  Future<Comparison?> getComparison({
    required String beforePhotoId,
    required String afterPhotoId,
  }) async {
    final rows = await _db.database.query(
      'comparisons',
      where: 'before_photo_id = ? AND after_photo_id = ?',
      whereArgs: [beforePhotoId, afterPhotoId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Comparison.fromRow(rows.first);
  }

  // --- Exports --------------------------------------------------------------

  Future<Result<ExportRecord>> saveExport(ExportRecord record) =>
      _db.transaction((txn) async {
        await txn.insert('exports', record.toRow());
        return record;
      });

  Future<List<ExportRecord>> getExports(String photoId) async {
    final rows = await _db.database.query(
      'exports',
      where: 'photo_id = ?',
      whereArgs: [photoId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ExportRecord.fromRow).toList(growable: false);
  }

  Future<Result<GalleryExport>> saveGalleryExport(GalleryExport record) =>
      _db.transaction((txn) async {
        await txn.insert('gallery_exports', record.toRow());
        return record;
      });
}
