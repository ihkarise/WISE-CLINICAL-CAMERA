import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../core/imaging/metadata_anonymizer.dart';
import '../../models/enums.dart';
import '../../models/tool_capabilities.dart';
import '../../models/tool_overrides.dart';
import '../../models/user_preferences.dart';
import '../../shared/constants/wise_strings.dart';

/// Settings (UX/UI section 47).
///
/// Every switch here changes a **persistent default**, in contrast to the Tools
/// drawer, which changes only the current capture. Keeping the two apart is
/// what makes "your camera tools" mean something stable (PRD sections 22-23,
/// Functional SET-001..004, UX/UI section 12).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final capabilities = ref.watch(toolCapabilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Settings could not be loaded.')),
        data: (current) => ListView(
          children: [
            _SectionHeader(title: WiseStrings.yourCameraTools),
            for (final tool in WiseTool.values)
              _ToolDefaultSwitch(
                tool: tool,
                preferences: current,
                capabilities: capabilities,
              ),

            const Divider(),
            _SectionHeader(title: 'Measurement'),
            ListTile(
              title: const Text('Unit'),
              subtitle: Text(current.measurementUnit.symbol),
              trailing: DropdownButton<LengthUnit>(
                value: current.measurementUnit,
                onChanged: (unit) => unit == null
                    ? null
                    : _save(ref, current.copyWith(measurementUnit: unit)),
                items: [
                  for (final unit in LengthUnit.values)
                    DropdownMenuItem(value: unit, child: Text(unit.symbol)),
                ],
              ),
            ),

            const Divider(),
            _SectionHeader(title: 'Comparison'),
            ListTile(
              title: const Text('Default mode'),
              trailing: DropdownButton<ComparisonMode>(
                value: current.comparisonMode,
                onChanged: (mode) => mode == null
                    ? null
                    : _save(ref, current.copyWith(comparisonMode: mode)),
                items: [
                  for (final mode in ComparisonMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
              ),
            ),

            const Divider(),
            _SectionHeader(title: 'Saving'),
            ListTile(
              title: const Text('Save to device Gallery'),
              subtitle: Text(
                current.privacyMode
                    ? 'Privacy Mode prevents automatic Gallery copies.'
                    : 'WISE always keeps its own copy.',
              ),
              trailing: DropdownButton<GallerySaveMode>(
                value: current.gallerySaveMode,
                onChanged: (mode) => mode == null
                    ? null
                    : _save(ref, current.copyWith(gallerySaveMode: mode)),
                items: [
                  for (final mode in GallerySaveMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
              ),
            ),

            const Divider(),
            _SectionHeader(title: 'Privacy'),
            SwitchListTile(
              value: current.privacyMode,
              onChanged: (value) =>
                  _save(ref, current.copyWith(privacyMode: value)),
              title: const Text('Privacy Mode'),
              subtitle: const Text(
                'No automatic Gallery copies, no cloud processing, and no '
                'third-party image processing.',
              ),
            ),
            const _AnonymizationDetails(),

            const Divider(),
            _SectionHeader(title: 'Advanced'),
            SwitchListTile(
              value: current.showAlignmentScore,
              onChanged: (value) =>
                  _save(ref, current.copyWith(showAlignmentScore: value)),
              title: const Text('Show alignment score'),
              subtitle: const Text(
                'A reproducibility score, not a measure of clinical accuracy.',
              ),
            ),
            const SizedBox(height: WiseTokens.space32),
          ],
        ),
      ),
    );
  }

  void _save(WidgetRef ref, UserPreferences preferences) {
    ref.read(savePreferencesProvider)(preferences);
  }
}

class _ToolDefaultSwitch extends ConsumerWidget {
  const _ToolDefaultSwitch({
    required this.tool,
    required this.preferences,
    required this.capabilities,
  });

  final WiseTool tool;
  final UserPreferences preferences;
  final ToolCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = capabilities.supports(tool);
    final enabled = _valueOf(preferences, tool);

    return SwitchListTile(
      value: enabled && supported,
      onChanged: supported
          ? (value) => ref.read(savePreferencesProvider)(
              _withTool(preferences, tool, value),
            )
          : null,
      title: Text(tool.label),
      subtitle: supported
          ? null
          : Text(
              capabilities.reasonFor(tool) ?? 'Unavailable on this device',
              style: Theme.of(context).textTheme.labelSmall,
            ),
    );
  }

  static bool _valueOf(UserPreferences p, WiseTool tool) => switch (tool) {
    WiseTool.overlay => p.overlayEnabled,
    WiseTool.alignment => p.alignmentEnabled,
    WiseTool.lighting => p.lightingEnabled,
    WiseTool.focus => p.focusEnabled,
    WiseTool.grid => p.gridEnabled,
    WiseTool.level => p.levelEnabled,
    WiseTool.measurement => p.measurementEnabled,
    WiseTool.annotation => p.annotationEnabled,
    WiseTool.difference => p.differenceEnabled,
  };

  static UserPreferences _withTool(
    UserPreferences p,
    WiseTool tool,
    bool value,
  ) => switch (tool) {
    WiseTool.overlay => p.copyWith(overlayEnabled: value),
    WiseTool.alignment => p.copyWith(alignmentEnabled: value),
    WiseTool.lighting => p.copyWith(lightingEnabled: value),
    WiseTool.focus => p.copyWith(focusEnabled: value),
    WiseTool.grid => p.copyWith(gridEnabled: value),
    WiseTool.level => p.copyWith(levelEnabled: value),
    WiseTool.measurement => p.copyWith(measurementEnabled: value),
    WiseTool.annotation => p.copyWith(annotationEnabled: value),
    WiseTool.difference => p.copyWith(differenceEnabled: value),
  };
}

/// States plainly what an anonymized export removes.
///
/// Build Specification section 49 requires documenting exactly what is
/// stripped, and the person who most needs to know is the clinician about to
/// share the file.
class _AnonymizationDetails extends StatelessWidget {
  const _AnonymizationDetails();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      title: const Text('What anonymized export removes'),
      childrenPadding: const EdgeInsets.symmetric(
        horizontal: WiseTokens.gutter,
        vertical: WiseTokens.space8,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Removed', style: theme.textTheme.titleMedium),
              for (final field in MetadataAnonymizer.removedFields)
                Text('- $field', style: theme.textTheme.bodyMedium),
              const SizedBox(height: WiseTokens.space8),
              Text('Kept', style: theme.textTheme.titleMedium),
              for (final field in MetadataAnonymizer.retainedFields)
                Text('- $field', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      WiseTokens.gutter,
      WiseTokens.space16,
      WiseTokens.gutter,
      WiseTokens.space4,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}
