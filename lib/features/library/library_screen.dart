import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/wise_empty_state.dart';
import 'photo_thumbnail.dart';

/// The current library filter (Build Specification section 107).
class LibraryFilter {
  const LibraryFilter({this.type, this.bodyPart});

  final PhotoType? type;
  final BodyPart? bodyPart;

  LibraryFilter copyWith({
    PhotoType? type,
    BodyPart? bodyPart,
    bool clearType = false,
    bool clearBodyPart = false,
  }) => LibraryFilter(
    type: clearType ? null : (type ?? this.type),
    bodyPart: clearBodyPart ? null : (bodyPart ?? this.bodyPart),
  );
}

final libraryFilterProvider = StateProvider<LibraryFilter>(
  (ref) => const LibraryFilter(),
);

final libraryPhotosProvider = FutureProvider<List<Photo>>((ref) async {
  final repository = await ref.watch(photoRepositoryProvider.future);
  final filter = ref.watch(libraryFilterProvider);
  return repository.getPhotos(type: filter.type, bodyPart: filter.bodyPart);
});

/// The photograph library (UX/UI section 44).
///
/// Browses on thumbnails and metadata, never full originals
/// (Build Specification section 107). Search stays local: the library is never
/// uploaded to implement it (Build Specification section 108).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(libraryPhotosProvider);
    final filter = ref.watch(libraryFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: WiseTokens.gutter,
              vertical: WiseTokens.space8,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filter.type == null,
                  onSelected: () => ref
                      .read(libraryFilterProvider.notifier)
                      .update((f) => f.copyWith(clearType: true)),
                ),
                for (final type in PhotoType.values)
                  Padding(
                    padding: const EdgeInsets.only(left: WiseTokens.space8),
                    child: _FilterChip(
                      label: type.wireName,
                      selected: filter.type == type,
                      onSelected: () => ref
                          .read(libraryFilterProvider.notifier)
                          .update((f) => f.copyWith(type: type)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: photos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const WiseEmptyState(
                message: WiseStrings.emptyLibrary,
                icon: Icons.error_outline,
              ),
              data: (list) => list.isEmpty
                  ? const WiseEmptyState(message: WiseStrings.emptyLibrary)
                  : GridView.builder(
                      padding: const EdgeInsets.all(WiseTokens.gutter),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: WiseTokens.space8,
                            crossAxisSpacing: WiseTokens.space8,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: list.length,
                      itemBuilder: (context, index) => PhotoThumbnail(
                        photo: list[index],
                        size: double.infinity,
                        onTap: () => Navigator.of(context).pushNamed(
                          WiseRoutes.photoDetail,
                          arguments: list[index],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: true,
  );
}
