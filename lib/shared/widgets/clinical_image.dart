import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';

/// Displays a clinical photograph at a bounded decode resolution.
///
/// Exists for one reason: memory. `Image.file` decodes at the file's full
/// resolution regardless of how large it is drawn. A 12 MP clinical photograph
/// occupies roughly 48 MB once decoded, the comparison screen shows two at
/// once, and the ghost overlay sits on top of a camera preview that is already
/// holding its own buffers. Flutter's default image cache is 100 MB, so a
/// handful of photographs is enough to start thrashing it — and on a low-end
/// device, to be killed outright.
///
/// Technical Architecture section 42 and Build Specification section 62 both
/// require avoiding unnecessary full-resolution copies; Phase 2 section 33
/// asks specifically that the app degrade gracefully on weaker hardware.
///
/// This widget sizes the decode to the space the image is actually drawn in,
/// multiplied by the device pixel ratio, so nothing is decoded larger than it
/// can be seen. It never upscales the request beyond [maxDecodeWidth].
///
/// It also centralises the missing-file placeholder, which was previously
/// duplicated at six call sites with slightly different behaviour.
class ClinicalImage extends StatelessWidget {
  const ClinicalImage.file(
    this.path, {
    this.fit = BoxFit.contain,
    this.maxDecodeWidth = 2048,
    this.semanticLabel,
    super.key,
  }) : bytes = null;

  const ClinicalImage.memory(
    this.bytes, {
    this.fit = BoxFit.contain,
    this.maxDecodeWidth = 2048,
    this.semanticLabel,
    super.key,
  }) : path = null;

  final String? path;
  final Uint8List? bytes;
  final BoxFit fit;

  /// Upper bound on the decode width, whatever the layout asks for.
  ///
  /// 2048 is comfortably beyond any phone screen while cutting a 4032-wide
  /// original's decoded footprint by roughly three quarters.
  final int maxDecodeWidth;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

        // An unbounded constraint (inside a scroll view, say) gives no useful
        // target, so fall back to the screen width rather than to infinity.
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final cacheWidth = math.min(
          maxDecodeWidth,
          math.max(1, (logicalWidth * devicePixelRatio).round()),
        );

        final image = path != null
            ? Image.file(
                File(path!),
                fit: fit,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.medium,
                errorBuilder: _placeholder,
              )
            : Image.memory(
                bytes!,
                fit: fit,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.medium,
                errorBuilder: _placeholder,
              );

        return semanticLabel == null
            ? image
            : Semantics(
                label: semanticLabel,
                image: true,
                child: ExcludeSemantics(child: image),
              );
      },
    );
  }

  /// A missing or unreadable file shows a placeholder rather than crashing the
  /// screen (Build Specification section 92).
  static Widget _placeholder(
    BuildContext context,
    Object error,
    StackTrace? stack,
  ) => const ColoredBox(
    color: WiseTokens.lightGray,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: WiseTokens.slateGray),
    ),
  );
}
