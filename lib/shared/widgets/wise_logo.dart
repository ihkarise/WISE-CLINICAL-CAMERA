import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';

/// The WISE Clinical Camera brand mark, drawn to match the launcher icon: a
/// white camera aperture over a Deep Navy -> Wise Blue gradient with a single
/// Wise Red focus point (UX/UI 2.1-2.2, master prompt §8).
///
/// Painted rather than shipped as an asset so it scales crisply at any size and
/// stays in step with [WiseTokens]; the launcher/splash bitmaps are generated
/// from the same construction.
class WiseLogo extends StatelessWidget {
  const WiseLogo({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _WiseAperturePainter(),
      isComplex: true,
      willChange: false,
    ),
  );
}

class _WiseAperturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.28),
    );

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [WiseTokens.deepNavy, WiseTokens.wiseBlue],
      ).createShader(rect);
    canvas.drawRRect(rrect, bg);

    canvas.save();
    canvas.clipRRect(rrect);

    final center = size.center(Offset.zero);
    final r = size.width * 0.30;
    final inner = r * 0.52;

    // Compose the aperture in its own layer so the iris opening and the blade
    // separators can be cut out to reveal the gradient beneath.
    canvas.saveLayer(rect, Paint());
    canvas.drawCircle(center, r, Paint()..color = WiseTokens.white);

    final hexagon = Path();
    for (var k = 0; k < 6; k++) {
      final a = (60 * k - 90) * math.pi / 180;
      final p = center + Offset(inner * math.cos(a), inner * math.sin(a));
      k == 0 ? hexagon.moveTo(p.dx, p.dy) : hexagon.lineTo(p.dx, p.dy);
    }
    hexagon.close();
    canvas.drawPath(hexagon, Paint()..blendMode = BlendMode.clear);

    final blade = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 6; k++) {
      final a = (60 * k - 90) * math.pi / 180;
      final v = center + Offset(inner * math.cos(a), inner * math.sin(a));
      final ao = (60 * k - 90 + 34) * math.pi / 180;
      final o =
          center + Offset(r * 1.02 * math.cos(ao), r * 1.02 * math.sin(ao));
      canvas.drawLine(v, o, blade);
    }
    canvas.restore();

    // The restrained Wise Red accent at the centre.
    canvas.drawCircle(center, r * 0.14, Paint()..color = WiseTokens.wiseRed);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WiseAperturePainter oldDelegate) => false;
}
