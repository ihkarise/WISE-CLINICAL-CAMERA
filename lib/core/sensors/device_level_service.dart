import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// A tilt reading from the device's accelerometer.
class LevelReading {
  const LevelReading({
    required this.rollDegrees,
    required this.pitchDegrees,
    required this.available,
  });

  /// No usable sensor. The level tool is then hidden rather than shown doing
  /// nothing (UX/UI section 74, Functional LVL-002).
  static const LevelReading unavailable = LevelReading(
    rollDegrees: 0,
    pitchDegrees: 0,
    available: false,
  );

  /// Rotation about the viewing axis. 0 is upright.
  final double rollDegrees;

  /// Forward/backward tilt. 0 is vertical.
  final double pitchDegrees;

  final bool available;

  /// Whether the device is level within [toleranceDegrees].
  ///
  /// The tolerance is a parameter rather than a constant because Functional
  /// LVL-003 says the visual threshold "shall be validated during testing".
  bool isLevel({double toleranceDegrees = 1}) =>
      available && rollDegrees.abs() <= toleranceDegrees;

  /// The value shown to the user, e.g. "0.2 degrees" (PRD section 10).
  String get displayRoll => '${rollDegrees.abs().toStringAsFixed(1)}°';
}

/// Device orientation for the level tool and for capture-recipe tilt
/// (Functional LVL-001..003, CV section 10).
///
/// Degrades quietly: a device with no accelerometer emits
/// [LevelReading.unavailable] rather than failing, and the tool disappears from
/// the camera (Functional LVL-002, Technical Architecture section 6).
class DeviceLevelService {
  DeviceLevelService({
    Stream<AccelerometerEvent>? source,
    this.samplingPeriod = const Duration(milliseconds: 100),
    this.smoothing = 0.75,
  }) : _source = source;

  final Stream<AccelerometerEvent>? _source;
  final Duration samplingPeriod;

  /// Exponential smoothing. Accelerometer output is noisy enough that an
  /// unsmoothed readout jitters by a degree or more while the device is still.
  final double smoothing;

  late final StreamController<LevelReading> _controller =
      StreamController<LevelReading>.broadcast(
        // The sensor is only subscribed to while something is listening, so a
        // camera screen that is closed stops draining the battery.
        onListen: _start,
        onCancel: _stop,
      );

  StreamSubscription<AccelerometerEvent>? _subscription;
  LevelReading _latest = LevelReading.unavailable;

  LevelReading get latest => _latest;

  /// Smoothed tilt readings. Emits [LevelReading.unavailable] if the sensor
  /// cannot be read.
  Stream<LevelReading> get readings => _controller.stream;

  void _start() {
    final source =
        _source ?? accelerometerEventStream(samplingPeriod: samplingPeriod);

    _subscription = source.listen(
      (event) {
        final reading = readingFrom(event.x, event.y, event.z);
        _latest = _smooth(_latest, reading);
        if (!_controller.isClosed) _controller.add(_latest);
      },
      onError: (Object _) {
        // No usable sensor on this device.
        _latest = LevelReading.unavailable;
        if (!_controller.isClosed) _controller.add(_latest);
      },
      cancelOnError: false,
    );
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await _stop();
    if (!_controller.isClosed) await _controller.close();
  }

  /// Converts an accelerometer vector to roll and pitch.
  ///
  /// The accelerometer reports proper acceleration including gravity, so a
  /// stationary device held upright in portrait reads roughly (0, +g, 0):
  /// +y points up the screen. Roll about the viewing axis is therefore
  /// `atan2(x, y)`, which gives 0 upright and +90 in landscape.
  ///
  /// Exposed as a static so the arithmetic can be tested without a sensor,
  /// which is where sign mistakes actually live.
  static LevelReading readingFrom(double x, double y, double z) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    // Free fall, or a sensor returning zeros: no meaningful orientation.
    if (magnitude < 1) return LevelReading.unavailable;

    final roll = math.atan2(x, y) * 180 / math.pi;
    final pitch = math.atan2(-z, math.sqrt(x * x + y * y)) * 180 / math.pi;

    return LevelReading(
      rollDegrees: _normalise(roll),
      pitchDegrees: pitch,
      available: true,
    );
  }

  LevelReading _smooth(LevelReading previous, LevelReading current) {
    if (!previous.available || !current.available) return current;
    return LevelReading(
      rollDegrees:
          previous.rollDegrees * smoothing +
          current.rollDegrees * (1 - smoothing),
      pitchDegrees:
          previous.pitchDegrees * smoothing +
          current.pitchDegrees * (1 - smoothing),
      available: true,
    );
  }

  /// Wraps to -180..180 so a device just past upright does not read as 359.
  static double _normalise(double degrees) {
    var value = degrees % 360;
    if (value > 180) value -= 360;
    if (value < -180) value += 360;
    return value;
  }
}
