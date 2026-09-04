import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import 'photo_thumbnail.dart';

/// Recent photographs on the home screen (UX/UI section 8).
final recentPhotosProvider = FutureProvider<List<Photo>>((ref) async {
  final repository = await ref.watch(photoRepositoryProvider.future);
  return repository.getPhotos(limit: 20);
});

class RecentPhotosStrip extends ConsumerWidget {
  const RecentPhotosStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(recentPhotosProvider);

    return photos.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      // A storage or database problem must not blank the home screen.
      error: (error, stack) => Center(
        child: Text(
          WiseStrings.emptyLibrary,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              WiseStrings.emptyLibrary,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          );
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: WiseTokens.space8),
          itemBuilder: (context, index) => PhotoThumbnail(
            photo: list[index],
            onTap: () => Navigator.of(
              context,
            ).pushNamed(WiseRoutes.photoDetail, arguments: list[index]),
          ),
        );
      },
    );
  }
}
