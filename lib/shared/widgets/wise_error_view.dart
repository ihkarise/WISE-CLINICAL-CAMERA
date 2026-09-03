import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../core/errors/failures.dart';

/// Renders a [Failure] as something a clinician can act on.
///
/// The only place a failure becomes visible text. A raw exception must never
/// reach the user (Build Specification section 91, UX/UI section 53), so this
/// takes a typed `Failure` and shows its `userMessage`, never its
/// `technicalDetail`.
class WiseErrorView extends StatelessWidget {
  const WiseErrorView({
    required this.failure,
    this.onRetry,
    this.onOpenSettings,
    super.key,
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // Permission failures are the only ones with a route to platform settings.
    final needsSettings =
        failure is CameraPermanentlyDenied ||
        failure is CameraPermissionDenied ||
        failure is GalleryPermissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WiseTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: WiseTokens.warningRed,
            ),
            const SizedBox(height: WiseTokens.space16),
            Text(
              failure.userMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: WiseTokens.space24),
            Wrap(
              spacing: WiseTokens.space8,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                if (needsSettings && onOpenSettings != null)
                  OutlinedButton(
                    onPressed: onOpenSettings,
                    child: const Text('Open Settings'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
