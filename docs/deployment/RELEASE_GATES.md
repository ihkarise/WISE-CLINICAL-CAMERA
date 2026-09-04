# V1 Release Gates

The gates from Build Specification §115, Functional §49 and Phase 2 §6/§46.

Every row carries the command that produced its status. A gate whose command
was not run says **NOT RUN**; a gate that cannot be run here says
**BLOCKED — ENVIRONMENT** and names what is missing. Nothing is marked PASS on
the strength of the code looking right.

| | |
|---|---|
| Commit | `db221ef` |
| Date | 2026-09-04 |
| Toolchain | Flutter 3.35.5 stable · Dart 3.9.2 |
| Suite | **524 tests, 0 failures** |
| Coverage | **77.8% lines (4586/5894)** |

## Status vocabulary

| Status | Meaning |
|---|---|
| **PASS** | A command was run and it succeeded. The command is in the row. |
| **PARTIAL** | Verified in part. The row says which part is not covered. |
| **FAIL** | A command was run and it failed. |
| **BLOCKED — ENVIRONMENT** | Cannot be run here. Not a code defect. |
| **NOT RUN** | Runnable, not yet run. |
| **DEFERRED** | A specification defers it out of V1. |

## Summary

| Status | Count |
|---|---:|
| PASS | 24 |
| PARTIAL | 6 |
| BLOCKED — ENVIRONMENT | 6 |
| DEFERRED | 1 |
| FAIL | 0 |

**V1 is not releasable.** No gate fails, and none is blocked by missing code.
Six are blocked on hardware and SDKs that are unobtainable in this environment,
and the CV thresholds are unvalidated against real clinical images. Those are
the blockers, and they are inputs rather than work.

---

## Build and toolchain

| Gate | Status | Evidence | How to verify | Blocking |
|---|---|---|---|---|
| Static analysis clean | **PASS** | `No issues found` | `flutter analyze` | Yes |
| Formatting clean | **PASS** | CI job `analyze` | `dart format --set-exit-if-changed lib test` | Yes |
| Full test suite green | **PASS** | `524 tests, All tests passed!` | `flutter test` | Yes |
| Release AOT compilation | **PASS** | `flutter build linux --release` produced a 7.6 MB `libapp.so` | `flutter build linux --release` | Yes |
| Android build | **BLOCKED — ENVIRONMENT** | `dl.google.com` returns 403 CONNECT through the agent proxy; the Android SDK cannot be installed here | CI job `build-android` on a runner with the SDK | **Yes** |
| iOS build | **BLOCKED — ENVIRONMENT** | No macOS host | CI job `build-ios` on a macOS runner | **Yes** |

`flutter test` runs the Dart VM in JIT and would not catch a release-only
compilation failure, which is why the Linux release build is a gate in its own
right. It is a compilation gate only: the camera, sensors, permissions, gallery,
path and sqflite plugins have no Linux implementation and are absent from the
plugin registrant. See `linux/README.md`.

## The three modes

| Gate | Status | Evidence | How to verify | Blocking |
|---|---|---|---|---|
| BEFORE capture | **PASS** | `capture_controller_test.dart` (30), `clinical_workflow_test.dart` | `flutter test test/features/ test/integration/` | Yes |
| AFTER capture with a reference | **PASS** | Same, including the reference relationship in both directions | as above | Yes |
| PHOTO capture | **PASS** | `clinical_workflow_test.dart` | as above | Yes |
| Capture is never blocked by a warning | **PASS** | `capture_controller_test.dart`: a flat, featureless frame still permits the shutter | `flutter test test/features/capture_controller_test.dart` | Yes |
| A protocol's hard threshold can block | **PASS** | Same file: an AFTER session under a 0.99 threshold refuses the shutter, and permits it with no protocol | as above | Yes |
| Camera on real hardware | **BLOCKED — ENVIRONMENT** | `plugin_camera_engine.dart` is 0% covered; there is no camera here | `docs/testing/DEVICE_TEST_PLAN.md` D-CAM-01..12 | **Yes** |

## Clinical tools

| Gate | Status | Evidence | How to verify | Blocking |
|---|---|---|---|---|
| Reference selection | **PASS** | `screen_smoke_test.dart`, `reference_transform_test.dart` | `flutter test test/widget/` | Yes |
| Ghost overlay | **PARTIAL** | Renders; the transform model is fully tested | Gesture handling needs D-OVL-01..06 | No |
| Alignment engine | **PASS** (synthetic) | `alignment_benchmark_test.dart` (20): scale, rotation and translation recovered to ~2% | `flutter test test/cv/` | Yes |
| Alignment on clinical images | **BLOCKED — DATASET** | Every figure comes from generated imagery | D-ALN-01..10 against a governed dataset; see `test_data/README.md` | **Yes** |
| Lighting check | **PASS** (synthetic) | `quality_engines_test.dart` | `flutter test test/cv/` | No |
| Focus check | **PASS** (synthetic) | Laplacian variance monotonic under blur | as above | No |
| Grid | **PASS** | `screens_test.dart`: draws for every type, stays inside an `IgnorePointer` | `flutter test test/widget/screens_test.dart` | Yes |
| Level | **PARTIAL** | Roll and pitch arithmetic tested directly; the sensor stream is faked | Needs a real accelerometer, D-LVL-01..04 | No |
| Calibration | **PASS** | `measurement_test.dart`, including every rejection case | `flutter test test/unit/measurement_test.dart` | Yes |
| Measurement | **PASS** | The specification's worked examples reproduce exactly | as above | Yes |
| No physical units without calibration | **PASS** | `markup_controller_test.dart`, `screens_test.dart` — asserted at the model, the controller and the screen | `flutter test test/features/ test/widget/` | Yes |
| Annotation | **PASS** | `markup_controller_test.dart` (21), `markup_export_test.dart` (23) | `flutter test test/features/ test/integration/` | Yes |
| On-screen and exported markup agree | **PASS** | `markup_rendering_test.dart` (13): both draw from one shared geometry | `flutter test test/imaging/` | Yes |
| Comparison, all five modes | **PARTIAL** | Renders and persists; alignment reuse tested | Visual behaviour needs a device | No |
| Export, seven presets | **PASS** | `markup_export_test.dart`, `export_sheet` coverage | `flutter test test/integration/` | Yes |
| Measurement accuracy quantified | **BLOCKED — ENVIRONMENT** | The mathematics is verified; the real-world error is not | D-MES-01..07 | No — but no accuracy figure may be published until it closes |

## Data and integrity

| Gate | Status | Evidence | How to verify | Blocking |
|---|---|---|---|---|
| Originals immutable | **PASS** | SHA-256 unchanged across a full annotate/measure/export/anonymise cycle; `corrupt_input_test.dart` (72) | `flutter test test/privacy/ test/security/` | Yes |
| Two-phase write, no orphans | **PASS** | `consistency_test.dart` (12) | `flutter test test/database/` | Yes |
| Migrations, fresh and upgrade | **PASS** | `migration_test.dart`; all four migrations 100% covered | as above | Yes |
| Everything written can be read back | **PASS** | `persistence_roundtrip_test.dart` (24) | as above | Yes |
| Preferences persist | **PASS** | Round-tripped through real SQLite | as above | Yes |
| Session overrides never persist | **PASS** | `capture_controller_test.dart`: an override reaches the settings chain and never the database | `flutter test test/features/` | Yes |
| Deleting a case keeps its photographs | **PASS** | `persistence_roundtrip_test.dart` | `flutter test test/database/` | Yes |

## Privacy and security

| Gate | Status | Evidence | How to verify | Blocking |
|---|---|---|---|---|
| Offline core workflow | **PASS** | Empty network audit after the complete workflow | `flutter test test/privacy/` | Yes |
| No INTERNET permission | **PASS** | CI asserts the Android manifest | CI job `privacy-gates` | Yes |
| Privacy Mode | **PASS** | `network_policy_test.dart` (11) | `flutter test test/privacy/` | Yes |
| EXIF anonymisation | **PASS** | `exif_roundtrip_test.dart` (9); `metadata_anonymizer` 100% | as above | Yes |
| Log redaction | **PASS** | `anonymization_and_logging_test.dart` (15) | as above | Yes |
| No secrets committed | **PASS** | CI secret scan, tuned so the logger's own redaction list does not trip it | CI job `privacy-gates` | Yes |
| Hostile input handled | **PASS** | `corrupt_input_test.dart` (72) | `flutter test test/security/` | Yes |
| Permission flows on device | **BLOCKED — ENVIRONMENT** | `permission_service.dart` at 28.6%; no platform channel here | D-PRM-01..05 | **Yes** |
| At-rest encryption | **DEFERRED** | Not implemented; relies on OS device encryption | Product decision, see `SPECIFICATION_CONFLICTS.md` | No |
| Penetration test | **NOT RUN** | Privacy §79 | External engagement | No for V1 |

## Application behaviour

| Gate | Status | Evidence | How to verify | Blocking |
|---|---|---|---|---|
| Every screen renders | **PASS** | `screen_smoke_test.dart` (10) builds all of them with real data and fails on any framework exception | `flutter test test/widget/screen_smoke_test.dart` | Yes |
| Accessibility guidelines | **PARTIAL** | `accessibility_test.dart` (13) covers the shared status widgets, home and the tokens | The full capture, library, comparison and calibration screens are not asserted against the guideline matchers | No |
| Status never colour-only | **PASS** | Every state chip carries an icon and a word | `flutter test test/widget/accessibility_test.dart` | Yes |
| Performance on device | **BLOCKED — ENVIRONMENT** | Decode is bounded by construction; no heap or frame profile exists | D-PRF-01..08 | No |
| Low-end degradation | **PARTIAL** | Decode resolution bounded; frame analysis drops rather than queues | Needs a low-end device | No |
| AI stays optional and off | **PASS** | Every AI flag defaults false; `aiFullyDisabled` asserted in the privacy suite | `flutter test test/privacy/` | Yes |
| Cloud AI | **DEFERRED** | AI §4 Tier 4, Build Specification §67 | — | No |

---

## What actually blocks release

Three things, none of them code.

**1. No build has ever run for Android or iOS.** Gradle configuration, plugin
registration and pod integration all fail in ways static analysis cannot see.
The CI jobs exist and are written; they have never executed on a runner with
the toolchains. Until they do, "it compiles" is an assumption.

*To close:* run CI on an Ubuntu runner with the Android SDK and a macOS runner
with Xcode.

**2. No photograph has ever been taken with a real camera.** The entire capture
path is verified against `FakeCameraEngine`. That proves the orchestration —
and it found real defects — but it says nothing about a real sensor's
orientation reporting, its still resolution, its focus behaviour, or how any of
it degrades on a mid-range Android device.

*To close:* `docs/testing/DEVICE_TEST_PLAN.md`, D-CAM and D-PRM.

**3. No clinical image has been through the alignment pipeline.** Every CV
threshold in `AlignmentConfig` and `QualityConfig` is provisional. CV §78 is
explicit that they must be established experimentally, and the synthetic
dataset — even with the hair, dressing, shadow, movement and gamma analogues
added this phase — cannot stand in for real skin, wounds, dressings, varied skin
tones and real lighting change.

Shipping with them would mean publishing confidence figures nobody has checked,
which is the specific failure CV §71 warns about. The benchmark already shows
the shape of the problem: at 1.2× scale the estimator recovers the transform
essentially perfectly and still reports POOR, because confidence currently
tracks feature survival rather than alignment correctness.

*To close:* D-ALN-01..10 against a governed dataset, laid out in
`test_data/README.md`. No clinical photograph is committed to this repository.

## Missing inputs, not missing code

| Input | Consequence |
|---|---|
| Android SDK, Xcode, real devices | Six gates unverifiable |
| Governed clinical dataset | CV thresholds cannot be validated; no accuracy figure may be published |
| Design system source | Radii, elevation, gradients and icons are inferred from what the UX/UI specification quotes (C-014) |
| Logo, icon, splash, Poppins files | The application renders on platform defaults (C-015) |

## Milestone acceptance

Build Specification §114 requires, before moving on: P0 tests pass, no critical
data-loss issue, no original-image corruption, no unexpected network upload, no
unresolved build failure.

The first four hold and are enforced by CI. The fifth now holds for release AOT
compilation on Linux, and remains unasserted for Android and iOS.
