import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../app/providers.dart';
import '../../core/database/database_ids.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/image_storage_service.dart';
import '../../models/enums.dart';
import '../../models/export_record.dart';
import '../../models/photo.dart';
import '../../repositories/clinical_repository.dart';

/// What should happen when a photograph is saved.
enum GalleryDecision {
  /// Ask the clinician (Functional SAV-003, `ASK`).
  ask,

  /// Copy without asking.
  save,

  /// Do not copy.
  skip,
}

/// Copying a photograph into the device Gallery (Functional SAV-002..004,
/// PRD sections 26-27, Privacy sections 35-38).
///
/// Three rules the specifications are firm about:
///
/// - **The Gallery copy is independent.** It is a separate file the clinician
///   chose to place outside WISE. Deleting the WISE record never deletes it
///   (Data Model section 37.7, Functional section 34).
/// - **The WISE original is never replaced by it** (Functional SAV-004).
/// - **Privacy Mode forbids automatic copies.** `ALWAYS` is downgraded to
///   `ASK` rather than obeyed (PRD section 28, Functional PRI-004).
class GalleryService {
  GalleryService({
    required ImageStorageService storage,
    required ClinicalRepository clinical,
    GalleryPlatform platform = const GalleryPlatform(),
    DatabaseIds ids = const DatabaseIds(),
  }) : _storage = storage,
       _clinical = clinical,
       _platform = platform,
       _ids = ids;

  /// The album name from PRD section 27, subject to platform support.
  static const String albumName = 'WISE Clinical Photos';

  final ImageStorageService _storage;
  final ClinicalRepository _clinical;
  final GalleryPlatform _platform;
  final DatabaseIds _ids;
  final AppLogger _log = const AppLogger('gallery');

  /// Resolves the saved preference into an action for this capture.
  ///
  /// Privacy Mode is applied here rather than at the call site so no caller can
  /// bypass it by reading the raw preference.
  static GalleryDecision decide({
    required GallerySaveMode mode,
    required bool privacyMode,
  }) {
    if (privacyMode) {
      // No automatic copy under Privacy Mode. ALWAYS becomes a question, not a
      // silent write (PRD section 28).
      return mode == GallerySaveMode.never
          ? GalleryDecision.skip
          : GalleryDecision.ask;
    }
    return switch (mode) {
      GallerySaveMode.always => GalleryDecision.save,
      GallerySaveMode.never => GalleryDecision.skip,
      GallerySaveMode.ask => GalleryDecision.ask,
    };
  }

  /// Copies a photograph into the Gallery.
  ///
  /// Always an explicit, user-initiated action: nothing calls this from the
  /// capture path without a decision from [decide] or a direct tap.
  Future<Result<void>> saveToGallery({
    required Photo photo,
    Uint8List? bytes,
  }) async {
    Uint8List? payload = bytes;

    if (payload == null) {
      final read = await _storage.readBytes(photo.originalPath);
      if (read.isFailure) return Result.failed(read.failureOrNull!);
      payload = read.valueOrNull;
    }

    final saved = await _platform.putImageBytes(payload!, album: albumName);
    if (saved.isFailure) return saved;

    // Recorded so the library can show that a copy exists, and so deletion can
    // warn without assuming it is still there (Data Model section 32).
    await _clinical.saveGalleryExport(
      GalleryExport(
        id: _ids.newId(),
        photoId: photo.id,
        albumName: albumName,
        createdAt: DateTime.now(),
        status: 'SAVED',
      ),
    );

    _log.info('gallery copy created', {'photo_id': photo.id});
    return const Result.ok(null);
  }
}

/// Wraps the `gal` plugin so [GalleryService] is testable without a platform
/// channel, and so a permission failure becomes a typed failure rather than an
/// exception (Build Specification sections 90-91).
class GalleryPlatform {
  const GalleryPlatform();

  Future<Result<void>> putImageBytes(
    Uint8List bytes, {
    required String album,
  }) async {
    try {
      // Requests the add-only permission the platform needs, at the point of
      // use (Privacy section 8).
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) return const Result.failed(GalleryPermissionDenied());
      }
      await Gal.putImageBytes(bytes, album: album);
      return const Result.ok(null);
    } on GalException catch (error) {
      return switch (error.type) {
        GalExceptionType.accessDenied => Result.failed(
          GalleryPermissionDenied(technicalDetail: error.type.name),
        ),
        GalExceptionType.notEnoughSpace => const Result.failed(
          InsufficientStorage(),
        ),
        _ => Result.failed(GallerySaveFailed(technicalDetail: error.type.name)),
      };
    }
  }
}

final galleryServiceProvider = FutureProvider<GalleryService>((ref) async {
  return GalleryService(
    storage: await ref.watch(imageStorageProvider.future),
    clinical: await ref.watch(clinicalRepositoryProvider.future),
  );
});
