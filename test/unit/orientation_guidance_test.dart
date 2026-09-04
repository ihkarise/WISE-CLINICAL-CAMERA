import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/alignment_result.dart';
import 'package:wise_clinical_camera/core/cv/guidance_engine.dart';
import 'package:wise_clinical_camera/features/capture/capture_readiness.dart';
import 'package:wise_clinical_camera/models/capture_recipe.dart';
import 'package:wise_clinical_camera/models/enums.dart';

/// Orientation comparison (Functional CAM-005, Computer Vision section 33,
/// Build Specification section 27).
///
/// Computer Vision section 33 puts orientation at the top of the guidance
/// priority order: nothing else is worth saying while the device is held the
/// wrong way round.
///
/// The regression this pins: both `GuidanceEngine` and `CaptureReadiness` skip
/// the orientation branch when `currentOrientation` is null. If a caller omits
/// it, the check silently never runs and the highest-priority instruction
/// becomes unreachable — a failure with no visible symptom.
void main() {
  const guidance = GuidanceEngine();

  AlignmentResult aligned() => const AlignmentResult(
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

  group('guidance engine', () {
    test('a mismatch produces the rotate instruction', () {
      final instruction = guidance.primaryInstruction(
        aligned(),
        referenceOrientation: CaptureOrientation.portrait,
        currentOrientation: CaptureOrientation.landscape,
      );

      expect(instruction, isNotNull);
      expect(instruction!.message, 'Rotate the device');
      expect(instruction.priority, 0, reason: 'orientation outranks all else');
    });

    test('a match produces no orientation instruction', () {
      expect(
        guidance.primaryInstruction(
          aligned(),
          referenceOrientation: CaptureOrientation.portrait,
          currentOrientation: CaptureOrientation.portrait,
        ),
        isNull,
      );
    });

    test('omitting the current orientation disables the check entirely', () {
      // Documents the trap rather than the desired behaviour: with the
      // argument absent the branch cannot fire, whatever the reference says.
      // The production wiring must therefore always supply it.
      expect(
        guidance.primaryInstruction(
          aligned(),
          referenceOrientation: CaptureOrientation.landscape,
        ),
        isNull,
        reason: 'this is precisely why the caller must pass it',
      );
    });
  });

  group('capture readiness', () {
    test('a mismatch raises a warning without blocking capture', () {
      final readiness = CaptureReadiness.evaluate(
        referenceOrientation: CaptureOrientation.landscape,
        currentOrientation: CaptureOrientation.portrait,
      );

      expect(readiness.hasWarnings, isTrue);
      expect(readiness.primaryWarning!.action, 'Rotate the device');
      expect(readiness.primaryWarning!.message, contains('landscape'));
      expect(
        readiness.canCapture,
        isTrue,
        reason: 'an orientation mismatch is advisory, never a block',
      );
    });

    test('a match raises nothing', () {
      final readiness = CaptureReadiness.evaluate(
        referenceOrientation: CaptureOrientation.portrait,
        currentOrientation: CaptureOrientation.portrait,
      );

      expect(readiness.hasWarnings, isFalse);
    });

    test('omitting the current orientation disables the check entirely', () {
      expect(
        CaptureReadiness.evaluate(
          referenceOrientation: CaptureOrientation.landscape,
        ).hasWarnings,
        isFalse,
        reason: 'the same trap, on the readiness path',
      );
    });
  });

  group('capture recipe round trip', () {
    test('a landscape capture stores landscape, not a default', () {
      // The regression for a hard-coded portrait in the recipe builder.
      const recipe = CaptureRecipe(orientation: CaptureOrientation.landscape);

      final restored = CaptureRecipe.fromJson(recipe.toJson());

      expect(restored.orientation, CaptureOrientation.landscape);
    });

    test('a recipe reports an orientation difference to the user', () {
      const reference = CaptureRecipe(
        orientation: CaptureOrientation.landscape,
      );
      const current = CaptureRecipe(orientation: CaptureOrientation.portrait);

      final differences = reference.differencesFrom(current);

      expect(differences, isNotEmpty);
      expect(differences.first, contains('landscape'));
    });

    test('an unknown orientation on either side reports no difference', () {
      // An absent value means "this device did not report it", never a
      // mismatch. Reporting one would be a false warning
      // (Data Model section 13).
      const reference = CaptureRecipe(
        orientation: CaptureOrientation.landscape,
      );

      expect(reference.differencesFrom(const CaptureRecipe()), isEmpty);
      expect(const CaptureRecipe().differencesFrom(reference), isEmpty);
    });
  });
}
