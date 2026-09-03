# V1 Release Gates

The gates from Build Specification §115, Functional §49 and master prompt Phase
64, with an honest status for each.

**Legend:** ✅ met and verified · ⚙️ implemented, verification needs hardware ·
❌ not met · ⏸️ deferred by a specification

---

## Summary

| | Count |
|---|---:|
| ✅ Met and verified automatically | 14 |
| ⚙️ Implemented, needs device verification | 11 |
| ❌ Not met | 2 |
| ⏸️ Deferred by specification | 1 |

**V1 is not releasable.** Two gates are unmet, and eleven cannot be closed
without hardware. Nothing here is a coding gap: the blockers are the build
toolchains, real devices, and a real clinical dataset.

---

## The gates

| Gate | Status | Evidence or what is missing |
|---|---|---|
| iOS build works | ❌ | No Xcode in this environment. CI has a macOS job ready to run |
| Android build works | ❌ | No Android SDK; the egress proxy blocks Google's SDK host. CI has an Ubuntu job ready to run |
| Camera works | ⚙️ | `CameraEngine` and `PluginCameraEngine` implemented with capability probing. Needs D-CAM-01..12 |
| BEFORE works | ✅ | `clinical_workflow_test.dart`, `photo_repository_test.dart` |
| AFTER works | ✅ | Same, including the reference relationship both ways |
| PHOTO works | ✅ | `clinical_workflow_test.dart` |
| Reference works | ✅ | Picker, loader and candidate filtering tested |
| Overlay works | ⚙️ | `GhostOverlay` with opacity, transform, flip and lock; the transform model is tested, the gesture path needs a device |
| Alignment works on validated cases | ⚙️ | Validated on **synthetic** ground truth to within ~2 % on translation, rotation and scale. **Not validated on clinical images** — D-ALN-01..10 |
| Lighting check works | ⚙️ | Tested against synthetic brightness and histogram change; real lighting needs D-ALN-09 |
| Focus check works | ⚙️ | Laplacian variance monotonic under blur; the threshold needs per-device validation |
| Grid works | ✅ | Display layer only; the immutability test confirms it never reaches an original |
| Level works | ⚙️ | Roll and pitch derivation tested directly; needs a real accelerometer |
| Calibration works | ✅ | `measurement_test.dart`, including every rejection case |
| Measurement works | ✅ | Specification worked examples reproduce exactly |
| Annotation works | ✅ | Eight types, non-destructive, editable, hideable, deletable |
| Comparison works | ⚙️ | All five modes implemented; alignment reuse is tested; visual behaviour needs a device |
| Export works | ✅ | Seven presets tested end to end |
| Privacy Mode works | ✅ | `privacy_mode` gating and gallery downgrade tested |
| Offline workflow works | ✅ | Empty network audit after the full workflow. Device-level confirmation is D-OFF-03 |
| Preferences persist | ✅ | Stored in SQLite; round-trip tested |
| Session overrides work | ✅ | Resolution is pure and writes nothing |
| Originals remain immutable | ✅ | SHA-256 before and after a full annotate/measure/export/anonymize cycle |
| Database migrations work | ✅ | Fresh install and a v1-to-current upgrade with rows intact |
| Security checks pass | ⚙️ | Secret scan clean, no `INTERNET` permission, backup excluded, no hard-coded credentials. A penetration test (Privacy §79) is outstanding |
| Privacy checks pass | ✅ | Original protection, network policy, anonymization, log redaction, no GPS field |
| Performance checks pass | ⚙️ | No device measurements. D-PRF-01..08 |
| Regression suite passes | ✅ | Full suite green |
| P0 test suite passes | ✅ | Every P0 requirement has an automated test |
| AI optional | ✅ | No provider registered; the core runs untouched with AI off |
| Cloud AI implementation | ⏸️ | Deferred by AI §4 Tier 4 and Build Specification §67 |

---

## What blocks release

### 1. Platform builds (❌)

Neither `flutter build apk` nor `flutter build ios` has run. The CI workflow
defines both jobs and they should pass on a runner with the toolchains, but
"should" is not "did". Gradle configuration, plugin registration and iOS
pod integration can all fail in ways static analysis cannot see.

**To close:** run CI on a runner with the Android SDK and a macOS runner with
Xcode.

### 2. CV thresholds validated on clinical images (⚙️, effectively blocking)

Every alignment, lighting and focus threshold is provisional. The specification
is explicit that they must be established experimentally (CV §78, §44,
Functional ALG-006), and the synthetic dataset cannot substitute for real skin,
wounds, hair, dressings, varied skin tones or real lighting change.

Releasing with unvalidated thresholds would mean shipping confidence figures
nobody has checked — which is exactly the false-confidence risk the CV
specification spends §71 warning about.

**To close:** run D-ALN-01..10 against a governed clinical dataset, record the
metrics CV §67 lists, and replace the defaults in `AlignmentConfig` and
`QualityConfig`.

### 3. Measurement accuracy unquantified (⚙️, blocking any accuracy claim)

The mathematics is correct and tested. What is unknown is the real-world error
under perspective, distance and device variation.

The app already describes results as *"Photographic measurement. Accuracy
depends on calibration and capture geometry."*, so no unsupported claim is made
today. But no numeric accuracy figure may be published until D-MES-01..07 is
complete (Technical Architecture §51).

---

## Missing inputs, not missing code

| Input | Consequence | Reference |
|---|---|---|
| Android SDK / Xcode / devices | Two gates unmet, eleven unverifiable | C-017 |
| Clinical CV dataset | Thresholds cannot be validated | C-016 |
| Design system source | Radii, elevation, gradients and icons are inferred from what the UX/UI spec quotes | C-014 |
| Logo, icon, splash, Poppins files | The app renders on platform defaults | C-015 |

---

## Acceptance gates between milestones

Build Specification §114 requires, before moving on: P0 tests pass, no critical
data-loss issue, no original-image corruption, no unexpected network upload, no
unresolved build failure.

Current state: the first four hold and are enforced by CI. The fifth cannot be
asserted, because the platform builds have not been attempted.
