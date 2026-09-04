import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../models/export_record.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import 'export_service.dart';

/// Choosing an export preset (UX/UI sections 42-43, Functional EXP-001).
///
/// Every preset produces a **derived asset**; the original is never replaced
/// (Build Specification section 48, Functional SAV-004).
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({required this.photo, this.comparisonWith, super.key});

  final Photo photo;

  /// Set when exporting a Before/After pair.
  final Photo? comparisonWith;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The active protocol may recommend a preset (Functional PRO-002).
    final recommended = ref
        .watch(activeProtocolProvider)
        ?.settings
        .exportPreset;
    final presets = ExportPreset.values.where(
      // Pair presets need a second photograph.
      (preset) => !preset.isPair || widget.comparisonWith != null,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WiseTokens.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export', style: theme.textTheme.titleLarge),
            const SizedBox(height: WiseTokens.space4),
            Text(
              'Your original photograph is never changed.',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: WiseTokens.space8),

            for (final preset in presets)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  preset == ExportPreset.anonymized
                      ? Icons.visibility_off_outlined
                      : Icons.image_outlined,
                  color: WiseTokens.wiseBlue,
                ),
                title: Text(preset.label),
                subtitle: preset == ExportPreset.anonymized
                    ? Text(
                        'Removes location, device and identifying metadata.',
                        style: theme.textTheme.labelSmall,
                      )
                    : null,
                trailing: preset == recommended
                    ? Text(
                        'Recommended',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: WiseTokens.wiseBlue,
                        ),
                      )
                    : null,
                enabled: !_busy,
                onTap: () => _export(preset),
              ),

            if (_message != null) ...[
              const SizedBox(height: WiseTokens.space8),
              // A live region so the export outcome is announced to a screen
              // reader, which otherwise gives no feedback after the tap
              // (UX/UI section 55).
              Semantics(
                liveRegion: true,
                child: Text(_message!, style: theme.textTheme.bodyMedium),
              ),
            ],
            const SizedBox(height: WiseTokens.space8),
            Text(
              WiseStrings.measurementDisclaimer,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(ExportPreset preset) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final service = await ref.read(exportServiceProvider.future);

      // Honour the protocol's footer preference (Functional PRO-002). It can
      // only suppress a footer the preset would otherwise carry, never force
      // one onto a preset (like Original or Anonymized) that omits it.
      final base = ExportConfiguration.forPreset(preset);
      final footerAllowed =
          ref.read(activeProtocolProvider)?.settings.exportFooter ?? true;
      final config = footerAllowed ? base : base.copyWith(includeFooter: false);

      final result = await service.export(
        photo: widget.photo,
        preset: preset,
        pairedWith: widget.comparisonWith,
        configuration: config,
      );

      if (!mounted) return;
      setState(() {
        _message = result.fold(
          onOk: (record) => 'Export created.',
          onFailure: (failure) => failure.userMessage,
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
