import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/capture_protocol.dart';
import '../../shared/widgets/wise_empty_state.dart';

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
class ProtocolsScreen extends ConsumerWidget {
  const ProtocolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final protocols = ref.watch(protocolsProvider);
    final active = ref.watch(activeProtocolOverridesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Protocols')),
      body: protocols.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const WiseEmptyState(
          message: 'Protocols could not be loaded.',
          icon: Icons.error_outline,
        ),
        data: (list) => list.isEmpty
            ? const WiseEmptyState(
                message: 'No protocols yet.',
                icon: Icons.checklist_outlined,
              )
            : ListView(
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
                  RadioListTile<String?>(
                    value: null,
                    // ignore: deprecated_member_use
                    groupValue: active == null ? null : 'active',
                    // ignore: deprecated_member_use
                    onChanged: (_) =>
                        ref
                                .read(activeProtocolOverridesProvider.notifier)
                                .state =
                            null,
                    title: const Text('No protocol'),
                    subtitle: const Text('Use my saved defaults'),
                  ),
                  for (final protocol in list)
                    _ProtocolTile(protocol: protocol),
                ],
              ),
      ),
    );
  }
}

class _ProtocolTile extends ConsumerWidget {
  const _ProtocolTile({required this.protocol});

  final CaptureProtocol protocol;

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
      onTap: () {
        ref.read(activeProtocolOverridesProvider.notifier).state =
            protocol.settings.tools;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${protocol.name} is active for capture.')),
        );
      },
    );
  }
}
