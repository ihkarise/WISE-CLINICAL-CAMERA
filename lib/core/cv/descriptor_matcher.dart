import 'alignment_config.dart';
import 'keypoint.dart';

/// Brute-force Hamming matching with ambiguity filtering (CV section 14).
///
/// Three filters, in the order the specification lists them:
/// 1. absolute distance cut-off
/// 2. Lowe ratio test — reject a match that is barely better than the runner-up
/// 3. cross-check — keep only mutually-best pairs
///
/// The ratio test and cross-check exist specifically to suppress false
/// correspondences, which is the failure mode that produces a *confident wrong*
/// alignment. Testing section 79 makes avoiding that a first-class requirement,
/// so these filters are deliberately strict.
class DescriptorMatcher {
  const DescriptorMatcher([this.config = const AlignmentConfig()]);

  final AlignmentConfig config;

  List<FeatureMatch> match(
    List<Descriptor> reference,
    List<Descriptor> target,
  ) {
    if (reference.isEmpty || target.isEmpty) return const <FeatureMatch>[];

    final forward = _bestMatches(reference, target);
    final backward = _bestMatches(target, reference);

    final matches = <FeatureMatch>[];
    for (var i = 0; i < forward.length; i++) {
      final candidate = forward[i];
      if (candidate == null) continue;

      // Cross-check: the target's own best match must point back here.
      // A one-directional best match is often a repeated texture matching an
      // arbitrary instance of itself.
      if (backward[candidate.index]?.index != i) continue;

      matches.add(
        FeatureMatch(
          referenceIndex: i,
          targetIndex: candidate.index,
          distance: candidate.best,
          ratio: candidate.ratio,
        ),
      );
    }

    matches.sort((a, b) => a.distance.compareTo(b.distance));
    return matches;
  }

  List<({int index, int best, double ratio})?> _bestMatches(
    List<Descriptor> from,
    List<Descriptor> to,
  ) {
    final results = List<({int index, int best, double ratio})?>.filled(
      from.length,
      null,
    );

    for (var i = 0; i < from.length; i++) {
      var bestDistance = Descriptor.lengthBits + 1;
      var secondDistance = Descriptor.lengthBits + 1;
      var bestIndex = -1;

      for (var j = 0; j < to.length; j++) {
        final distance = from[i].distanceTo(to[j]);
        if (distance < bestDistance) {
          secondDistance = bestDistance;
          bestDistance = distance;
          bestIndex = j;
        } else if (distance < secondDistance) {
          secondDistance = distance;
        }
      }

      if (bestIndex < 0 || bestDistance > config.maxHammingDistance) continue;

      // With only one candidate there is nothing to compare against, so the
      // match is treated as maximally ambiguous rather than accepted.
      final ratio = secondDistance > Descriptor.lengthBits
          ? 1.0
          : bestDistance / (secondDistance == 0 ? 1 : secondDistance);

      if (ratio > config.loweRatio) continue;

      results[i] = (index: bestIndex, best: bestDistance, ratio: ratio);
    }
    return results;
  }
}
