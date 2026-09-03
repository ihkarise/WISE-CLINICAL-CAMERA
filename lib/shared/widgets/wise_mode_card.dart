import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';

/// One of the three primary mode cards on the home screen.
///
/// These are the product's primary actions and must dominate the screen
/// (UX/UI section 8, PRD section 2, Build Specification sections 8-9).
class WiseModeCard extends StatelessWidget {
  const WiseModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.disabledReason,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  /// Shown instead of the subtitle when disabled, so a control never appears
  /// to do nothing (UX/UI section 74).
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? '$title. $subtitle'
          : '$title. ${disabledReason ?? 'Unavailable'}',
      excludeSemantics: true,
      child: Material(
        color: enabled ? colours.surface : colours.surfaceContainerLow,
        borderRadius: BorderRadius.circular(WiseTokens.cardRadius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(WiseTokens.cardRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(WiseTokens.space16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WiseTokens.cardRadius),
              border: Border.all(color: colours.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: enabled ? WiseTokens.wiseBlue : WiseTokens.slateGray,
                ),
                const SizedBox(height: WiseTokens.space8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: 0.5,
                        color: enabled
                            ? WiseTokens.deepNavy
                            : WiseTokens.slateGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled ? subtitle : (disabledReason ?? subtitle),
                      style: theme.textTheme.labelSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
