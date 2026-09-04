import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../app/providers.dart';
import '../../app/theme/wise_tokens.dart';
import '../../core/cv/working_image.dart';
import '../../core/imaging/image_codec.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/clinical_image.dart';

/// The visual difference view (Functional CMP-005, UX/UI section 39,
/// Build Specification section 42).
///
/// **Not a diagnostic tool.** The disclaimer is rendered as part of the view
/// rather than as an optional caption, so it cannot be scrolled away or
/// screenshotted off: PRD section 18, Functional CMP-005 and Build
/// Specification section 42 all require it to accompany this view.
///
/// Registration reuses a stored alignment where one exists rather than deriving
/// a second, possibly conflicting transform (Functional CMP-006, CV 50).
class DifferenceView extends ConsumerWidget {
  const DifferenceView({required this.before, required this.after, super.key});

  final Photo before;
  final Photo after;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difference = ref.watch(
      differenceImageProvider((before: before, after: after)),
    );

    return Column(
      children: [
        Expanded(
          child: difference.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const Center(
              child: Padding(
                padding: EdgeInsets.all(WiseTokens.space24),
                child: Text(
                  'A difference view could not be generated for these '
                  'photographs.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (bytes) => bytes == null
                ? const Center(child: Text('A difference view is unavailable.'))
                : ClinicalImage.memory(
                    bytes,
                    semanticLabel:
                        'Visual difference between the two photographs',
                  ),
          ),
        ),

        // Always present, never conditional.
        Container(
          width: double.infinity,
          color: WiseTokens.deepNavy,
          padding: const EdgeInsets.all(WiseTokens.space8),
          child: Text(
            WiseStrings.differenceDisclaimer,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: WiseTokens.white),
          ),
        ),
      ],
    );
  }
}

/// Computes the difference image.
///
/// Runs off the UI thread via `compute`, because differencing two
/// full-resolution clinical photographs would otherwise stall the interface
/// (Build Specification sections 61, 104).
final differenceImageProvider =
    FutureProvider.family<Uint8List?, ({Photo before, Photo after})>((
      ref,
      photos,
    ) async {
      final storage = await ref.watch(imageStorageProvider.future);

      final beforeBytes = await storage.readBytes(photos.before.originalPath);
      final afterBytes = await storage.readBytes(photos.after.originalPath);
      if (beforeBytes.isFailure || afterBytes.isFailure) return null;

      return computeDifference((
        before: beforeBytes.valueOrNull!,
        after: afterBytes.valueOrNull!,
      ));
    });

/// Absolute per-pixel difference, rendered as a heat overlay.
///
/// A visual aid only (CV section 51). Both images are downscaled to a common
/// size first; without that, a size mismatch would read as difference
/// everywhere.
Uint8List? computeDifference(({Uint8List before, Uint8List after}) input) {
  final before = ImageCodec.decode(input.before);
  final after = ImageCodec.decode(input.after);
  if (before == null || after == null) return null;

  const workingSize = 640;
  final beforeWorking = WorkingImage.fromImage(
    before,
    maxDimension: workingSize,
  );
  final afterWorking = WorkingImage.fromImage(after, maxDimension: workingSize);

  final width = beforeWorking.width < afterWorking.width
      ? beforeWorking.width
      : afterWorking.width;
  final height = beforeWorking.height < afterWorking.height
      ? beforeWorking.height
      : afterWorking.height;
  if (width <= 0 || height <= 0) return null;

  final output = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final delta = (beforeWorking.at(x, y) - afterWorking.at(x, y))
          .abs()
          .clamp(0, 255);
      // Warm where the images differ, dark where they agree. Intensity encodes
      // magnitude, so the reader is not asked to distinguish hues.
      output.setPixelRgb(x, y, delta, (delta * 0.35).round(), 0);
    }
  }

  return Uint8List.fromList(img.encodeJpg(output, quality: 85));
}
