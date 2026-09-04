import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/database/database_ids.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/imaging/layer_renderer.dart';
import '../../core/imaging/layer_stack.dart';
import '../../core/imaging/metadata_anonymizer.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/image_storage_service.dart';
import '../../models/annotation.dart';
import '../../models/derived_asset.dart';
import '../../models/enums.dart';
import '../../models/export_record.dart';
import '../../models/measurement.dart';
import '../../models/photo.dart';
import '../../repositories/clinical_repository.dart';
import '../../shared/constants/wise_strings.dart';

/// Produces export files (Functional EXP-001..004, Build Specification 47-49).
///
/// The invariant that governs the whole class: **an export is a derived asset**.
/// The original is opened read-only, everything is composed onto a copy, and
/// the result is written to `derived/exports/`
/// (Build Specification section 48, Privacy PRI-004).
class ExportService {
  ExportService({
    required ImageStorageService storage,
    required ClinicalRepository clinical,
    LayerRenderer renderer = const LayerRenderer(),
    MetadataAnonymizer anonymizer = const MetadataAnonymizer(),
    DatabaseIds ids = const DatabaseIds(),
  }) : _storage = storage,
       _clinical = clinical,
       _renderer = renderer,
       _anonymizer = anonymizer,
       _ids = ids;

  final ImageStorageService _storage;
  final ClinicalRepository _clinical;
  final LayerRenderer _renderer;
  final MetadataAnonymizer _anonymizer;
  final DatabaseIds _ids;
  final AppLogger _log = const AppLogger('export');

  Future<Result<ExportRecord>> export({
    required Photo photo,
    required ExportPreset preset,
    Photo? pairedWith,
    ExportConfiguration? configuration,
  }) async {
    final config = configuration ?? ExportConfiguration.forPreset(preset);

    final originalBytes = await _storage.readBytes(photo.originalPath);
    if (originalBytes.isFailure) {
      return Result.failed(originalBytes.failureOrNull!);
    }

    final rendered = await _renderBytes(
      photo: photo,
      preset: preset,
      config: config,
      originalBytes: originalBytes.valueOrNull!,
      pairedWith: pairedWith,
    );
    if (rendered.isFailure) return Result.failed(rendered.failureOrNull!);

    var bytes = rendered.valueOrNull!;

    // Anonymization is the last step, so it strips metadata from whatever the
    // preset produced rather than only from the source.
    if (preset == ExportPreset.anonymized) {
      final anonymized = _anonymizer.anonymize(
        bytes,
        keepTimestamps: config.includeDate,
      );
      if (anonymized.isFailure) {
        return Result.failed(anonymized.failureOrNull!);
      }
      bytes = anonymized.valueOrNull!;
    }

    final assetId = _ids.newId();
    final stored = await _storage.storeDerived(
      assetId: assetId,
      directory: _storage.paths.exports,
      bytes: bytes,
    );
    if (stored.isFailure) {
      return const Result.failed(ExportFailed());
    }

    final asset = stored.valueOrNull!;
    final now = DateTime.now();

    await _clinical.saveDerivedAsset(
      DerivedAsset(
        id: assetId,
        sourcePhotoId: photo.id,
        assetType: preset == ExportPreset.anonymized
            ? DerivedAssetType.anonymized
            : DerivedAssetType.export,
        filePath: asset.path,
        widthPx: asset.widthPx,
        heightPx: asset.heightPx,
        fileSizeBytes: asset.fileSizeBytes,
        checksum: asset.checksum,
        configuration: config.toMap(),
        createdAt: now,
      ),
    );

    final record = ExportRecord(
      id: _ids.newId(),
      photoId: photo.id,
      preset: preset,
      outputPath: asset.path,
      configuration: config,
      anonymized: preset == ExportPreset.anonymized,
      createdAt: now,
      status: 'COMPLETE',
    );

    final saved = await _clinical.saveExport(record);
    if (saved.isFailure) {
      // The row failed, so the file has no record: remove it rather than
      // leaving an orphan (Data Model section 44).
      await _storage.deleteDerived(asset.path);
      return const Result.failed(ExportFailed());
    }

    _log.info('export created', {
      'preset': preset.wireName,
      'photo_id': photo.id,
    });
    return Result.ok(record);
  }

  Future<Result<Uint8List>> _renderBytes({
    required Photo photo,
    required ExportPreset preset,
    required ExportConfiguration config,
    required Uint8List originalBytes,
    Photo? pairedWith,
  }) async {
    if (preset.isPair) {
      if (pairedWith == null) {
        return const Result.failed(
          ExportFailed(technicalDetail: 'pair preset without a second photo'),
        );
      }
      final partnerBytes = await _storage.readBytes(pairedWith.originalPath);
      if (partnerBytes.isFailure) {
        return Result.failed(partnerBytes.failureOrNull!);
      }

      // The Before is the reference, so it goes on the left regardless of
      // which photograph the export was started from.
      final beforeIsCurrent = photo.type == PhotoType.before;
      return _renderer.renderPair(
        beforeBytes: beforeIsCurrent
            ? originalBytes
            : partnerBytes.valueOrNull!,
        afterBytes: beforeIsCurrent ? partnerBytes.valueOrNull! : originalBytes,
        beforeStack: config.includeMeasurements
            ? await _stackFor(beforeIsCurrent ? photo : pairedWith, config)
            : null,
        afterStack: config.includeMeasurements
            ? await _stackFor(beforeIsCurrent ? pairedWith : photo, config)
            : null,
        maxDimension: config.maxDimension,
      );
    }

    final stack = await _stackFor(photo, config);

    // An ORIGINAL export with nothing to draw returns the bytes untouched,
    // rather than decoding and re-encoding them, which would lose quality for
    // no reason (Functional EXP-004).
    if (stack.isPassThrough) return Result.ok(originalBytes);

    return _renderer.render(
      originalBytes: originalBytes,
      stack: stack,
      maxDimension: config.maxDimension,
    );
  }

  Future<LayerStack> _stackFor(Photo photo, ExportConfiguration config) async {
    final measurements = config.includeMeasurements
        ? await _clinical.getMeasurements(photo.id, visibleOnly: true)
        : const <Measurement>[];
    final annotations = config.includeAnnotations
        ? await _clinical.getAnnotations(photo.id, visibleOnly: true)
        : const <Annotation>[];

    return LayerStack(
      originalPath: photo.originalPath,
      widthPx: photo.widthPx,
      heightPx: photo.heightPx,
      measurements: measurements,
      annotations: annotations,
      // A grid reaches a file only when the export explicitly asks for it
      // (SPECIFICATION_CONFLICTS C-002).
      gridType: config.includeGrid
          ? photo.captureRecipe?.gridType ?? GridType.thirds
          : null,
      footerLines: config.includeFooter
          ? _footerFor(photo, measurements, config)
          : const <String>[],
    );
  }

  /// The measurement footer (PRD section 15, UX/UI section 41).
  List<String> _footerFor(
    Photo photo,
    List<Measurement> measurements,
    ExportConfiguration config,
  ) {
    final lines = <String>['WISE CLINICAL PHOTO'];

    if (config.footerText != null && config.footerText!.isNotEmpty) {
      lines.add(config.footerText!);
    }

    for (final measurement in measurements.take(3)) {
      lines.add('${measurement.type.label}: ${measurement.displayValue}');
    }

    if (measurements.any((m) => m.hasPhysicalValue)) {
      lines.add(WiseStrings.measurementDisclaimer);
    }

    if (config.includeDate) {
      final date = photo.capturedAt.toLocal();
      lines.add(
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}',
      );
    }

    return lines;
  }
}

final exportServiceProvider = FutureProvider<ExportService>((ref) async {
  return ExportService(
    storage: await ref.watch(imageStorageProvider.future),
    clinical: await ref.watch(clinicalRepositoryProvider.future),
    renderer: ref.watch(layerRendererProvider),
  );
});
