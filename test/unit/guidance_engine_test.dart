import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/alignment_config.dart';
import 'package:wise_clinical_camera/core/cv/alignment_result.dart';
import 'package:wise_clinical_camera/core/cv/guidance_engine.dart';
import 'package:wise_clinical_camera/core/cv/local_alignment_engine.dart';
import 'package:wise_clinical_camera/models/enums.dart';

/// Alignment guidance (CV sections 32-33, Functional ALG-004, Build
/// Specification section 27, Testing section 15).
///
/// The point of this layer is that the clinician sees "Move closer", never
/// "scale = 1.24". Kept separate from the estimator so the CV engine stays
/// reusable by other WISE products (CV section 77).
void main() {
  const engine = GuidanceEngine();

  AlignmentResult result({
    double translationX = 0,
    double translationY = 0,
    double rotationDegrees = 0,
    double scale = 1,
    AlignmentStatus status = AlignmentStatus.good,
  }) => AlignmentResult(
    status: status,
    confidence: 0.9,
    translationX: translationX,
    translationY: translationY,
    rotationDegrees: rotationDegrees,
    scale: scale,
    engineVersion: LocalAlignmentEngine.version,
  );

  group('direction', () {
    test('a rightward offset asks the user to move right', () {
      expect(
        engine.primaryInstruction(result(translationX: 0.2))!.message,
        'Move right',
      );
    });

    test('a leftward offset asks the user to move left', () {
      expect(
        engine.primaryInstruction(result(translationX: -0.2))!.message,
        'Move left',
      );
    });

    test('a downward offset asks the user to move down', () {
      expect(
        engine.primaryInstruction(result(translationY: 0.2))!.message,
        'Move down',
      );
    });

    test('a subject filling more of the frame asks the user to back off', () {
      expect(
        engine.primaryInstruction(result(scale: 1.4))!.message,
        'Move farther away',
      );
    });

    test('a subject too small asks the user to move closer', () {
      expect(
        engine.primaryInstruction(result(scale: 0.7))!.message,
        'Move closer',
      );
    });

    test('rotation is phrased as a slight turn', () {
      expect(
        engine.primaryInstruction(result(rotationDegrees: 8))!.message,
        'Rotate slightly left',
      );
      expect(
        engine.primaryInstruction(result(rotationDegrees: -8))!.message,
        'Rotate slightly right',
      );
    });
  });

  group('priority', () {
    test('orientation outranks everything and suppresses the rest', () {
      // CV section 33: orientation first. Nothing else is worth saying while
      // the device is held the wrong way round.
      final instructions = engine.instructionsFor(
        result(translationX: 0.5, scale: 2),
        referenceOrientation: CaptureOrientation.portrait,
        currentOrientation: CaptureOrientation.landscape,
      );

      expect(instructions, hasLength(1));
      expect(instructions.single.message, 'Rotate the device');
    });

    test('a large position error outranks a small scale error', () {
      final instructions = engine.instructionsFor(
        result(translationX: 0.4, scale: 1.08),
      );

      expect(instructions.first.message, 'Move right');
    });

    test('a large scale error outranks rotation', () {
      final instructions = engine.instructionsFor(
        result(scale: 1.5, rotationDegrees: 4),
      );

      expect(instructions.first.message, 'Move farther away');
    });

    test('only one instruction is surfaced at a time', () {
      // CV section 33 and UX/UI section 20: one action at a time.
      final instructions = engine.instructionsFor(
        result(translationX: 0.3, translationY: 0.3, scale: 1.4),
      );

      expect(instructions.length, greaterThan(1));
      expect(engine.primaryInstruction(result(translationX: 0.3)), isNotNull);
    });

    test('a matching orientation does not suppress other guidance', () {
      final instructions = engine.instructionsFor(
        result(translationX: 0.3),
        referenceOrientation: CaptureOrientation.portrait,
        currentOrientation: CaptureOrientation.portrait,
      );

      expect(instructions.first.message, 'Move right');
    });
  });

  group('tolerance', () {
    test('an aligned frame produces no instruction', () {
      expect(engine.primaryInstruction(result()), isNull);
      expect(engine.instructionsFor(result()), isEmpty);
    });

    test('an error inside tolerance produces no instruction', () {
      const config = AlignmentConfig();

      expect(
        engine.primaryInstruction(
          result(
            translationX: config.translationToleranceFraction * 0.5,
            rotationDegrees: config.rotationToleranceDegrees * 0.5,
            scale: 1 + config.scaleTolerance * 0.5,
          ),
        ),
        isNull,
      );
    });

    test('tolerances are configurable', () {
      const strict = GuidanceEngine(
        AlignmentConfig(translationToleranceFraction: 0.001),
      );

      expect(engine.primaryInstruction(result(translationX: 0.02)), isNull);
      expect(
        strict.primaryInstruction(result(translationX: 0.02))!.message,
        'Move right',
      );
    });
  });

  group('language', () {
    test('no instruction contains computer-vision terminology', () {
      // Build Specification section 27 / CV section 61.
      final messages = <String>[
        for (final r in [
          result(translationX: 0.3),
          result(translationY: -0.3),
          result(scale: 1.5),
          result(scale: 0.6),
          result(rotationDegrees: 10),
        ])
          ...engine.instructionsFor(r).map((i) => i.message),
        engine.statusMessage(result()),
        engine.statusMessage(
          const AlignmentResult.unavailable(engineVersion: 'cv-1.0.0'),
        ),
      ];

      for (final message in messages) {
        final lower = message.toLowerCase();
        for (final term in const [
          'translation',
          'homography',
          'transform',
          'ransac',
          'inlier',
          'keypoint',
          'descriptor',
          'matrix',
          'reprojection',
        ]) {
          expect(
            lower,
            isNot(contains(term)),
            reason: '"$message" leaks the CV term "$term"',
          );
        }
      }
    });

    test('the unavailable status uses the specified wording', () {
      // Functional ALG-007 and Technical Architecture section 46.
      expect(
        engine.statusMessage(
          const AlignmentResult.unavailable(engineVersion: 'cv-1.0.0'),
        ),
        'Automatic alignment unavailable.',
      );
    });

    test('an unavailable result produces no directional guidance', () {
      expect(
        engine.instructionsFor(
          const AlignmentResult.unavailable(engineVersion: 'cv-1.0.0'),
        ),
        isEmpty,
      );
    });

    test('a fully aligned good result reads as ready', () {
      const aligned = AlignmentResult(
        status: AlignmentStatus.good,
        confidence: 0.95,
        engineVersion: 'cv-1.0.0',
        dimensions: AlignmentDimensions(
          position: true,
          scale: true,
          rotation: true,
          framing: true,
          orientation: true,
        ),
      );

      expect(engine.statusMessage(aligned), 'Ready to capture');
    });
  });
}
