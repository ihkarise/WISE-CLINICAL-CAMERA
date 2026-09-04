import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../models/geometry.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/clinical_image.dart';

/// Establishing the image scale (UX/UI sections 29-30, Functional
/// CAL-002..006, Build Specification sections 35-36).
///
/// The workflow the specification prescribes: draw a line across a known
/// distance, enter the value, choose the unit, confirm.
///
/// Until this succeeds, measurements exist only in pixels. That is the whole
/// point of the screen (Functional CAL-001).
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({required this.photo, super.key});

  final Photo photo;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  ImagePoint? _start;
  ImagePoint? _end;
  CalibrationMethod _method = CalibrationMethod.manual;
  LengthUnit _unit = LengthUnit.centimetre;
  final TextEditingController _valueController = TextEditingController(
    text: '5',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double? get _pixelDistance =>
      _start == null || _end == null ? null : _start!.distanceTo(_end!);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set scale')),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapDown: (details) =>
                    _addPoint(details.localPosition, constraints.biggest),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClinicalImage.file(widget.photo.originalPath),
                    if (_start != null)
                      CustomPaint(
                        painter: _CalibrationLinePainter(
                          start: _toScreen(_start!, constraints.biggest),
                          end: _end == null
                              ? null
                              : _toScreen(_end!, constraints.biggest),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(WiseTokens.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _start == null
                      ? 'Tap the start of a known distance.'
                      : _end == null
                      ? 'Tap the end of that distance.'
                      : 'Enter how long that distance really is.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: WiseTokens.space16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Known distance',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: WiseTokens.space8),
                    DropdownButton<LengthUnit>(
                      value: _unit,
                      onChanged: (unit) =>
                          setState(() => _unit = unit ?? _unit),
                      items: [
                        for (final unit in LengthUnit.values)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(unit.symbol),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: WiseTokens.space8),
                SegmentedButton<CalibrationMethod>(
                  segments: [
                    for (final method in CalibrationMethod.values)
                      ButtonSegment(value: method, label: Text(method.label)),
                  ],
                  selected: {_method},
                  onSelectionChanged: (selection) =>
                      setState(() => _method = selection.first),
                ),

                if (_error != null) ...[
                  const SizedBox(height: WiseTokens.space8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: WiseTokens.warningRed,
                    ),
                  ),
                ],

                const SizedBox(height: WiseTokens.space8),
                Text(
                  WiseStrings.perspectiveWarning,
                  style: theme.textTheme.labelSmall,
                ),

                const SizedBox(height: WiseTokens.space16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _start = null;
                          _end = null;
                          _error = null;
                        }),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: WiseTokens.space8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _pixelDistance == null || _saving
                            ? null
                            : _save,
                        child: const Text('Calibrate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Converts a tap into original-image pixel coordinates.
  ///
  /// Geometry is stored against the original, not the screen, so a calibration
  /// survives rotation and re-display at a different size
  /// (Data Model section 21).
  void _addPoint(Offset local, Size viewport) {
    final fitted = _fittedRect(viewport);
    if (!fitted.contains(local)) return;

    final point = ImagePoint(
      (local.dx - fitted.left) / fitted.width * widget.photo.widthPx,
      (local.dy - fitted.top) / fitted.height * widget.photo.heightPx,
    );

    setState(() {
      if (_start == null || _end != null) {
        _start = point;
        _end = null;
      } else {
        _end = point;
      }
      _error = null;
    });
  }

  Offset _toScreen(ImagePoint point, Size viewport) {
    final fitted = _fittedRect(viewport);
    return Offset(
      fitted.left + point.x / widget.photo.widthPx * fitted.width,
      fitted.top + point.y / widget.photo.heightPx * fitted.height,
    );
  }

  /// Where `BoxFit.contain` actually places the image inside the viewport.
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

  Future<void> _save() async {
    final value = double.tryParse(_valueController.text.trim());
    if (value == null) {
      setState(() => _error = 'Enter a number greater than zero.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = await ref.read(clinicalRepositoryProvider.future);
      final result = await repository.saveCalibration(
        photoId: widget.photo.id,
        method: _method,
        knownValue: value,
        unit: _unit,
        pixelDistance: _pixelDistance!,
        referenceGeometry: Geometry([_start!, _end!]),
      );

      if (!mounted) return;
      if (result.isFailure) {
        setState(() => _error = result.failureOrNull!.userMessage);
        return;
      }
      Navigator.of(context).pop(result.valueOrNull);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CalibrationLinePainter extends CustomPainter {
  const _CalibrationLinePainter({required this.start, this.end});

  final Offset start;
  final Offset? end;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WiseTokens.wiseRed
      ..strokeWidth = 3;

    canvas.drawCircle(start, 6, paint);
    if (end != null) {
      canvas
        ..drawLine(start, end!, paint)
        ..drawCircle(end!, 6, paint);
    }
  }

  @override
  bool shouldRepaint(_CalibrationLinePainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
