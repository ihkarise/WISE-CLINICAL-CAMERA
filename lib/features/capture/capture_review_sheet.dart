import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/clinical_image.dart';
import '../../shared/widgets/wise_status_chip.dart';
import 'capture_state.dart';

/// The review step after capture (UX/UI section 25, Functional section 38).
///
/// Shows the photograph with the quality status recorded at capture, and offers
/// Retake or Use photo. The clinician inspects before saving.
class CaptureReviewSheet extends StatelessWidget {
  const CaptureReviewSheet({
    required this.state,
    required this.onRetake,
    required this.onUse,
    super.key,
  });

  final CaptureState state;
  final VoidCallback onRetake;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final photo = state.capturedPhoto;
    if (photo == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(WiseTokens.space16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(WiseTokens.controlRadius),
              child: ClinicalImage.file(
                photo.originalPath,
                semanticLabel: 'Captured photograph, under review',
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WiseTokens.space16),
          child: Wrap(
            spacing: WiseTokens.space8,
            runSpacing: WiseTokens.space8,
            alignment: WrapAlignment.center,
            children: [
              if (state.focus != null)
                WiseStatusChip(
                  label: state.focus!.status.label,
                  tone: state.focus!.isWarning
                      ? WiseStatusTone.warning
                      : WiseStatusTone.good,
                  onDark: true,
                ),
              if (state.lighting != null)
                WiseStatusChip(
                  label: state.lighting!.message,
                  tone: state.lighting!.isWarning
                      ? WiseStatusTone.warning
                      : WiseStatusTone.good,
                  onDark: true,
                ),
              if (state.alignment != null)
                WiseStatusChip(
                  label: state.alignment!.isAvailable
                      ? 'Alignment ${state.alignment!.status.label.toLowerCase()}'
                      : WiseStrings.alignmentUnavailable,
                  tone: switch (state.alignment!.status) {
                    AlignmentStatus.good => WiseStatusTone.good,
                    AlignmentStatus.fair => WiseStatusTone.neutral,
                    AlignmentStatus.poor => WiseStatusTone.warning,
                    AlignmentStatus.unavailable => WiseStatusTone.unavailable,
                  },
                  onDark: true,
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(WiseTokens.space24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  child: const Text(WiseStrings.retake),
                ),
              ),
              const SizedBox(width: WiseTokens.space16),
              Expanded(
                child: FilledButton(
                  onPressed: onUse,
                  child: const Text(WiseStrings.usePhoto),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
