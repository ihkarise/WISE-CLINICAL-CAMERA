import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/wise_empty_state.dart';
import '../library/photo_thumbnail.dart';

/// Before photographs available as references.
final referenceCandidatesProvider = FutureProvider<List<Photo>>((ref) async {
  final repository = await ref.watch(photoRepositoryProvider.future);
  return repository.getReferenceCandidates();
});

/// Selecting the Before to reproduce (UX/UI section 16, Functional MOD-002,
/// Build Specification section 16).
///
/// Sources: the WISE library first, since Before images are prioritised
/// (Build Specification section 16), then the device gallery and Files.
/// Gallery permission is requested only when the clinician chooses to import,
/// never on entry (Privacy section 8).
class ReferencePickerScreen extends ConsumerWidget {
  const ReferencePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(referenceCandidatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(WiseStrings.chooseBefore)),
      body: candidates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const WiseEmptyState(
          message: WiseStrings.emptyReference,
          icon: Icons.error_outline,
        ),
        data: (photos) => Column(
          children: [
            Expanded(
              child: photos.isEmpty
                  ? const WiseEmptyState(
                      message: WiseStrings.emptyReference,
                      icon: Icons.filter_1_outlined,
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(WiseTokens.gutter),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: WiseTokens.space8,
                            crossAxisSpacing: WiseTokens.space8,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) => PhotoThumbnail(
                        photo: photos[index],
                        size: double.infinity,
                        onTap: () => _useReference(context, photos[index]),
                      ),
                    ),
            ),
            _ImportRow(onImported: (photo) => _useReference(context, photo)),
          ],
        ),
      ),
    );
  }

  void _useReference(BuildContext context, Photo reference) {
    Navigator.of(context).pushReplacementNamed(
      WiseRoutes.capture,
      arguments: CaptureArguments(
        type: PhotoType.after,
        referencePhoto: reference,
      ),
    );
  }
}

/// Importing a reference from outside WISE (Functional section 33).
class _ImportRow extends ConsumerStatefulWidget {
  const _ImportRow({required this.onImported});

  final ValueChanged<Photo> onImported;

  @override
  ConsumerState<_ImportRow> createState() => _ImportRowState();
}

class _ImportRowState extends ConsumerState<_ImportRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WiseTokens.gutter),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Import from Gallery'),
                onPressed: _busy ? null : _importFromGallery,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromGallery() async {
    setState(() => _busy = true);
    try {
      // Permission is requested here, at the point of use (Privacy section 8).
      final permission = await ref
          .read(permissionServiceProvider)
          .requestPhotoLibrary();
      if (permission.isFailure) {
        _showMessage(permission.failureOrNull!.userMessage);
        return;
      }

      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final repository = await ref.read(photoRepositoryProvider.future);
      final user = await ref.read(currentUserProvider.future);

      // The imported file is copied into WISE storage rather than referenced
      // in place, so the reference cannot vanish when the user tidies their
      // gallery. The source is left untouched (Functional section 33).
      final created = await repository.createPhoto(
        bytes: bytes,
        type: PhotoType.before,
        source: PhotoSource.import,
        userId: user.id,
      );

      if (created.isFailure) {
        _showMessage(created.failureOrNull!.userMessage);
        return;
      }

      ref.invalidate(referenceCandidatesProvider);
      widget.onImported(created.valueOrNull!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
