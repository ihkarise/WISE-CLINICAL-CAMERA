# Linux target — build verification only

**This is not a shipping platform.** The product targets iOS and Android
(PRD, Technical Architecture §3). This directory exists so that a *real*
Flutter build can be executed and proven in an environment without the Android
SDK or Xcode.

## What `flutter build linux --release` proves

- The entire Dart tree compiles **AOT in release mode**. `flutter test` runs in
  JIT, so it never exercises AOT compilation, tree-shaking, or const
  evaluation under release settings. This is the only gate in the project that
  does.
- The plugin registration mechanism generates and compiles.
- Native linking succeeds.

## What it does not prove

Most plugins have no Linux implementation and are simply omitted from the
generated registrant. This build therefore says **nothing** about:

`camera` · `sensors_plus` · `permission_handler` · `image_picker` · `gal` ·
`path_provider` · `sqflite`

Those are verified only by `flutter build apk` / `flutter build ios` and by
running on hardware. See `docs/testing/DEVICE_TEST_PLAN.md`.

## Do not

- Add Linux-specific product code.
- Treat a passing Linux build as an Android or iOS release gate.
- Remove it without replacing the AOT compile gate it provides.
