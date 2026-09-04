import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../models/measurement.dart';
import '../../shared/widgets/clinical_image.dart';
import 'difference_view.dart';
import 'measurement_change_table.dart';

/// Before/After comparison (UX/UI sections 34-40, Functional CMP-001..006).
///
/// All five modes. The selected mode persists as the user's preference
/// (UX/UI section 34).
class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({required this.arguments, super.key});

  final ComparisonArguments arguments;

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  ComparisonMode? _mode;
  double _sliderPosition = 0.5;
  double _overlayOpacity = 0.5;
  bool _blinkShowingAfter = false;
  Timer? _blinkTimer;

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  ComparisonMode get _effectiveMode =>
      _mode ??
      ref.read(preferencesProvider).valueOrNull?.comparisonMode ??
      ComparisonMode.sideBySide;

  @override
  Widget build(BuildContext context) {
    final mode = _effectiveMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Before / After')),
      body: Column(
        children: [
          Expanded(child: _buildComparison(mode)),

          if (mode == ComparisonMode.slider)
            Slider(
              value: _sliderPosition,
              onChanged: (value) => setState(() => _sliderPosition = value),
            ),
          if (mode == ComparisonMode.overlay)
            Slider(
              value: _overlayOpacity,
              onChanged: (value) => setState(() => _overlayOpacity = value),
            ),

          _ModeSelector(selected: mode, onSelected: _selectMode),

          _ChangeSummary(
            beforePhotoId: widget.arguments.before.id,
            afterPhotoId: widget.arguments.after.id,
          ),
        ],
      ),
    );
  }

  void _selectMode(ComparisonMode mode) {
    _blinkTimer?.cancel();
    setState(() => _mode = mode);

    if (mode == ComparisonMode.blink) {
      // Respect reduced motion: an automatic flicker is exactly what that
      // setting exists to suppress (UX/UI sections 38, 55).
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduceMotion) {
        _blinkTimer = Timer.periodic(
          WiseTokens.blinkInterval,
          (_) => setState(() => _blinkShowingAfter = !_blinkShowingAfter),
        );
      }
    }

    // Persist as the preferred mode (UX/UI section 34).
    final preferences = ref.read(preferencesProvider).valueOrNull;
    if (preferences != null) {
      unawaited(
        ref.read(savePreferencesProvider)(
          preferences.copyWith(comparisonMode: mode),
        ),
      );
    }
  }

  Widget _buildComparison(ComparisonMode mode) {
    final beforePath = widget.arguments.before.originalPath;
    final afterPath = widget.arguments.after.originalPath;

    return switch (mode) {
      ComparisonMode.sideBySide => Row(
        children: [
          Expanded(
            child: _LabelledImage(path: beforePath, label: 'BEFORE'),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _LabelledImage(path: afterPath, label: 'AFTER'),
          ),
        ],
      ),
      ComparisonMode.slider => _SliderComparison(
        beforePath: beforePath,
        afterPath: afterPath,
        position: _sliderPosition,
      ),
      ComparisonMode.overlay => Stack(
        fit: StackFit.expand,
        children: [
          _Photo(path: afterPath),
          Opacity(
            opacity: _overlayOpacity,
            child: _Photo(path: beforePath),
          ),
        ],
      ),
      ComparisonMode.blink => _LabelledImage(
        path: _blinkShowingAfter ? afterPath : beforePath,
        label: _blinkShowingAfter ? 'AFTER' : 'BEFORE',
      ),
      ComparisonMode.difference => DifferenceView(
        before: widget.arguments.before,
        after: widget.arguments.after,
      ),
    };
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelected});

  final ComparisonMode selected;
  final ValueChanged<ComparisonMode> onSelected;

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
          for (final mode in ComparisonMode.values)
            Padding(
              padding: const EdgeInsets.only(right: WiseTokens.space8),
              child: ChoiceChip(
                label: Text(mode.label),
                selected: selected == mode,
                onSelected: (_) => onSelected(mode),
              ),
            ),
        ],
      ),
    );
  }
}

/// Measurement change, when both sides are calibrated (Functional section 19).
class _ChangeSummary extends ConsumerWidget {
  const _ChangeSummary({
    required this.beforePhotoId,
    required this.afterPhotoId,
  });

  final String beforePhotoId;
  final String afterPhotoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(
      comparisonMeasurementsProvider((
        before: beforePhotoId,
        after: afterPhotoId,
      )),
    );

    return measurements.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (pair) =>
          MeasurementChangeTable(before: pair.before, after: pair.after),
    );
  }
}

final comparisonMeasurementsProvider =
    FutureProvider.family<
      ({List<Measurement> before, List<Measurement> after}),
      ({String before, String after})
    >((ref, ids) async {
      final repository = await ref.watch(clinicalRepositoryProvider.future);
      return (
        before: await repository.getMeasurements(ids.before),
        after: await repository.getMeasurements(ids.after),
      );
    });

class _LabelledImage extends StatelessWidget {
  const _LabelledImage({required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _Photo(path: path),
      Positioned(
        left: WiseTokens.space8,
        top: WiseTokens.space8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: WiseTokens.cameraChrome,
            borderRadius: BorderRadius.circular(WiseTokens.pillRadius),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: WiseTokens.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}

class _SliderComparison extends StatelessWidget {
  const _SliderComparison({
    required this.beforePath,
    required this.afterPath,
    required this.position,
  });

  final String beforePath;
  final String afterPath;
  final double position;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        _Photo(path: afterPath),
        ClipRect(
          clipper: _LeftClipper(position),
          child: _Photo(path: beforePath),
        ),
        Positioned(
          left: constraints.maxWidth * position - 1,
          top: 0,
          bottom: 0,
          child: Container(width: 2, color: WiseTokens.white),
        ),
      ],
    ),
  );
}

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClipper oldClipper) => oldClipper.fraction != fraction;
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => ClinicalImage.file(path);
}
