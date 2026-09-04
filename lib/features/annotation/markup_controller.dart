import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/measurement/measurement_calculator.dart';
import '../../models/annotation.dart';
import '../../models/calibration.dart';
import '../../models/enums.dart';
import '../../models/geometry.dart';
import '../../models/measurement.dart';
import '../../models/photo.dart';

/// What the markup editor is currently placing.
sealed class MarkupTool {
  const MarkupTool();
}

class MeasurementTool extends MarkupTool {
  const MeasurementTool(this.type);
  final MeasurementType type;
}

class AnnotationTool extends MarkupTool {
  const AnnotationTool(this.type);
  final AnnotationType type;
}

class SelectTool extends MarkupTool {
  const SelectTool();
}

/// Editor state.
class MarkupState {
  const MarkupState({
    required this.photo,
    this.tool = const SelectTool(),
    this.calibration,
    this.measurements = const <Measurement>[],
    this.annotations = const <Annotation>[],
    this.pendingPoints = const <ImagePoint>[],
    this.selectedId,
    this.saving = false,
  });

  final Photo photo;
  final MarkupTool tool;

  /// Null means physical units are unavailable. Everything downstream honours
  /// that (Functional CAL-001).
  final Calibration? calibration;

  final List<Measurement> measurements;
  final List<Annotation> annotations;

  /// Points placed for the object being drawn.
  final List<ImagePoint> pendingPoints;

  final String? selectedId;
  final bool saving;

  bool get hasCalibration => calibration?.isUsable ?? false;

  /// Whether the pending points are enough to commit the current tool.
  bool get canCommit => switch (tool) {
    MeasurementTool(:final type) =>
      pendingPoints.length >= MeasurementCalculator.minimumPoints(type),
    AnnotationTool(:final type) => pendingPoints.length >= _minimumFor(type),
    SelectTool() => false,
  };

  static int _minimumFor(AnnotationType type) => switch (type) {
    AnnotationType.point || AnnotationType.text => 1,
    AnnotationType.pen => 2,
    _ => 2,
  };

  MarkupState copyWith({
    MarkupTool? tool,
    Calibration? calibration,
    List<Measurement>? measurements,
    List<Annotation>? annotations,
    List<ImagePoint>? pendingPoints,
    String? selectedId,
    bool? saving,
    bool clearSelection = false,
  }) => MarkupState(
    photo: photo,
    tool: tool ?? this.tool,
    calibration: calibration ?? this.calibration,
    measurements: measurements ?? this.measurements,
    annotations: annotations ?? this.annotations,
    pendingPoints: pendingPoints ?? this.pendingPoints,
    selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
    saving: saving ?? this.saving,
  );
}

/// Places, edits and deletes measurements and annotations
/// (Functional MES-001..009, ANN-001..004).
///
/// Everything it writes is a separate record referencing the photograph. The
/// original image is never opened for writing from here; the editor has no code
/// path that could (PRD section 33, Privacy PRI-004).
class MarkupController extends StateNotifier<MarkupState> {
  MarkupController({required this.ref, required this.photo})
    : super(MarkupState(photo: photo));

  final Ref ref;

  /// Held outside the state so it stays readable during teardown, when the
  /// state itself is no longer safe to touch.
  final Photo photo;

  /// Loads existing markup and any calibration.
  Future<void> load() async {
    final photoId = photo.id;
    final repository = await ref.read(clinicalRepositoryProvider.future);

    // Read everything first, then write once. The editor is opened from a
    // list, and a clinician who taps a photograph and immediately goes back
    // disposes this controller while these reads are still in flight —
    // touching `state` after that throws. Awaiting inside the copyWith
    // argument list would put the writes back on the wrong side of the check.
    final calibration = await repository.getCalibrationFor(photoId);
    final measurements = await repository.getMeasurements(photoId);
    final annotations = await repository.getAnnotations(photoId);

    if (!mounted) return;
    state = state.copyWith(
      calibration: calibration,
      measurements: measurements,
      annotations: annotations,
    );
  }

  void selectTool(MarkupTool tool) => state = state.copyWith(
    tool: tool,
    pendingPoints: const <ImagePoint>[],
    clearSelection: true,
  );

  /// Adds a point in original-image coordinates.
  void addPoint(ImagePoint point) {
    if (state.tool is SelectTool) return;
    state = state.copyWith(pendingPoints: [...state.pendingPoints, point]);
  }

  void clearPending() =>
      state = state.copyWith(pendingPoints: const <ImagePoint>[]);

  /// Commits the pending points as a measurement or annotation.
  Future<void> commit() async {
    if (!state.canCommit) return;
    state = state.copyWith(saving: true);

    try {
      final repository = await ref.read(clinicalRepositoryProvider.future);
      if (!mounted) return;

      switch (state.tool) {
        case MeasurementTool(:final type):
          final closed =
              type == MeasurementType.area || type == MeasurementType.perimeter;

          final measurement = MeasurementCalculator.build(
            id: repository.newId(),
            photoId: state.photo.id,
            type: type,
            geometry: Geometry(state.pendingPoints, closed: closed),
            // Null when uncalibrated, which produces a pixel-only measurement
            // rather than an invented physical one.
            calibration: state.calibration,
          );

          final saved = await repository.saveMeasurement(measurement);
          if (saved.isOk && mounted) {
            state = state.copyWith(
              measurements: [...state.measurements, measurement],
            );
          }

        case AnnotationTool(:final type):
          final now = DateTime.now();
          final annotation = Annotation(
            id: repository.newId(),
            photoId: state.photo.id,
            type: type,
            geometry: Geometry(
              state.pendingPoints,
              closed: type == AnnotationType.rectangle,
            ),
            zIndex: state.annotations.length,
            createdAt: now,
            updatedAt: now,
          );

          final saved = await repository.saveAnnotation(annotation);
          if (saved.isOk && mounted) {
            state = state.copyWith(
              annotations: [...state.annotations, annotation],
            );
          }

        case SelectTool():
          break;
      }
    } finally {
      if (mounted) {
        state = state.copyWith(
          pendingPoints: const <ImagePoint>[],
          saving: false,
        );
      }
    }
  }

  /// Hides an object without deleting it (Functional MES-008, ANN-003).
  Future<void> toggleVisibility(String id) async {
    final repository = await ref.read(clinicalRepositoryProvider.future);
    if (!mounted) return;

    final measurementIndex = state.measurements.indexWhere((m) => m.id == id);
    if (measurementIndex >= 0) {
      final updated = state.measurements[measurementIndex].copyWith(
        visible: !state.measurements[measurementIndex].visible,
        updatedAt: DateTime.now(),
      );
      await repository.updateMeasurement(updated);
      if (!mounted) return;
      final list = [...state.measurements]..[measurementIndex] = updated;
      state = state.copyWith(measurements: list);
      return;
    }

    final annotationIndex = state.annotations.indexWhere((a) => a.id == id);
    if (annotationIndex >= 0) {
      final updated = state.annotations[annotationIndex].copyWith(
        visible: !state.annotations[annotationIndex].visible,
        updatedAt: DateTime.now(),
      );
      await repository.updateAnnotation(updated);
      if (!mounted) return;
      final list = [...state.annotations]..[annotationIndex] = updated;
      state = state.copyWith(annotations: list);
    }
  }

  Future<void> delete(String id) async {
    final repository = await ref.read(clinicalRepositoryProvider.future);
    if (!mounted) return;

    if (state.measurements.any((m) => m.id == id)) {
      await repository.deleteMeasurement(id);
      if (!mounted) return;
      state = state.copyWith(
        measurements: state.measurements.where((m) => m.id != id).toList(),
        clearSelection: true,
      );
      return;
    }

    if (state.annotations.any((a) => a.id == id)) {
      await repository.deleteAnnotation(id);
      if (!mounted) return;
      state = state.copyWith(
        annotations: state.annotations.where((a) => a.id != id).toList(),
        clearSelection: true,
      );
    }
  }

  /// Recalculates every measurement against a new calibration.
  ///
  /// The reason geometry is stored separately from the value: a calibration
  /// added or corrected after the fact converts existing pixel measurements
  /// without the clinician replacing a single point (Data Model section 21).
  Future<void> applyCalibration(Calibration calibration) async {
    final repository = await ref.read(clinicalRepositoryProvider.future);
    if (!mounted) return;
    final updated = <Measurement>[];

    for (final measurement in state.measurements) {
      final recalculated = MeasurementCalculator.recalculate(
        measurement,
        calibration: calibration,
      );
      await repository.updateMeasurement(recalculated);
      updated.add(recalculated);
    }

    if (!mounted) return;
    state = state.copyWith(calibration: calibration, measurements: updated);
  }
}

final markupControllerProvider = StateNotifierProvider.autoDispose
    .family<MarkupController, MarkupState, Photo>(
      (ref, photo) => MarkupController(ref: ref, photo: photo),
    );
