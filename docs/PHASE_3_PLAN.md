# WISE Clinical Camera — Phase 3 Plan

**Document:** `docs/PHASE_3_PLAN.md`
**Status:** DRAFT — planning audit complete, implementation not yet started
**Last Updated:** 2026-09-04
**Author context:** produced in a fresh Claude Code session with no prior
conversation memory, from the repository alone.

---

## 1. Purpose

This document records the Phase 3 plan for WISE Clinical Camera and the audit
that produced it. It follows the objective and Definition of Done in
[`PROJECT_STATUS.md`](PROJECT_STATUS.md) §17 and §26.

Phase 3 moves the project from a substantial software foundation toward a
**functionally complete clinical photography workflow**, without expanding
scope beyond what the specifications already require (`PROJECT_STATUS.md` §18).

It was written under the permanent rule of this project: *if the project needs
to remember it, GitHub must remember it.* Nothing here relies on a previous AI
conversation.

---

## 2. Audit method and what was inspected

The audit read the repository documentation and then verified every material
claim against the actual tree and Git history, rather than trusting the
handoff document.

Read in full:

- `docs/PROJECT_STATUS.md`
- `docs/REQUIREMENTS_TRACEABILITY.md`
- `docs/SPECIFICATION_CONFLICTS.md`
- `docs/PROJECT_KNOWLEDGE_MAP.md`
- `docs/deployment/RELEASE_GATES.md`
- `.github/workflows/ci.yml`
- `pubspec.yaml`, `.metadata`

Verified directly against the code and Git:

- Git state: on `claude/phase-3-planning-audit-0f2iu8`, clean tree, `main`
  merged through PR #1 (Phase 2 build) and PR #2 (status handoff). HEAD is
  `1c36cc5`; the last commit that changes code is `289f257`, matching the
  figure cited by `RELEASE_GATES.md` and `REQUIREMENTS_TRACEABILITY.md`.
- The full `lib/` and `test/` trees (99 source files, 39 test files) match the
  module and test paths named in the traceability matrix.
- The specific gaps the traceability matrix marks `PARTIAL` were each
  re-checked in code (see §4). They are accurate.

---

## 3. Environment reality for Phase 3

This is stricter than the Phase 2 environment and must shape the plan.

| Capability | Phase 2 environment | This Phase 3 session |
|---|---|---|
| `flutter analyze` / `flutter test` | Available (524 tests ran) | **Not available — no Flutter/Dart SDK on PATH** |
| `flutter build linux --release` | Ran, produced `libapp.so` | Not available |
| Android SDK / `flutter build apk` | `dl.google.com` blocked (403) | Not available |
| macOS / Xcode / `flutter build ios` | No macOS host | No macOS host |
| Physical camera / sensors / device | None | None |
| Governed clinical CV dataset | None | None |

**Consequence.** In *this* session no code can be validated locally. Any code
written here would be `IMPLEMENTED — NOT VALIDATED` until it runs somewhere
that has the toolchain.

**Where software validation actually happens.** `.github/workflows/ci.yml`
runs on every pull request and on push to `main`. It is the software validator
for Phase 3:

- `analyze` job — `dart format --set-exit-if-changed`, `flutter analyze
  --fatal-infos --fatal-warnings`, `flutter test --coverage`.
- `privacy-gates` job — the P0 privacy/CV/integration suites, the
  no-INTERNET-permission assertion, the secret scan, and the core-layer
  boundary assertion.
- `build-android`, `build-ios`, `build-linux` — compilation gates on runners
  that have the toolchains.

`RELEASE_GATES.md` records honestly that the Android/iOS build jobs *exist and
have never executed green on a real runner*. Getting them to run is itself a
Phase 3 outcome (a validation, not new code).

**What no environment available to this project can validate:** real-camera
capture, real sensor behaviour, on-device permission flows, on-device
performance/memory, and CV thresholds against real clinical images. These stay
`BLOCKED — ENVIRONMENT` or `REQUIRES DATASET` and must never be marked passed.

---

## 4. Current state — verified

Phase 2 delivered a broad, honestly-documented foundation. The traceability
matrix stands at 68 `DONE`, 15 `DONE (device)`, 8 `PARTIAL`, 1 `DEFERRED`.

The `PARTIAL` rows share one shape, confirmed in code during this audit: **the
model, the repository and the query layer support a capability, and no screen
lets a clinician use it.** The row is complete from the database's point of
view and incomplete from the clinician's. This is the core of Phase 3.

Evidence gathered in this audit:

| Gap | Requirement | Verified finding |
|---|---|---|
| Capture metadata never set | MOD-012, MOD-030 | `setMetadata` is defined in `capture_controller.dart:317` and called **only** from `test/features/capture_controller_test.dart`. No UI calls it. `capture_review_sheet.dart` has no body-part/laterality/case field. Every photo is stored with those three null. |
| Body-part filter can never match | MOD-030 | `photo_repository.getPhotos` already filters by `bodyPart` and `caseId` (`photo_repository.dart:196–218`), but nothing ever writes a body part, so the filter has nothing to match. |
| Case has no contents | CAS-001..003 | `cases_screen.dart` creates/lists/deletes cases and shows a photo count, but there is **no entry point to attach a photograph to a case**. `photo_detail_screen.dart` shows metadata read-only (`_MetadataRows`) with no "attach to case" or "edit metadata" action. |
| AFTER reference sources incomplete | MOD-002 | `reference_picker_screen.dart` offers the WISE library and Gallery import (`image_picker`). There is **no Files source and no case source**. Note: `file_selector: ^1.0.3` is already a dependency, so the Files source needs no new package. |
| Annotation edit incomplete | ANN-003 | `markup_controller.dart` carries `selectedId` in state and copies it, but **no method ever sets it** and there is no move/resize/edit of a committed shape — only delete and hide. |
| Protocol fields inert | PRO-001..003 | `preferredOrientation`, `preferredFlash`, `measurementRequired` and `exportPreset` are written by the protocol seeds (`protocol_repository.dart`) and round-trip through SQLite, but **no consumer reads them** — capture, export and the readiness check ignore them. |
| Marker auto-detect | CAL-003 | Manual marker placement works; automatic detection is deferred by FS CAL-003 / CV §47. Not Phase 3 scope. |
| Multi-signal alignment | ALG-002 | Implemented to the extent the synthetic dataset allows; real-signal weighting is dataset-blocked (C-004/C-005). |

Nothing in the audit contradicts the handoff documents; the matrix is an
accurate description of the tree. One minor documentation inconsistency was
found and is corrected alongside this plan (see §9).

---

## 5. Phase 3 scope

Phase 3 splits cleanly into work that this project *can* finish and validate,
and work that is blocked on inputs no environment here can supply. The plan
commits to the first and tracks the second honestly.

### 5.1 Work stream A — Software completion (in-repo, CI-validatable)

These close the `PARTIAL` rows above. They are pure Flutter/Dart, need no
device, and are fully validatable by widget/unit/integration tests in CI.

- **A1 — Capture metadata workflow (MOD-012, MOD-030).**
  Add body-part (the 18 categories), laterality and optional case selection to
  the capture review step, wiring the existing `CaptureController.setMetadata`.
  Files: `features/capture/capture_review_sheet.dart`,
  `features/capture/capture_controller.dart` (caller only),
  a new metadata form widget under `features/capture/`.
  Acceptance: a captured photo persists the chosen body part/laterality/case;
  omitting them still succeeds (metadata stays optional, MOD-012).
  Tests: extend `capture_controller_test.dart`; add a widget test for the
  review sheet form; assert the stored row.

- **A2 — Library filtering by metadata (MOD-030).**
  Surface the already-implemented `getPhotos(bodyPart:, caseId:)` filters in
  `features/library/library_screen.dart`.
  Acceptance: filtering by a body part returns only photos with it; the filter
  is reachable and clearable.
  Tests: widget test driving the filter against seeded photos.

- **A3 — Case linking after capture (CAS-001..003, PROJECT_STATUS §6
  "Case linking may be performed after capture").**
  Add "attach to case" / "move to case" from `photo_detail_screen.dart` (and
  reuse the A1 case picker). Deleting a case must still leave its photographs
  (already guaranteed by the schema and `persistence_roundtrip_test.dart`).
  Acceptance: a case can hold photographs; the count in `cases_screen.dart`
  reflects them.
  Tests: widget + repository test that attach/detach updates `case_id` and
  survives a case deletion.

- **A4 — AFTER reference sources: Files and case (MOD-002).**
  Add a Files source (via the existing `file_selector`) and a case source to
  `reference_picker_screen.dart`, so all specified AFTER sources exist.
  Acceptance: an AFTER capture can start from a file import and from a photo
  chosen within a case.
  Tests: widget test for source selection; the import path already has a
  two-phase-write test to extend.

- **A5 — Annotation select / move / resize / edit (ANN-003).**
  Implement selection (set `selectedId`), move, resize and text edit of a
  committed shape in `markup_controller.dart` / `markup_screen.dart` /
  `markup_painter.dart`, keeping the original immutable (ANN-004).
  Acceptance: a committed shape can be selected and moved/resized/edited; the
  original checksum is unchanged (existing immutability test must still pass).
  Tests: extend `markup_controller_test.dart` and `markup_rendering_test.dart`.

- **A6 — Protocol behaviour wiring (PRO-001..003).**
  Make the capture and export paths *read* `preferredOrientation`,
  `preferredFlash`, `measurementRequired` and `exportPreset` from the active
  protocol, respecting the precedence chain (PRO-004: capability → default →
  protocol → session). `measurementRequired` must warn, not hard-block, unless
  a `hardAlignmentThreshold` is also set (C-018 stays intact).
  Acceptance: activating a protocol changes the pre-filled export preset and
  the suggested orientation/flash; a session override still wins and never
  persists.
  Tests: extend `effective_settings_test.dart` and `capture_controller_test.dart`.

### 5.2 Work stream B — Validation of existing software (CI runs)

No new features; these are about producing evidence.

- **B1 — Make the Android/iOS/Linux CI build jobs actually run.**
  The jobs are written but have never executed green on a real runner
  (`RELEASE_GATES.md` §"What actually blocks release"). Opening the Phase 3 PR
  triggers them; their results (pass/fail) get recorded in `RELEASE_GATES.md`
  as evidence, replacing the current "never executed" note. A failure here is
  Phase 3 work, not a blocker to hide.
- **B2 — Accessibility coverage (RELEASE_GATES "Accessibility guidelines"
  PARTIAL).** Extend `accessibility_test.dart` to assert the capture, library,
  comparison and calibration screens against the guideline matchers.
- **B3 — Coverage.** Track line coverage after A1–A6; new UI paths must carry
  tests so coverage does not regress from 77.6%.

### 5.3 Work stream C — Blocked / decision items (track, do not fake)

- **C1 — Real camera + permission validation (CAM-001..006, D-CAM, D-PRM).**
  `BLOCKED — ENVIRONMENT`. `plugin_camera_engine.dart` and
  `permission_service.dart` stay device-validated only. Keep
  `DEVICE_TEST_PLAN.md` as the executable checklist for when hardware exists.
- **C2 — CV clinical-image validation (C-004/005/006/016, D-ALN).**
  `REQUIRES DATASET`. No clinical image is committed (Privacy §52, BS §97).
  `test_data/` is laid out for a governed dataset. Thresholds in
  `AlignmentConfig`/`QualityConfig` stay provisional; no accuracy figure may
  be published.
- **C3 — On-device performance/memory (D-PRF).** `BLOCKED — ENVIRONMENT`.
- **C4 — C-019 at-rest database encryption.** `DEFERRED` by specification with
  OS-sandbox fallback. A product decision is owed before any deployment
  handling identifiable clinical data on shared/unmanaged devices. Phase 3
  keeps it tracked in `SPECIFICATION_CONFLICTS.md`; it is not code work unless
  the decision is made to enable SQLCipher + keystore.

---

## 5.4 Work stream A — implementation status (2026-09-04)

Work stream A is implemented, each item with new automated tests, in focused
commits on `claude/phase-3-planning-audit-0f2iu8`:

| Item | Requirement | Status | Commit subject |
|---|---|---|---|
| A1 capture metadata | MOD-012, MOD-030 | `DONE` | `feat(capture): clinical metadata workflow` |
| A2 library filtering | MOD-030 | `DONE` | `feat(library): body-part filter control` |
| A3 case linking | CAS-001..003 | `DONE` | `feat(library): link a photograph to a case after capture` |
| A4 reference sources | MOD-002 | `DONE` | `feat(reference): file import and case reference sources` |
| A5 markup editing | ANN-003 | `DONE` | `feat(annotation): select, move, resize and edit committed markup` |
| A6 protocol reading | PRO-001..003 | `DONE` | `feat(protocols): read the protocol capture and export preferences` |

All six are `DONE`: validated by the PR
[#3](https://github.com/ihkarise/WISE-CLINICAL-CAMERA/pull/3) CI run on commit
`10076c6` — all five jobs green (Format/analyze/test with **548 tests**,
Privacy gates, Android build, iOS build, Linux build) and reproduced locally on
the pinned toolchain (Flutter 3.35.5 / Dart 3.9.2). Two format/import fixes
(`e299d43`, `10076c6`) were needed after the first CI run and are folded in.

**Work stream B partial outcome:** B1 (make the Android/iOS/Linux CI build jobs
actually run) is achieved — all three executed green on a real runner for the
first time, closing the "no build has ever run" release blocker (compilation
only; device validation still open).

**B2 (broader accessibility coverage) is now implemented.** The clinical
workflow screens gained the screen-reader semantics they were missing: every
slider (capture reference opacity, comparison reveal, comparison overlay
opacity) announces *what it adjusts* rather than a bare percentage, and two
status changes that had been carried only by colour — the export result and a
rejected calibration — are announced through live regions.
`workflow_accessibility_test.dart` asserts these against the capture,
comparison, calibration, export and library screens, and adds
`labeledTapTargetGuideline` coverage for comparison/export/library. This closes
the RELEASE_GATES gap that named "the full capture, library, comparison and
calibration screens are not asserted against the guideline matchers." Because
this session has no local Flutter toolchain, the new tests are
`IMPLEMENTED — NOT VALIDATED` until the Phase 3B CI run; the accessibility of
the *on-device* screen readers (VoiceOver/TalkBack) is a separate,
device-blocked gate. The traceability matrix records this as ACC-005/ACC-006
(`PARTIAL`) and ACC-007 (device-blocked).

B3 (coverage tracking) remains a follow-up; the new UI is small and carries
tests, so it should not regress coverage materially, but the figure is only
known once CI reports it. Work stream C (hardware/dataset/decision items) is
unchanged and is **not** started here.

## 6. Non-goals (from `PROJECT_STATUS.md` §18)

Not in Phase 3: cloud backend, authentication platform, social features,
unnecessary AI features, cloud image processing, premature synchronization,
unrelated WISE products. AI integration is explicitly not required for Phase 3.
Automatic marker detection, optical flow, and angle measurement remain deferred
by their specifications.

---

## 7. Sequenced commit plan

Focused commits on `claude/phase-3-planning-audit-0f2iu8`, one phase-level PR
(`PROJECT_STATUS.md` §23). This planning commit is first:

```text
Phase 3:
  commit: phase 3 planning audit + PHASE_3_PLAN.md   ← this commit
  commit: capture metadata workflow (A1)
  commit: library metadata filtering (A2)
  commit: case linking after capture (A3)
  commit: AFTER reference sources — files and case (A4)
  commit: annotation select/move/resize/edit (A5)
  commit: protocol behaviour wiring (A6)
  commit: accessibility coverage (B2)
  commit: documentation and release-gate sync
```

Each feature commit updates code **and** tests **and** the affected rows of
`REQUIREMENTS_TRACEABILITY.md` in the same commit. Each commit must leave the
tree in a state CI can validate.

---

## 8. Definition of Done and validation posture

Mapped from `PROJECT_STATUS.md` §26. The right-hand column is the honest
posture for each item given this project's environments.

| DoD area | Item | Validation posture after Phase 3 |
|---|---|---|
| Functional | Before / After / Photo, multiple Afters, recipe inheritance/immutability, reference lock, overlay, alignment/lighting/focus/grid/level, calibration, measurement, comparison, export, library | Software `VALIDATED` via CI tests; capture/overlay/comparison visual behaviour stays `DONE (device)` |
| Functional | Body part, laterality, case linking, capture context, metadata | Target `DONE` via A1–A4 with widget/repo tests in CI |
| Functional | Annotation full edit | Target `DONE` via A5 |
| Functional | Protocol behaviour | Target `DONE` via A6 |
| Technical | analyzer clean, formatter clean, tests passing, no lifecycle regressions, DB/filesystem integrity, migration safety, bounded image processing | `VALIDATED` by CI `analyze` + `privacy-gates` |
| Camera | permissions, lifecycle, rotation, capability detection, real-plugin validation | `BLOCKED — ENVIRONMENT` (C1) |
| Computer Vision | synthetic validation | `VALIDATED (synthetic)` |
| Computer Vision | real-image validation, dataset protocol, threshold documentation | `REQUIRES DATASET` (C2) |
| Security / Privacy | no network image transfer, privacy mode, metadata handling, local storage, encryption decision, C-019 | Software gates `VALIDATED` by `privacy-gates`; C-019 `DEFERRED` + tracked (C4) |
| Platform | Android/iOS build | `NOT RUN → PASS/FAIL` once CI jobs execute (B1); device validation `BLOCKED — ENVIRONMENT` |
| Accessibility | readable text, targets, semantics, contrast, non-colour-only status | Broaden from `PARTIAL` toward `DONE` via B2 |

Phase 3 is **not** release-ready on completion: C1/C2/C3 remain open and are
inputs, not code. `PROJECT_STATUS.md`'s **NOT RELEASE READY** stays true.

---

## 9. Documentation synchronization obligations

Per `PROJECT_STATUS.md` §33, every meaningful change updates the affected
documents in the same commit. For Phase 3 that means:

- `REQUIREMENTS_TRACEABILITY.md` — flip the six `PARTIAL` rows as A1–A6 land,
  with the proving test named.
- `docs/deployment/RELEASE_GATES.md` — record real Android/iOS/Linux CI build
  results (B1), updated coverage (B3), and accessibility status (B2).
- `PROJECT_STATUS.md` — update §34 summary table, test count, coverage, and
  §25 next-action as work completes; add a Phase 3 section.
- `docs/PHASE_3_COMPLETION_REPORT.md` — created at phase end.
- `SPECIFICATION_CONFLICTS.md` — keep C-019 tracked; record any new decision.

**Correction applied with this plan:** `PROJECT_STATUS.md` §20/§21 and §26
reference `docs/RELEASE_GATES.md`, but the file lives at
`docs/deployment/RELEASE_GATES.md` (where `REQUIREMENTS_TRACEABILITY.md`
correctly links it). The stale path references are corrected so the handoff
chain resolves.

---

## 10. Risks

- **Blind pushes.** With no local Flutter, Phase 3 code written in a session
  like this one cannot be run before it reaches CI. Mitigation: keep commits
  small and self-contained; read the diff adversarially against the analyzer
  and formatter before pushing; treat the first CI run as the validation step
  and fix forward.
- **Overstating status.** The temptation is to mark a wired-up feature
  `VALIDATED` on the strength of the code. It is `VALIDATED` only when a CI
  test exercises it. Device- and dataset-dependent items never become
  `VALIDATED` here.
- **Scope creep.** The `PARTIAL` rows are the boundary. New capability beyond
  the specifications is a §18 non-goal.

---

## 11. Immediate next action

This planning commit lands first. Implementation of work stream A then
proceeds in the commit order of §7, each commit carrying its tests and
traceability update, with CI as the validator. Before implementation begins in
earnest, confirm with the project owner whether Phase 3 coding should proceed
in an environment without a local Flutter toolchain (every change validated
only in CI), or whether a session with the toolchain is preferred.
