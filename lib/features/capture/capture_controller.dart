import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/camera/camera_engine.dart';
import '../../core/cv/alignment_engine.dart';
import '../../core/cv/focus_engine.dart';
import '../../core/cv/guidance_engine.dart';
import '../../core/cv/lighting_engine.dart';
import '../../core/cv/working_image.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/logging/app_logger.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/sensors/device_level_service.dart';
import '../../models/capture_recipe.dart';
import '../../models/effective_settings.dart';
import '../../models/enums.dart';
import '../../models/photo.dart';
import '../../models/quality_check.dart';
import '../../models/reference_transform.dart';
import '../../models/tool_overrides.dart';
import '../../repositories/photo_repository.dart';
import 'capture_readiness.dart';
import 'capture_state.dart';

/// Drives one capture session.
///
/// Owns the sequence the specifications lay out: initialise the camera, prepare
/// the reference, analyse sampled frames, decide readiness, capture, store the
/// original, then process derived assets (Functional section 47, Data Model
/// section 41, Build Specification sections 13-14, 58).
///
/// Deliberately holds no widgets and no pixels beyond the frame in flight.
class CaptureController extends StateNotifier<CaptureState> {
  CaptureController({
    required this.ref,
    required PhotoType mode,
    Photo? reference,
  }) : super(CaptureState(mode: mode, reference: reference)) {
    _log = AppLogger('capture');
  }

  final Ref ref;
  late final AppLogger _log;

  StreamSubscription<CameraFrame>? _frameSubscription;
  StreamSubscription<LevelReading>? _levelSubscription;
  ReferenceFeatures? _referenceFeatures;
  Uint8List? _referenceBytes;
  WorkingImage? _referenceWorking;

  /// True while a frame is being analysed, so frames are dropped rather than
  /// queued. A backlog would make guidance lag behind what the clinician sees
  /// (CV sections 55-57).
  bool _analysing = false;

  CameraEngine get _camera => ref.read(cameraEngineProvider);
  AlignmentEngine get _alignment => ref.read(alignmentEngineProvider);
  GuidanceEngine get _guidance => ref.read(guidanceEngineProvider);
  LightingEngine get _lighting => ref.read(lightingEngineProvider);
  FocusEngine get _focus => ref.read(focusEngineProvider);
  PermissionService get _permissions => ref.read(permissionServiceProvider);

  EffectiveSettings? get _settings =>
      ref.read(effectiveSettingsProvider).valueOrNull;

  /// Starts the session: permission, camera, reference, sensors.
  Future<void> start() async {
    state = state.copyWith(
      phase: CapturePhase.cameraInitializing,
      clearFailure: true,
    );

    final permission = await _permissions.requestCamera();
    if (permission.isFailure) {
      state = state.copyWith(
        phase: CapturePhase.error,
        failure: permission.failureOrNull,
      );
      return;
    }

    final initialized = await _camera.initialize();
    if (initialized.isFailure) {
      state = state.copyWith(
        phase: CapturePhase.error,
        failure: initialized.failureOrNull,
      );
      return;
    }

    // Feed detected capabilities into the settings precedence chain, so a tool
    // the device cannot support is vetoed rather than shown (Build
    // Specification section 22).
    _publishCapabilities();

    if (state.isAfterMode && state.reference != null) {
      await _prepareReference(state.reference!);
    }

    _startLevel();
    _startFrames();

    state = state.copyWith(phase: CapturePhase.previewing);
    _recomputeReadiness();
  }

  void _publishCapabilities() {
    final capabilities = _camera.capabilities;
    ref
        .read(toolCapabilitiesProvider.notifier)
        .update(
          (current) =>
              current.copyWith(cameraAvailable: capabilities.hasCamera),
        );
  }

  /// Loads and pre-processes the reference (CV section 6, Build Spec 17).
  Future<void> _prepareReference(Photo reference) async {
    state = state.copyWith(phase: CapturePhase.referenceLoading);

    final storage = await ref.read(imageStorageProvider.future);
    final bytes = await storage.readBytes(reference.originalPath);
    if (bytes.isFailure) {
      // A missing reference does not end the session: PHOTO-style capture is
      // still possible, and the user is told (Functional REF-T003).
      state = state.copyWith(
        failure: const ReferenceUnavailable(),
        phase: CapturePhase.previewing,
      );
      return;
    }

    _referenceBytes = bytes.valueOrNull;
    _referenceWorking = WorkingImage.fromBytes(
      _referenceBytes!,
      maxDimension: ref.read(alignmentConfigProvider).workingResolution,
    );

    final prepared = await _alignment.prepareReference(
      photoId: reference.id,
      imageBytes: _referenceBytes!,
    );

    if (prepared.isOk) {
      _referenceFeatures = prepared.valueOrNull;
    } else {
      // A reference with too little detail to match is a real condition, not a
      // bug. Ghost Overlay and manual positioning still work
      // (Functional ALG-007, CV section 36).
      _referenceFeatures = null;
      _log.info('reference not alignable', {
        'photo_id': reference.id,
        'reason': prepared.failureOrNull?.technicalDetail,
      });
    }

    state = state.copyWith(phase: CapturePhase.previewing);
  }

  void _startLevel() {
    _levelSubscription?.cancel();
    _levelSubscription = ref.read(levelServiceProvider).readings.listen((
      reading,
    ) {
      if (!mounted) return;
      state = state.copyWith(level: reading);
      // Reflect a missing sensor into the capability layer so the Level tool
      // disappears rather than showing a dead readout.
      if (!reading.available) {
        ref
            .read(toolCapabilitiesProvider.notifier)
            .update(
              (current) => current.copyWith(orientationSensorAvailable: false),
            );
      }
    });
  }

  void _startFrames() {
    _frameSubscription?.cancel();
    _frameSubscription = _camera.frames.listen(_onFrame);
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (!mounted || _analysing) return;
    final settings = _settings;
    if (settings == null) return;

    final needsAnalysis =
        settings.alignmentEnabled ||
        settings.lightingEnabled ||
        settings.focusEnabled;
    if (!needsAnalysis) return;

    _analysing = true;
    try {
      final working = WorkingImage(
        width: frame.width,
        height: frame.height,
        pixels: frame.luminance,
      );

      final alignment = settings.alignmentEnabled && _referenceFeatures != null
          ? await _alignment.analyzeFrame(
              frame: working,
              reference: _referenceFeatures!,
            )
          : null;

      final lighting = !settings.lightingEnabled
          ? null
          : (_referenceWorking != null
                ? _lighting.compare(
                    reference: _referenceWorking!,
                    frame: working,
                  )
                : _lighting.assessAbsolute(working));

      final focus = settings.focusEnabled ? _focus.assess(working) : null;

      if (!mounted) return;

      state = state.copyWith(
        alignment: alignment,
        lighting: lighting,
        focus: focus,
        guidance: alignment == null
            ? null
            : _guidance.primaryInstruction(
                alignment,
                referenceOrientation:
                    state.reference?.captureRecipe?.orientation,
                currentOrientation: _camera.currentOrientation,
              ),
        clearGuidance: alignment == null,
        clearAlignment: alignment == null && settings.alignmentEnabled,
      );
      _recomputeReadiness();
    } finally {
      _analysing = false;
    }
  }

  void _recomputeReadiness() {
    if (!mounted) return;
    state = state.copyWith(
      readiness: CaptureReadiness.evaluate(
        alignment: state.alignment,
        lighting: state.lighting,
        focus: state.focus,
        referenceOrientation: state.reference?.captureRecipe?.orientation,
        // Without this the orientation comparison short-circuits on a null and
        // the check never runs at all.
        currentOrientation: _camera.currentOrientation,
        cameraAvailable: _camera.capabilities.hasCamera,
      ),
    );
  }

  // --- Reference overlay ----------------------------------------------------

  void adjustReference(ReferenceTransform transform) =>
      state = state.copyWith(referenceTransform: transform);

  void setReferenceLock({required bool locked}) => state = state.copyWith(
    referenceTransform: state.referenceTransform.withLock(locked: locked),
  );

  void resetReference() => state = state.copyWith(
    referenceTransform: state.referenceTransform.reset(),
  );

  // --- Session overrides ----------------------------------------------------

  /// Turns a tool on or off **for this capture only**.
  ///
  /// Writes to the session layer, never to the database, which is what makes
  /// the override temporary (Functional SET-003, Build Specification 2.7).
  void overrideTool(WiseTool tool, {required bool enabled}) {
    ref
        .read(sessionOverridesProvider.notifier)
        .update((current) => current.setting(tool, value: enabled));
  }

  void clearOverride(WiseTool tool) {
    ref
        .read(sessionOverridesProvider.notifier)
        .update((current) => current.clearing(tool));
  }

  // --- Metadata -------------------------------------------------------------

  void setMetadata({
    BodyPart? bodyPart,
    Laterality? laterality,
    String? caseId,
    String? protocolId,
  }) => state = state.copyWith(
    bodyPart: bodyPart,
    laterality: laterality,
    caseId: caseId,
    protocolId: protocolId,
  );

  // --- Capture --------------------------------------------------------------

  /// Takes the photograph and stores it.
  ///
  /// Order matters and follows Data Model section 41: write the original,
  /// commit the record, then generate derived assets. A failure after the
  /// original is written leaves the photograph usable
  /// (Build Specification section 105).
  Future<Result<Photo>> capture() async {
    if (!mounted) {
      return const Result.failed(CameraUnavailable());
    }
    state = state.copyWith(phase: CapturePhase.capturing, clearFailure: true);

    final captured = await _camera.capture();
    if (captured.isFailure) {
      state = state.copyWith(
        phase: CapturePhase.previewing,
        failure: captured.failureOrNull,
      );
      return Result.failed(captured.failureOrNull!);
    }

    state = state.copyWith(phase: CapturePhase.processing);

    final repository = await ref.read(photoRepositoryProvider.future);
    final user = await ref.read(currentUserProvider.future);

    final created = await repository.createPhoto(
      bytes: captured.valueOrNull!.bytes,
      type: state.mode,
      source: PhotoSource.camera,
      userId: user.id,
      caseId: state.caseId,
      bodyPart: state.bodyPart,
      laterality: state.laterality,
      referencePhotoId: state.reference?.id,
      protocolId: state.protocolId,
      captureRecipe: _buildRecipe(),
    );

    if (created.isFailure) {
      state = state.copyWith(
        phase: CapturePhase.previewing,
        failure: created.failureOrNull,
      );
      return created;
    }

    final photo = created.valueOrNull!;

    // Derived work. Each step is allowed to fail without costing the original.
    await _generateThumbnail(repository, photo, captured.valueOrNull!.bytes);
    await _recordQualityChecks(photo);

    final finalised = await repository.getPhoto(photo.id) ?? photo;
    state = state.copyWith(
      phase: CapturePhase.reviewing,
      capturedPhoto: finalised,
    );
    return Result.ok(finalised);
  }

  Future<void> _generateThumbnail(
    PhotoRepository repository,
    Photo photo,
    Uint8List bytes,
  ) async {
    final generated = ref.read(thumbnailGeneratorProvider).generate(bytes);
    if (generated.isFailure) {
      // A thumbnail is regenerable; the photograph stays active without one.
      _log.warning('thumbnail failed', {'photo_id': photo.id});
      await repository.markProcessed(photo.id);
      return;
    }

    final storage = await ref.read(imageStorageProvider.future);
    final path = storage.paths.thumbnailFile(photo.id);
    final stored = await storage.storeDerived(
      assetId: photo.id,
      directory: storage.paths.thumbnails,
      bytes: generated.valueOrNull!,
    );

    await repository.markProcessed(
      photo.id,
      thumbnailPath: stored.isOk ? stored.valueOrNull!.path : path,
    );
  }

  /// Persists the quality state at capture, including when the clinician chose
  /// to capture anyway (CV section 39).
  Future<void> _recordQualityChecks(Photo photo) async {
    final clinical = await ref.read(clinicalRepositoryProvider.future);
    final checks = <QualityCheck>[];
    final now = DateTime.now();

    final focus = state.focus;
    if (focus != null && focus.status != FocusStatus.unavailable) {
      checks.add(
        QualityCheck(
          id: clinical.newId(),
          photoId: photo.id,
          checkType: QualityCheckType.focus,
          score: focus.score,
          status: focus.isWarning ? QualityStatus.warning : QualityStatus.good,
          details: focus.toDetails(),
          engineVersion: _alignment.engineVersion,
          createdAt: now,
        ),
      );
    }

    final lighting = state.lighting;
    if (lighting != null && lighting.status != LightingStatus.unavailable) {
      checks.add(
        QualityCheck(
          id: clinical.newId(),
          photoId: photo.id,
          checkType: QualityCheckType.lighting,
          score: lighting.histogramSimilarity,
          status: lighting.isWarning
              ? QualityStatus.warning
              : QualityStatus.good,
          details: lighting.toDetails(),
          engineVersion: _alignment.engineVersion,
          createdAt: now,
        ),
      );
    }

    final alignment = state.alignment;
    if (alignment != null) {
      checks.add(
        QualityCheck(
          id: clinical.newId(),
          photoId: photo.id,
          checkType: QualityCheckType.alignment,
          score: alignment.confidence,
          status: switch (alignment.status) {
            AlignmentStatus.good => QualityStatus.good,
            AlignmentStatus.fair => QualityStatus.warning,
            AlignmentStatus.poor => QualityStatus.warning,
            AlignmentStatus.unavailable => QualityStatus.unavailable,
          },
          details: alignment.metrics.toMap(),
          engineVersion: alignment.engineVersion,
          createdAt: now,
        ),
      );
    }

    if (checks.isNotEmpty) await clinical.saveQualityChecks(checks);
  }

  /// Records what the photograph was taken with, so it can be reproduced
  /// (Data Model section 11, Build Specification section 13).
  CaptureRecipe _buildRecipe() {
    final settings = _settings;
    return CaptureRecipe(
      cameraPosition: _camera.activeCamera?.position,
      lensIdentifier: _camera.activeCamera?.id,
      zoom: _camera.capabilities.supportsZoom ? _camera.currentZoom : null,
      flashMode: _camera.capabilities.supportsFlash
          ? _camera.currentFlashMode
          : null,
      // The orientation actually in force, not an assumption. A BEFORE taken
      // in landscape must record landscape, or the AFTER guidance will compare
      // against the wrong value (Functional CAM-005).
      orientation: _camera.currentOrientation,
      gridType: settings?.gridEnabled ?? false ? settings?.gridType : null,
      levelEnabled: settings?.levelEnabled ?? false,
      overlayEnabled: settings?.overlayEnabled ?? false,
      alignmentEnabled: settings?.alignmentEnabled ?? false,
      lightingCheckEnabled: settings?.lightingEnabled ?? false,
      focusCheckEnabled: settings?.focusEnabled ?? false,
      measurementEnabled: settings?.measurementEnabled ?? false,
      annotationEnabled: settings?.annotationEnabled ?? false,
      deviceTiltDegrees: state.level.available ? state.level.rollDegrees : null,
      protocolId: state.protocolId,
    );
  }

  /// Discards the reviewed photograph and returns to the preview.
  ///
  /// Retake soft-deletes rather than hard-deleting, so a mistaken retake is
  /// recoverable (Data Model section 36).
  Future<void> retake() async {
    final photo = state.capturedPhoto;
    if (photo != null) {
      final repository = await ref.read(photoRepositoryProvider.future);
      await repository.deletePhoto(photo.id, force: true);
    }
    state = state.copyWith(
      phase: CapturePhase.previewing,
      clearCapturedPhoto: true,
      clearFailure: true,
    );
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _levelSubscription?.cancel();
    // Session overrides never outlive the session (Functional SET-003).
    ref.read(sessionOverridesProvider.notifier).state = ToolOverrides.none;
    _alignment.reset();
    super.dispose();
  }
}

/// One controller per capture session.
final captureControllerProvider = StateNotifierProvider.autoDispose
    .family<
      CaptureController,
      CaptureState,
      ({PhotoType mode, Photo? reference})
    >(
      (ref, args) => CaptureController(
        ref: ref,
        mode: args.mode,
        reference: args.reference,
      ),
    );
