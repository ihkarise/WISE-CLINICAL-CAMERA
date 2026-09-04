# Phase 2 Audit — WISE Clinical Camera

Phase 2 §3. A subsystem-by-subsystem statement of what exists, what is
verified, and what is merely written down.

The distinction this document is built around: **code that runs is not the
same as code that is checked**. A subsystem can be complete, elegant and
entirely unverified. Recording those separately is the point.

## Evidence basis

Every number below comes from a command run against this commit. Nothing is
recalled.

| | |
|---|---|
| Commit | `7cf00cf` |
| Date | 2026-09-04 |
| Toolchain | Flutter 3.35.5 stable · Dart 3.9.2 |
| `flutter analyze` | No issues found |
| `flutter test` | **410 passed, 0 failed** |
| `flutter test --coverage` | **45.6% line coverage (2671/5855)** |
| Production source | 113 files, 18,176 lines |
| Test source | 28 files, 7,132 lines |

Coverage figures per file come from `coverage/lcov.info`, produced by
`flutter test --coverage` on this commit.

## Status vocabulary

| Status | Meaning |
|---|---|
| **VERIFIED** | Implemented, and automated tests exercise the behaviour that matters. |
| **UNVERIFIED** | Implemented, but with no or negligible automated coverage. It may well work. Nothing proves it does. |
| **PARTIAL** | Some of the specified behaviour exists; some does not. |
| **BLOCKED — ENVIRONMENT** | Cannot be verified here for want of hardware or an SDK. Not a code defect. |
| **EXPERIMENTAL** | Present, behind a flag, off by default. |
| **MISSING** | Specified, not built. |
| **BROKEN** | Present and known not to work. |

There are no BROKEN entries at this commit. There is one MISSING entry, and it
is deliberate.

## The headline

The engine is verified. The screens are not.

| Layer | Coverage | Reading |
|---|---:|---|
| `lib/core/cv` | 87.0% | Verified |
| `lib/core/database` | 90.7% | Verified |
| `lib/core/imaging` | 89.8% | Verified |
| `lib/core/network` | 90.5% | Verified |
| `lib/core/measurement` | 84.4% | Verified |
| `lib/core/storage` | 83.2% | Verified |
| `lib/models` | 57.8% | Mixed |
| `lib/repositories` | 51.0% | Mixed |
| `lib/features/*` (UI) | 0–9% typical | Unverified |
| `lib/core/camera` | 19.4% | Hardware-bound |

That shape is defensible for a clinical imaging application — the parts that
can silently produce a *wrong measurement or a lost original* are the parts
under test — but it is not the same as being tested, and this document does not
pretend otherwise.

---

## 1. Capture

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 1.1 | Camera engine abstraction (`camera_engine.dart`) | VERIFIED | `test/unit/camera_engine_test.dart` — 14 tests | — |
| 1.2 | Plugin camera engine (`plugin_camera_engine.dart`) | BLOCKED — ENVIRONMENT | 0/197 lines. No camera in this container. | Needs the device matrix in `docs/testing/DEVICE_TEST_PLAN.md`. |
| 1.3 | Camera capabilities / platform veto | VERIFIED | 90.5%; `effective_settings_test.dart` — 15 tests | — |
| 1.4 | Fake camera engine (test double) | VERIFIED | 61.4%, used by the capture suites | — |
| 1.5 | Capture readiness (`capture_readiness.dart`) | VERIFIED | **100%** (33/33); `capture_readiness_test.dart` — 14 tests | — |
| 1.6 | Orientation guidance | VERIFIED | `orientation_guidance_test.dart` — 9 tests | Was dead code until this phase; see §"Defects found". |
| 1.7 | **Capture controller** (`capture_controller.dart`) | **UNVERIFIED** | **0/238 lines** | The orchestrator of the whole capture path is entirely untested. Largest single gap in the repository. `FakeCameraEngine` already exists, so this is testable **without hardware**. |
| 1.8 | Capture screen / review sheet | UNVERIFIED | 1.1% and 0% | Widget tests need a pumped camera surface. |
| 1.9 | Capture recipe (reproducibility) | PARTIAL | 61.3%; recorded and persisted | Replay of a recipe onto a live camera is untested (1.2). |

## 2. Computer vision

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 2.1 | Feature detection (FAST-9 + pyramid + rBRIEF) | VERIFIED | **100%** (119/119); benchmark 20 tests | Synthetic imagery only. |
| 2.2 | Descriptor matching (Hamming, ratio, cross-check) | VERIFIED | **100%** (28/28) | — |
| 2.3 | Transform estimation (RANSAC + Umeyama refit) | VERIFIED | **100%** (136/136) | — |
| 2.4 | Working image / pyramid | VERIFIED | 98.3% | — |
| 2.5 | Confidence model | VERIFIED (characterised) | 76.4%; `false_confidence_test.dart` — 19 tests | See §"Known characterisation". |
| 2.6 | Local alignment engine | VERIFIED | 83.7%; `alignment_engine_test.dart` — 14 tests | — |
| 2.7 | Lighting engine | VERIFIED | 89.7%; `quality_engines_test.dart` | — |
| 2.8 | Focus engine | VERIFIED | 87.5%; same suite | — |
| 2.9 | Guidance engine | VERIFIED | 92.2%; `guidance_engine_test.dart` — 18 tests | — |
| 2.10 | Alignment benchmark harness | VERIFIED | `alignment_benchmark_test.dart` — 20 tests, emits `docs/cv/THRESHOLDS.md` tables | **Synthetic ground truth only.** |
| 2.11 | Clinical-analogue dataset | PARTIAL | `clinical_analogue_test.dart` — 11 tests (hair, dressing, shadow, partial movement, gamma) | Analogues, not photographs. See §"The dataset question". |
| 2.12 | Homography / optical flow | EXPERIMENTAL (off) | `FeatureFlags.homography = false`, `opticalFlow = false` | CV §73 stages 4 and 7. Correctly deferred until benchmarked. |

## 3. Storage and integrity

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 3.1 | Two-phase file write (temp → verify → move → commit) | VERIFIED | 65.2%; `consistency_test.dart` — 12 tests | — |
| 3.2 | SHA-256 checksums | VERIFIED | **100%** (11/11) | — |
| 3.3 | Original immutability | VERIFIED | `original_immutability_test.dart` — 7 tests; `corrupt_input_test.dart` — 72 tests | Strongest-covered invariant in the project. |
| 3.4 | Storage paths | VERIFIED | 94.7% | — |
| 3.5 | Maintenance service | VERIFIED | 92.0% | Never repairs an original; reports only. Asymmetry is deliberate and tested. |
| 3.6 | Thumbnail generator | PARTIAL | 53.8% | Regeneration path untested. |

## 4. Database

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 4.1 | Schema | VERIFIED | `schema_test.dart` — 5 tests | — |
| 4.2 | Migrations 001–004 | VERIFIED | **100%** each; `migration_test.dart` — 6 tests | Forward migration only; no downgrade path exists or is specified. |
| 4.3 | Database service | VERIFIED | 82.0% | — |
| 4.4 | Photo repository | VERIFIED | 93.1%; `photo_repository_test.dart` — 20 tests | — |
| 4.5 | Clinical repository | PARTIAL | 51.9% | Calibration and measurement reads covered; annotation writes thin. |
| 4.6 | **Case repository** | **UNVERIFIED** | **0/36** | Testable without hardware. |
| 4.7 | **Protocol repository** | **UNVERIFIED** | **0/50** | Testable without hardware. |
| 4.8 | **Preference repository** | **UNVERIFIED** | **0/23** | Testable without hardware. Settings precedence is verified at the *model* layer (5.1) but not through persistence. |

## 5. Clinical tools

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 5.1 | Effective settings precedence | VERIFIED | **100%** (59/59) — platform veto → user → protocol → session | — |
| 5.2 | Measurement calculator | VERIFIED | 75.9%; `measurement_test.dart` — 30 tests | — |
| 5.3 | Measurement change / delta | VERIFIED | **100%** (32/32) | — |
| 5.4 | Calibration model | PARTIAL | 45.0% | No physical units without calibration is enforced and tested; the calibration *screen* is not (5.5). |
| 5.5 | Calibration screen | UNVERIFIED | 0/131 | — |
| 5.6 | Annotation model | VERIFIED | 85.5% | — |
| 5.7 | **Markup controller** | **UNVERIFIED** | **2/108** | Undo/redo, tool switching and pending-point state are unproven. Testable without hardware. |
| 5.8 | **Markup painter** (on-screen) | **UNVERIFIED** | **0/118** | See §"Defects found" — duplicates the export renderer's geometry. |
| 5.9 | Layer renderer (export) | VERIFIED | 92.2%; `markup_export_test.dart` — 23 tests | — |
| 5.10 | Layer stack | VERIFIED | 81.2% | — |
| 5.11 | Comparison model | PARTIAL | 30.2% | — |
| 5.12 | Difference view | PARTIAL | 42.2% | — |
| 5.13 | Comparison screen | UNVERIFIED | 0/121 | — |
| 5.14 | Export service | VERIFIED | 88.2% | — |
| 5.15 | Gallery service | UNVERIFIED | 18.2% | Platform-bound (`gal`); policy layer is covered by `gallery_policy_test.dart` — 8 tests. |

## 6. Privacy and security

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 6.1 | Network guard | VERIFIED | 90.5%; `network_policy_test.dart` — 11 tests | — |
| 6.2 | No-INTERNET-permission gate | VERIFIED | CI job asserts the Android manifest | — |
| 6.3 | Metadata anonymizer (EXIF) | VERIFIED | **100%** (23/23); `exif_roundtrip_test.dart` — 9 tests | — |
| 6.4 | Logger redaction | VERIFIED | 83.8%; `anonymization_and_logging_test.dart` — 15 tests | — |
| 6.5 | Corrupt / hostile input handling | VERIFIED | `corrupt_input_test.dart` — **72 tests** | — |
| 6.6 | Secret scan | VERIFIED | CI job, tuned against false positives per Phase 2 §30 | — |
| 6.7 | Permission service | BLOCKED — ENVIRONMENT | 2/28 | Needs a platform channel. |
| 6.8 | At-rest encryption | **MISSING** | — | Not implemented. Relies on OS-level device encryption. Deliberate for V1; recorded as a product decision in `SPECIFICATION_CONFLICTS.md`. |

## 7. Platform and shell

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 7.1 | App root / bootstrap | VERIFIED | 100%; `app_smoke_test.dart` — 4 tests | — |
| 7.2 | Routing | PARTIAL | 19.4% | Routes are exercised only where a screen test pumps them. |
| 7.3 | Riverpod provider graph | PARTIAL | 10.9% | Overrides are used throughout the test suite; the production graph itself is thinly covered. |
| 7.4 | Theme and tokens | VERIFIED | 93.8% | — |
| 7.5 | Accessibility | PARTIAL | `accessibility_test.dart` — 13 tests | Covers shared status widgets, home, and tokens. **Does not** cover capture, library, comparison or calibration screens. |
| 7.6 | Device level / sensors | PARTIAL | 36.6% | `level_test.dart` — 9 tests cover the maths; the sensor stream is platform-bound. |
| 7.7 | Feature flags | VERIFIED (by inspection) | 25.9% line coverage, but `aiFullyDisabled` is asserted in the privacy suite | — |
| 7.8 | AI service | EXPERIMENTAL (fully off) | 75.0%; every capability defaults `false`; guarded by the network guard | Intentionally inert. See Phase 2 §49. |

## 8. Build and release

| # | Gate | Status | Evidence |
|---|---|---|---|
| 8.1 | `dart format` | PASS | Clean at this commit |
| 8.2 | `flutter analyze` | PASS | No issues found |
| 8.3 | `flutter test` | PASS | 410/410 |
| 8.4 | Linux release build (AOT) | PASS | `flutter build linux --release` produced a 7.6 MB `libapp.so` |
| 8.5 | Android build | **BLOCKED — ENVIRONMENT** | `dl.google.com` returns 403 CONNECT through the agent proxy. The Android SDK cannot be installed here. CI job exists and is untested against a real runner. |
| 8.6 | iOS build | **BLOCKED — ENVIRONMENT** | No macOS host. CI job exists and is untested against a real runner. |
| 8.7 | Hardware camera test | **BLOCKED — ENVIRONMENT** | No device. |

`flutter build linux --release` is the only *release-mode AOT compilation*
evidence in this repository. It matters more than its platform suggests, because
`flutter test` runs JIT and would not catch a release-only compilation failure.
It proves nothing about the camera, sensors, permissions, gallery, path or
sqflite plugins — none of which have a Linux implementation. See `linux/README.md`.

---

## Defects found in Phase 2

Found by reading the code and by tests written to check it, not by tests that
were already failing. All are fixed at this commit unless stated.

1. **Orientation guidance was unreachable.** `CaptureGuidance.primaryInstruction`
   took a `currentOrientation` that the controller never supplied, so the
   portrait/landscape instruction could never fire. Fixed; `CameraEngine` now
   exposes `currentOrientation` and the controller passes it at all three call
   sites. *Nothing failed before this fix — the feature simply did not exist at
   runtime.*
2. **`CapturedImage` carried preview dimensions as if they were still
   dimensions.** A camera's preview resolution is not its capture resolution.
   Removed; dimensions are read from the encoded bytes at storage time.
3. **Capture recipes recorded a hard-coded portrait orientation.** Any recipe
   captured in landscape was wrong on replay. Fixed.
4. **`maxDimension` was not honoured on export.** The footer was composited
   *after* the resize, so an 800×600 export capped at 200 px produced a 200×210
   image. Found by a test written this phase. Fixed with a re-clamp after
   compositing.
5. **Every image widget decoded at full sensor resolution.** No `cacheWidth`
   anywhere. A 12 MP photograph is ~48 MB decoded, the comparison screen holds
   two, and Flutter's default image cache is 100 MB. Fixed by `ClinicalImage`.
   *Not verified on hardware* — the reduction is arithmetic, not a measured heap
   profile.
6. **The on-screen painter and the export renderer duplicate their geometry.**
   `MarkupPainter._paintArrowHead` and `LayerRenderer._drawArrowHead` both
   hard-code `spread = 0.5` and `length = thickness * 4`, in two idioms — and
   they already disagree: the export renderer floors the arrowhead at 10 px,
   the on-screen painter does not. At small stroke widths the clinician sees no
   arrowhead and the export has one. **Open.** This is a what-you-see-is-what-you-
   export defect and it is the reason 5.8 being at 0% coverage matters.

## Known characterisation, deliberately not "fixed"

**The confidence model conflates estimator trust with alignment quality.** At
scale 1.2× the estimator recovers the transform essentially perfectly (1.200
against a true 1.200) and still reports POOR (0.64), because few features
survive the scale change. A clinician reading "POOR" would reasonably infer the
alignment is wrong. It is not; the evidence for it is merely thin.

This is documented rather than tuned. Retuning a confidence curve against
synthetic imagery is precisely what CV §78 warns against — it would produce a
model calibrated to the test generator. The correction belongs with the real
dataset work, and is recorded in `docs/cv/THRESHOLDS.md`.

## The dataset question

Every CV number in this repository comes from **synthetically generated
imagery**. The clinical-analogue suite adds hair-like texture, dressing
occlusion, directional shadow, partial subject movement and gamma shift — those
are the failure modes real wound photography exhibits — but they remain
analogues.

Per Phase 2 §14, none of these results may be described as clinical accuracy.
They characterise the algorithm's behaviour under controlled distortion. That
is a genuine and useful thing to know, and it is not the same thing.

`test_data/` is laid out for real-world validation. Per Phase 2 §15, no clinical
photograph is committed to this repository, and none should be.

## What would move the needle most

Ranked by verification gained per unit of work, and restricted to what needs no
hardware:

1. **`capture_controller.dart` (0/238).** `FakeCameraEngine` already exists.
   This is the single highest-value test file not yet written.
2. **`markup_controller.dart` (2/108).** Undo/redo and tool state are pure Dart.
3. **The three untested repositories (0/109 combined).** `sqflite_common_ffi`
   is already wired into the test harness.
4. **Shared arrowhead/label geometry**, so the painter and the renderer cannot
   disagree — and a test that proves they don't.
5. **Model round-trips** for `capture_protocol`, `clinical_case`,
   `quality_check`, `wise_user` (0% each), against the real schema.

Items requiring hardware or an SDK — the camera engine, permissions, sensors,
gallery, and the Android and iOS builds — cannot be closed in this environment
and are marked BLOCKED — ENVIRONMENT rather than assumed working.

## Honest summary

This is a large, coherent, well-factored implementation whose **safety-critical
core is genuinely tested** and whose **user interface is largely not**. The
invariants that protect a patient's data — originals never mutated, nothing
leaves the device, no physical units without calibration — are the best-covered
code in the repository, which is the right priority.

It is **not release ready**, and the blockers are specific: no build has ever
run on Android or iOS, no photograph has ever been taken with a real camera, and
no real clinical image has been through the alignment pipeline.
