import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/effective_settings.dart';
import '../../models/tool_capabilities.dart';
import '../../models/tool_overrides.dart';
import '../../shared/constants/wise_strings.dart';

/// The Tools drawer (UX/UI section 15, Build Specification section 19).
///
/// The one place every optional tool appears with its current state. Two things
/// it must get right:
///
/// - **A change here is a one-capture override, not a new default.** The user
///   opts into changing the default explicitly, which is what keeps a
///   persistent preference from being rewritten by a single session
///   (Functional SET-003, SET-004; UX/UI sections 13-14).
/// - **An unsupported tool shows why, rather than a switch that does nothing**
///   (UX/UI section 74).
class ToolsDrawer extends ConsumerWidget {
  const ToolsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(effectiveSettingsProvider).valueOrNull;
    final capabilities = ref.watch(toolCapabilitiesProvider);
    final theme = Theme.of(context);

    if (settings == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WiseTokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(WiseStrings.toolsTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: WiseTokens.space8),
            Text(
              'Changes apply to this capture. Your saved defaults are '
              'unchanged.',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: WiseTokens.space16),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final tool in WiseTool.values)
                    _ToolRow(
                      tool: tool,
                      settings: settings,
                      capabilities: capabilities,
                    ),
                ],
              ),
            ),

            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Explicitly promote the current session state to the saved
                  // default (Functional SET-004).
                  _saveAsDefaults(ref, settings);
                  Navigator.of(context).pop();
                },
                child: const Text(WiseStrings.changeDefault),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsDefaults(
    WidgetRef ref,
    EffectiveSettings settings,
  ) async {
    final preferences = ref.read(preferencesProvider).valueOrNull;
    if (preferences == null) return;

    await ref.read(savePreferencesProvider)(
      preferences.copyWith(
        overlayEnabled: settings.overlayEnabled,
        overlayOpacity: settings.overlayOpacity,
        alignmentEnabled: settings.alignmentEnabled,
        lightingEnabled: settings.lightingEnabled,
        focusEnabled: settings.focusEnabled,
        gridEnabled: settings.gridEnabled,
        gridType: settings.gridType,
        levelEnabled: settings.levelEnabled,
        measurementEnabled: settings.measurementEnabled,
        annotationEnabled: settings.annotationEnabled,
        differenceEnabled: settings.differenceEnabled,
      ),
    );

    // The session layer has been folded into the defaults, so it is cleared to
    // avoid a stale override masking the new default.
    ref.read(sessionOverridesProvider.notifier).state = ToolOverrides.none;
  }
}

class _ToolRow extends ConsumerWidget {
  const _ToolRow({
    required this.tool,
    required this.settings,
    required this.capabilities,
  });

  final WiseTool tool;
  final EffectiveSettings settings;
  final ToolCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = capabilities.supports(tool);
    final enabled = settings.isEnabled(tool);
    final overridden = settings.isSessionOverridden(tool);

    return SwitchListTile(
      value: enabled,
      onChanged: supported
          ? (value) => ref
                .read(sessionOverridesProvider.notifier)
                .update((current) => current.setting(tool, value: value))
          : null,
      title: Text(tool.label),
      subtitle: !supported
          ? Text(
              capabilities.reasonFor(tool) ?? 'Unavailable on this device',
              style: Theme.of(context).textTheme.labelSmall,
            )
          : overridden
          ? Text(
              enabled
                  ? WiseStrings.onForThisCapture
                  : WiseStrings.offForThisCapture,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: WiseTokens.wiseRed),
            )
          : Text(
              // Naming the source lets the user see why a tool is off without
              // guessing (UX/UI section 74).
              switch (settings.sourceOf(tool)) {
                SettingSource.protocol => 'Set by the active protocol',
                SettingSource.platform => 'Unavailable on this device',
                _ => enabled ? 'On by default' : 'Off by default',
              },
              style: Theme.of(context).textTheme.labelSmall,
            ),
      secondary: Icon(
        _iconFor(tool),
        color: supported ? WiseTokens.wiseBlue : WiseTokens.slateGray,
      ),
    );
  }

  static IconData _iconFor(WiseTool tool) => switch (tool) {
    WiseTool.overlay => Icons.layers_outlined,
    WiseTool.alignment => Icons.center_focus_strong_outlined,
    WiseTool.lighting => Icons.wb_sunny_outlined,
    WiseTool.focus => Icons.filter_center_focus_outlined,
    WiseTool.grid => Icons.grid_3x3_outlined,
    WiseTool.level => Icons.straighten_outlined,
    WiseTool.measurement => Icons.square_foot_outlined,
    WiseTool.annotation => Icons.edit_outlined,
    WiseTool.difference => Icons.difference_outlined,
  };
}
