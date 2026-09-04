import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../core/sensors/device_level_service.dart';

/// A simple tilt readout (Functional LVL-003, PRD section 10).
///
/// Shows the angle as a number as well as a visual cue, so the state is
/// readable without relying on colour or position alone (UX/UI section 55).
///
/// Renders nothing when the device has no usable sensor, rather than showing a
/// dead readout (UX/UI section 74).
class LevelIndicator extends StatelessWidget {
  const LevelIndicator({
    required this.reading,
    this.toleranceDegrees = 1,
    super.key,
  });

  final LevelReading reading;

  /// Functional LVL-003 notes the visual threshold must be validated during
  /// testing, so it is a parameter rather than a constant.
  final double toleranceDegrees;

  @override
  Widget build(BuildContext context) {
    if (!reading.available) return const SizedBox.shrink();

    final level = reading.isLevel(toleranceDegrees: toleranceDegrees);
    final colour = level ? WiseTokens.successGreen : WiseTokens.cameraOnSurface;

    return Semantics(
      label: level
          ? 'Device level, ${reading.displayRoll}'
          : 'Device tilted ${reading.displayRoll}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WiseTokens.space8 + 2,
          vertical: WiseTokens.space4 + 2,
        ),
        decoration: BoxDecoration(
          color: WiseTokens.cameraChrome,
          borderRadius: BorderRadius.circular(WiseTokens.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: reading.rollDegrees * 3.1415926535 / 180,
              child: Icon(
                level ? Icons.horizontal_rule : Icons.straighten,
                size: 14,
                color: colour,
              ),
            ),
            const SizedBox(width: WiseTokens.space4 + 2),
            Text(
              level ? 'Level' : reading.displayRoll,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colour),
            ),
          ],
        ),
      ),
    );
  }
}
