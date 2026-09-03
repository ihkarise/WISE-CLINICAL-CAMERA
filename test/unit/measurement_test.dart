import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_calculator.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_change.dart';
import 'package:wise_clinical_camera/models/calibration.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/models/measurement.dart';

/// Calibration and measurement mathematics.
///
/// Priority: P0 (Build Specification sections 36-38 and 75, Testing sections
/// 22-25, master prompt Phase 43). The rule under test throughout is that a
/// physical unit may never appear without a valid calibration.
void main() {
  /// 10 px per mm: a 50 mm ruler measured as 500 px.
  Calibration calibrationOf({
    double knownValue = 5,
    LengthUnit unit = LengthUnit.centimetre,
    double pixelDistance = 500,
    bool isValid = true,
  }) => Calibration(
    id: 'cal-1',
    photoId: 'photo-1',
    method: CalibrationMethod.manual,
    knownValue: knownValue,
    unit: unit,
    pixelDistance: pixelDistance,
    isValid: isValid,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Geometry line(double lengthPx) =>
      Geometry([const ImagePoint(0, 0), ImagePoint(lengthPx, 0)]);

  group('calibration mathematics', () {
    test('pixelsPerUnit = pixelDistance / knownDistance', () {
      // Build Specification section 36.
      final calibration = calibrationOf();

      expect(calibration.pixelsPerUnit, closeTo(100, 1e-9)); // px per cm
      expect(calibration.pixelsPerMillimetre, closeTo(10, 1e-9));
      expect(calibration.isUsable, isTrue);
    });

    test('normalises correctly across units', () {
      // The same physical scale expressed three ways must give one answer.
      expect(
        calibrationOf(
          knownValue: 50,
          unit: LengthUnit.millimetre,
        ).pixelsPerMillimetre,
        closeTo(10, 1e-9),
      );
      expect(
        calibrationOf(
          knownValue: 5,
          unit: LengthUnit.centimetre,
        ).pixelsPerMillimetre,
        closeTo(10, 1e-9),
      );
      expect(
        calibrationOf(
          knownValue: 0.05,
          unit: LengthUnit.metre,
        ).pixelsPerMillimetre,
        closeTo(10, 1e-9),
      );
    });

    group('rejects invalid input', () {
      // Build Specification section 36: validate knownDistance > 0 and
      // pixelDistance > 0.
      for (final (name, known, pixels) in const <(String, double, double)>[
        ('zero known distance', 0, 500),
        ('negative known distance', -5, 500),
        ('zero pixel distance', 5, 0),
        ('negative pixel distance', 5, -500),
        ('infinite known distance', double.infinity, 500),
        ('NaN pixel distance', 5, double.nan),
      ]) {
        test(name, () {
          expect(
            Calibration.create(
              id: 'c',
              photoId: 'p',
              method: CalibrationMethod.manual,
              knownValue: known,
              unit: LengthUnit.centimetre,
              pixelDistance: pixels,
            ),
            isNull,
            reason: '$name must not produce a calibration',
          );
        });
      }
    });

    test('an invalidated calibration stops being usable', () {
      expect(calibrationOf(isValid: false).isUsable, isFalse);
    });
  });

  group('uncalibrated measurement', () {
    test('produces pixels and no unit', () {
      // Testing section 24, P0: "The application must not invent a physical
      // measurement."
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(280),
      );

      expect(measurement.calibrationId, isNull);
      expect(measurement.value, isNull);
      expect(measurement.unit, isNull);
      expect(measurement.hasPhysicalValue, isFalse);
      expect(measurement.pixelValue, closeTo(280, 1e-9));
      expect(measurement.displayValue, '280 px');
      expect(measurement.displayValue, isNot(contains('cm')));
    });

    test('an unusable calibration is treated as no calibration', () {
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(280),
        calibration: calibrationOf(isValid: false),
      );

      expect(measurement.hasPhysicalValue, isFalse);
      expect(measurement.displayValue, endsWith('px'));
    });

    test('an uncalibrated area reports square pixels', () {
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.area,
        geometry: const Geometry([
          ImagePoint(0, 0),
          ImagePoint(100, 0),
          ImagePoint(100, 100),
          ImagePoint(0, 100),
        ], closed: true),
      );

      expect(measurement.displayValue, '10000 px²');
    });
  });

  group('calibrated measurement', () {
    test('length converts to centimetres', () {
      // 280 px at 100 px/cm = 2.8 cm, the PRD's worked example.
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(280),
        calibration: calibrationOf(),
      );

      expect(measurement.hasPhysicalValue, isTrue);
      expect(measurement.value, closeTo(2.8, 1e-9));
      expect(measurement.unit, LengthUnit.centimetre);
      expect(measurement.displayValue, '2.8 cm');
    });

    test('area scales with the square of the linear scale', () {
      // A 200x180 px rectangle at 100 px/cm is 2 cm x 1.8 cm = 3.6 cm².
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.area,
        geometry: const Geometry([
          ImagePoint(0, 0),
          ImagePoint(200, 0),
          ImagePoint(200, 180),
          ImagePoint(0, 180),
        ], closed: true),
        calibration: calibrationOf(),
      );

      expect(measurement.value, closeTo(3.6, 1e-9));
      expect(measurement.displayValue, '3.6 cm²');
    });

    test('perimeter closes the shape', () {
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.perimeter,
        geometry: const Geometry([
          ImagePoint(0, 0),
          ImagePoint(100, 0),
          ImagePoint(100, 100),
          ImagePoint(0, 100),
        ], closed: true),
        calibration: calibrationOf(),
      );

      // 400 px perimeter at 100 px/cm = 4 cm.
      expect(measurement.value, closeTo(4, 1e-9));
    });

    test('the display unit can differ from the calibration unit', () {
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(280),
        calibration: calibrationOf(),
        displayUnit: LengthUnit.millimetre,
      );

      expect(measurement.value, closeTo(28, 1e-9));
      expect(measurement.displayValue, '28.0 mm');
    });

    test('width and diameter use the same two-point distance', () {
      for (final type in const [
        MeasurementType.length,
        MeasurementType.width,
        MeasurementType.diameter,
      ]) {
        final measurement = MeasurementCalculator.build(
          id: 'm',
          photoId: 'p',
          type: type,
          geometry: line(170),
          calibration: calibrationOf(),
        );
        expect(measurement.value, closeTo(1.7, 1e-9), reason: '$type');
      }
    });
  });

  group('recalculation', () {
    test('adding a calibration converts an existing pixel measurement', () {
      // The clinician measures first, then calibrates. The stored geometry is
      // what makes this possible (Data Model section 21).
      final pixelOnly = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(420),
      );
      expect(pixelOnly.hasPhysicalValue, isFalse);

      final recalculated = MeasurementCalculator.recalculate(
        pixelOnly,
        calibration: calibrationOf(),
      );

      expect(recalculated.hasPhysicalValue, isTrue);
      expect(recalculated.value, closeTo(4.2, 1e-9));
      expect(
        recalculated.geometry.points,
        pixelOnly.geometry.points,
        reason: 'the placed points must not move',
      );
    });

    test('removing a calibration falls back to pixels', () {
      final calibrated = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(280),
        calibration: calibrationOf(),
      );

      final stripped = MeasurementCalculator.recalculate(calibrated);

      expect(stripped.hasPhysicalValue, isFalse);
      expect(stripped.displayValue, endsWith('px'));
    });

    test('moving a point updates both pixel and physical values', () {
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: line(280),
        calibration: calibrationOf(),
      );

      final moved = MeasurementCalculator.recalculate(
        measurement,
        geometry: line(560),
        calibration: calibrationOf(),
      );

      expect(moved.pixelValue, closeTo(560, 1e-9));
      expect(moved.value, closeTo(5.6, 1e-9));
    });
  });

  group('degenerate geometry', () {
    test('a single point measures zero rather than crashing', () {
      final measurement = MeasurementCalculator.build(
        id: 'm1',
        photoId: 'photo-1',
        type: MeasurementType.length,
        geometry: const Geometry([ImagePoint(10, 10)]),
      );

      expect(measurement.pixelValue, 0);
    });

    test('an empty geometry measures zero', () {
      expect(
        MeasurementCalculator.pixelValueFor(
          MeasurementType.area,
          const Geometry([]),
        ),
        0,
      );
    });

    test('reports how many points each type needs', () {
      expect(MeasurementCalculator.minimumPoints(MeasurementType.length), 2);
      expect(MeasurementCalculator.minimumPoints(MeasurementType.area), 3);
      expect(MeasurementCalculator.minimumPoints(MeasurementType.angle), 3);
      expect(
        MeasurementCalculator.hasEnoughPoints(MeasurementType.area, line(10)),
        isFalse,
      );
    });

    test('area is independent of winding order', () {
      const clockwise = Geometry([
        ImagePoint(0, 0),
        ImagePoint(100, 0),
        ImagePoint(100, 100),
      ], closed: true);
      const counterClockwise = Geometry([
        ImagePoint(100, 100),
        ImagePoint(100, 0),
        ImagePoint(0, 0),
      ], closed: true);

      expect(
        clockwise.pixelArea(),
        closeTo(counterClockwise.pixelArea(), 1e-9),
      );
    });
  });

  group('before/after change', () {
    Measurement measurementOf(double centimetres, {String id = 'm'}) =>
        Measurement(
          id: id,
          photoId: 'p',
          calibrationId: 'cal-1',
          type: MeasurementType.length,
          unit: LengthUnit.centimetre,
          value: centimetres,
          pixelValue: centimetres * 100,
          geometry: line(centimetres * 100),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('matches the specification worked example', () {
      // Testing section 25: Before 4.2 cm, After 2.8 cm
      //   -> change -1.4 cm, percentage -33.33%.
      final change = MeasurementChange.between(
        before: measurementOf(4.2),
        after: measurementOf(2.8),
      );

      expect(change.comparable, isTrue);
      expect(change.absolute, closeTo(-1.4, 1e-9));
      expect(change.percentage, closeTo(-33.333333, 1e-4));
      expect(change.displayPercentage, '-33.3%');
      expect(change.decreased, isTrue);
    });

    test('handles a zero baseline without dividing by zero', () {
      // Testing section 25 requires no division-by-zero error and a meaningful
      // fallback. Null, not 0 or Infinity: a number here would read as fact.
      final change = MeasurementChange.between(
        before: measurementOf(0),
        after: measurementOf(2.8),
      );

      expect(change.percentage, isNull);
      expect(change.displayPercentage, '—');
      expect(change.absolute, closeTo(2.8, 1e-9));
      expect(change.unavailableReason, contains('baseline is zero'));
    });

    test('refuses to compare when either side is uncalibrated', () {
      final uncalibrated = MeasurementCalculator.build(
        id: 'm2',
        photoId: 'p',
        type: MeasurementType.length,
        geometry: line(280),
      );

      final change = MeasurementChange.between(
        before: measurementOf(4.2),
        after: uncalibrated,
      );

      expect(change.comparable, isFalse);
      expect(change.percentage, isNull);
      expect(change.displayAbsolute, '—');
      expect(change.unavailableReason, contains('scale calibration'));
    });

    test('refuses to compare different measurement types', () {
      final area = Measurement(
        id: 'm2',
        photoId: 'p',
        calibrationId: 'cal-1',
        type: MeasurementType.area,
        unit: LengthUnit.centimetre,
        value: 3.6,
        pixelValue: 36000,
        geometry: line(100),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(
        MeasurementChange.between(
          before: measurementOf(4.2),
          after: area,
        ).comparable,
        isFalse,
      );
    });

    test('converts between units before comparing', () {
      final beforeCm = measurementOf(4.2);
      final afterMm = Measurement(
        id: 'm2',
        photoId: 'p',
        calibrationId: 'cal-1',
        type: MeasurementType.length,
        unit: LengthUnit.millimetre,
        value: 28,
        pixelValue: 280,
        geometry: line(280),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final change = MeasurementChange.between(
        before: beforeCm,
        after: afterMm,
      );

      // 28 mm is 2.8 cm, so the same -33.33% as the worked example.
      expect(change.after, closeTo(2.8, 1e-9));
      expect(change.percentage, closeTo(-33.333333, 1e-4));
    });

    test('reports an increase with a signed display', () {
      final change = MeasurementChange.between(
        before: measurementOf(2),
        after: measurementOf(3),
      );

      expect(change.increased, isTrue);
      expect(change.displayPercentage, '+50.0%');
      expect(change.displayAbsolute, '+1.0 cm');
    });
  });
}
