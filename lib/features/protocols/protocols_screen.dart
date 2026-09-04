import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/capture_protocol.dart';
import '../../shared/widgets/wise_empty_state.dart';
import 'protocol_editor_screen.dart';

final protocolsProvider = FutureProvider<List<CaptureProtocol>>((ref) async {
  final repository = await ref.watch(protocolRepositoryProvider.future);
  return repository.getProtocols();
});

/// Reusable capture configurations (UX/UI sections 49-50, Functional
/// PRO-001..005).
///
/// Selecting one sets the protocol layer of the precedence chain for the next
/// capture. It does not touch the user's saved defaults, which stay available
/// underneath (UX/UI section 50).
///
/// Built-in protocols are separated from user-created ones and are immutable:
/// they can be selected or duplicated but never edited or deleted (master
/// prompt §7).
class ProtocolsScreen extends ConsumerWidget {
  const ProtocolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final protocols = ref.watch(protocolsProvider);
    final active = ref.watch(activeProtocolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Protocols')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProtocolEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New protocol'),
      ),
      body: protocols.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const WiseEmptyState(
          message: 'Protocols could not be loaded.',
          icon: Icons.error_outline,
        ),
        data: (list) {
          final builtIn = list.where((p) => p.isSystem).toList();
          final userMade = list.where((p) => !p.isSystem).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: WiseTokens.space96),
            children: [
              Padding(
                padding: const EdgeInsets.all(WiseTokens.gutter),
                child: Text(
                  'A protocol sets the tools for a capture. Your saved '
                  'defaults are unchanged and return when no protocol is '
                  'active.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              RadioListTile<bool>(
                value: true,
                // ignore: deprecated_member_use
                groupValue: active == null,
                // ignore: deprecated_member_use
                onChanged: (_) =>
                    ref.read(activeProtocolProvider.notifier).state = null,
                title: const Text('No protocol'),
                subtitle: const Text('Use my saved defaults'),
              ),

              if (builtIn.isNotEmpty) _GroupHeader(title: 'Built-in'),
              for (final protocol in builtIn)
                _ProtocolTile(protocol: protocol, active: active),

              _GroupHeader(title: 'Your protocols'),
              if (userMade.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    WiseTokens.gutter,
                    WiseTokens.space4,
                    WiseTokens.gutter,
                    WiseTokens.space16,
                  ),
                  child: Text(
                    'None yet. Tap New protocol to create one, or duplicate a '
                    'built-in protocol as a starting point.',
                  ),
                ),
              for (final protocol in userMade)
                _ProtocolTile(protocol: protocol, active: active),
            ],
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      WiseTokens.gutter,
      WiseTokens.space16,
      WiseTokens.gutter,
      WiseTokens.space4,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ProtocolTile extends ConsumerWidget {
  const _ProtocolTile({required this.protocol, required this.active});

  final CaptureProtocol protocol;
  final CaptureProtocol? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledTools = protocol.settings.tools.enabled.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.shortLabel)
        .join(', ');

    return ListTile(
      leading: Icon(
        protocol.isSystem ? Icons.verified_outlined : Icons.checklist_outlined,
        color: WiseTokens.wiseBlue,
      ),
      title: Text(protocol.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (protocol.description != null) Text(protocol.description!),
          if (enabledTools.isNotEmpty)
            Text(enabledTools, style: Theme.of(context).textTheme.labelSmall),
          // Versioned so an edit cannot rewrite what earlier photographs were
          // captured under (Functional PRO-005).
          Text(
            'Version ${protocol.version}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active?.id == protocol.id)
            const Icon(Icons.check_circle, color: WiseTokens.wiseBlue),
          _ProtocolMenu(protocol: protocol),
        ],
      ),
      onTap: () {
        ref.read(activeProtocolProvider.notifier).state = protocol;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${protocol.name} is active for capture.')),
        );
      },
    );
  }
}

enum _ProtocolAction { edit, duplicate, delete }

class _ProtocolMenu extends ConsumerWidget {
  const _ProtocolMenu({required this.protocol});

  final CaptureProtocol protocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ProtocolAction>(
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        // Built-in protocols are immutable: only duplication is offered so the
        // user can build on one without altering it (master prompt §7).
        if (!protocol.isSystem)
          const PopupMenuItem(value: _ProtocolAction.edit, child: Text('Edit')),
        const PopupMenuItem(
          value: _ProtocolAction.duplicate,
          child: Text('Duplicate'),
        ),
        if (!protocol.isSystem)
          const PopupMenuItem(
            value: _ProtocolAction.delete,
            child: Text('Delete'),
          ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _ProtocolAction action,
  ) async {
    switch (action) {
      case _ProtocolAction.edit:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProtocolEditorScreen(protocol: protocol),
          ),
        );
      case _ProtocolAction.duplicate:
        final repository = await ref.read(protocolRepositoryProvider.future);
        final user = await ref.read(currentUserProvider.future);
        await repository.duplicateProtocol(protocol, userId: user.id);
        ref.invalidate(protocolsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicated ${protocol.name}.')),
          );
        }
      case _ProtocolAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${protocol.name}?'),
        content: const Text(
          'Photographs already captured with this protocol keep naming it. '
          'This only removes it from the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = await ref.read(protocolRepositoryProvider.future);
    final result = await repository.deleteProtocol(protocol.id);
    // A retired protocol must not stay selected for the next capture.
    if (ref.read(activeProtocolProvider)?.id == protocol.id) {
      ref.read(activeProtocolProvider.notifier).state = null;
    }
    ref.invalidate(protocolsProvider);
    if (context.mounted && result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull!.userMessage)),
      );
    }
  }
}
