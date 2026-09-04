import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/alignment_config.dart';
import 'package:wise_clinical_camera/core/cv/confidence_model.dart';
import 'package:wise_clinical_camera/core/cv/local_alignment_engine.dart';
import 'package:wise_clinical_camera/core/cv/transform_estimator.dart';
import 'package:wise_clinical_camera/models/enums.dart';

import '../support/cv_dataset.dart';

/// False-confidence testing (Testing section 79, CV sections 22-23, 29, 71;
/// master prompt Phases 17 and 46).
///
/// This is the safety-critical CV suite. The dangerous failure is not "the
/// engine could not align" — that is handled and reported. It is "the engine
/// reported a good alignment that is wrong", because the clinician then
/// captures an After believing it reproduces the Before when it does not, and
/// the two photographs are compared as if they matched.
///
/// Every test here asserts that the system **lowers confidence or declines**
/// rather than asserting a good match.
void main() {
  group('degenerate evidence is refused', () {
    late LocalAlignmentEngine engine;

    setUp(() => engine = LocalAlignmentEngine());

    test('ALG-T007 a repeating pattern does not align confidently', () async {
      // Every cell of a checkerboard looks like every other. A matcher without
      // ambiguity filtering will match the wrong cell and report a confident,
      // wrong offset. The Lowe ratio test and cross-check exist for this.
      final pattern = CvDataset.repeatingPattern();
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(pattern),
      );

      if (prepared.isFailure) return; // Declining outright is also correct.

      // Shift by exactly one period: every feature has a plausible but wrong
      // partner one cell over.
      final shifted = CvDataset.transform(pattern, translateX: 20);
      final result = await engine.analyzeFrame(
        frame: CvDataset.toWorking(shifted),
        reference: prepared.valueOrNull!,
      );

      expect(
        result.isReady,
        isFalse,
        reason:
            'a repeating pattern shifted by one period must never report '
            'ready to capture',
      );
    });

    test('ALG-T008 detail in one corner does not align confidently', () async {
      // Computer Vision section 23: matches concentrated in one small region
      // cannot constrain the transform, however many of them agree.
      final scene = CvDataset.concentratedDetail();
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(scene),
      );

      if (prepared.isFailure) return;

      final result = await engine.analyzeFrame(
        frame: CvDataset.toWorking(scene),
        reference: prepared.valueOrNull!,
      );

      expect(
        result.status,
        isNot(AlignmentStatus.good),
        reason:
            'identical images must still not read as GOOD when the only '
            'matching detail sits in one corner',
      );
    });

    test('heavy occlusion lowers confidence', () async {
      final scene = CvDataset.texturedScene();
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(scene),
      );

      final clear = await engine.analyzeFrame(
        frame: CvDataset.toWorking(scene),
        reference: prepared.valueOrNull!,
      );
      engine.reset();
      final occluded = await engine.analyzeFrame(
        frame: CvDataset.toWorking(CvDataset.occlude(scene, 0.6)),
        reference: prepared.valueOrNull!,
      );

      expect(
        occluded.confidence,
        lessThan(clear.confidence),
        reason: 'covering most of the frame must reduce confidence',
      );
    });

    test('a blank frame is refused, not scored low', () async {
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(CvDataset.texturedScene()),
      );

      final result = await engine.analyzeFrame(
        frame: CvDataset.toWorking(CvDataset.flatScene()),
        reference: prepared.valueOrNull!,
      );

      // UNAVAILABLE, not POOR: a number still reads as an estimate, and there
      // isn't one.
      expect(result.status, AlignmentStatus.unavailable);
      expect(result.confidence, 0);
      expect(result.transform, isNull);
    });
  });

  group('confidence gates', () {
    const config = AlignmentConfig();
    const model = ConfidenceModel(config);

    TransformEstimate estimate({
      int inliers = 40,
      int candidates = 60,
      double spread = 0.3,
      int quadrants = 4,
      double error = 1,
      bool hasTransform = true,
    }) => TransformEstimate(
      transform: hasTransform ? SimilarityTransform.identity : null,
      inlierIndices: List<int>.generate(inliers, (i) => i),
      candidateCount: candidates,
      meanReprojectionError: error,
      spatialSpread: spread,
      quadrantsCovered: quadrants,
    );

    test('accepts strong evidence', () {
      // Nearly every candidate agrees, spread across the frame.
      final strong = estimate(inliers: 57, candidates: 60, spread: 0.34);

      expect(model.rejectionReason(strong), isNull);
      expect(model.score(strong), greaterThan(config.fairConfidence));
    });

    test('mediocre evidence scores below GOOD', () {
      // A third of candidates disagreeing is not a good match, even with 40
      // inliers and a reasonable spread. The model is deliberately biased
      // toward under-confidence (Computer Vision section 71): the costly
      // failure is a high score on a wrong alignment, so evidence that is
      // merely acceptable must not read as GOOD.
      final mediocre = estimate(inliers: 40, candidates: 60);

      expect(model.rejectionReason(mediocre), isNull);
      expect(model.score(mediocre), lessThan(config.goodConfidence));
    });

    test('rejects too few inliers however good the ratio', () {
      // 100% of 4 matches is still 4 matches.
      final reason = model.rejectionReason(estimate(inliers: 4, candidates: 4));
      expect(reason, isNotNull);
      expect(reason, contains('Too few'));
    });

    test('rejects a low inlier ratio however many inliers', () {
      // 20 inliers out of 400 candidates means most matches disagreed.
      expect(
        model.rejectionReason(estimate(inliers: 20, candidates: 400)),
        isNotNull,
      );
    });

    test('rejects concentrated inliers however many there are', () {
      // The Computer Vision section 23 failure mode, stated as a gate.
      final reason = model.rejectionReason(
        estimate(inliers: 200, candidates: 210, spread: 0.02, quadrants: 1),
      );
      expect(reason, isNotNull);
      expect(reason, contains('one small area'));
    });

    test('rejects inliers covering too few quadrants', () {
      expect(
        model.rejectionReason(estimate(spread: 0.3, quadrants: 1)),
        isNotNull,
      );
    });

    test('rejects a large reprojection error', () {
      expect(model.rejectionReason(estimate(error: 100)), isNotNull);
    });

    test('rejects a non-finite reprojection error', () {
      expect(
        model.rejectionReason(estimate(error: double.infinity)),
        isNotNull,
      );
    });

    test('rejects a missing transform', () {
      expect(model.rejectionReason(estimate(hasTransform: false)), isNotNull);
    });

    test('poor spread caps the score even when everything else is strong', () {
      // The multiplicative gate: a weighted mean alone would let a high inlier
      // count mask a spread that cannot constrain the transform.
      final strong = model.score(estimate(spread: 0.34));
      final concentrated = model.score(estimate(spread: 0.13));

      expect(concentrated, lessThan(strong));
    });

    test('a rejection reason is plain language, not CV jargon', () {
      for (final reason in [
        model.rejectionReason(estimate(inliers: 2, candidates: 2)),
        model.rejectionReason(estimate(spread: 0.01, quadrants: 1)),
        model.rejectionReason(estimate(hasTransform: false)),
      ]) {
        expect(reason, isNotNull);
        final text = reason!.toLowerCase();
        for (final term in const [
          'ransac',
          'homography',
          'descriptor',
          'hamming',
          'matrix',
        ]) {
          expect(text, isNot(contains(term)));
        }
      }
    });
  });

  group('implausible transforms are rejected', () {
    const config = AlignmentConfig();

    test('a scale beyond plausible limits is refused', () {
      // Computer Vision section 22: "scale is within plausible limits".
      expect(
        const SimilarityTransform(
          scale: 40,
          rotationRadians: 0,
          translationX: 0,
          translationY: 0,
        ).isPlausible(config),
        isFalse,
      );
      expect(
        const SimilarityTransform(
          scale: 0.01,
          rotationRadians: 0,
          translationX: 0,
          translationY: 0,
        ).isPlausible(config),
        isFalse,
      );
    });

    test('a non-finite transform is refused', () {
      expect(
        const SimilarityTransform(
          scale: double.nan,
          rotationRadians: 0,
          translationX: 0,
          translationY: 0,
        ).isPlausible(config),
        isFalse,
      );
      expect(
        SimilarityTransform(
          scale: 1,
          rotationRadians: 0,
          translationX: double.infinity,
          translationY: 0,
        ).isPlausible(config),
        isFalse,
      );
    });

    test('an ordinary transform is accepted', () {
      expect(
        const SimilarityTransform(
          scale: 1.1,
          rotationRadians: 0.05,
          translationX: 12,
          translationY: -8,
        ).isPlausible(config),
        isTrue,
      );
    });
  });

  group('readiness requires more than a high score', () {
    test('a good score with one dimension off is not ready', () async {
      // isReady requires GOOD *and* every dimension satisfied. Otherwise the
      // clinician is told to capture a frame that does not actually match.
      final engine = LocalAlignmentEngine();
      final scene = CvDataset.texturedScene();
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(scene),
      );

      final shifted = await engine.analyzeFrame(
        frame: CvDataset.toWorking(
          CvDataset.transform(scene, translateX: 30, translateY: 20),
        ),
        reference: prepared.valueOrNull!,
      );

      expect(shifted.status, AlignmentStatus.good);
      expect(shifted.dimensions.position, isFalse);
      expect(
        shifted.isReady,
        isFalse,
        reason: 'a high score with the framing off must not read as ready',
      );
    });
  });
}
