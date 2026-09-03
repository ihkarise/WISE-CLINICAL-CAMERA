import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// SHA-256 file integrity (Data Model section 39).
///
/// Used to detect accidental corruption, identify duplicate imports and verify
/// that an original is byte-for-byte unchanged. The immutability test hashes an
/// original before and after a full annotate/measure/export cycle.
abstract final class Checksum {
  /// Streams the file so a large photograph is never fully buffered
  /// (Data Model section 70, Technical Architecture section 42).
  static Future<String> ofFile(File file) async {
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return sink.digest.toString();
  }

  static String ofBytes(Uint8List bytes) => sha256.convert(bytes).toString();
}

/// Captures the single digest emitted by a chunked SHA-256 conversion.
class _DigestSink implements Sink<Digest> {
  late final Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
