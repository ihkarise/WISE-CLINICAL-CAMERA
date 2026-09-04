import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/calibration.dart';
import '../../models/enums.dart';
import '../../models/geometry.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/clinical_image.dart';
import 'markup_controller.dart';
import 'markup_painter.dart';

/// Placing measurements and annotations (UX/UI sections 28-33).
///
/// Everything drawn here is a separate layer over the photograph. The original
/// is displayed read-only and is never written to (PRD section 17,
/// Privacy PRI-004).
class MarkupScreen extends ConsumerStatefulWidget {
  const MarkupScreen({required this.photo, super.key});

  final Photo photo;

  @override
  ConsumerState<MarkupScreen> createState() => _MarkupScreenState();
}

class _MarkupScreenState extends ConsumerState<MarkupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markupControllerProvider(widget.photo).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = markupControllerProvider(widget.photo);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measure and mark'),
        actions: [
          if (state.pendingPoints.isNotEmpty)
            TextButton(
              onPressed: controller.clearPending,
              child: const Text('Clear'),
            ),
          if (state.canCommit)
            TextButton(onPressed: controller.commit, child: const Text('Done')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fitted = _fittedRect(constraints.biggest);
                return GestureDetector(
                  onTapDown: (details) {
                    if (!fitted.contains(details.localPosition)) return;
                    controller.addPoint(
                      _toImage(details.localPosition, fitted),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClinicalImage.file(widget.photo.originalPath),
                      CustomPaint(
                        painter: MarkupPainter(
                          measurements: state.measurements,
                          annotations: state.annotations,
                          pendingPoints: state.pendingPoints,
                          imageRect: fitted,
                          imageWidth: widget.photo.widthPx,
                          imageHeight: widget.photo.heightPx,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (!state.hasCalibration) _CalibrationPrompt(photo: widget.photo),

          _ToolBar(state: state, controller: controller),
          _MarkupList(state: state, controller: controller),
        ],
      ),
    );
  }

  /// Where `BoxFit.contain` places the image inside the viewport.
  Rect _fittedRect(Size viewport) {
    final imageAspect = widget.photo.aspectRatio;
    final viewportAspect = viewport.width / viewport.height;

    if (imageAspect > viewportAspect) {
      final height = viewport.width / imageAspect;
      return Rect.fromLTWH(
        0,
        (viewport.height - height) / 2,
        viewport.width,
        height,
      );
    }
    final width = viewport.height * imageAspect;
    return Rect.fromLTWH(
      (viewport.width - width) / 2,
      0,
      width,
      viewport.height,
    );
  }

  /// Screen coordinates to original-image pixels, so geometry survives
  /// rotation and re-display at a different size (Data Model section 21).
  ImagePoint _toImage(Offset local, Rect fitted) => ImagePoint(
    (local.dx - fitted.left) / fitted.width * widget.photo.widthPx,
    (local.dy - fitted.top) / fitted.height * widget.photo.heightPx,
  );
}

/// Shown when no calibration exists (UX/UI section 29, Functional CAL-001).
class _CalibrationPrompt extends ConsumerWidget {
  const _CalibrationPrompt({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: WiseTokens.softBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: WiseTokens.gutter,
        vertical: WiseTokens.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              WiseStrings.calibrationRequired,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () async {
              final calibration = await Navigator.of(
                context,
              ).pushNamed(WiseRoutes.calibration, arguments: photo);

              if (calibration is Calibration) {
                // Existing pixel measurements convert immediately.
                await ref
                    .read(markupControllerProvider(photo).notifier)
                    .applyCalibration(calibration);
              }
            },
            child: const Text('Set scale'),
          ),
        ],
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.state, required this.controller});

  final MarkupState state;
  final MarkupController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: WiseTokens.gutter,
        vertical: WiseTokens.space8,
      ),
      child: Row(
        children: [
          // Measurement types (UX/UI section 28). ANGLE is excluded: Build
          // Specification section 37 lists it as future work.
          for (final type in const [
            MeasurementType.length,
            MeasurementType.width,
            MeasurementType.diameter,
            MeasurementType.perimeter,
            MeasurementType.area,
          ])
            _ToolChip(
              label: type.label,
              selected:
                  state.tool is MeasurementTool &&
                  (state.tool as MeasurementTool).type == type,
              onTap: () => controller.selectTool(MeasurementTool(type)),
            ),

          const SizedBox(width: WiseTokens.space16),

          // Annotation tools (UX/UI section 33, Functional ANN-002).
          for (final type in AnnotationType.values)
            if (type != AnnotationType.measurement)
              _ToolChip(
                label: type.label,
                selected:
                    state.tool is AnnotationTool &&
                    (state.tool as AnnotationTool).type == type,
                onTap: () => controller.selectTool(AnnotationTool(type)),
              ),
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: WiseTokens.space8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

/// The objects on this photograph, each hideable and deletable
/// (Functional MES-008, ANN-003).
class _MarkupList extends StatelessWidget {
  const _MarkupList({required this.state, required this.controller});

  final MarkupState state;
  final MarkupController controller;

  @override
  Widget build(BuildContext context) {
    if (state.measurements.isEmpty && state.annotations.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 148,
      child: ListView(
        children: [
          for (final measurement in state.measurements)
            ListTile(
              dense: true,
              leading: const Icon(Icons.straighten, size: 18),
              title: Text(measurement.type.label),
              subtitle: Text(measurement.displayValue),
              trailing: _RowActions(
                visible: measurement.visible,
                onToggle: () => controller.toggleVisibility(measurement.id),
                onDelete: () => controller.delete(measurement.id),
              ),
            ),
          for (final annotation in state.annotations)
            ListTile(
              dense: true,
              leading: const Icon(Icons.edit_outlined, size: 18),
              title: Text(annotation.type.label),
              trailing: _RowActions(
                visible: annotation.visible,
                onToggle: () => controller.toggleVisibility(annotation.id),
                onDelete: () => controller.delete(annotation.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.visible,
    required this.onToggle,
    required this.onDelete,
  });

  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
        tooltip: visible ? 'Hide' : 'Show',
        onPressed: onToggle,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: onDelete,
      ),
    ],
  );
}
