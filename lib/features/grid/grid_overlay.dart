import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';

/// The composition grid drawn over the live preview (Functional GRD-001..003).
///
/// A **display layer only**. It is painted over the preview and is never part
/// of the saved original; a grid reaches a file only through an explicitly
/// configured export (Functional GRD-003, Build Specification section 33,
/// SPECIFICATION_CONFLICTS C-002).
class GridOverlay extends StatelessWidget {
  const GridOverlay({required this.type, super.key});

  final GridType type;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(size: Size.infinite, painter: _GridPainter(type)),
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.type);

  final GridType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WiseTokens.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    switch (type) {
      case GridType.thirds:
        _drawDivisions(canvas, size, paint, 3);
      case GridType.quarters:
        _drawDivisions(canvas, size, paint, 4);
      case GridType.crosshair:
        final centre = Offset(size.width / 2, size.height / 2);
        final arm = size.shortestSide / 12;
        final thick = paint..strokeWidth = 2;
        canvas
          ..drawLine(centre.translate(-arm, 0), centre.translate(arm, 0), thick)
          ..drawLine(
            centre.translate(0, -arm),
            centre.translate(0, arm),
            thick,
          );
    }
  }

  void _drawDivisions(Canvas canvas, Size size, Paint paint, int divisions) {
    for (var i = 1; i < divisions; i++) {
      final x = size.width * i / divisions;
      final y = size.height * i / divisions;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), paint)
        ..drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.type != type;
}
