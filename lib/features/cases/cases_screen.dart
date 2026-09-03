import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/clinical_case.dart';
import '../../shared/widgets/wise_empty_state.dart';

final casesProvider = FutureProvider<List<ClinicalCase>>((ref) async {
  final repository = await ref.watch(caseRepositoryProvider.future);
  return repository.getCases();
});

/// Optional grouping of photographs (Functional CAS-001..003).
///
/// Optional throughout: a photograph works without a case, and deleting a case
/// never deletes its photographs (Data Model section 35).
///
/// Carries no patient-identifying fields. Data Model section 52 and Privacy
/// PRI-001 both forbid storing a name, ID or contact details unless a future
/// requirement defines them, so the form offers a title and a local reference
/// and nothing else.
class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(casesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cases')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCase(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New case'),
      ),
      body: cases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const WiseEmptyState(
          message: 'Cases could not be loaded.',
          icon: Icons.error_outline,
        ),
        data: (list) => list.isEmpty
            ? const WiseEmptyState(
                message:
                    'Cases are optional. Group related photographs here when '
                    'it helps.',
                icon: Icons.folder_special_outlined,
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _CaseTile(record: list[index]),
              ),
      ),
    );
  }

  Future<void> _createCase(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title or local reference',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: WiseTokens.space8),
            Text(
              'Avoid patient-identifying information.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (title == null || title.isEmpty) return;

    final repository = await ref.read(caseRepositoryProvider.future);
    final user = await ref.read(currentUserProvider.future);
    await repository.createCase(userId: user.id, title: title);
    ref.invalidate(casesProvider);
  }
}

class _CaseTile extends ConsumerWidget {
  const _CaseTile({required this.record});

  final ClinicalCase record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(casePhotoCountProvider(record.id));

    return ListTile(
      leading: const Icon(Icons.folder_outlined, color: WiseTokens.wiseBlue),
      title: Text(record.displayTitle),
      subtitle: Text(
        count.maybeWhen(
          data: (value) =>
              '$value ${value == 1 ? 'photograph' : 'photographs'}',
          orElse: () => '',
        ),
      ),
    );
  }
}

final casePhotoCountProvider = FutureProvider.family<int, String>((
  ref,
  caseId,
) async {
  final repository = await ref.watch(caseRepositoryProvider.future);
  return repository.photoCount(caseId);
});
