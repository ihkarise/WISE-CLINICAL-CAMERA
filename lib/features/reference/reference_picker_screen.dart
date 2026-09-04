import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
import '../cases/cases_screen.dart';
import '../library/photo_thumbnail.dart';

/// Narrows the reference candidates to a single case, or null for all Before
/// images (Functional MOD-002: a case is one of the reference sources).
final referenceCaseFilterProvider = StateProvider<String?>((ref) => null);

/// Before photographs available as references.
final referenceCandidatesProvider = FutureProvider<List<Photo>>((ref) async {
  final repository = await ref.watch(photoRepositoryProvider.future);
  final caseId = ref.watch(referenceCaseFilterProvider);
  return caseId == null
      ? repository.getReferenceCandidates()
      : repository.getPhotos(type: PhotoType.before, caseId: caseId);
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
            const _CaseFilterRow(),
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

/// Choosing a case restricts the references to Before images in it
/// (Functional MOD-002). Hidden until at least one case exists.
class _CaseFilterRow extends ConsumerWidget {
  const _CaseFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(casesProvider);
    final selected = ref.watch(referenceCaseFilterProvider);

    return cases.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WiseTokens.gutter,
                vertical: WiseTokens.space8,
              ),
              child: Row(
                children: [
                  Text('Case', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: WiseTokens.space8),
                  DropdownButton<String?>(
                    value: list.any((c) => c.id == selected) ? selected : null,
                    hint: const Text('All cases'),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('All cases')),
                      for (final record in list)
                        DropdownMenuItem<String?>(
                          value: record.id,
                          child: Text(record.displayTitle),
                        ),
                    ],
                    onChanged: (value) => ref
                        .read(referenceCaseFilterProvider.notifier)
                        .state = value,
                  ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
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
            const SizedBox(width: WiseTokens.space8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Import from File'),
                onPressed: _busy ? null : _importFromFile,
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

      await _importBytes(await picked.readAsBytes());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Importing a reference from the file system (Functional MOD-002 Files
  /// source). Unlike the gallery, a user-mediated file picker grants access to
  /// the chosen file only, so no photo-library permission is requested.
  Future<void> _importFromFile() async {
    setState(() => _busy = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      await _importBytes(await file.readAsBytes());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copies the imported bytes into WISE storage rather than referencing them
  /// in place, so the reference cannot vanish when the user tidies the source.
  /// The source file is left untouched (Functional section 33).
  Future<void> _importBytes(Uint8List bytes) async {
    final repository = await ref.read(photoRepositoryProvider.future);
    final user = await ref.read(currentUserProvider.future);

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
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
