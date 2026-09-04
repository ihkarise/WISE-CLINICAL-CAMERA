import 'dart:math' as math;

import '../../models/enums.dart';
import 'alignment_config.dart';
import 'alignment_result.dart';

/// One instruction for the clinician.
class GuidanceInstruction {
  const GuidanceInstruction({
    required this.message,
    required this.priority,
    required this.magnitude,
  });

  /// Plain language. Never a CV term (CV section 61, Build Specification 27).
  final String message;

  /// Lower sorts first (CV section 33's priority order).
  final int priority;

  /// How far off this dimension is, 0-1, for sizing an on-screen indicator.
  final double magnitude;
}

/// Turns an [AlignmentResult] into instructions a clinician can act on.
///
/// Kept separate from the estimator on purpose: CV section 77 requires that
/// "rotation = -2.4 degrees" and "Rotate slightly right" live in different
/// places, so the CV engine can be reused by other WISE products that phrase
/// guidance differently.
class GuidanceEngine {
  const GuidanceEngine([this.config = const AlignmentConfig()]);

  final AlignmentConfig config;

  /// Instructions in priority order (CV section 33).
  ///
  /// Ordering: orientation, then large position error, then large scale error,
  /// then rotation, then fine alignment.
  List<GuidanceInstruction> instructionsFor(
    AlignmentResult result, {
    CaptureOrientation? referenceOrientation,
    CaptureOrientation? currentOrientation,
  }) {
    final instructions = <GuidanceInstruction>[];

    // 1. Orientation. A portrait/landscape mismatch makes every other
    // correction pointless, so it is checked from sensors before the transform.
    if (referenceOrientation != null &&
        currentOrientation != null &&
        referenceOrientation != currentOrientation) {
      instructions.add(
        const GuidanceInstruction(
          message: 'Rotate the device',
          priority: 0,
          magnitude: 1,
        ),
      );
      // Nothing else is useful until this is fixed.
      return instructions;
    }

    if (!result.isAvailable) return instructions;

    // 2. Position.
    final tolerance = config.translationToleranceFraction;
    final absX = result.translationX.abs();
    final absY = result.translationY.abs();

    if (absX > tolerance) {
      instructions.add(
        GuidanceInstruction(
          // The subject appears right of the reference, so the camera moves
          // right to bring the framing back.
          message: result.translationX > 0 ? 'Move right' : 'Move left',
          priority: absX > tolerance * 3 ? 1 : 5,
          magnitude: _magnitude(absX, tolerance),
        ),
      );
    }
    if (absY > tolerance) {
      instructions.add(
        GuidanceInstruction(
          message: result.translationY > 0 ? 'Move down' : 'Move up',
          priority: absY > tolerance * 3 ? 1 : 5,
          magnitude: _magnitude(absY, tolerance),
        ),
      );
    }

    // 3. Scale.
    final scaleError = (result.scale - 1).abs();
    if (scaleError > config.scaleTolerance) {
      instructions.add(
        GuidanceInstruction(
          // scale > 1 means the subject fills more of the frame than in the
          // reference, so the camera needs to back off.
          message: result.scale > 1 ? 'Move farther away' : 'Move closer',
          priority: scaleError > config.scaleTolerance * 3 ? 2 : 6,
          magnitude: _magnitude(scaleError, config.scaleTolerance),
        ),
      );
    }

    // 4. Rotation.
    final rotationError = result.rotationDegrees.abs();
    if (rotationError > config.rotationToleranceDegrees) {
      instructions.add(
        GuidanceInstruction(
          message: result.rotationDegrees > 0
              ? 'Rotate slightly left'
              : 'Rotate slightly right',
          priority: 3,
          magnitude: _magnitude(rotationError, config.rotationToleranceDegrees),
        ),
      );
    }

    instructions.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : b.magnitude.compareTo(a.magnitude);
    });
    return instructions;
  }

  /// The single instruction to show.
  ///
  /// CV section 33: "Avoid displaying too many simultaneous instructions."
  /// One action at a time is also what UX/UI section 20 asks for.
  GuidanceInstruction? primaryInstruction(
    AlignmentResult result, {
    CaptureOrientation? referenceOrientation,
    CaptureOrientation? currentOrientation,
  }) {
    final instructions = instructionsFor(
      result,
      referenceOrientation: referenceOrientation,
      currentOrientation: currentOrientation,
    );
    return instructions.isEmpty ? null : instructions.first;
  }

  /// The line shown under the alignment panel.
  String statusMessage(AlignmentResult result) {
    if (!result.isAvailable) {
      // The exact wording Functional ALG-007 and Technical Architecture
      // section 46 specify.
      return 'Automatic alignment unavailable.';
    }
    if (result.isReady) return 'Ready to capture';
    return switch (result.status) {
      AlignmentStatus.good => 'Alignment good',
      AlignmentStatus.fair => 'Alignment fair',
      AlignmentStatus.poor => 'Alignment poor',
      AlignmentStatus.unavailable => 'Automatic alignment unavailable.',
    };
  }

  /// Scales an error into 0-1 for an indicator, saturating at 4x tolerance.
  static double _magnitude(double error, double tolerance) =>
      tolerance <= 0 ? 1 : math.min(1, (error - tolerance) / (tolerance * 3));
}
