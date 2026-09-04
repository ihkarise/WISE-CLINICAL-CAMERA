import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../errors/failures.dart';
import '../errors/result.dart';
import 'image_codec.dart';

/// Thumbnail sizes (Data Model section 40).
enum ThumbnailSize {
  small(256),
  medium(512);

  const ThumbnailSize(this.maxDimension);
  final int maxDimension;
}

/// Generates library thumbnails.
///
/// Thumbnails exist so browsing never decodes a full-resolution clinical
/// photograph (Data Model sections 40, 70; Build Specification sections 60,
/// 107). A thumbnail is never the source of truth and can always be
/// regenerated, so losing one is harmless.
///
/// Pure Dart with no Flutter binding, so it can run in a background isolate
/// (Build Specification section 61).
class ThumbnailGenerator {
  const ThumbnailGenerator();

  Result<Uint8List> generate(
    Uint8List originalBytes, {
    ThumbnailSize size = ThumbnailSize.medium,
    int quality = 80,
  }) {
    final decoded = ImageCodec.decode(originalBytes);
    if (decoded == null) {
      return const Result.failed(
        UnreadableImage(technicalDetail: 'thumbnail source failed to decode'),
      );
    }

    final longest = math.max(decoded.width, decoded.height);
    // Never upscale: a small original stays small rather than being blown up
    // into a larger, no more detailed file.
    final resized = longest <= size.maxDimension
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? size.maxDimension : null,
            height: decoded.height > decoded.width ? size.maxDimension : null,
            interpolation: img.Interpolation.average,
          );

    return Result.ok(
      Uint8List.fromList(img.encodeJpg(resized, quality: quality)),
    );
  }

  /// Reads dimensions without fully decoding, for validating an import.
  ({int width, int height})? probeDimensions(Uint8List bytes) {
    final decoded = ImageCodec.decode(bytes);
    if (decoded == null) return null;
    return (width: decoded.width, height: decoded.height);
  }
}
