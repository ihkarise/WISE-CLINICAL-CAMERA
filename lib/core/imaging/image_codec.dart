import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decoding that cannot throw.
///
/// `package:image`'s `decodeImage` probes each format in turn, and several
/// probes read past the end of a short or malformed buffer, throwing
/// `RangeError` rather than returning null. A truncated download, a partially
/// written file or a mislabelled extension would therefore crash rather than
/// fail cleanly, which Build Specification section 92 ("handle corrupt image")
/// and section 91 (never surface a raw exception) both forbid.
///
/// Every decode in the application goes through here.
abstract final class ImageCodec {
  /// Decodes, returning null for anything unreadable.
  static img.Image? decode(Uint8List bytes) {
    if (bytes.length < _minimumPlausibleLength) return null;
    try {
      return img.decodeImage(bytes);
    } on Object {
      // Any decoder failure means "not a readable image". The specific
      // exception varies by format and carries no information a caller could
      // act on differently.
      return null;
    }
  }

  /// Dimensions without keeping the decoded image alive.
  static ({int width, int height})? probeDimensions(Uint8List bytes) {
    final decoded = decode(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }
    return (width: decoded.width, height: decoded.height);
  }

  /// Shorter than the smallest possible header of any supported format.
  static const int _minimumPlausibleLength = 16;
}
