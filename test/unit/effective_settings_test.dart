import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/models/effective_settings.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/tool_capabilities.dart';
import 'package:wise_clinical_camera/models/tool_overrides.dart';
import 'package:wise_clinical_camera/models/user_preferences.dart';

/// Settings precedence (Functional PRO-004, Build Specification section 22,
/// Data Model section 54, master prompt Phases 14 and 43).
///
/// Priority: P0. Getting this wrong means either a user's saved default is
/// silently rewritten by a single capture, or a device limitation is ignored.
void main() {
  UserPreferences defaults({
    bool measurement = true,
    bool overlay = true,
    bool level = true,
    double opacity = 0.5,
    bool privacyMode = false,
    GallerySaveMode gallery = GallerySaveMode.ask,
  }) => UserPreferences(
    userId: 'u1',
    updatedAt: DateTime(2026),
    measurementEnabled: measurement,
    overlayEnabled: overlay,
    levelEnabled: level,
    overlayOpacity: opacity,
    privacyMode: privacyMode,
    gallerySaveMode: gallery,
  );

  group('precedence chain', () {
    test('user default applies when nothing overrides it', () {
      final settings = EffectiveSettings.resolve(defaults: defaults());

      expect(settings.measurementEnabled, isTrue);
      expect(
        settings.sourceOf(WiseTool.measurement),
        SettingSource.userDefault,
      );
    });

    test('protocol overrides the user default', () {
      final settings = EffectiveSettings.resolve(
        defaults: defaults(),
        protocol: ToolOverrides().setting(WiseTool.measurement, value: false),
      );

      expect(settings.measurementEnabled, isFalse);
      expect(settings.sourceOf(WiseTool.measurement), SettingSource.protocol);
    });

    test('session override beats the protocol', () {
      final settings = EffectiveSettings.resolve(
        defaults: defaults(),
        protocol: ToolOverrides().setting(WiseTool.measurement, value: false),
        session: ToolOverrides().setting(WiseTool.measurement, value: true),
      );

      expect(settings.measurementEnabled, isTrue);
      expect(settings.sourceOf(WiseTool.measurement), SettingSource.session);
    });

    test('platform limitation vetoes every lower layer', () {
      // The specification is explicit: "a platform limitation always wins".
      final settings = EffectiveSettings.resolve(
        defaults: defaults(),
        capabilities: const ToolCapabilities(orientationSensorAvailable: false),
        protocol: ToolOverrides().setting(WiseTool.level, value: true),
        session: ToolOverrides().setting(WiseTool.level, value: true),
      );

      expect(settings.levelEnabled, isFalse);
      expect(settings.sourceOf(WiseTool.level), SettingSource.platform);
    });

    test('each tool resolves independently', () {
      final settings = EffectiveSettings.resolve(
        defaults: defaults(),
        protocol: ToolOverrides().setting(WiseTool.overlay, value: false),
        session: ToolOverrides().setting(WiseTool.measurement, value: false),
      );

      expect(settings.overlayEnabled, isFalse);
      expect(settings.sourceOf(WiseTool.overlay), SettingSource.protocol);
      expect(settings.measurementEnabled, isFalse);
      expect(settings.sourceOf(WiseTool.measurement), SettingSource.session);
      expect(settings.levelEnabled, isTrue);
      expect(settings.sourceOf(WiseTool.level), SettingSource.userDefault);
    });
  });

  group('session overrides are temporary', () {
    test('resolving with an override does not mutate the stored default', () {
      // Functional SET-003 / Build Specification 2.7: "a one-capture override
      // must not silently modify the saved default".
      final stored = defaults();

      EffectiveSettings.resolve(
        defaults: stored,
        session: ToolOverrides().setting(WiseTool.measurement, value: false),
      );

      expect(
        stored.measurementEnabled,
        isTrue,
        reason: 'the persisted default must be untouched by resolution',
      );
    });

    test('clearing the session returns to the default', () {
      var session = ToolOverrides().setting(WiseTool.measurement, value: false);
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(),
          session: session,
        ).measurementEnabled,
        isFalse,
      );

      session = session.cleared();
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(),
          session: session,
        ).measurementEnabled,
        isTrue,
      );
    });

    test('clearing one tool leaves the other overrides in place', () {
      final session = ToolOverrides()
          .setting(WiseTool.measurement, value: false)
          .setting(WiseTool.overlay, value: false)
          .clearing(WiseTool.measurement);

      final settings = EffectiveSettings.resolve(
        defaults: defaults(),
        session: session,
      );

      expect(settings.measurementEnabled, isTrue);
      expect(settings.overlayEnabled, isFalse);
    });

    test('isSessionOverridden marks only session-decided tools', () {
      final settings = EffectiveSettings.resolve(
        defaults: defaults(),
        protocol: ToolOverrides().setting(WiseTool.overlay, value: false),
        session: ToolOverrides().setting(WiseTool.measurement, value: false),
      );

      expect(settings.isSessionOverridden(WiseTool.measurement), isTrue);
      expect(settings.isSessionOverridden(WiseTool.overlay), isFalse);
    });
  });

  group('overlay opacity', () {
    test('follows the same precedence as the tool flags', () {
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(opacity: 0.4),
        ).overlayOpacity,
        closeTo(0.4, 1e-9),
      );
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(opacity: 0.4),
          protocol: ToolOverrides().withOverlayOpacity(0.6),
        ).overlayOpacity,
        closeTo(0.6, 1e-9),
      );
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(opacity: 0.4),
          protocol: ToolOverrides().withOverlayOpacity(0.6),
          session: ToolOverrides().withOverlayOpacity(0.9),
        ).overlayOpacity,
        closeTo(0.9, 1e-9),
      );
    });

    test('is clamped to the specified 10%-100% range', () {
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(opacity: 0),
        ).overlayOpacity,
        closeTo(EffectiveSettings.minOverlayOpacity, 1e-9),
      );
      expect(
        EffectiveSettings.resolve(
          defaults: defaults(opacity: 5),
        ).overlayOpacity,
        closeTo(EffectiveSettings.maxOverlayOpacity, 1e-9),
      );
    });
  });

  group('privacy mode interaction', () {
    test('downgrades ALWAYS gallery saving to ASK', () {
      // Privacy Mode means "no automatic Gallery copy" (PRD 28, Functional
      // PRI-004). Obeying ALWAYS would make automatic copies anyway.
      final settings = EffectiveSettings.resolve(
        defaults: defaults(privacyMode: true, gallery: GallerySaveMode.always),
      );

      expect(settings.gallerySaveMode, GallerySaveMode.ask);
    });

    test('leaves NEVER alone', () {
      final settings = EffectiveSettings.resolve(
        defaults: defaults(privacyMode: true, gallery: GallerySaveMode.never),
      );

      expect(settings.gallerySaveMode, GallerySaveMode.never);
    });

    test('does not interfere when privacy mode is off', () {
      final settings = EffectiveSettings.resolve(
        defaults: defaults(gallery: GallerySaveMode.always),
      );

      expect(settings.gallerySaveMode, GallerySaveMode.always);
    });
  });

  test('the plain camera is reachable with every tool off', () {
    // PRD section 2: "The application must remain functional when all optional
    // tools are OFF."
    final allOff = UserPreferences(userId: 'u1', updatedAt: DateTime(2026))
        .copyWith(
          overlayEnabled: false,
          alignmentEnabled: false,
          lightingEnabled: false,
          focusEnabled: false,
        );

    final settings = EffectiveSettings.resolve(defaults: allOff);

    expect(settings.isPlainCamera, isTrue);
    expect(settings.activeTools, isEmpty);
  });
}
