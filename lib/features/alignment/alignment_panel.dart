import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../core/cv/alignment_result.dart';
import '../../models/enums.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/wise_status_chip.dart';

/// The compact alignment status panel (UX/UI sections 20-21).
///
/// Shows the five dimensions Functional ALG-003 requires. The numeric score is
/// hidden by default: "normal users should not need to interpret technical
/// numbers" (UX/UI section 21), and a percentage must never read as a clinical
/// accuracy figure (CV sections 31, 49, 71).
class AlignmentPanel extends StatelessWidget {
  const AlignmentPanel({
    required this.result,
    this.showScore = false,
    super.key,
  });

  final AlignmentResult? result;

  /// Functional ALG-005's optional advanced readout.
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final current = result;

    if (current == null || !current.isAvailable) {
      return const WiseStatusChip(
        label: WiseStrings.alignmentUnavailable,
        tone: WiseStatusTone.unavailable,
        onDark: true,
      );
    }

    final tone = switch (current.status) {
      AlignmentStatus.good => WiseStatusTone.good,
      AlignmentStatus.fair => WiseStatusTone.neutral,
      AlignmentStatus.poor => WiseStatusTone.warning,
      AlignmentStatus.unavailable => WiseStatusTone.unavailable,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: WiseTokens.space24),
      padding: const EdgeInsets.symmetric(
        horizontal: WiseTokens.space16,
        vertical: WiseTokens.space8,
      ),
      decoration: BoxDecoration(
        color: WiseTokens.cameraChrome,
        borderRadius: BorderRadius.circular(WiseTokens.controlRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WiseStatusChip(
                label: 'Alignment ${current.status.label.toLowerCase()}',
                tone: tone,
                onDark: true,
              ),
              if (showScore) ...[
                const SizedBox(width: WiseTokens.space8),
                Text(
                  '${current.scorePercent}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: WiseTokens.cameraOnSurfaceMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: WiseTokens.space8),
          Wrap(
            spacing: WiseTokens.space8,
            runSpacing: WiseTokens.space4,
            alignment: WrapAlignment.center,
            children: [
              _Dimension(
                label: 'Angle',
                satisfied: current.dimensions.rotation,
              ),
              _Dimension(
                label: 'Position',
                satisfied: current.dimensions.position,
              ),
              _Dimension(label: 'Scale', satisfied: current.dimensions.scale),
              _Dimension(
                label: 'Framing',
                satisfied: current.dimensions.framing,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One alignment dimension.
///
/// Carries a tick or cross as well as colour, so the state is legible without
/// distinguishing green from red (UX/UI section 55).
class _Dimension extends StatelessWidget {
  const _Dimension({required this.label, required this.satisfied});

  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final colour = satisfied
        ? WiseTokens.successGreen
        : WiseTokens.cameraOnSurfaceMuted;

    return Semantics(
      label: '$label ${satisfied ? 'matches' : 'does not match'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(satisfied ? Icons.check : Icons.close, size: 12, color: colour),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}
