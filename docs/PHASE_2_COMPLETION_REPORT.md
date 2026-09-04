# Phase 2 Completion Report — WISE Clinical Camera

Phase 2 §47. What was asked, what was done, what was found, and what is still
true that nobody would want to hear.

Phase 2 was a **verification and hardening** phase, not a feature phase. The
instruction was explicit — do not rebuild, do not fabricate results, do not
claim a gate that was not run, do not describe synthetic performance as clinical
accuracy, do not hide limitations. This report is written to those terms.

| | |
|---|---|
| Range | `2076b2d..289f257` (25 commits) |
| Diff | 68 files changed, +7,716 / −292 |
| Toolchain | Flutter 3.35.5 stable · Dart 3.9.2 |
| `flutter analyze` | No issues found |
| `flutter test` | **524 passed, 0 failed** (was 410 at the start of the phase, 223 at the end of Phase 1) |
| `flutter test --coverage` | **77.8% lines (4586/5894)** — was 45.6% |
| `flutter build linux --release` | Succeeded; 7.6 MB `libapp.so` |

---

## 1. Scope and constraints honoured

| Constraint | How it was honoured |
|---|---|
| §1 Do not rebuild | No subsystem was rewritten. The largest refactor is one shared arrowhead function and two colour parameters. |
| §7 Do not fabricate results when tooling is missing | Six gates are marked BLOCKED — ENVIRONMENT with the specific reason. Nothing is marked PASS without a command. |
| §14 Do not call synthetic performance clinical accuracy | Every CV figure is labelled synthetic, in the audit, the gates and `docs/cv/THRESHOLDS.md`. |
| §15 No clinical photographs committed | `test_data/` ignores every image directory; verified by dropping a file in and confirming git does not see it. |
| §30 Do not make the scanner useless with false-positive suppression | The CI secret scan matches assigned values and key material, not bare identifiers, so the logger's own redaction list does not trip it. |
| §41 Do not report a test count from memory | Every count in this report comes from `flutter test` output. |
| §44/§46 Every PASS has evidence | Each release-gate row names the command. |
| §48 Do not hide limitations | §9 and §10 below exist for that purpose. |
| §49 Keep AI off | Every AI flag still defaults false; `aiFullyDisabled` is asserted in the privacy suite. No cloud AI was added. |
| §50 No unrequested clinical features | Nothing was added. Two functional gaps were found and deliberately **not** built; they are recorded in §9. |
| §56 No single enormous commit | 25 commits, each one change. |
| §57 Do not say "production ready" | See §12. |

## 2. Method

`Inspect → Change → Test → Verify → Commit`, per §55. Every defect below was
found by one of two things: reading the code against its specification, or
writing a test for something that had none. **None was found by a test that was
already failing**, because the code that was tested was the code that worked.

The phase's organising insight came out of the audit in §3: coverage was 87–91%
in the engine and 0–9% in the user interface. That is a defensible priority for
a clinical application — the code that can silently produce a wrong measurement
or lose an original is the code that was tested — but it turned out to be
hiding a screen that had never rendered at all.

## 3. Repository audit (§3)

`docs/PHASE_2_AUDIT.md`. Every subsystem classified VERIFIED / UNVERIFIED /
PARTIAL / BLOCKED — ENVIRONMENT / EXPERIMENTAL / MISSING, each with the
command output behind it.

Layer coverage, start of phase → now:

| Layer | Was | Now |
|---|---:|---:|
| `lib/repositories` | 51.0% | 92.7% |
| `lib/models` | 57.8% | 86.3% |
| `lib/features` (UI) | ~10% | 74.3% |
| `lib/shared` | 55.7% | 79.2% |
| `lib/app` | 19.5% | 68.1% |
| `lib/core` | — | 75.8% |
| `lib/core/camera` | 19.4% | 19.4% (unchanged; needs a camera) |

## 4. Traceability (§4)

`docs/REQUIREMENTS_TRACEABILITY.md`, re-verified rather than re-read. All 92
rows were checked: every module path and every test path resolves in the tree.

**Six rows were downgraded from `DONE` to `PARTIAL`.** Almost all for the same
reason, which is worth stating once: the model, the repository and the query
layer support the capability, and no screen provides a way to use it. A row like
that reads as complete from the database's point of view and is not complete
from a clinician's.

Final: 68 `DONE`, 15 `DONE (device)`, 8 `PARTIAL`, 1 `DEFERRED`.

## 5. Specification conflicts (§5)

`docs/SPECIFICATION_CONFLICTS.md` now carries an index placing all nineteen
entries in the six buckets §5 asks for: eleven RESOLVED, one SAFE DEFAULT
EXISTS, five waiting on an input (dataset or hardware), one REQUIRES PRODUCT
DECISION pair, one DEFERRED.

C-019 is new — database encryption. Privacy §33 lists local encryption among the
protections and §14 says to evaluate it, but §338 states the fallback plainly,
so this is deferred by specification rather than missing. The consequence is
recorded rather than glossed: on a device with no passcode, or one rooted or
jailbroken, clinical photographs are readable by anything with filesystem
access.

C-018 needed a note of its own. The decision recorded there was correct and
implemented; Phase 2 found the value never reached the code that applies it. A
conflict resolved on paper can still be unresolved in the binary.

## 6. Release gates (§6, §46)

`docs/deployment/RELEASE_GATES.md`, rewritten in the Gate / Status / Evidence /
How to verify / Blocking form, with PASS / PARTIAL / FAIL / BLOCKED / NOT RUN /
DEFERRED.

**24 PASS · 6 PARTIAL · 6 BLOCKED — ENVIRONMENT · 1 DEFERRED · 0 FAIL.**

Every PASS names the command that produced it.

## 7. Platform builds and toolchain (§45)

| Target | Result |
|---|---|
| Linux release (AOT) | **PASS** — `flutter build linux --release`, 7.6 MB `libapp.so` |
| Android | **BLOCKED** — `dl.google.com` returns 403 CONNECT through the agent proxy; the SDK cannot be installed here |
| iOS | **BLOCKED** — no macOS host |

The Linux target was enabled for one reason and it is not portability: it is the
only **release-mode AOT compilation** available in this environment.
`flutter test` runs the Dart VM in JIT, so a release-only failure — a const
evaluation error, a tree-shaking problem, a missing entry point — would reach a
store build having passed everything else. `linux/README.md` states exactly what
the gate does not cover: the camera, sensors, permissions, gallery, path and
sqflite plugins have no Linux implementation and are absent from the registrant.

CI gained the Linux job, which asserts `libapp.so` was actually produced so a
silently skipped compile cannot report green, and a core-layer boundary check
(§11).

## 8. Defects found and fixed

Ten. All fixed, each in its own commit, each with a test that fails without the
fix.

| # | Defect | Why it mattered |
|---|---|---|
| 1 | Orientation guidance was unreachable dead code | The portrait/landscape instruction could never fire |
| 2 | `CapturedImage` carried preview dimensions as still dimensions | A preview resolution is not a capture resolution |
| 3 | Capture recipes hard-coded portrait | Any landscape BEFORE was wrong on replay |
| 4 | `maxDimension` ignored after the footer was composited | An 800×600 export capped at 200 produced 200×210 |
| 5 | Every image widget decoded at full sensor resolution | ~48 MB per 12 MP photograph against a 100 MB cache |
| 6 | On-screen and exported arrowheads disagreed | An export is meant to be evidence of what was marked |
| 7 | **The library grid could never lay out a thumbnail** | **The library had never displayed a photograph** |
| 8 | A protocol's `hardAlignmentThreshold` never reached the check | The one permitted capture block was silently advisory |
| 9 | Controllers wrote state after their screen had gone | Open markup, go straight back, and Riverpod throws |
| 10 | `dispose` read a provider during scope teardown | The throw meant the alignment engine kept the reference image for the life of the process |

Defect 7 is the one that justifies the phase. It was confirmed pre-existing by
running the new test against the code as it stood before this phase's image
work: the same failure, with a different message. A screen at 3.8% coverage was
not merely untested.

Defects 7 and 9 were only findable by rendering a screen. Both had been in the
repository since the feature was written.

## 9. Functional gaps found and deliberately not built (§50)

This was a hardening phase, so these are recorded rather than closed. Each is a
specified capability that is modelled, persisted and queryable with no way in.

1. **No screen sets a photograph's clinical metadata.** `bodyPart`,
   `laterality` and `caseId` are supported by the model, written by the
   repository, filterable in `getPhotos` and displayed on the detail screen.
   `CaptureController.setMetadata` has no caller anywhere in the application. So
   every photograph is captured with all three null, and the library's body-part
   filter can never match anything. Closing it means building a metadata entry
   step, which is a feature.
2. **A protocol's non-tool settings are stored and unread.**
   `preferredOrientation`, `preferredFlash`, `measurementRequired` and
   `exportPreset` round-trip correctly and nothing consumes them.
   `hardAlignmentThreshold` was in this list until this phase.
3. **Annotations cannot be selected, moved or resized.** Only delete and hide
   exist. `selectedId` is in the state and nothing ever sets it.
4. **Two of five specified reference sources are absent** — Files and case.
5. **Nothing can attach a photograph to a case**, so no case ever has contents.

## 10. Known limitations (§48)

**Everything the computer vision does is characterised against synthetic
imagery.** The clinical-analogue suite added hair-like texture, dressing
occlusion, directional shadow, partial subject movement and gamma shift — the
failure modes real wound photography exhibits — but they remain analogues. None
of these results may be described as clinical accuracy.

**The confidence model conflates estimator trust with alignment quality.** At
1.2× scale the estimator recovers the transform essentially perfectly and still
reports POOR, because few features survive the scale change. A clinician reading
POOR would reasonably infer the alignment is wrong. It is not; the evidence for
it is thin. This is documented rather than tuned — retuning a confidence curve
against synthetic imagery is precisely what CV §78 warns against, and would
produce a model calibrated to the test generator.

**No photograph has ever been taken with a real camera.** The entire capture
path is verified against `FakeCameraEngine`. That proved enough to find three
real defects, and it says nothing about a real sensor's orientation reporting,
its still resolution, or its focus behaviour.

**No performance figure exists.** The decode bound is arithmetic — from the
documented meaning of `cacheWidth` — not a measured heap profile on a low-end
device.

**Accessibility is asserted on the shared widgets, not the full screens.** The
guideline matchers run over the status chips, the alignment panel, the level
indicator, home and the tokens.

**At-rest encryption is not implemented.** See C-019.

## 11. Reusable platform boundaries (§51)

`docs/architecture/PLATFORM_BOUNDARIES.md`. The dependency map is generated from
the imports rather than from intent.

`core/cv`, `core/storage`, `core/database`, `core/camera`, `core/permissions`,
`core/sensors` and `core/network` are reusable as they stand. `core/imaging`
needs a small seam — the renderer is generic, the things it renders are this
product's vocabulary. `models/` is a shared-domain-package candidate rather than
a lift-and-shift.

One violation existed and is fixed: `CameraPreviewSurface` imported
`app/theme/wise_tokens.dart` for two placeholder colours, which would have
brought WISE's design tokens along with the camera engine. CI now asserts the
rule the whole requirement reduces to — a `core/` module may depend on `core/`
and `models/` and nothing above — so the next accidental theme import fails the
build.

## 12. Final release assessment (§57)

**NOT RELEASE READY.**

Not "nearly", and not blocked on code. Three things stand between this
repository and a release, and none of them is work that can be done here:

1. **No build has ever run for Android or iOS.** Gradle configuration, plugin
   registration and pod integration all fail in ways static analysis cannot see.
   The CI jobs are written and have never executed on a runner with the
   toolchains. Until they do, "it compiles" is an assumption.
2. **No photograph has ever been taken with a real camera.**
3. **No clinical image has been through the alignment pipeline.** Every
   threshold in `AlignmentConfig` and `QualityConfig` is provisional, and CV §78
   is explicit that they must be established experimentally. Shipping them would
   mean publishing confidence figures nobody has checked — the exact failure
   CV §71 warns about.

What is true, and worth saying alongside that: the invariants that protect a
patient's data — originals never mutated, nothing leaves the device, no physical
units without calibration — are the best-covered code in the repository, and are
now asserted at every layer they pass through rather than only at the model. The
persistence layer read back everything it writes, correctly, first time. Every
screen renders. No test fails and no analyzer diagnostic remains.

The gap between that and releasable is hardware, a dataset, and two build
runners.
