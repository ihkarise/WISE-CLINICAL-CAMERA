import '../../models/enums.dart';
import '../../models/measurement.dart';

/// The Before-to-After change for one measurement type (Functional section 19,
/// Data Model section 51, Build Specification section 43).
class MeasurementChange {
  const MeasurementChange({
    required this.type,
    required this.before,
    required this.after,
    required this.absolute,
    required this.percentage,
    required this.unit,
    required this.comparable,
    this.unavailableReason,
  });

  /// Computes the change between two measurements.
  ///
  /// Returns a non-comparable result, rather than a number, whenever the two
  /// measurements cannot honestly be compared:
  ///
  /// - either lacks a valid calibration, so one side would be pixels
  /// - they use different units without a conversion path
  /// - they are different measurement types
  ///
  /// A percentage of null when `before == 0` is deliberate: zero, infinity and
  /// NaN would all read as real figures in a clinical record
  /// (SPECIFICATION_CONFLICTS C-010).
  factory MeasurementChange.between({
    required Measurement before,
    required Measurement after,
  }) {
    if (before.type != after.type) {
      return MeasurementChange._unavailable(
        before.type,
        'These measurements are of different types.',
      );
    }

    if (!before.hasPhysicalValue || !after.hasPhysicalValue) {
      return MeasurementChange._unavailable(
        before.type,
        'Both photographs need a valid scale calibration before a change can '
        'be calculated.',
      );
    }

    // Normalise through millimetres so a Before in cm and an After in mm still
    // compare correctly.
    final unit = before.unit!;
    final beforeValue = before.value!;
    final afterValue = _inUnit(after.value!, after.unit!, unit, before.type);

    final absolute = afterValue - beforeValue;
    final percentage = beforeValue == 0 ? null : (absolute / beforeValue) * 100;

    return MeasurementChange(
      type: before.type,
      before: beforeValue,
      after: afterValue,
      absolute: absolute,
      percentage: percentage,
      unit: unit,
      comparable: true,
      unavailableReason: beforeValue == 0
          ? 'Percentage change unavailable (baseline is zero).'
          : null,
    );
  }

  const MeasurementChange._unavailable(this.type, this.unavailableReason)
    : before = 0,
      after = 0,
      absolute = 0,
      percentage = null,
      unit = null,
      comparable = false;

  final MeasurementType type;
  final double before;
  final double after;
  final double absolute;

  /// `((after - before) / before) * 100`, or null when the baseline is zero or
  /// the pair is not comparable.
  final double? percentage;

  final LengthUnit? unit;

  /// False when the two measurements cannot honestly be compared at all.
  final bool comparable;

  final String? unavailableReason;

  bool get decreased => comparable && absolute < 0;
  bool get increased => comparable && absolute > 0;

  String get displayAbsolute {
    if (!comparable || unit == null) return '—';
    final symbol = type.isAreal ? unit!.areaSymbol : unit!.symbol;
    final sign = absolute > 0 ? '+' : '';
    return '$sign${Measurement.formatPhysical(absolute)} $symbol';
  }

  String get displayPercentage {
    final value = percentage;
    if (value == null) return '—';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  static double _inUnit(
    double value,
    LengthUnit from,
    LengthUnit to,
    MeasurementType type,
  ) {
    if (from == to) return value;
    final ratio = from.millimetresPerUnit / to.millimetresPerUnit;
    // An area converts by the square of the linear ratio.
    return type.isAreal ? value * ratio * ratio : value * ratio;
  }
}
