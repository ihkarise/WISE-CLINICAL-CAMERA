import 'dart:convert';
import 'dart:math' as math;

/// How the reference image is positioned over the live camera preview
/// (Technical Architecture section 9, Functional OVR-003..005).
///
/// This is view state, not image state. Nothing here modifies the reference
/// photograph; it only describes how it is drawn (Functional OVR-006,
/// Privacy PRI-004).
class ReferenceTransform {
  const ReferenceTransform({
    this.translationX = 0,
    this.translationY = 0,
    this.scale = 1,
    this.rotationDegrees = 0,
    this.flipX = false,
    this.flipY = false,
    this.locked = false,
  });

  factory ReferenceTransform.fromJson(String json) =>
      ReferenceTransform.fromMap(jsonDecode(json) as Map<String, Object?>);

  factory ReferenceTransform.fromMap(Map<String, Object?> map) =>
      ReferenceTransform(
        translationX: (map['translation_x'] as num?)?.toDouble() ?? 0,
        translationY: (map['translation_y'] as num?)?.toDouble() ?? 0,
        scale: (map['scale'] as num?)?.toDouble() ?? 1,
        rotationDegrees: (map['rotation'] as num?)?.toDouble() ?? 0,
        flipX: map['flip_x'] as bool? ?? false,
        flipY: map['flip_y'] as bool? ?? false,
        locked: map['locked'] as bool? ?? false,
      );

  /// The state a freshly loaded reference starts in, and what RESET returns to
  /// (Functional OVR-004).
  static const ReferenceTransform identity = ReferenceTransform();

  static const double minScale = 0.25;
  static const double maxScale = 4;

  /// Fraction of the preview width. Positive moves the reference right.
  final double translationX;

  /// Fraction of the preview height. Positive moves the reference down.
  final double translationY;

  final double scale;
  final double rotationDegrees;
  final bool flipX;
  final bool flipY;

  /// When locked, translation, scale, rotation and flip are all refused
  /// (Functional OVR-005, PRD section 24).
  final bool locked;

  double get rotationRadians => rotationDegrees * math.pi / 180;

  bool get isIdentity =>
      translationX == 0 &&
      translationY == 0 &&
      scale == 1 &&
      rotationDegrees == 0 &&
      !flipX &&
      !flipY;

  /// Applies a change, or returns `this` unchanged when locked.
  ///
  /// Refusing at the model layer rather than in each gesture handler is what
  /// makes "the reference cannot accidentally move" true regardless of which
  /// control was touched.
  ReferenceTransform adjusted({
    double? translationX,
    double? translationY,
    double? scale,
    double? rotationDegrees,
    bool? flipX,
    bool? flipY,
  }) {
    if (locked) return this;
    return ReferenceTransform(
      translationX: translationX ?? this.translationX,
      translationY: translationY ?? this.translationY,
      scale: (scale ?? this.scale).clamp(minScale, maxScale),
      rotationDegrees: _normaliseDegrees(
        rotationDegrees ?? this.rotationDegrees,
      ),
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      locked: locked,
    );
  }

  /// Nudges by deltas. Also a no-op when locked.
  ReferenceTransform translatedBy(double dx, double dy) => adjusted(
    translationX: translationX + dx,
    translationY: translationY + dy,
  );

  ReferenceTransform scaledBy(double factor) => adjusted(scale: scale * factor);

  ReferenceTransform rotatedBy(double degrees) =>
      adjusted(rotationDegrees: rotationDegrees + degrees);

  /// Returns to [identity] while preserving the lock state, since RESET is a
  /// transform action and not an unlock (Functional OVR-004, OVR-005).
  ReferenceTransform reset() =>
      locked ? this : ReferenceTransform(locked: locked);

  ReferenceTransform withLock({required bool locked}) => ReferenceTransform(
    translationX: translationX,
    translationY: translationY,
    scale: scale,
    rotationDegrees: rotationDegrees,
    flipX: flipX,
    flipY: flipY,
    locked: locked,
  );

  Map<String, Object?> toMap() => {
    'translation_x': translationX,
    'translation_y': translationY,
    'scale': scale,
    'rotation': rotationDegrees,
    'flip_x': flipX,
    'flip_y': flipY,
    'locked': locked,
  };

  String toJson() => jsonEncode(toMap());

  static double _normaliseDegrees(double degrees) {
    var value = degrees % 360;
    if (value > 180) value -= 360;
    if (value < -180) value += 360;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is ReferenceTransform &&
      other.translationX == translationX &&
      other.translationY == translationY &&
      other.scale == scale &&
      other.rotationDegrees == rotationDegrees &&
      other.flipX == flipX &&
      other.flipY == flipY &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(
    translationX,
    translationY,
    scale,
    rotationDegrees,
    flipX,
    flipY,
    locked,
  );
}
