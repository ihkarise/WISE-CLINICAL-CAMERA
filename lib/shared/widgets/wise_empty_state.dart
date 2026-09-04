import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';

/// An empty state with a single clear action (UX/UI section 51).
class WiseEmptyState extends StatelessWidget {
  const WiseEmptyState({
    required this.message,
    this.icon = Icons.photo_camera_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WiseTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: WiseTokens.slateGray),
            const SizedBox(height: WiseTokens.space16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: WiseTokens.space24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
