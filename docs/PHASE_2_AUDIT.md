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
| Commit | `289f257` (the last commit that changes code) |
| Date | 2026-09-04 |
| Toolchain | Flutter 3.35.5 stable · Dart 3.9.2 |
| `flutter analyze` | No issues found |
| `flutter test` | **524 passed, 0 failed** |
| `flutter test --coverage` | **77.6% line coverage (4576/5900)** |
| `flutter build linux --release` | Succeeded; 7.6 MB `libapp.so` |
| Production source | 114 files |
| Test source | 33 files |

At the start of Phase 2 the suite stood at 410 tests and 45.6% coverage. Both
figures below are the current ones; where a subsystem moved, the row says so.

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

There are no BROKEN entries at this commit. There was one — the library grid,
defect 7 below — and it is fixed. There are no MISSING entries: the one
capability that is absent, at-rest encryption, is DEFERRED by a specification
that names the fallback, and is recorded as C-019.

## The headline

The audit opened with a finding: **the engine was verified and the screens were
not.** The feature layer sat at 0–9% line coverage, and the phase was spent
closing that, because the gap was not merely cosmetic — the library screen threw
on every build and had never once displayed a photograph.

| Layer | Coverage | Was | Reading |
|---|---:|---:|---|
| `lib/repositories` | 92.7% | 51.0% | Verified |
| `lib/models` | 86.3% | 57.8% | Verified |
| `lib/core` | 75.0% | — | Verified, except the camera |
| `lib/features` (UI) | 74.4% | ~10% | Verified |
| `lib/shared` | 79.2% | 55.7% | Verified |
| `lib/app` | 68.1% | 19.5% | Mixed |
| `lib/services` | 47.8% | — | Platform-bound |
| `lib/core/camera` | 23.9% | 19.4% | Hardware-bound; the plugin engine itself is still 0/197 |

Everything that remains low is low for a reason named in a row below, and the
single largest remaining block — `plugin_camera_engine.dart`, 0/197 — needs a
camera.

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
| 1.7 | Capture controller (`capture_controller.dart`) | **VERIFIED** | 88.3% (was 0/238); `capture_controller_test.dart` — 30 tests | Closed this phase. Found the disposal defect and the protocol wiring defect. |
| 1.8 | Capture screen | **VERIFIED** | 84.2% (was 1.1%); `screen_smoke_test.dart` builds it in all three modes | — |
| 1.8b | Capture review sheet | UNVERIFIED | 0/41 | Reached only after a capture completes on the screen. |
| 1.9 | Capture recipe (reproducibility) | PARTIAL | 61.3%; recorded and persisted | Replay of a recipe onto a live camera is untested (1.2). |

## 2. Computer vision

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 2.1 | Feature detection (FAST-9 + pyramid + rBRIEF) | VERIFIED | **100%** (119/119); benchmark 20 tests | Synthetic imagery only. |
| 2.2 | Descriptor matching (Hamming, ratio, cross-check) | VERIFIED | **100%** (28/28) | — |
| 2.3 | Transform estimation (RANSAC + Umeyama refit) | VERIFIED | **100%** (136/136) | — |
| 2.4 | Working image / pyramid | VERIFIED | 98.3% | — |
| 2.5 | Confidence model | VERIFIED (characterised) | 76.4%; `false_confidence_test.dart` — 19 tests | See "Known characterisation" below. |
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
| 4.5 | Clinical repository | **VERIFIED** | 91.3% (was 51.9%) | Closed this phase. |
| 4.6 | Case repository | **VERIFIED** | **100%** (was 0/36); `persistence_roundtrip_test.dart` | Closed this phase. |
| 4.7 | Protocol repository | **VERIFIED** | **100%** (was 0/50) | Closed this phase. |
| 4.8 | Preference repository | **VERIFIED** | 69.6% (was 0/23) | Exercised through the capture controller's settings chain. |

## 5. Clinical tools

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 5.1 | Effective settings precedence | VERIFIED | **100%** (59/59) — platform veto → user → protocol → session | — |
| 5.2 | Measurement calculator | VERIFIED | 75.9%; `measurement_test.dart` — 30 tests | — |
| 5.3 | Measurement change / delta | VERIFIED | **100%** (32/32) | — |
| 5.4 | Calibration model | **VERIFIED** | 68.3% (was 45.0%) | "No physical units without calibration" is now asserted at the model, the controller and the screen. |
| 5.5 | Calibration screen | PARTIAL | 42.0% (was 0/131) | Renders with data; the drag-to-calibrate gesture is untested. |
| 5.6 | Annotation model | VERIFIED | 85.5% | — |
| 5.7 | Markup controller | **VERIFIED** | 97.5% (was 2/108); `markup_controller_test.dart` — 21 tests | Closed this phase. Found the disposal defect. |
| 5.8 | Markup painter (on-screen) | **VERIFIED** | 87.7% (was 0/118); `markup_rendering_test.dart` — 13 tests | Closed this phase. Found the arrowhead divergence. |
| 5.8b | Markup screen | PARTIAL | 59.2% (was 0/130) | Renders with data; the tap-to-place gesture is untested. |
| 5.9 | Layer renderer (export) | VERIFIED | 92.2%; `markup_export_test.dart` — 23 tests | — |
| 5.10 | Layer stack | VERIFIED | 81.2% | — |
| 5.11 | Comparison model | **VERIFIED** | 90.7% (was 30.2%) | Round-tripped through the real schema. |
| 5.12 | Difference view | PARTIAL | 42.2% | The disclaimer is asserted; the rendered difference is not. |
| 5.13 | Comparison screen | PARTIAL | 57.0% (was 0/121) | Renders with data in every mode; mode switching is untested. |
| 5.14 | Export service | VERIFIED | 88.2% | — |
| 5.15 | Gallery service | BLOCKED — ENVIRONMENT | 18.2% | Platform-bound (`gal`); the policy layer is covered by `gallery_policy_test.dart` — 8 tests. |

## 6. Privacy and security

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 6.1 | Network guard | VERIFIED | 90.5%; `network_policy_test.dart` — 11 tests | — |
| 6.2 | No-INTERNET-permission gate | VERIFIED | CI job asserts the Android manifest | — |
| 6.3 | Metadata anonymizer (EXIF) | VERIFIED | **100%** (23/23); `exif_roundtrip_test.dart` — 9 tests | — |
| 6.4 | Logger redaction | VERIFIED | 83.8%; `anonymization_and_logging_test.dart` — 15 tests | — |
| 6.5 | Corrupt / hostile input handling | VERIFIED | `corrupt_input_test.dart` — **72 tests** | — |
| 6.6 | Secret scan | VERIFIED | CI job, tuned against false positives per Phase 2 §30 | — |
| 6.7 | Permission service | BLOCKED — ENVIRONMENT | 28.6% | The decision logic is now exercised through a scripted shim; the platform channel itself still needs a device. |
| 6.8 | At-rest encryption | **DEFERRED** | Privacy §338 permits it | No application-level encryption; relies on OS device encryption and an excluded Android backup. On a device with no passcode this offers nothing. Recorded as C-019 in `SPECIFICATION_CONFLICTS.md`. |

## 7. Platform and shell

| # | Subsystem | Status | Evidence | Gap |
|---|---|---|---|---|
| 7.1 | App root / bootstrap | VERIFIED | 100%; `app_smoke_test.dart` — 4 tests | — |
| 7.2 | Routing | PARTIAL | 25.8% | `generateWiseRoute` is installed in every screen test but most routes are never navigated to. |
| 7.3 | Riverpod provider graph | **VERIFIED** | 62.4% (was 10.9%) | The real graph is now built in every controller and screen test. |
| 7.4 | Theme and tokens | VERIFIED | 93.8% | — |
| 7.5 | Accessibility | PARTIAL | `accessibility_test.dart` — 13 tests | Covers the shared status widgets, home and the tokens. **Does not** run the guideline matchers over the capture, library, comparison or calibration screens. |
| 7.6 | Device level / sensors | **VERIFIED** | 73.3% (was 36.6%) | The arithmetic and the stream handling are both covered; the physical sensor is not. |
| 7.7 | Feature flags | VERIFIED (by inspection) | 25.9% line coverage, but `aiFullyDisabled` is asserted in the privacy suite | — |
| 7.8 | AI service | EXPERIMENTAL (fully off) | 75.0%; every capability defaults `false`; guarded by the network guard | Intentionally inert. See Phase 2 §49. |

## 8. Build and release

| # | Gate | Status | Evidence |
|---|---|---|---|
| 8.1 | `dart format` | PASS | Clean at this commit |
| 8.2 | `flutter analyze` | PASS | No issues found |
| 8.3 | `flutter test` | PASS | 524/524 |
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

Ten, all found by reading the code or by tests written to check it, none by a
test that was already failing. All are fixed at this commit.

1. **Orientation guidance was unreachable.** `CaptureGuidance.primaryInstruction`
   took a `currentOrientation` the controller never supplied, so the
   portrait/landscape instruction could never fire. `CameraEngine` now exposes
   `currentOrientation` and the controller passes it at all three call sites.
   *Nothing failed before this fix — the feature simply did not exist at
   runtime.*
2. **`CapturedImage` carried preview dimensions as if they were still
   dimensions.** A camera's preview resolution is not its capture resolution.
   Removed; dimensions are read from the encoded bytes at storage time.
3. **Capture recipes recorded a hard-coded portrait orientation.** Any recipe
   captured in landscape was wrong on replay.
4. **`maxDimension` was not honoured on export.** The footer was composited
   *after* the resize, so an 800×600 export capped at 200 px produced a 200×210
   image. Found by a test written this phase.
5. **Every image widget decoded at full sensor resolution.** No `cacheWidth`
   anywhere. A 12 MP photograph is ~48 MB decoded, the comparison screen holds
   two, and Flutter's default image cache is 100 MB. Fixed by `ClinicalImage`.
   *Not verified on hardware* — the reduction is arithmetic, not a measured heap
   profile.
6. **The on-screen painter and the export renderer disagreed about
   arrowheads.** Both hard-coded the geometry; the export floored the barb at
   10 px and the painter did not, so below a 2.5 px stroke the clinician saw a
   bare line and the exported file carried an arrow. An export is meant to be
   evidence of what was marked; if the two renderers disagree about the mark, it
   is not. Now one shared `ArrowHead`, with a test that fails if either grows a
   private copy.
7. **The library grid could never lay out a thumbnail.** `LibraryScreen` passes
   `size: double.infinity` meaning "fill the tile"; `PhotoThumbnail` turned that
   into a `SizedBox` of infinite height inside a `Column`, which throws. **The
   library has never displayed a photograph.** Confirmed pre-existing by running
   the new test against the code as it stood before this phase's image work.
   This is the finding that justifies the whole exercise: a screen at 3.8%
   coverage was not merely untested, it was broken.
8. **A protocol's `hardAlignmentThreshold` never reached the check that applies
   it.** Selecting a protocol stored only its tool block and discarded
   everything else, and the capture controller never passed a protocol into
   `CaptureReadiness`. The one mechanism the specification permits to block
   capture was silently advisory. Nothing shipped changes — every seeded
   protocol leaves the threshold null — but a configured one now works.
9. **Controllers wrote state after their screen had gone.** Both controllers
   awaited a repository and then assigned to `state` without checking they were
   still mounted, which Riverpod throws on. Opening a photograph's markup and
   going straight back was enough to trigger it. Every post-await write in both
   controllers is now guarded; in `capture()` the storage path deliberately runs
   to completion regardless, because a capture the clinician cannot repeat is
   not something to abandon because nobody is watching.
10. **`CaptureController.dispose` read a provider during scope teardown.** The
    read throws once the container is disposed, and the throw meant
    `_alignment.reset()` never ran — so the alignment engine kept the reference
    image and its descriptors, the largest thing a session holds, for the life
    of the process.

Two of these (7 and 9) were only findable by rendering a screen. Both had been
in the repository since the feature was written.

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

## Functional gaps found, deliberately not built

Phase 2 is a verification and hardening phase, so these are recorded rather
than fixed. Each is a specified capability that is modelled, persisted and
queryable but has no way in.

1. **No screen sets a photograph's clinical metadata.** `bodyPart`,
   `laterality` and `caseId` are supported by the model, written by the
   repository, filterable in `getPhotos`, and displayed on the detail screen —
   but `CaptureController.setMetadata` has no caller anywhere in the
   application. Every photograph is therefore captured with all three null, and
   the library's body-part filter can never match anything. Closing it means
   building a metadata entry step, which is a feature.
2. **A protocol's non-tool settings are stored but unused.**
   `preferredOrientation`, `preferredFlash`, `measurementRequired` and
   `exportPreset` round-trip through the database correctly and nothing reads
   them. `hardAlignmentThreshold` was in this list until this phase; the others
   remain.
3. **No downgrade path exists for the database.** Migrations run forward only.
   No specification requires otherwise, and it is recorded here so the absence
   is a decision rather than an oversight.

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
photograph is committed to this repository, and none should be. The image
directories are ignored, and that was verified by dropping a file into one and
confirming git does not see it.

## What is left, and why

Ranked by what it would take rather than by line count.

**Needs hardware or an SDK, and nothing else:**

| Item | State |
|---|---|
| `plugin_camera_engine.dart` (0/197) | The single largest untested file. Needs a camera. |
| `permission_service.dart` (28.6%) | Decision logic covered through a scripted shim; the platform channel is not. |
| `gallery_service.dart` (18.2%) | Platform-bound; the policy layer is covered. |
| Android and iOS builds | The SDK host is blocked by the egress proxy; there is no macOS host. |
| Every performance figure | No heap or frame profile exists. |

**Needs a governed clinical dataset:**

Every threshold in `AlignmentConfig` and `QualityConfig`, and the confidence
characterisation above.

**Could still be done here, in rough order of value:**

1. Gesture paths — tap-to-place in markup, drag-to-calibrate, comparison mode
   switching. Rendering is covered; interaction is not.
2. `capture_review_sheet.dart` (0/41), reachable only after a capture completes
   on the screen.
3. `wise_error_view.dart` (0/19) and `recent_photos_strip.dart` (30.4%).
4. Running the accessibility guideline matchers over the full screens rather
   than the shared widgets.

## Honest summary

This began as a large, coherent implementation whose safety-critical core was
genuinely tested and whose user interface was not tested at all. That asymmetry
turned out to be hiding two real defects, one of which meant a primary screen
had never worked.

The invariants that protect a patient's data — originals never mutated, nothing
leaves the device, no physical units without calibration — remain the
best-covered code in the repository, and are now asserted at every layer they
pass through rather than only at the model.

It is **not release ready**, and the blockers are specific and unchanged by any
of this work: no build has ever run on Android or iOS, no photograph has ever
been taken with a real camera, and no real clinical image has been through the
alignment pipeline.
