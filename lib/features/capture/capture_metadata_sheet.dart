import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../cases/cases_screen.dart';

/// Optional clinical context chosen before the shutter (Functional MOD-012,
/// MOD-030, PRD section 20).
///
/// Body part, laterality and case are always optional: nothing here is required
/// to capture. The sheet only edits the capture session's metadata; it is the
/// caller that persists it, so this widget takes the current values and reports
/// changes rather than reaching into the controller.
class CaptureMetadataSheet extends ConsumerWidget {
  const CaptureMetadataSheet({
    required this.bodyPart,
    required this.laterality,
    required this.caseId,
    required this.onBodyPartChanged,
    required this.onLateralityChanged,
    required this.onCaseChanged,
    super.key,
  });

  final BodyPart? bodyPart;
  final Laterality? laterality;
  final String? caseId;
  final ValueChanged<BodyPart?> onBodyPartChanged;
  final ValueChanged<Laterality?> onLateralityChanged;
  final ValueChanged<String?> onCaseChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(casesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WiseTokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture details', style: theme.textTheme.titleMedium),
            const SizedBox(height: WiseTokens.space4),
            Text(
              'All optional. A photograph can be captured without any of these.',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: WiseTokens.space16),

            _Field(
              label: 'Body part',
              child: DropdownButton<BodyPart?>(
                value: bodyPart,
                isExpanded: true,
                hint: const Text('Not recorded'),
                items: [
                  const DropdownMenuItem<BodyPart?>(
                    child: Text('Not recorded'),
                  ),
                  for (final part in BodyPart.values)
                    DropdownMenuItem<BodyPart?>(
                      value: part,
                      child: Text(part.label),
                    ),
                ],
                onChanged: onBodyPartChanged,
              ),
            ),
            const SizedBox(height: WiseTokens.space16),

            _Field(
              label: 'Side',
              child: DropdownButton<Laterality?>(
                value: laterality,
                isExpanded: true,
                hint: const Text('Not recorded'),
                items: [
                  const DropdownMenuItem<Laterality?>(
                    child: Text('Not recorded'),
                  ),
                  for (final side in Laterality.values)
                    DropdownMenuItem<Laterality?>(
                      value: side,
                      child: Text(side.label),
                    ),
                ],
                onChanged: onLateralityChanged,
              ),
            ),
            const SizedBox(height: WiseTokens.space16),

            _Field(
              label: 'Case',
              child: cases.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(
                  'Cases could not be loaded.',
                  style: theme.textTheme.labelSmall,
                ),
                data: (list) => DropdownButton<String?>(
                  value: list.any((c) => c.id == caseId) ? caseId : null,
                  isExpanded: true,
                  hint: const Text('No case'),
                  items: [
                    const DropdownMenuItem<String?>(child: Text('No case')),
                    for (final record in list)
                      DropdownMenuItem<String?>(
                        value: record.id,
                        child: Text(
                          record.displayTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onCaseChanged,
                ),
              ),
            ),
            const SizedBox(height: WiseTokens.space24),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        child,
      ],
    );
  }
}
