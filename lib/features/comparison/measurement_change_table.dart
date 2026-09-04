import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../core/measurement/measurement_change.dart';
import '../../models/measurement.dart';
import '../../shared/constants/wise_strings.dart';

/// Before/After measurement change (UX/UI section 40, Functional section 19).
///
/// Two things it deliberately does not do:
///
/// - It shows no figure at all when either side lacks a valid calibration.
///   Presenting a change derived from pixels as clinical change would be the
///   exact failure Data Model section 50 forbids.
/// - It draws no conclusion. "Do not infer disease improvement automatically"
///   (UX/UI section 40), so the table reports the numbers and stops.
class MeasurementChangeTable extends StatelessWidget {
  const MeasurementChangeTable({
    required this.before,
    required this.after,
    super.key,
  });

  final List<Measurement> before;
  final List<Measurement> after;

  @override
  Widget build(BuildContext context) {
    final changes = _pairMeasurements();
    if (changes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WiseTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Measurement change', style: theme.textTheme.titleMedium),
          const SizedBox(height: WiseTokens.space8),

          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: WiseTokens.space4),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      change.type.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      change.comparable
                          ? '${change.displayAbsolute}  '
                                '(${change.displayPercentage})'
                          : change.unavailableReason ?? '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: change.comparable
                            ? (change.decreased
                                  ? WiseTokens.successGreen
                                  : WiseTokens.deepNavy)
                            : WiseTokens.slateGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: WiseTokens.space8),
          Text(
            WiseStrings.measurementDisclaimer,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  /// Pairs measurements of the same type, in the order they were created.
  ///
  /// Deliberately conservative: only the first measurement of each type on each
  /// side is compared, because matching several same-type measurements between
  /// two photographs would require guessing which lesion is which. No
  /// specification defines that mapping, so it is not invented
  /// (Build Specification section 85).
  List<MeasurementChange> _pairMeasurements() {
    final changes = <MeasurementChange>[];
    // A local copy: the widget's own lists must not be mutated during build,
    // and the provider may hand back an unmodifiable list.
    final remaining = List<Measurement>.of(after);

    for (final beforeMeasurement in before) {
      final index = remaining.indexWhere(
        (m) => m.type == beforeMeasurement.type,
      );
      if (index < 0) continue;

      changes.add(
        MeasurementChange.between(
          before: beforeMeasurement,
          after: remaining.removeAt(index),
        ),
      );
    }

    return changes;
  }
}
