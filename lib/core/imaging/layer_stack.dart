import '../../models/annotation.dart';
import '../../models/enums.dart';
import '../../models/measurement.dart';

/// The layers that can sit over an original (Data Model section 24, Functional
/// ANN-010, Build Specification section 40).
///
/// Order is the compositing order, bottom first.
enum PhotoLayer {
  original('Original'),
  reference('Reference'),
  measurements('Measurements'),
  annotations('Annotations'),
  grid('Grid'),
  labels('Labels'),
  footer('Footer');

  const PhotoLayer(this.label);
  final String label;
}

/// A non-destructive composition over one photograph.
///
/// The whole point of this type is that it holds *no pixels*. It names an
/// original by path and describes what should be drawn over it. Rendering
/// always produces a new file; the original is opened read-only and never
/// written back (PRD section 33, Data Model section 38, Privacy PRI-004,
/// Build Specification section 2.1).
class LayerStack {
  const LayerStack({
    required this.originalPath,
    required this.widthPx,
    required this.heightPx,
    this.measurements = const <Measurement>[],
    this.annotations = const <Annotation>[],
    this.gridType,
    this.footerLines = const <String>[],
    this.hiddenLayers = const <PhotoLayer>{},
  });

  /// Read-only source. Never a write target.
  final String originalPath;

  final int widthPx;
  final int heightPx;
  final List<Measurement> measurements;
  final List<Annotation> annotations;

  /// Null means no grid. A grid is only ever drawn into a derived asset,
  /// never into the original (Functional GRD-003,
  /// SPECIFICATION_CONFLICTS C-002).
  final GridType? gridType;

  final List<String> footerLines;

  /// Layers the user has switched off (Functional ANN-010).
  final Set<PhotoLayer> hiddenLayers;

  bool isVisible(PhotoLayer layer) => !hiddenLayers.contains(layer);

  LayerStack withLayerVisible(PhotoLayer layer, {required bool visible}) {
    final hidden = {...hiddenLayers};
    if (visible) {
      hidden.remove(layer);
    } else {
      hidden.add(layer);
    }
    return copyWith(hiddenLayers: hidden);
  }

  /// Measurements that should actually be drawn.
  Iterable<Measurement> get visibleMeasurements =>
      isVisible(PhotoLayer.measurements)
      ? measurements.where((m) => m.visible && !m.isDeleted)
      : const <Measurement>[];

  /// Annotations that should actually be drawn, in z-order.
  Iterable<Annotation> get visibleAnnotations {
    if (!isVisible(PhotoLayer.annotations)) return const <Annotation>[];
    final list = annotations.where((a) => a.visible && !a.isDeleted).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return list;
  }

  bool get hasVisibleGrid => gridType != null && isVisible(PhotoLayer.grid);

  bool get hasVisibleFooter =>
      footerLines.isNotEmpty && isVisible(PhotoLayer.footer);

  /// True when nothing would be drawn, so an export can simply copy the
  /// original rather than re-encoding it and losing quality.
  bool get isPassThrough =>
      visibleMeasurements.isEmpty &&
      visibleAnnotations.isEmpty &&
      !hasVisibleGrid &&
      !hasVisibleFooter;

  LayerStack copyWith({
    List<Measurement>? measurements,
    List<Annotation>? annotations,
    GridType? gridType,
    List<String>? footerLines,
    Set<PhotoLayer>? hiddenLayers,
    bool clearGrid = false,
  }) => LayerStack(
    originalPath: originalPath,
    widthPx: widthPx,
    heightPx: heightPx,
    measurements: measurements ?? this.measurements,
    annotations: annotations ?? this.annotations,
    gridType: clearGrid ? null : (gridType ?? this.gridType),
    footerLines: footerLines ?? this.footerLines,
    hiddenLayers: hiddenLayers ?? this.hiddenLayers,
  );
}
