import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/cv/alignment_result.dart';
import 'package:wise_clinical_camera/core/cv/focus_engine.dart';
import 'package:wise_clinical_camera/core/cv/lighting_engine.dart';
import 'package:wise_clinical_camera/features/capture/capture_readiness.dart';
import 'package:wise_clinical_camera/models/capture_protocol.dart';
import 'package:wise_clinical_camera/models/enums.dart';

/// Capture readiness (Functional MOD-023, CV sections 38-40, UX/UI sections
/// 22-24, Build Specification sections 2.8 and 30, Testing sections 16-17).
///
/// Priority: P0. The failure this guards against is software that refuses to
/// take a clinical photograph.
void main() {
  AlignmentResult alignment(
    AlignmentStatus status, {
    double confidence = 0.9,
  }) => AlignmentResult(
    status: status,
    confidence: confidence,
    engineVersion: 'cv-1.0.0',
    dimensions: const AlignmentDimensions(
      position: true,
      scale: true,
      rotation: true,
      framing: true,
      orientation: true,
    ),
  );

  group('capture stays possible', () {
    test('with no tools active at all', () {
      final readiness = CaptureReadiness.evaluate();

      expect(readiness.canCapture, isTrue);
      expect(readiness.isReady, isTrue);
      expect(readiness.warnings, isEmpty);
      expect(readiness.captureLabel, 'Capture');
    });

    test('with poor alignment', () {
      final readiness = CaptureReadiness.evaluate(
        alignment: alignment(AlignmentStatus.poor, confidence: 0.2),
      );

      expect(readiness.canCapture, isTrue);
      expect(readiness.hasWarnings, isTrue);
      expect(readiness.captureLabel, 'Capture anyway');
    });

    test('with alignment unavailable', () {
      final readiness = CaptureReadiness.evaluate(
        alignment: const AlignmentResult.unavailable(engineVersion: 'cv-1.0.0'),
      );

      expect(readiness.canCapture, isTrue);
      expect(
        readiness.primaryWarning!.action,
        contains('Ghost Overlay'),
        reason: 'the user must be pointed at the fallback',
      );
    });

    test('with a blur warning', () {
      final readiness = CaptureReadiness.evaluate(
        focus: const FocusAssessment(
          status: FocusStatus.mayBeBlurred,
          score: 10,
          threshold: 120,
        ),
      );

      expect(readiness.canCapture, isTrue);
      expect(readiness.primaryWarning!.message, 'Image may be blurred');
      expect(readiness.primaryWarning!.action, 'Retake');
    });

    test('with a lighting warning', () {
      final readiness = CaptureReadiness.evaluate(
        lighting: const LightingAssessment(
          status: LightingStatus.different,
          meanDifference: 40,
          histogramSimilarity: 0.4,
          detail: '18% brighter than the Before image',
        ),
      );

      expect(readiness.canCapture, isTrue);
      expect(readiness.primaryWarning!.message, contains('brighter'));
    });

    test('with every warning at once', () {
      final readiness = CaptureReadiness.evaluate(
        alignment: alignment(AlignmentStatus.poor),
        lighting: const LightingAssessment(
          status: LightingStatus.tooDark,
          meanDifference: -60,
          histogramSimilarity: 0.3,
        ),
        focus: const FocusAssessment(
          status: FocusStatus.mayBeBlurred,
          score: 5,
          threshold: 120,
        ),
        referenceOrientation: CaptureOrientation.portrait,
        currentOrientation: CaptureOrientation.landscape,
      );

      expect(
        readiness.canCapture,
        isTrue,
        reason: 'no combination of advisory warnings may block capture',
      );
      expect(readiness.warnings.length, greaterThanOrEqualTo(4));
    });

    test('no shipped protocol blocks capture', () {
      // SPECIFICATION_CONFLICTS C-018: hardAlignmentThreshold is null on every
      // seeded protocol.
      const settings = ProtocolSettings();

      final readiness = CaptureReadiness.evaluate(
        alignment: alignment(AlignmentStatus.poor, confidence: 0.1),
        protocol: settings,
      );

      expect(settings.hardAlignmentThreshold, isNull);
      expect(readiness.canCapture, isTrue);
    });
  });

  group('the two things that do stop capture', () {
    test('an unavailable camera', () {
      final readiness = CaptureReadiness.evaluate(cameraAvailable: false);

      expect(readiness.canCapture, isFalse);
      expect(readiness.blockedReason, contains('Camera unavailable'));
    });

    test('a protocol that deliberately sets a hard threshold', () {
      const strict = ProtocolSettings(hardAlignmentThreshold: 0.9);

      expect(
        CaptureReadiness.evaluate(
          alignment: alignment(AlignmentStatus.poor, confidence: 0.4),
          protocol: strict,
        ).canCapture,
        isFalse,
      );

      // And permits it once the threshold is met.
      expect(
        CaptureReadiness.evaluate(
          alignment: alignment(AlignmentStatus.good, confidence: 0.95),
          protocol: strict,
        ).canCapture,
        isTrue,
      );
    });

    test('a hard threshold blocks when alignment is unavailable', () {
      // Cannot verify the requirement is met, so it is not met.
      expect(
        CaptureReadiness.evaluate(
          alignment: const AlignmentResult.unavailable(
            engineVersion: 'cv-1.0.0',
          ),
          protocol: const ProtocolSettings(hardAlignmentThreshold: 0.9),
        ).canCapture,
        isFalse,
      );
    });
  });

  group('warning presentation', () {
    test('a caution outranks an advisory', () {
      final readiness = CaptureReadiness.evaluate(
        alignment: alignment(AlignmentStatus.fair),
        focus: const FocusAssessment(
          status: FocusStatus.mayBeBlurred,
          score: 5,
          threshold: 120,
        ),
      );

      expect(readiness.primaryWarning!.message, 'Image may be blurred');
    });

    test('an orientation mismatch is reported', () {
      final readiness = CaptureReadiness.evaluate(
        referenceOrientation: CaptureOrientation.landscape,
        currentOrientation: CaptureOrientation.portrait,
      );

      expect(readiness.primaryWarning!.action, 'Rotate the device');
    });

    test('good alignment with no warnings reads as ready', () {
      final readiness = CaptureReadiness.evaluate(
        alignment: alignment(AlignmentStatus.good),
        lighting: const LightingAssessment(
          status: LightingStatus.similar,
          meanDifference: 2,
          histogramSimilarity: 0.95,
        ),
        focus: const FocusAssessment(
          status: FocusStatus.good,
          score: 400,
          threshold: 120,
        ),
      );

      expect(readiness.isReady, isTrue);
      expect(readiness.hasWarnings, isFalse);
    });

    test('warnings never contain CV terminology', () {
      final readiness = CaptureReadiness.evaluate(
        alignment: const AlignmentResult.unavailable(engineVersion: 'x'),
        focus: const FocusAssessment(
          status: FocusStatus.mayBeBlurred,
          score: 0,
          threshold: 1,
        ),
      );

      for (final warning in readiness.warnings) {
        final text = '${warning.message} ${warning.action ?? ''}'.toLowerCase();
        for (final term in const ['ransac', 'homography', 'inlier', 'matrix']) {
          expect(text, isNot(contains(term)));
        }
      }
    });
  });
}
