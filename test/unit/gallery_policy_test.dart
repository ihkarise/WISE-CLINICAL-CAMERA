import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/services/gallery/gallery_service.dart';

/// Gallery saving policy (Functional SAV-003, PRD sections 26-28,
/// Privacy sections 35-38, Testing sections 39-40).
void main() {
  group('outside Privacy Mode', () {
    test('ALWAYS saves without asking', () {
      expect(
        GalleryService.decide(mode: GallerySaveMode.always, privacyMode: false),
        GalleryDecision.save,
      );
    });

    test('NEVER skips', () {
      expect(
        GalleryService.decide(mode: GallerySaveMode.never, privacyMode: false),
        GalleryDecision.skip,
      );
    });

    test('ASK asks', () {
      expect(
        GalleryService.decide(mode: GallerySaveMode.ask, privacyMode: false),
        GalleryDecision.ask,
      );
    });
  });

  group('under Privacy Mode', () {
    test('ALWAYS is downgraded to ASK, never obeyed', () {
      // PRD section 28 and Functional PRI-004: Privacy Mode means no automatic
      // Gallery copy. Honouring ALWAYS would make automatic copies anyway.
      expect(
        GalleryService.decide(mode: GallerySaveMode.always, privacyMode: true),
        GalleryDecision.ask,
        reason: 'Privacy Mode must prevent an automatic Gallery copy',
      );
    });

    test('NEVER still skips', () {
      expect(
        GalleryService.decide(mode: GallerySaveMode.never, privacyMode: true),
        GalleryDecision.skip,
      );
    });

    test('ASK still asks', () {
      expect(
        GalleryService.decide(mode: GallerySaveMode.ask, privacyMode: true),
        GalleryDecision.ask,
      );
    });

    test('no configuration produces an automatic copy', () {
      // The property that matters, stated directly: under Privacy Mode there
      // is no combination of settings that silently writes to the Gallery.
      for (final mode in GallerySaveMode.values) {
        expect(
          GalleryService.decide(mode: mode, privacyMode: true),
          isNot(GalleryDecision.save),
          reason: '$mode produced an automatic copy under Privacy Mode',
        );
      }
    });
  });

  test('the album name matches the specification', () {
    // PRD section 27.
    expect(GalleryService.albumName, 'WISE Clinical Photos');
  });
}
