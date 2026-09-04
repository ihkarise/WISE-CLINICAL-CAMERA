# Specification Conflicts & Open Decisions

Per master-prompt Phases 3, 60 and 61. Nothing here was silently resolved: every
entry names the documents involved, the interpretations, the temporary
implementation chosen, and whether a product decision is still owed.

**Status legend**

- `RESOLVED` — resolvable safely from context; implemented; no decision owed.
- `CONFIGURABLE` — not safely resolvable; implemented behind a documented
  configuration constant with a safe default; decision owed.
- `MISSING INPUT` — a required file or datum was never supplied; implementation
  proceeds with a documented fallback; input owed.
- `DEFERRED` — a specification permits leaving it out of V1 and names the
  fallback; a decision is owed before a deployment that needs it.

The Phase 2 re-classification table below indexes every entry against the six
buckets Phase 2 §5 asks for.


## Phase 2 re-classification

Phase 2 §5 asks for every entry to be placed in one of six buckets, so that what
is genuinely finished is separable from what is waiting on something. The
detailed entries below are unchanged; this is the index.

| # | Subject | Phase 2 classification | Waiting on |
|---|---|---|---|
| C-001 | Home screen composition | **RESOLVED** | — |
| C-002 | Grid in the saved original | **RESOLVED** | — |
| C-003 | Ghost overlay flip control | **RESOLVED** | — |
| C-004 | Alignment vocabulary and thresholds | **REQUIRES DATASET** · safe default exists | A governed clinical dataset |
| C-005 | Confidence weighting | **REQUIRES DATASET** · safe default exists | The same dataset |
| C-006 | Blur and lighting thresholds | **REQUIRES DATASET** and **REQUIRES HARDWARE VALIDATION** · safe default exists | Dataset, then per-device-tier validation |
| C-007 | V1 table set | **RESOLVED** | — |
| C-008 | Dimensions on an undecodable import | **RESOLVED** | — |
| C-009 | Measurement `WIDTH` versus `LENGTH` | **RESOLVED** | — |
| C-010 | Percentage change when `before == 0` | **RESOLVED** | — |
| C-011 | Calibration reuse across photographs | **RESOLVED** | — |
| C-012 | Users table versus no account required | **RESOLVED** | — |
| C-013 | Which CV library | **SAFE DEFAULT EXISTS** | A device benchmark (CV §73 stage 6) before any change |
| C-014 | Design system source file | **REQUIRES PRODUCT DECISION** | The source file, or a decision to keep the inferred tokens |
| C-015 | Brand assets | **REQUIRES PRODUCT DECISION** | Logo, icon, splash and the Poppins files |
| C-016 | CV regression dataset | **REQUIRES DATASET** | The dataset itself; `test_data/` is laid out for it |
| C-017 | Device and platform verification | **REQUIRES HARDWARE VALIDATION** | Android SDK, Xcode, real devices |
| C-018 | Hard capture blocking | **RESOLVED** | — |
| C-019 | Database encryption | **DEFERRED** by specification | A decision to enable it for a sensitive deployment |

Eleven resolved, one with a safe default, five waiting on an input nobody in
this environment can supply, one product decision pair, one deferred.

**Nothing in this list blocks release on its own except C-016 and C-017**, and
neither is a coding gap.

A note on C-018, because it changed. The decision recorded there — that only a
deliberately configured protocol may block capture, and no shipped protocol
does — was correct and implemented in `CaptureReadiness`. Phase 2 found that the
value never reached it: activating a protocol stored only its tool block, and
the capture controller never passed a protocol into the check. The decision was
sound; the wiring was missing. It is wired now, and tested.

---

## C-001 — Home screen composition · RESOLVED

**Documents:** PRD §34 vs UX/UI §8 + Build Spec §9.

**Conflict.** PRD §34 sketches a *single* screen carrying the live camera view,
the BEFORE/AFTER/PHOTO selector, the capture button and a `+ TOOLS` affordance
together. UX/UI §8 and Build Spec §9 both describe a *separate* home screen
("What would you like to capture?" with three mode cards plus Recent) that
navigates into a camera screen.

**Interpretations.** (a) Camera-first single screen with mode switching in place.
(b) Home → camera, two screens.

**Chosen.** (b). Two documents agree against one, the AFTER mode requires a
reference-selection step before the camera can open at all (FS MOD-020), and
UX/UI is authoritative for screen composition. PRD §34's intent — "the camera
should open quickly", three modes as the primary actions — is preserved: the
home screen is a thin launcher and the mode buttons are the dominant element.

**Decision owed.** None.

---

## C-002 — Grid in the saved original · RESOLVED

**Documents:** PRD §9 vs FS GRD-003, Build Spec §33, TA §8.

**Conflict.** PRD §9: "The grid must not become part of the saved original
photograph *unless explicitly requested*." Build Spec §33: "The grid exists only
as a display/export layer. **Never** burn it into the original."

**Chosen.** Never in the original. The `unless explicitly requested` escape is
honoured by letting the user request a grid in a *derived export*
(`ExportConfiguration.includeGrid`), which is what FS GRD-003 already says:
"It may be included in an explicitly configured export." This satisfies both
readings without weakening the immutability invariant (PRI-004), which is
inviolable.

**Decision owed.** None.

---

## C-003 — Ghost overlay flip control · RESOLVED

**Documents:** PRD §5 and FS OVR-003 and TA §9 vs Build Spec §18.

**Conflict.** PRD §5 lists overlay controls as opacity / rotate / flip / reset /
lock. FS OVR-003 requires translation, scaling, rotation, horizontal flip and
"vertical flip if required". TA §9 `ReferenceState` carries `flipX` and `flipY`.
Build Spec §18 lists only Opacity / Move / Scale / Rotate / Reset / Lock — no flip.

**Chosen.** Flip is implemented (both axes). Three documents including the PRD
and the Functional Specification require it; the Build Spec list is an
abbreviation, not an exclusion. `ReferenceTransform` carries `flipX`/`flipY`.

**Decision owed.** None.

---

## C-004 — Alignment status vocabulary and thresholds · CONFIGURABLE

**Documents:** TA §14 vs CV §31 + Build Spec §26.

**Conflict.** TA §14 proposes a four-band numeric scale
(`0–69 Poor`, `70–84 Acceptable`, `85–94 Good`, `95–100 Excellent`) while
explicitly calling the numbers "placeholders for engineering validation".
CV §31 and Build Spec §26 define four *statuses*:
`GOOD / FAIR / POOR / UNAVAILABLE`.

**Chosen.** The CV/Build status vocabulary (`AlignmentStatus.good|fair|poor|
unavailable`) is the model. TA's numeric bands are carried as the *provisional
default* threshold configuration, remapped onto three thresholds
(`good ≥ 0.85`, `fair ≥ 0.70`, else `poor`), with "Excellent" collapsed into
`good` since no specification gives it distinct behaviour.

Thresholds live in `AlignmentConfig` (`lib/core/cv/alignment_config.dart`), are
never hard-coded at a call site, and are marked provisional in code.

**Decision owed.** Yes. CV §78 and FS ALG-006 both forbid treating unvalidated
percentages as production thresholds. The defaults must be replaced with values
derived from the ground-truth dataset (CV §66) before any clinical release. See
[`docs/cv/THRESHOLDS.md`](cv/THRESHOLDS.md).

---

## C-005 — Confidence weighting · CONFIGURABLE

**Documents:** CV §30, §28 of the Build Spec.

**Conflict.** Not a contradiction — an unspecified quantity. CV §30 lists seven
confidence inputs (feature quality, inlier ratio, spatial distribution,
reprojection error, transform stability, sensor agreement, image similarity) and
states "the exact mathematical weighting must be determined experimentally".
No document supplies weights.

**Chosen.** `ConfidenceModel` implements the seven-signal combination with named,
individually adjustable weights in `AlignmentConfig`, defaulting to a
deliberately **conservative** scheme: the score is the weighted mean *multiplied
by* gating factors that collapse toward zero when inlier ratio or spatial spread
is poor. Under-confidence is the safe failure direction (CV §71, master prompt
Phase 17), so the default errs low.

**Decision owed.** Yes — empirical weights from the regression dataset.

---

## C-006 — Blur / lighting thresholds · CONFIGURABLE

**Documents:** CV §44, TA §16, FS FOC-002, Build Spec §32, §86.

**Conflict.** Every document requires a focus and lighting check; every document
explicitly refuses to name a threshold, and CV §44 warns "do not use one
universal threshold without validation".

**Chosen.** `QualityConfig` (`lib/core/cv/quality_config.dart`) holds
`focusLaplacianVarianceThreshold`, `luminanceDifferenceThreshold`,
`histogramSimilarityThreshold`, clipping fractions and the resolution the focus
score is normalised against. Values are provisional constants documented as
such. The focus score is normalised by working resolution so it is at least
comparable across devices.

**Decision owed.** Yes — per-device-tier validation (CV §44, §69).

---

## C-007 — V1 table set · RESOLVED

**Documents:** DB §63 vs DB §64 vs DB §76 vs Build Spec §54.

**Conflict.** DB §63 and Build Spec §54 list fifteen core tables. DB §64
("Minimal V1") offers an eleven-table subset, deferring `quality_checks`,
`exports`, `gallery_exports`, `events`. DB §76 assigns P0–P3 priorities that
match neither list exactly.

**Chosen.** All fifteen tables, created by migrations 001–004 exactly as DB §46
prescribes (`001` core, `002` clinical tools, `003` reproducibility, `004`
exports). `events` is created but writes are disabled by default per DB §33 and
Privacy §24. This satisfies the maximal list; §64's subset was offered as a
*fallback* ("if development needs a smaller first milestone"), which is not
needed.

**Decision owed.** None.

---

## C-008 — `photos.width_px` / `height_px` required, but imports may fail to decode · RESOLVED

**Documents:** DB §8 (both `Required: Yes`) vs FS §33 (Gallery/file import) vs
DB §49 ("dimensions > 0").

**Conflict.** An imported file may be unreadable or of an unsupported format, so
dimensions cannot always be known at record-creation time, yet the column is
required and validation demands `> 0`.

**Chosen.** Dimensions are resolved *before* the database record is committed.
The two-phase write (DB §44) decodes the image header in the verify step; a file
whose dimensions cannot be established is rejected at import with
`StorageFailure.unreadableImage` and no row is written. This keeps the column
non-null and the validation rule true without inventing a placeholder dimension.

**Decision owed.** None.

---

## C-009 — Measurement `WIDTH` versus `LENGTH` · RESOLVED

**Documents:** FS MES-002/MES-003, DB §20, PRD §11.

**Conflict.** `LENGTH` and `WIDTH` are listed as distinct measurement types but
are geometrically identical (a two-point distance). FS MES-003 says width is
"perpendicular *or otherwise specified*", i.e. not necessarily constrained.

**Chosen.** Both types exist in the enum and are stored distinctly (the
distinction is *semantic labelling* for the clinician and for Before/After change
tables), and both use the same two-point geometry and the same calculator. No
perpendicularity constraint is enforced, because FS MES-003 explicitly declines
to require one. Inventing a perpendicularity rule would be inventing clinical
behaviour (Build Spec §85).

**Decision owed.** None.

---

## C-010 — Percentage change when `before == 0` · RESOLVED

**Documents:** FS §19, DB §51, BS §43, Testing §25 (all require it be handled;
none specifies the result).

**Chosen.** `MeasurementChange.percentage` is `null` when `before == 0` (and when
either measurement lacks valid calibration). The UI renders `—` with the
explanatory string "Percentage change unavailable (baseline is zero)". Returning
`null` rather than `0`, `∞` or `NaN` prevents a meaningless number reaching a
clinical record. Absolute change is still reported.

**Decision owed.** None.

---

## C-011 — Calibration reuse across photographs · RESOLVED

**Documents:** DB §19, CV §48–49, PRD §12.

**Conflict.** PRD §12 says "calibration information should be stored with the
image/session", implying a session-level scope. DB §19 says a calibration
belongs to a *specific image* and "must not automatically be reused on a
different photograph unless the application can establish that the same scale
relationship is valid".

**Chosen.** Strict per-photo binding. `calibrations.photo_id` is required. There
is no automatic propagation to an AFTER photo even when alignment is `good`,
because CV §49 states plainly that "alignment confidence ≠ measurement accuracy".
The user may explicitly copy a calibration to another photo; doing so creates a
**new** calibration row with `method = MANUAL` and a lowered `confidence`, and
the UI warns. This is the safest reversible reading.

**Decision owed.** None, unless a future workflow defines validated shared
calibration.

---

## C-012 — "Users" table versus "no account required" · RESOLVED

**Documents:** DB §6 vs PRD §39.14 ("No account required for basic capture") vs
BS §100 ("no premature backend").

**Conflict.** Apparent only. DB §6 defines a `users` table but states "No online
account is required for basic capture."

**Chosen.** A single local user row is created on first launch with a generated
UUID and no credentials, no email, no authentication. It exists so preferences
and protocols have a stable owner and so future multi-user/sync work (DB §55) has
a key to hang on. No login screen exists.

**Decision owed.** None.

---

## C-013 — Which CV library · RESOLVED (implementation decision)

**Documents:** CV §12–13 ("selected through benchmarking rather than assumed"),
CV §72 (recommended V1 stack), CV §75 (engine behind an interface), TA §3,
BS §5 (dependency rules), BS §25 ("do not assume the first algorithm selected is
production-ready — benchmark it").

**Conflict.** None; a decision was delegated to implementation.

**Chosen.** A **pure-Dart** implementation of the CV §72 stack — FAST-9 corner
detection, intensity-centroid orientation, rotated-BRIEF (ORB) descriptors,
brute-force Hamming matching with Lowe ratio test, RANSAC similarity/affine
estimation, optional homography — behind the `AlignmentEngine` interface
(CV §75).

**Reasoning**, against BS §5's dependency checklist:

1. *Can Flutter/Dart do it?* Yes. The algorithms are arithmetic over a byte
   buffer; no platform capability is required.
2. *Is a native API sufficient?* iOS Vision and Android ML Kit offer neither ORB
   nor a RANSAC similarity estimator, and would diverge between platforms —
   directly against CV §77 (reusable, platform-independent CV).
3. *Existing dependency?* No.
4. *Maintenance / license / platform support / size / security* of an OpenCV
   binding: adds ~20–40 MB per ABI, pulls a large native attack surface into an
   app holding clinical images (Privacy §60–61), and the maintained Flutter
   bindings are thin and young.
5. *Testability* — decisive. A pure-Dart engine runs in `flutter test` on CI with
   **no device and no emulator**, which is the only way the CV §65–68 regression
   suite and the §79 false-confidence tests can actually run here.

**Cost.** Dart is slower than optimised native SIMD. Mitigated by CV §8/§55–57:
the engine works on a downsampled grayscale working image (default 320 px on the
long edge), processes sampled frames rather than every frame, and degrades per
CV §58 device tiers. `AlignmentEngine` is an interface, so a native or FFI
implementation can be swapped in after benchmarking without touching any caller.

**Decision owed.** Benchmarking on real devices (CV §73 Stage 6) before deciding
whether a native implementation is warranted.

---

## C-014 — Design system source file · MISSING INPUT

**Documents:** UX/UI §1–4, §56–68 (cites "WiseAiTechs Design MD System"
throughout via `fileciteturn0file0…` markers); Build Spec §7; master prompt
Phase 37.

**Missing.** The design system document itself was never uploaded.

**Fallback.** The UX/UI specification quotes the needed material inline: the ten
brand colours with their roles (§2), Poppins with fallback stack and a mobile
type scale (§3), spacing scale and grid (§4), the component inventory (§64),
button treatments (§65–67), icon principles (§68) and motion rules (§56). These
are implemented as `WiseTokens` / `WiseTheme` in `lib/app/theme/`. **No second
design system was invented** (master prompt Phase 37).

**Input owed.** The source document, to verify radii, elevation, gradient stops
and the icon set. Anything not quoted in the UX/UI spec is marked
`// TODO(design-system)` in `lib/app/theme/wise_tokens.dart`.

---

## C-015 — Brand assets · MISSING INPUT

**Missing.** Logo, app icon, splash art, Poppins font files, calibration-marker
artwork, UI reference mockups.

**Fallback.** The theme declares the `Poppins` family with the specified fallback
chain, so the app renders correctly with the platform default until font files
are dropped into `assets/fonts/`. `google_fonts` was **deliberately not added**:
it fetches fonts over the network at runtime, which would breach the offline-first
requirement (PRD §30) and the network policy (Privacy §31). Icon/splash slots are
documented in `docs/deployment/ASSETS.md`; no placeholder art is committed.

**Input owed.** The asset files.

---

## C-016 — CV regression dataset · MISSING INPUT

**Documents:** CV §65–68, Testing §6–7, §61–62, master prompt Phase 45.

**Missing.** Clinical photography examples and the ground-truth dataset with
known transformations.

**Fallback.** `test/cv/` builds a **synthetic** ground-truth dataset at test time:
procedurally generated textured images are transformed by *known* translation,
rotation and scale, so estimated-versus-known error is measurable today. This
covers the geometric accuracy cases (Testing ALG-T002/003/004), the degenerate
cases (ALG-T006 low texture, ALG-T007 false matches, ALG-T008 concentrated
features) and the §79 false-confidence cases.

**What it cannot cover:** real skin, wounds, hair-bearing areas, varied skin
tones, dressings, real lighting change, real device/lens variation (CV §64).
Thresholds validated only against synthetic data **must not** be treated as
validated (CV §44, §78).

**Input owed.** A real clinical dataset, governed per AI §59. Note Privacy §52
and BS §97: real clinical photographs must **not** be committed to this
repository.

---

## C-017 — Device and platform verification · MISSING INPUT (environment)

**Documents:** Build Spec §83, §115, §117; Testing §5, §58; master prompt
Phases 48, 64.

**Missing.** This build environment has no Android SDK, no Xcode, no simulator
and no physical device. `flutter analyze` and `flutter test` run; `flutter build
apk` and `flutter build ios` cannot.

**Fallback.** Everything verifiable without a device is verified here and in CI.
Device-dependent behaviour (real camera capability detection, real sensors,
gallery permissions, thermal/battery, on-device performance) is implemented
against the platform APIs but is **unverified**. `docs/testing/DEVICE_TEST_PLAN.md`
lists exactly what must be run on hardware, and `docs/deployment/RELEASE_GATES.md`
marks those V1 gates as **not met**.

**Input owed.** A build machine with the platform toolchains, and physical
devices.

---

## C-018 — Hard capture blocking · RESOLVED

**Documents:** FS MOD-023, CV §40, UX §24, BS §30, PRD §6.

**Conflict.** Apparent only, but worth recording because it is easy to get
backwards. Every document says warnings are advisory *by default*; a hard block
is permitted only when "a deliberately configured protocol" requires it.

**Chosen.** `CaptureReadiness` always exposes `canCapture = true` unless the
active protocol sets `hardAlignmentThreshold`, which is `null` on all five seeded
system protocols. No built-in configuration blocks capture. The `Capture anyway`
affordance is always present when warnings exist.

**Decision owed.** None.

---

## C-019 — Database encryption · DEFERRED

**Documents:** Privacy §14, Privacy §33 ("local encryption" listed among the
protections), Privacy §338.

**Conflict.** Privacy §33 lists local encryption among the protections the
application offers, and Privacy §14 says the project "should evaluate encrypted
SQLite storage for sensitive deployments" — but the same section then states
plainly: "If encryption is not enabled in an initial build, the application must
still rely on OS sandboxing and secure device storage."

**Interpretations.** (a) Encrypted SQLite is required for V1. (b) It is an
evaluated option, with OS-level protection as the specified fallback.

**Chosen.** (b), because §338 states the fallback as a permitted position rather
than a gap, and because a key-management scheme introduced without a decision
about where keys live would be worse than the OS keystore, not better.

**Implementation.** No application-level encryption. The database and the
originals live in application-private storage, which is encrypted at rest by
both platforms when the device has a passcode. Nothing is written outside the
sandbox: `StoragePaths` resolves everything under the application support
directory, and Android backup is excluded so the database cannot be copied off
the device by a cloud backup.

**Consequence, stated plainly.** On a device with no passcode, or one that is
rooted or jailbroken, clinical photographs are readable by anything with
filesystem access. That is a property of the deployment, not of the code, and it
is the reason this is a decision rather than a default.

**Decision owed.** Yes, before any deployment handling identifiable clinical
data on shared or unmanaged devices. Enabling it means adopting SQLCipher (or
platform equivalent) and a key stored in the platform keystore — Privacy §344
and §354 already specify where keys may and may not live.
