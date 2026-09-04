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
/// require avoiding unnecessary full-resolution copies; Phase 2 section 33 asks
/// specifically that the application degrade gracefully on weaker hardware.
///
/// The decode is sized to the screen, or to [decodeWidth] where the caller
/// knows the box it is drawing into, multiplied by the device pixel ratio. The
/// screen width is a sound upper bound for anything drawn on screen: a
/// 4032 px original decoded at 1080 costs about a fifteenth of the memory and
/// looks identical.
///
/// It deliberately does **not** measure itself with a `LayoutBuilder`. Doing so
/// looks tempting — the exact drawn width is more precise than the screen width
/// — but a `LayoutBuilder` sizes itself to the biggest allowed size, so in any
/// unbounded box (the library grid passes an infinite height) it asserts rather
/// than rendering. An image widget has to survive being handed loose
/// constraints, because plenty of layouts do exactly that.
///
/// It also centralises the missing-file placeholder, which was previously
/// duplicated at six call sites with slightly different behaviour.
class ClinicalImage extends StatelessWidget {
  const ClinicalImage.file(
    this.path, {
    this.fit = BoxFit.contain,
    this.maxDecodeWidth = 2048,
    this.decodeWidth,
    this.semanticLabel,
    super.key,
  }) : bytes = null;

  const ClinicalImage.memory(
    this.bytes, {
    this.fit = BoxFit.contain,
    this.maxDecodeWidth = 2048,
    this.decodeWidth,
    this.semanticLabel,
    super.key,
  }) : path = null;

  final String? path;
  final Uint8List? bytes;
  final BoxFit fit;

  /// Upper bound on the decode width, whatever else is asked for.
  ///
  /// 2048 is comfortably beyond any phone screen while cutting a 4032-wide
  /// original's decoded footprint by roughly three quarters. It is the cap that
  /// still leaves room to pinch-zoom without a visible resample.
  final int maxDecodeWidth;

  /// The logical width this image is drawn at, when the caller knows it.
  ///
  /// A thumbnail is a fraction of the screen, so passing its side length here
  /// decodes a fraction of the pixels. Ignored when non-finite, which is how a
  /// grid tile asks for "as wide as you like".
  final double? decodeWidth;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final width = decodeWidth;
    final logicalWidth = (width != null && width.isFinite && width > 0)
        ? width
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
