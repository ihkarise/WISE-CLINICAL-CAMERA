import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/focus_engine.dart';
import 'package:wise_clinical_camera/core/cv/lighting_engine.dart';
import 'package:wise_clinical_camera/core/cv/quality_config.dart';
import 'package:wise_clinical_camera/models/enums.dart';

import '../support/cv_dataset.dart';

/// Lighting and focus checks (Testing sections 18-19, CV sections 41-44).
void main() {
  group('focus (FOC-T001..T003)', () {
    const engine = FocusEngine();

    test('a sharp image reports good focus', () {
      final assessment = engine.assess(
        CvDataset.toWorking(CvDataset.texturedScene()),
      );

      expect(assessment.status, FocusStatus.good);
      expect(assessment.score, greaterThan(assessment.threshold));
    });

    test('a blurred image is flagged', () {
      final blurred = CvDataset.blur(CvDataset.texturedScene(), 6);
      final assessment = engine.assess(CvDataset.toWorking(blurred));

      expect(assessment.status, FocusStatus.mayBeBlurred);
      expect(assessment.isWarning, isTrue);
    });

    test('blur reduces the score monotonically', () {
      final sharp = engine
          .assess(CvDataset.toWorking(CvDataset.texturedScene()))
          .score;
      final slight = engine
          .assess(
            CvDataset.toWorking(CvDataset.blur(CvDataset.texturedScene(), 2)),
          )
          .score;
      final heavy = engine
          .assess(
            CvDataset.toWorking(CvDataset.blur(CvDataset.texturedScene(), 8)),
          )
          .score;

      expect(slight, lessThan(sharp));
      expect(heavy, lessThan(slight));
    });

    test('FOC-T003 a low-texture image is not confidently called sharp', () {
      // A flat field has no high-frequency content, so it cannot be
      // distinguished from a blurred image. Reporting "may be blurred" is the
      // honest answer.
      final assessment = engine.assess(
        CvDataset.toWorking(CvDataset.flatScene()),
      );

      expect(assessment.status, isNot(FocusStatus.good));
    });

    test('the threshold is configurable', () {
      // Build Specification section 32: thresholds must be configurable for
      // testing.
      final sharp = CvDataset.toWorking(CvDataset.texturedScene());

      expect(const FocusEngine().assess(sharp).status, FocusStatus.good);
      expect(
        const FocusEngine(
          QualityConfig(focusVarianceThreshold: 1e9),
        ).assess(sharp).status,
        FocusStatus.mayBeBlurred,
      );
    });

    test('a degenerate image reports unavailable rather than crashing', () {
      final tiny = CvDataset.toWorking(
        CvDataset.flatScene(width: 2, height: 2),
        maxDimension: 2,
      );
      expect(engine.assess(tiny).status, FocusStatus.unavailable);
    });
  });

  group('lighting (LGT-T001..T003)', () {
    const engine = LightingEngine();

    test('LGT-T001 similar lighting is recognised', () {
      final scene = CvDataset.texturedScene();
      final assessment = engine.compare(
        reference: CvDataset.toWorking(scene),
        frame: CvDataset.toWorking(scene),
      );

      expect(assessment.status, LightingStatus.similar);
      expect(assessment.isWarning, isFalse);
      expect(assessment.meanDifference.abs(), lessThan(2));
    });

    test('LGT-T002 a dark image is flagged', () {
      final dark = CvDataset.adjustBrightness(CvDataset.texturedScene(), -110);
      final assessment = engine.assessAbsolute(CvDataset.toWorking(dark));

      expect(assessment.status, LightingStatus.tooDark);
      expect(assessment.isWarning, isTrue);
      expect(assessment.message, contains('dark'));
    });

    test('LGT-T003 an overexposed image is flagged', () {
      final bright = CvDataset.adjustBrightness(CvDataset.texturedScene(), 120);
      final assessment = engine.assessAbsolute(CvDataset.toWorking(bright));

      expect(assessment.status, LightingStatus.tooBright);
      expect(assessment.isWarning, isTrue);
    });

    test('a moderate brightness difference from the reference is reported', () {
      final scene = CvDataset.texturedScene();
      final brighter = CvDataset.adjustBrightness(scene, 45);

      final assessment = engine.compare(
        reference: CvDataset.toWorking(scene),
        frame: CvDataset.toWorking(brighter),
      );

      expect(assessment.status, LightingStatus.different);
      expect(assessment.meanDifference, greaterThan(0));
      expect(assessment.message, contains('brighter'));
    });

    test('a darker frame is described as darker', () {
      final scene = CvDataset.texturedScene();
      final darker = CvDataset.adjustBrightness(scene, -45);

      final assessment = engine.compare(
        reference: CvDataset.toWorking(scene),
        frame: CvDataset.toWorking(darker),
      );

      expect(assessment.meanDifference, lessThan(0));
      expect(assessment.message, contains('darker'));
    });

    test('the message never claims equivalent illumination', () {
      // Image statistics cannot support a claim about actual illumination
      // (Computer Vision section 71, master prompt Phase 19).
      final scene = CvDataset.texturedScene();
      final assessment = engine.compare(
        reference: CvDataset.toWorking(scene),
        frame: CvDataset.toWorking(scene),
      );

      final message = assessment.message.toLowerCase();
      for (final claim in const [
        'identical',
        'equivalent',
        'same lighting',
        'matched',
      ]) {
        expect(message, isNot(contains(claim)));
      }
    });

    test('thresholds are configurable', () {
      final scene = CvDataset.texturedScene();
      final slightlyBrighter = CvDataset.adjustBrightness(scene, 12);

      // Default threshold tolerates a 12-level shift.
      expect(
        const LightingEngine()
            .compare(
              reference: CvDataset.toWorking(scene),
              frame: CvDataset.toWorking(slightlyBrighter),
            )
            .status,
        LightingStatus.similar,
      );

      // A strict configuration flags it.
      expect(
        const LightingEngine(
              QualityConfig(
                luminanceDifferenceThreshold: 2,
                histogramSimilarityThreshold: 0.99,
              ),
            )
            .compare(
              reference: CvDataset.toWorking(scene),
              frame: CvDataset.toWorking(slightlyBrighter),
            )
            .status,
        LightingStatus.different,
      );
    });
  });
}
