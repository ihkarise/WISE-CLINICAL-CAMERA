import 'dart:typed_data';

import '../errors/result.dart';
import 'alignment_result.dart';
import 'keypoint.dart';
import 'working_image.dart';

/// Everything precomputed from the Before photograph (CV section 7).
///
/// Built once when a reference is selected and reused for every live frame, so
/// the expensive detection work does not repeat at frame rate.
class ReferenceFeatures {
  const ReferenceFeatures({
    required this.photoId,
    required this.image,
    required this.keypoints,
    required this.descriptors,
    required this.engineVersion,
    this.sourceWidth = 0,
    this.sourceHeight = 0,
  });

  final String photoId;

  /// The grayscale working-resolution copy. The original is never modified
  /// (CV section 6).
  final WorkingImage image;

  final List<Keypoint> keypoints;
  final List<Descriptor> descriptors;

  /// Dimensions of the original, so a working-resolution transform can be
  /// mapped back.
  final int sourceWidth;
  final int sourceHeight;

  final String engineVersion;

  /// Whether the reference carries enough detail to align against at all.
  ///
  /// A reference that fails this is not a bug: a flat, low-texture clinical
  /// image genuinely cannot be matched, and saying so beats guessing
  /// (CV section 60).
  bool get isUsable => keypoints.length >= 12;
}

/// The interface the rest of the application depends on (CV section 75).
///
/// Features and screens talk to this, never to a detector or matcher. That is
/// what lets the pure-Dart implementation be swapped for a native one after
/// benchmarking, and what keeps the CV stack reusable by other WISE products
/// (CV sections 74, 77; master prompt Phase 54).
abstract class AlignmentEngine {
  /// Version stamped onto every stored result so it can be reprocessed when
  /// the algorithm changes (CV section 53).
  String get engineVersion;

  /// Prepares a reference for repeated frame comparison.
  Future<Result<ReferenceFeatures>> prepareReference({
    required String photoId,
    required Uint8List imageBytes,
  });

  /// Compares one live frame against the prepared reference.
  Future<AlignmentResult> analyzeFrame({
    required WorkingImage frame,
    required ReferenceFeatures reference,
  });

  /// Aligns two stored photographs, for comparison rendering.
  Future<AlignmentResult> align({
    required Uint8List referenceBytes,
    required Uint8List targetBytes,
  });

  /// Clears any per-session state, such as the temporal smoothing history.
  void reset();
}
