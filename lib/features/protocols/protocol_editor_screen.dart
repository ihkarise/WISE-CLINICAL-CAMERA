import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/capture_protocol.dart';
import '../../models/enums.dart';
import '../../models/tool_overrides.dart';
import 'protocols_screen.dart';

/// Create or edit a user protocol (Functional PRO-001..005, master prompt §7).
///
/// Built-in protocols are immutable and never reach this screen for editing;
/// the list offers "Duplicate" instead, which lands here on the fresh copy.
/// Everything configured here feeds the settings precedence chain, so a switch
/// turned off actually removes that tool from the next capture rather than
/// being decorative (master prompt §7: no inert controls).
class ProtocolEditorScreen extends ConsumerStatefulWidget {
  const ProtocolEditorScreen({this.protocol, super.key});

  /// The protocol being edited, or null to create a new one.
  final CaptureProtocol? protocol;

  @override
  ConsumerState<ProtocolEditorScreen> createState() =>
      _ProtocolEditorScreenState();
}

class _ProtocolEditorScreenState extends ConsumerState<ProtocolEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final Map<WiseTool, bool> _tools;
  late GridType _gridType;
  CaptureOrientation? _orientation;
  WiseFlashMode? _flash;
  ExportPreset? _exportPreset;
  bool _measurementRequired = false;
  bool _saving = false;

  bool get _isNew => widget.protocol == null;

  @override
  void initState() {
    super.initState();
    final protocol = widget.protocol;
    final settings = protocol?.settings;
    _name = TextEditingController(text: protocol?.name ?? '');
    _description = TextEditingController(text: protocol?.description ?? '');
    _tools = {
      for (final tool in WiseTool.values)
        tool: settings?.tools.valueFor(tool) ?? false,
    };
    _gridType = settings?.tools.gridType ?? GridType.thirds;
    _orientation = settings?.preferredOrientation;
    _flash = settings?.preferredFlash;
    _exportPreset = settings?.exportPreset;
    _measurementRequired = settings?.measurementRequired ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New protocol' : 'Edit protocol'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: WiseTokens.space8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WiseTokens.gutter),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: WiseTokens.space16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WiseTokens.gutter),
            child: TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const Divider(height: WiseTokens.space32),
          _Header(title: 'Capture guides and quality checks'),
          for (final tool in WiseTool.values)
            SwitchListTile(
              value: _tools[tool] ?? false,
              onChanged: (value) => setState(() => _tools[tool] = value),
              title: Text(tool.label),
            ),

          if (_tools[WiseTool.grid] ?? false)
            ListTile(
              title: const Text('Grid layout'),
              trailing: DropdownButton<GridType>(
                value: _gridType,
                onChanged: (value) =>
                    value == null ? null : setState(() => _gridType = value),
                items: [
                  for (final type in GridType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
              ),
            ),

          const Divider(height: WiseTokens.space32),
          _Header(title: 'Required metadata'),
          SwitchListTile(
            value: _measurementRequired,
            onChanged: (value) => setState(() => _measurementRequired = value),
            title: const Text('Prompt for a measurement'),
            subtitle: Text(
              'Advisory only — it never blocks capture.',
              style: theme.textTheme.labelSmall,
            ),
          ),

          const Divider(height: WiseTokens.space32),
          _Header(title: 'Camera preferences'),
          ListTile(
            title: const Text('Preferred orientation'),
            trailing: DropdownButton<CaptureOrientation?>(
              value: _orientation,
              hint: const Text('Any'),
              onChanged: (value) => setState(() => _orientation = value),
              items: [
                const DropdownMenuItem<CaptureOrientation?>(child: Text('Any')),
                for (final orientation in CaptureOrientation.values)
                  DropdownMenuItem<CaptureOrientation?>(
                    value: orientation,
                    child: Text(orientation.wireName),
                  ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Preferred flash'),
            trailing: DropdownButton<WiseFlashMode?>(
              value: _flash,
              hint: const Text('Leave as is'),
              onChanged: (value) => setState(() => _flash = value),
              items: [
                const DropdownMenuItem<WiseFlashMode?>(
                  child: Text('Leave as is'),
                ),
                for (final mode in WiseFlashMode.values)
                  DropdownMenuItem<WiseFlashMode?>(
                    value: mode,
                    child: Text(mode.wireName),
                  ),
              ],
            ),
          ),

          const Divider(height: WiseTokens.space32),
          _Header(title: 'Export'),
          ListTile(
            title: const Text('Default export preset'),
            trailing: DropdownButton<ExportPreset?>(
              value: _exportPreset,
              hint: const Text('Ask each time'),
              onChanged: (value) => setState(() => _exportPreset = value),
              items: [
                const DropdownMenuItem<ExportPreset?>(
                  child: Text('Ask each time'),
                ),
                for (final preset in ExportPreset.values)
                  DropdownMenuItem<ExportPreset?>(
                    value: preset,
                    child: Text(preset.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: WiseTokens.space32),
        ],
      ),
    );
  }

  ProtocolSettings _buildSettings() => ProtocolSettings(
    tools: ToolOverrides(
      enabled: Map<WiseTool, bool>.from(_tools),
      gridType: _gridType,
    ),
    preferredOrientation: _orientation,
    preferredFlash: _flash,
    measurementRequired: _measurementRequired,
    exportPreset: _exportPreset,
    // A user protocol never imposes a hard block on capture: the one mechanism
    // permitted to do so is left unset (SPECIFICATION_CONFLICTS C-018).
  );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showMessage('Give the protocol a name.');
      return;
    }
    setState(() => _saving = true);

    final repository = await ref.read(protocolRepositoryProvider.future);
    final settings = _buildSettings();
    final description = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();

    final result = _isNew
        ? await repository.createProtocol(
            name: _name.text,
            description: description,
            settings: settings,
            userId: (await ref.read(currentUserProvider.future)).id,
          )
        : await repository.updateProtocol(
            widget.protocol!,
            name: _name.text.trim(),
            description: description,
            settings: settings,
          );

    if (!mounted) return;
    if (result.isFailure) {
      setState(() => _saving = false);
      _showMessage(result.failureOrNull!.userMessage);
      return;
    }

    ref.invalidate(protocolsProvider);
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      WiseTokens.gutter,
      WiseTokens.space8,
      WiseTokens.gutter,
      WiseTokens.space4,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}
