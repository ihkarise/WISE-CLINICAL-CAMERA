import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/sensors/device_level_service.dart';

/// Level and tilt (Functional LVL-001..003, PRD section 10, CV section 10).
///
/// The derivation is tested directly, without a sensor, because the arithmetic
/// is where the mistakes are. Real accelerometer behaviour is device test
/// D-SEN-01..04.
void main() {
  group('reading derivation', () {
    test('a device held upright reads level', () {
      // Portrait, upright: gravity lies along -y.
      final reading = DeviceLevelService.readingFrom(0, 9.81, 0);

      expect(reading.available, isTrue);
      expect(reading.rollDegrees.abs(), lessThan(1));
      expect(reading.isLevel(), isTrue);
      expect(reading.displayRoll, '0.0°');
    });

    test('a tilted device reports the roll', () {
      // Gravity split evenly between x and y is a 45 degree roll.
      final reading = DeviceLevelService.readingFrom(6.94, 6.94, 0);

      expect(reading.available, isTrue);
      expect(reading.rollDegrees.abs(), closeTo(45, 1));
      expect(reading.isLevel(), isFalse);
    });

    test('roll sign distinguishes the two directions', () {
      final left = DeviceLevelService.readingFrom(-3, 9.3, 0);
      final right = DeviceLevelService.readingFrom(3, 9.3, 0);

      expect(left.rollDegrees.sign, isNot(right.rollDegrees.sign));
    });

    test('roll stays within -180..180', () {
      // A device just past upright must not read as 359 degrees.
      for (final x in const [-1.0, 0.0, 1.0]) {
        for (final y in const [-9.8, 0.0, 9.8]) {
          final reading = DeviceLevelService.readingFrom(x, y, 0.5);
          if (!reading.available) continue;
          expect(reading.rollDegrees, inInclusiveRange(-180, 180));
        }
      }
    });

    test('pitch responds to forward and backward tilt', () {
      final flat = DeviceLevelService.readingFrom(0, 0, 9.81);
      final upright = DeviceLevelService.readingFrom(0, 9.81, 0);

      expect(flat.pitchDegrees.abs(), greaterThan(60));
      expect(upright.pitchDegrees.abs(), lessThan(30));
    });
  });

  group('unavailable sensor', () {
    test('a zero vector reports unavailable rather than level', () {
      // A sensor returning zeros, or genuine free fall. Reporting "level"
      // would be a confident wrong answer.
      final reading = DeviceLevelService.readingFrom(0, 0, 0);

      expect(reading.available, isFalse);
      expect(reading.isLevel(), isFalse);
    });

    test('the unavailable reading is never level at any tolerance', () {
      expect(
        LevelReading.unavailable.isLevel(toleranceDegrees: 180),
        isFalse,
        reason: 'an unavailable sensor must not satisfy a level check',
      );
    });
  });

  group('tolerance', () {
    test('is a parameter, not a constant', () {
      // Functional LVL-003 states the visual threshold must be validated
      // during testing, so it cannot be baked in.
      final slightlyTilted = DeviceLevelService.readingFrom(0.5, 9.8, 0);

      expect(slightlyTilted.rollDegrees.abs(), greaterThan(1));
      expect(slightlyTilted.isLevel(toleranceDegrees: 0.5), isFalse);
      expect(slightlyTilted.isLevel(toleranceDegrees: 10), isTrue);
    });

    test('the display value is a plain angle', () {
      // PRD section 10 shows "0.2 degrees".
      final reading = DeviceLevelService.readingFrom(0.5, 9.8, 0);
      expect(reading.displayRoll, matches(r'^\d+\.\d°$'));
    });
  });
}
