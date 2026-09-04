import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';

/// Severity of a status indicator.
enum WiseStatusTone { neutral, good, warning, unavailable }

/// A compact status indicator carrying both an icon and text.
///
/// Never colour alone. UX/UI section 55 and the accessibility requirements in
/// Functional section 42 both require non-colour-only status, and Technical
/// Architecture section 47 gives the example directly: show "Good", not a green
/// dot. Every instance therefore pairs a shape with a word, and exposes both to
/// screen readers through a semantic label.
class WiseStatusChip extends StatelessWidget {
  const WiseStatusChip({
    required this.label,
    this.tone = WiseStatusTone.neutral,
    this.icon,
    this.onDark = false,
    super.key,
  });

  final String label;
  final WiseStatusTone tone;
  final IconData? icon;

  /// True when placed over the camera preview.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colour = switch (tone) {
      WiseStatusTone.good => WiseTokens.successGreen,
      WiseStatusTone.warning => WiseTokens.warningRed,
      WiseStatusTone.unavailable => WiseTokens.slateGray,
      WiseStatusTone.neutral =>
        onDark ? WiseTokens.cameraOnSurface : WiseTokens.wiseBlue,
    };

    final resolvedIcon = icon ?? _defaultIcon;

    return Semantics(
      // The tone is spoken, so the meaning does not depend on seeing colour.
      label: '${_toneWord(tone)}: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WiseTokens.space8 + 2,
          vertical: WiseTokens.space4 + 2,
        ),
        decoration: BoxDecoration(
          color: onDark
              ? WiseTokens.cameraChrome
              : colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(WiseTokens.pillRadius),
          border: Border.all(color: colour.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(resolvedIcon, size: 14, color: colour),
            const SizedBox(width: WiseTokens.space4 + 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: onDark ? WiseTokens.cameraOnSurface : colour,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _defaultIcon => switch (tone) {
    WiseStatusTone.good => Icons.check_circle_outline,
    WiseStatusTone.warning => Icons.error_outline,
    WiseStatusTone.unavailable => Icons.remove_circle_outline,
    WiseStatusTone.neutral => Icons.info_outline,
  };

  static String _toneWord(WiseStatusTone tone) => switch (tone) {
    WiseStatusTone.good => 'Good',
    WiseStatusTone.warning => 'Warning',
    WiseStatusTone.unavailable => 'Unavailable',
    WiseStatusTone.neutral => 'Status',
  };
}
