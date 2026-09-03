import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/models/reference_transform.dart';

/// Ghost overlay transform and lock (Functional OVR-003..005, PRD section 24).
///
/// The lock is enforced in the model rather than in each gesture handler, so
/// "the reference cannot accidentally move" holds regardless of which control
/// was touched.
void main() {
  group('transform', () {
    test('starts at identity', () {
      expect(ReferenceTransform.identity.isIdentity, isTrue);
      expect(ReferenceTransform.identity.locked, isFalse);
    });

    test('translates, scales, rotates and flips', () {
      const start = ReferenceTransform.identity;

      final moved = start.translatedBy(0.1, -0.2);
      expect(moved.translationX, closeTo(0.1, 1e-9));
      expect(moved.translationY, closeTo(-0.2, 1e-9));

      expect(start.scaledBy(2).scale, closeTo(2, 1e-9));
      expect(start.rotatedBy(15).rotationDegrees, closeTo(15, 1e-9));
      expect(start.adjusted(flipX: true).flipX, isTrue);
      expect(start.adjusted(flipY: true).flipY, isTrue);
    });

    test('clamps scale to a usable range', () {
      expect(
        ReferenceTransform.identity.scaledBy(100).scale,
        closeTo(ReferenceTransform.maxScale, 1e-9),
      );
      expect(
        ReferenceTransform.identity.scaledBy(0.001).scale,
        closeTo(ReferenceTransform.minScale, 1e-9),
      );
    });

    test('normalises rotation to -180..180', () {
      // A device just past upright must not read as 359 degrees.
      expect(
        ReferenceTransform.identity.rotatedBy(370).rotationDegrees,
        closeTo(10, 1e-9),
      );
      expect(
        ReferenceTransform.identity.rotatedBy(-190).rotationDegrees,
        closeTo(170, 1e-9),
      );
    });

    test('reset returns to identity', () {
      final adjusted = ReferenceTransform.identity
          .translatedBy(0.3, 0.3)
          .scaledBy(1.5)
          .rotatedBy(20);

      expect(adjusted.isIdentity, isFalse);
      expect(adjusted.reset().isIdentity, isTrue);
    });
  });

  group('lock', () {
    test('refuses every transform while locked', () {
      // Functional OVR-005: translation, scaling, rotation and flip are all
      // disabled by the lock.
      const locked = ReferenceTransform(locked: true);

      expect(locked.translatedBy(0.5, 0.5), locked);
      expect(locked.scaledBy(3), locked);
      expect(locked.rotatedBy(45), locked);
      expect(locked.adjusted(flipX: true), locked);
    });

    test('preserves the current position when locking', () {
      final positioned = ReferenceTransform.identity
          .translatedBy(0.2, 0.1)
          .scaledBy(1.3);

      final locked = positioned.withLock(locked: true);

      expect(locked.locked, isTrue);
      expect(locked.translationX, closeTo(0.2, 1e-9));
      expect(locked.scale, closeTo(1.3, 1e-9));
    });

    test('unlocking restores editing without moving the reference', () {
      final locked = ReferenceTransform.identity
          .translatedBy(0.2, 0)
          .withLock(locked: true);

      final unlocked = locked.withLock(locked: false);

      expect(unlocked.translationX, closeTo(0.2, 1e-9));
      expect(unlocked.translatedBy(0.1, 0).translationX, closeTo(0.3, 1e-9));
    });

    test('reset is refused while locked', () {
      // Reset is a transform action, not an unlock.
      final locked = ReferenceTransform.identity
          .translatedBy(0.4, 0.4)
          .withLock(locked: true);

      expect(locked.reset(), locked);
      expect(locked.reset().isIdentity, isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips through JSON', () {
      final original = ReferenceTransform.identity
          .translatedBy(0.15, -0.25)
          .scaledBy(1.4)
          .rotatedBy(12)
          .adjusted(flipX: true)
          .withLock(locked: true);

      expect(ReferenceTransform.fromJson(original.toJson()), original);
    });
  });
}
