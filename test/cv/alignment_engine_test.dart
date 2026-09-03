import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/alignment_config.dart';
import 'package:wise_clinical_camera/core/cv/local_alignment_engine.dart';
import 'package:wise_clinical_camera/models/enums.dart';

import '../support/cv_dataset.dart';

/// Alignment regression suite (CV sections 65-70, Testing sections 12-14).
///
/// Every case here has a *known* transform, so the estimate can be scored
/// against ground truth rather than merely inspected. See
/// `test/support/cv_dataset.dart` for what this dataset can and cannot
/// validate.
void main() {
  late LocalAlignmentEngine engine;

  setUp(() {
    engine = LocalAlignmentEngine();
  });

  Future<({dynamic reference, dynamic result})> runCase({
    double translateX = 0,
    double translateY = 0,
    double rotationDegrees = 0,
    double scale = 1,
    int seed = 42,
  }) async {
    final scene = CvDataset.texturedScene(seed: seed);
    final prepared = await engine.prepareReference(
      photoId: 'ref',
      imageBytes: CvDataset.toJpeg(scene),
    );
    expect(
      prepared.isOk,
      isTrue,
      reason:
          'the textured reference must be usable: ${prepared.failureOrNull}',
    );

    final transformed = CvDataset.transform(
      scene,
      translateX: translateX,
      translateY: translateY,
      rotationDegrees: rotationDegrees,
      scale: scale,
    );

    final result = await engine.analyzeFrame(
      frame: CvDataset.toWorking(transformed),
      reference: prepared.valueOrNull!,
    );
    return (reference: prepared.valueOrNull, result: result);
  }

  group('ALG-T001 identical images', () {
    test('reports a good alignment with an identity transform', () async {
      final outcome = await runCase();
      final result = outcome.result;

      expect(result.isAvailable, isTrue);
      expect(result.status, AlignmentStatus.good);
      expect(result.confidence, greaterThan(0.7));
      expect(result.translationX.abs(), lessThan(0.02));
      expect(result.translationY.abs(), lessThan(0.02));
      expect(result.rotationDegrees.abs(), lessThan(1.5));
      expect(result.scale, closeTo(1, 0.05));
      expect(result.dimensions.allSatisfied, isTrue);
      expect(result.isReady, isTrue);
    });

    test('stamps the engine version on the result', () async {
      // Computer Vision section 53: every CV result records its engine version
      // so it can be reprocessed later.
      final outcome = await runCase();
      expect(outcome.result.engineVersion, LocalAlignmentEngine.version);
    });
  });

  group('ALG-T002 translation', () {
    test('recovers the direction and rough magnitude of a shift', () async {
      // The frame is shifted +30 px right and +20 px down on a 320 px canvas.
      final outcome = await runCase(translateX: 30, translateY: 20);
      final result = outcome.result;

      expect(result.isAvailable, isTrue);
      expect(
        result.translationX,
        greaterThan(0.04),
        reason: 'a rightward shift must read as positive x',
      );
      expect(result.translationY, greaterThan(0.02));
      expect(result.dimensions.position, isFalse);
    });

    test('a shift the other way reverses the sign', () async {
      final outcome = await runCase(translateX: -30);
      expect(outcome.result.translationX, lessThan(-0.04));
    });
  });

  group('ALG-T003 rotation', () {
    test('recovers a small rotation to within two degrees', () async {
      final outcome = await runCase(rotationDegrees: 6);
      final result = outcome.result;

      expect(result.isAvailable, isTrue);
      expect(result.rotationDegrees.abs(), closeTo(6, 2));
      expect(result.dimensions.rotation, isFalse);
    });
  });

  group('ALG-T004 scale', () {
    test('recovers a scale increase', () async {
      final outcome = await runCase(scale: 1.2);
      final result = outcome.result;

      expect(result.isAvailable, isTrue);
      expect(
        result.scale,
        greaterThan(1.05),
        reason: 'a subject filling more of the frame must read as scale > 1',
      );
      expect(result.dimensions.scale, isFalse);
    });

    test('recovers a scale decrease', () async {
      final outcome = await runCase(scale: 0.82);
      expect(outcome.result.scale, lessThan(0.95));
    });
  });

  group('ALG-T006 low texture', () {
    test('a flat reference is refused rather than accepted', () async {
      // Computer Vision section 60: insufficient features is a real failure
      // condition and must be reported, not worked around.
      final prepared = await engine.prepareReference(
        photoId: 'flat',
        imageBytes: CvDataset.toJpeg(CvDataset.flatScene()),
      );

      expect(prepared.isFailure, isTrue);
      expect(
        prepared.failureOrNull!.userMessage,
        contains('Ghost Overlay'),
        reason: 'the user must be told the fallback still works',
      );
    });

    test('a flat frame against a good reference is unavailable', () async {
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(CvDataset.texturedScene()),
      );

      final result = await engine.analyzeFrame(
        frame: CvDataset.toWorking(CvDataset.flatScene()),
        reference: prepared.valueOrNull!,
      );

      expect(result.status, AlignmentStatus.unavailable);
      expect(result.confidence, 0);
      expect(result.unavailableReason, isNotNull);
    });
  });

  group('ALG-T009 large viewpoint change', () {
    test('an unrelated scene does not produce a confident match', () async {
      // Two different scenes must not align. A confident answer here would be
      // the worst possible failure: the clinician captures believing the frames
      // match (Computer Vision section 71).
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(CvDataset.texturedScene(seed: 1)),
      );

      final result = await engine.analyzeFrame(
        frame: CvDataset.toWorking(CvDataset.texturedScene(seed: 900)),
        reference: prepared.valueOrNull!,
      );

      expect(
        result.isReady,
        isFalse,
        reason: 'an unrelated scene must never report ready to capture',
      );
      expect(result.status, isNot(AlignmentStatus.good));
    });
  });

  group('failure handling', () {
    test('unreadable bytes fail without throwing', () async {
      final prepared = await engine.prepareReference(
        photoId: 'bad',
        imageBytes: CvDataset.toJpeg(CvDataset.texturedScene()).sublist(0, 10),
      );
      expect(prepared.isFailure, isTrue);
    });

    test('the unavailable message contains no CV terminology', () async {
      // Computer Vision section 61: never show "Homography matrix singular."
      final prepared = await engine.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(CvDataset.texturedScene()),
      );
      final result = await engine.analyzeFrame(
        frame: CvDataset.toWorking(CvDataset.flatScene()),
        reference: prepared.valueOrNull!,
      );

      final message = result.unavailableReason!.toLowerCase();
      for (final term in const [
        'homography',
        'ransac',
        'descriptor',
        'keypoint',
        'matrix',
        'inlier',
        'singular',
        'orb',
        'hamming',
      ]) {
        expect(
          message,
          isNot(contains(term)),
          reason: 'user-facing text must not contain "$term"',
        );
      }
    });

    test('reset clears smoothing state between sessions', () async {
      await runCase(translateX: 40);
      engine.reset();

      // With history cleared, an identical frame must read as aligned rather
      // than being dragged toward the previous offset.
      final outcome = await runCase();
      expect(outcome.result.translationX.abs(), lessThan(0.02));
    });
  });

  group('configurability', () {
    test('thresholds come from configuration, not from constants', () async {
      // Functional ALG-006 and Build Specification section 86: thresholds must
      // be configurable for testing without rebuilding the architecture.
      final strict = LocalAlignmentEngine(
        config: const AlignmentConfig(
          goodConfidence: 0.99,
          fairConfidence: 0.98,
        ),
      );

      final scene = CvDataset.texturedScene();
      final prepared = await strict.prepareReference(
        photoId: 'ref',
        imageBytes: CvDataset.toJpeg(scene),
      );
      final result = await strict.analyzeFrame(
        frame: CvDataset.toWorking(scene),
        reference: prepared.valueOrNull!,
      );

      expect(
        result.status,
        isNot(AlignmentStatus.good),
        reason: 'raising the threshold must change the reported status',
      );
    });
  });
}
