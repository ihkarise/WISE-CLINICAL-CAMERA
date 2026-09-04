# Requirements Traceability Matrix

Every numbered requirement in the Functional Specification, plus the
non-negotiable principles from the Build Specification and the P0 privacy and
data rules, mapped to the module that implements it and the test that proves it.

**Status values**

| Value | Meaning |
|---|---|
| `DONE` | Implemented and covered by an automated test that runs in CI. |
| `DONE (device)` | Implemented against a platform API; correctness needs hardware. See [C-017](SPECIFICATION_CONFLICTS.md#c-017--device-and-platform-verification--missing-input-environment). |
| `PARTIAL` | Implemented to the extent the specification defines; a documented gap remains. |
| `DEFERRED` | Explicitly out of V1 scope by a specification. |

**Test status values:** `AUTO` (automated, runs in CI) · `MANUAL` (device test
plan) · `NONE`.

Priorities are from Functional Specification §50 and Data Model §76.

**Re-verified at commit `10076c6` (Phase 3 work stream A): 548 automated tests,
all passing; `flutter analyze --fatal-infos --fatal-warnings` clean; 76.8% line
coverage (4758/6195), measured in the Phase 3 CI run and reproduced locally on
the pinned toolchain.** Every module and test path in the table below was
checked to exist in the tree. (The Phase 2 baseline was 524 tests / 77.6% at
`289f257`; the new UI code added this phase carries tests but lowers the ratio
slightly.)

Counts after the Phase 3 work stream A merge-candidate (six rows moved to
`DONE` once the Phase 3 CI run went green — see below):

| Status | Count | Meaning |
|---|---:|---|
| `DONE` | 74 | Implemented and covered by a CI test |
| `DONE (device)` | 15 | Implemented; correctness needs hardware |
| `PARTIAL` | 2 | Implemented to the extent specified; a documented gap remains (ALG-002, CAL-003) |
| `DEFERRED` | 1 | Explicitly out of V1 scope (AI tiers 2-4) |

**Six rows were downgraded from `DONE` to `PARTIAL` in the Phase 2
re-verification** — MOD-002, MOD-012, MOD-030, ANN-003, PRO-001..003 and
CAS-001..003; ALG-002 and CAL-003 were already `PARTIAL`. The pattern
in almost all of them is the same and worth stating once: the model, the
repository and the query layer support the capability, and no screen provides a
way to use it. A row like that reads as complete from the database's point of
view and is not complete from a clinician's.

## Phase 3 update (2026-09-04)

Phase 3 work stream A closed the clinician-facing gap in all six of those
rows: the capture metadata workflow (MOD-012, MOD-030), library body-part
filtering (MOD-030), case linking after capture (CAS-001..003), the file and
case reference sources (MOD-002), committed-markup editing (ANN-003), and
reading the protocol capture/export preferences (PRO-001..003). Each carries
new automated tests.

These six rows are now `DONE`. They were validated by the Phase 3 pull
request ([#3](https://github.com/ihkarise/WISE-CLINICAL-CAMERA/pull/3)) CI run
on commit `10076c6`, where all five jobs passed — **Format, analyze and test**
(`dart format` clean, `flutter analyze --fatal-infos --fatal-warnings` clean,
**548 tests, 0 failures**), **Privacy and security gates**, **Linux release
build**, **Android build** and **iOS build**. The same checks were reproduced
locally against the pinned toolchain (Flutter 3.35.5 / Dart 3.9.2).

Scope of that evidence: it is **software** validation. The Android and iOS
**build** jobs prove the app compiles and links for those platforms; they are
not device, camera, sensor, permission, performance or clinical-CV validation,
which remain open (see the `DONE (device)` rows, C-016 and C-017).

The `DONE (device)` rows are the honest limit of this environment: no Android
SDK, no Xcode, no device. See
[`docs/testing/DEVICE_TEST_PLAN.md`](testing/DEVICE_TEST_PLAN.md) and
[`docs/deployment/RELEASE_GATES.md`](deployment/RELEASE_GATES.md).

### Work stream B — accessibility (2026-09-04)

Work stream B validated and extended the accessibility of the clinical
workflow screens. The new `ACC` section below decomposes UX/UI §55 into traced
rows. ACC-001..004 were already covered by `accessibility_test.dart` (green in
the 10076c6 CI run) and are `DONE`. ACC-005 (sliders that name what they
control) and ACC-006 (export/calibration outcomes announced through live
regions) are new code in this work stream, covered by
`workflow_accessibility_test.dart`; they are `PARTIAL` — the software is
implemented but was authored without a local Flutter toolchain, so it is
`IMPLEMENTED — NOT VALIDATED` until the Phase 3B CI run turns them green.
ACC-007 (on-device VoiceOver/TalkBack) stays device-blocked. These rows are
tracked in the dedicated ACC section and are deliberately kept out of the
headline FS counts above, which describe the Functional Specification rows.

---

## Non-Negotiable Principles (Build Spec §2)

| Req | Source | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| 2.1 Original is immutable | BS §2.1, PRD §33, DB §38, Privacy PRI-004 | P0 | `core/storage/image_storage_service.dart` | `DONE` | `test/privacy/original_immutability_test.dart` |
| 2.2 Local first | BS §2.2, PRD §30, Privacy PRI-002 | P0 | whole app; `core/network/network_guard.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| 2.3 No silent upload | BS §2.3, Privacy PRI-003 | P0 | `core/network/network_guard.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| 2.4 AI is optional | BS §2.4, AI §3 | P0 | `services/ai/ai_service.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| 2.5 Advanced tools optional | BS §2.5, PRD §2 | P0 | `models/effective_settings.dart` | `DONE` | `test/unit/effective_settings_test.dart` |
| 2.6 Preferences persist | BS §2.6, FS SET-002 | P0 | `repositories/preference_repository.dart` | `DONE` | `test/database/schema_test.dart` |
| 2.7 Session overrides temporary | BS §2.7, FS SET-003 | P0 | `models/tool_overrides.dart` | `DONE` | `test/unit/effective_settings_test.dart` |
| 2.8 Capture remains possible | BS §2.8, FS MOD-023 | P0 | `features/capture/capture_readiness.dart` | `DONE` | `test/unit/capture_readiness_test.dart` |
| 2.9 Measurements require calibration | BS §2.9, FS CAL-001 | P0 | `core/measurement/measurement_calculator.dart` | `DONE` | `test/unit/measurement_test.dart` |
| 2.10 Privacy is a default | BS §2.10, Privacy §69 | P0 | `core/config/feature_flags.dart`, seeded preferences | `DONE` | `test/privacy/anonymization_and_logging_test.dart` |

## CAM — Camera

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| CAM-001 | Camera initialization, capability detection, permission, preview | P0 | `core/camera/camera_engine.dart` | `DONE (device)` | `test/unit/capture_readiness_test.dart` + MANUAL |
| CAM-002 | Front/rear selection, rear default | P0 | `core/camera/camera_engine.dart` | `DONE (device)` | MANUAL |
| CAM-003 | Zoom exposure and recording for matching | P1 | `core/camera/camera_engine.dart`, `models/capture_recipe.dart` | `DONE (device)` | AUTO (recipe) + MANUAL |
| CAM-004 | Flash modes; state stored; difference vs reference indicated | P1 | `core/camera/camera_engine.dart`, `features/capture/capture_controller.dart` | `DONE (device)` | AUTO (recipe) + MANUAL |
| CAM-005 | Orientation detection and AFTER guidance | P1 | `core/sensors/device_level_service.dart`, `core/cv/guidance_engine.dart` | `DONE (device)` | `test/unit/guidance_engine_test.dart` |
| CAM-006 | Autofocus / focus state | P1 | `core/camera/camera_engine.dart` | `DONE (device)` | MANUAL |

## MOD — Capture modes

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| MOD-001 | BEFORE starts reference-capture workflow | P0 | `features/capture/capture_controller.dart` | `DONE` | `test/widget/home_screen_test.dart` |
| MOD-002 | AFTER requires a reference; five sources | P0 | `features/reference/reference_picker_screen.dart` | `DONE` | `test/widget/reference_picker_test.dart` — Phase 3 adds a Files source (via `file_selector`) and a case filter. WISE library, Gallery, recent Before and now Files and case are all present |
| MOD-003 | PHOTO standalone capture | P0 | `features/capture/capture_controller.dart` | `DONE` | `test/widget/home_screen_test.dart` |
| MOD-010 | Before capture workflow | P0 | `features/capture/capture_controller.dart` | `DONE` | `test/integration/clinical_workflow_test.dart` |
| MOD-011 | Before becomes reference-eligible; unique ID | P0 | `repositories/photo_repository.dart` | `DONE` | `test/database/photo_repository_test.dart` |
| MOD-012 | Before metadata optional | P0 | `features/capture/capture_metadata_sheet.dart`, `features/capture/capture_controller.dart` | `DONE` | `test/widget/capture_metadata_sheet_test.dart`, `test/features/capture_controller_test.dart` — Phase 3 adds a pre-capture "Details" sheet wiring `setMetadata`; every field stays optional and can be cleared |
| MOD-020 | Select reference before AFTER camera | P0 | `features/reference/reference_picker_screen.dart` | `DONE` | `test/widget/home_screen_test.dart` |
| MOD-021 | Reference preparation loads image/metadata/transform/calibration/protocol | P0 | `features/capture/capture_controller.dart` | `DONE` | `test/integration/clinical_workflow_test.dart` |
| MOD-022 | AFTER camera shows live feed + overlay + alignment | P0 | `features/capture/capture_controller.dart`, `features/overlay/ghost_overlay.dart` | `DONE (device)` | `test/widget/home_screen_test.dart` |
| MOD-023 | Capture possible despite non-critical warnings | P0 | `features/capture/capture_readiness.dart` | `DONE` | `test/unit/capture_readiness_test.dart`, `test/features/capture_controller_test.dart` — a flat, featureless frame still permits the shutter, and a protocol's hard threshold refuses it |
| MOD-030 | Body part, 18 categories | P1 | `features/capture/capture_metadata_sheet.dart`, `features/library/library_screen.dart` | `DONE` | `test/widget/capture_metadata_sheet_test.dart`, `test/widget/screens_test.dart` — Phase 3 lets capture set a body part and the library filter by one, so the filter now matches |

## REF / OVR — Reference & ghost overlay

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| OVR-001 | Enable/disable, persistent | P0 | `models/effective_settings.dart` | `DONE` | `test/unit/effective_settings_test.dart` |
| OVR-002 | Opacity 10–100 % | P0 | `features/overlay/ghost_overlay.dart` | `DONE (device)` | `test/unit/reference_transform_test.dart` |
| OVR-003 | Translate / scale / rotate / flip | P0 | `models/reference_transform.dart` | `DONE (device)` | `test/unit/reference_transform_test.dart` |
| OVR-004 | Reset | P0 | `models/reference_transform.dart` | `DONE (device)` | `test/unit/reference_transform_test.dart` |
| OVR-005 | Lock disables all transforms | P0 | `models/reference_transform.dart` | `DONE (device)` | `test/unit/reference_transform_test.dart` |
| OVR-006 | Live rendering, no cloud | P0 | `features/overlay/ghost_overlay.dart` | `DONE` | `test/privacy/network_policy_test.dart` |

## ALG — Alignment

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ALG-001 | Enable/disable, persistent | P1 | `features/settings/settings_screen.dart` | `DONE` | `test/unit/effective_settings_test.dart` |
| ALG-002 | Multi-signal inputs | P1 | `core/cv/local_alignment_engine.dart` | `PARTIAL` | `test/cv/alignment_engine_test.dart` |
| ALG-003 | Per-dimension status (angle/position/scale/rotation/framing) | P1 | `core/cv/alignment_result.dart` | `DONE` | `test/cv/alignment_engine_test.dart` |
| ALG-004 | Plain-language guidance | P1 | `core/cv/guidance_engine.dart` | `DONE` | `test/unit/guidance_engine_test.dart` |
| ALG-005 | Optional score + detail panel | P1 | `features/alignment/alignment_panel.dart` | `DONE (device)` | `test/unit/guidance_engine_test.dart` |
| ALG-006 | Thresholds configurable, not clinical claims | P1 | `core/cv/alignment_config.dart` | `DONE` | `test/cv/alignment_engine_test.dart` |
| ALG-007 | Failure → "Automatic alignment unavailable", overlay still usable | P1 | `core/cv/local_alignment_engine.dart`, `features/alignment/alignment_panel.dart` | `DONE` | `test/cv/false_confidence_test.dart` |

## LGT / FOC / GRD / LVL — Quality & guides

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| LGT-001..004 | Lighting check, comparison, states, non-blocking | P1 | `core/cv/lighting_engine.dart` | `DONE` | `test/cv/quality_engines_test.dart` |
| FOC-001..003 | Focus check, Laplacian variance, warn + override | P1 | `core/cv/focus_engine.dart` | `DONE` | `test/cv/quality_engines_test.dart` |
| GRD-001..003 | Grid 3×3 / 4×4 / crosshair; never in original | P1 | `features/grid/grid_overlay.dart` | `DONE` | `test/privacy/original_immutability_test.dart`, `test/privacy/original_immutability_test.dart` |
| LVL-001..003 | Level from device sensors, graceful absence | P1 | `core/sensors/device_level_service.dart` | `DONE (device)` | `test/unit/level_test.dart` + MANUAL |

## CAL / MES — Calibration & measurement

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| CAL-001 | No physical units without calibration | P0 | `core/measurement/measurement_calculator.dart` | `DONE` | `test/unit/measurement_test.dart`, `test/features/markup_controller_test.dart`, `test/widget/screens_test.dart` — asserted at the model, the controller and the screen |
| CAL-002 | Ruler calibration | P2 | `features/calibration/calibration_screen.dart` | `DONE` | `test/unit/measurement_test.dart` |
| CAL-003 | Marker calibration (manual placement; auto-detect deferred) | P2 | `features/calibration/calibration_screen.dart` | `PARTIAL` | `test/unit/measurement_test.dart` |
| CAL-004 | Manual known-distance calibration | P2 | `features/calibration/calibration_screen.dart` | `DONE` | `test/unit/measurement_test.dart` |
| CAL-005 | Units mm / cm / m | P2 | `models/enums.dart` | `DONE` | `test/unit/measurement_test.dart` |
| CAL-006 | Calibration record fields | P2 | `models/calibration.dart` | `DONE` | `test/database/photo_repository_test.dart` |
| CAL-007 | Warn when calibration may be invalid | P2 | `features/calibration/calibration_screen.dart` | `DONE` | `test/unit/measurement_test.dart` |
| MES-001..009 | Length/width/diameter/perimeter/area, multiple, editable, separate layer | P2 | `core/measurement/measurement_calculator.dart` | `DONE` | `test/unit/measurement_test.dart` |

## ANN — Annotation & layers

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ANN-001..002 | Eight annotation tools | P2 | `features/annotation/markup_controller.dart` | `DONE` | `test/features/markup_controller_test.dart`, `test/imaging/markup_rendering_test.dart` |
| ANN-003 | Select / move / resize / edit / delete / hide | P2 | `features/annotation/markup_controller.dart`, `features/annotation/markup_screen.dart` | `DONE` | `test/features/markup_controller_test.dart` — Phase 3 adds select, move, resize and text edit of a committed shape (a move preserves a measurement's value, a resize recomputes it), all non-destructive; delete and hide already existed |
| ANN-004 | Non-destructive | P0 | `core/imaging/layer_renderer.dart` | `DONE` | `test/privacy/original_immutability_test.dart`, `test/features/markup_controller_test.dart` — the original's checksum is unchanged by a full edit session |
| ANN-010 | Layer visibility control | P2 | `core/imaging/layer_stack.dart` | `DONE` | `test/privacy/original_immutability_test.dart` |
| ANN-011 | Export layer selection | P2 | `features/export/export_service.dart` | `DONE` | `test/integration/clinical_workflow_test.dart` |

## CMP — Comparison

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| CMP-001..005 | Side-by-side / slider / overlay / blink / difference | P2 | `features/comparison/comparison_screen.dart` | `DONE (device)` | `test/widget/home_screen_test.dart` |
| CMP-005 | Difference disclaimer displayed | P0 | `shared/constants/wise_strings.dart` | `DONE` | `test/widget/home_screen_test.dart` |
| CMP-006 | Reuse stored alignment | P2 | `features/comparison/comparison_screen.dart` | `DONE` | `test/integration/clinical_workflow_test.dart` |
| §19 | Change and percentage change; zero-safe | P2 | `core/measurement/measurement_change.dart` | `DONE` | `test/unit/measurement_test.dart` |

## SAV / EXP — Saving & export

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| SAV-001 | Save original to WISE storage | P0 | `core/storage/image_storage_service.dart` | `DONE` | `test/integration/clinical_workflow_test.dart` |
| SAV-002/003 | Gallery save; ASK / ALWAYS / NEVER | P0 | `services/gallery/gallery_service.dart` | `DONE (device)` | `test/unit/gallery_policy_test.dart` + MANUAL |
| SAV-004 | Gallery/derived never replace original | P0 | `core/storage/image_storage_service.dart` | `DONE` | `test/privacy/original_immutability_test.dart` |
| EXP-001..004 | Seven presets, layer selection, footer, faithful original | P2 | `features/export/export_service.dart` | `DONE` | `test/integration/clinical_workflow_test.dart` |

## SET / PRO / CAS — Settings, protocols, cases

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| SET-001..004 | Defaults, persistence, override, save-as-default | P0 | `features/settings/settings_screen.dart` | `DONE` | `test/unit/effective_settings_test.dart`, `test/features/capture_controller_test.dart` — including that a session override reaches the settings chain and never the database |
| PRO-001..003 | Create / configure / activate protocol | P3 | `features/protocols/protocols_screen.dart`, `features/capture/capture_controller.dart`, `features/export/export_sheet.dart` | `DONE` | `test/features/capture_controller_test.dart`, `test/unit/capture_readiness_test.dart`, `test/widget/screens_test.dart` — Phase 3 reads all four preferences: `preferredFlash` sets the camera, `measurementRequired` and `preferredOrientation` become advisories (never blocking, C-018), `exportPreset`/`exportFooter` drive the export sheet |
| PRO-004 | Precedence: capability → default → protocol → session | P0 | `models/effective_settings.dart` | `DONE` | `test/unit/effective_settings_test.dart` |
| PRO-005 | Protocol versioning; history not rewritten | P3 | `repositories/protocol_repository.dart` | `DONE` | `test/database/persistence_roundtrip_test.dart` — an edit bumps the version, and retiring a protocol leaves historical captures still naming it |
| CAS-001..003 | Optional cases, attach, contents | P3 | `features/cases/cases_screen.dart`, `features/library/photo_detail_screen.dart` | `DONE` | `test/widget/screens_test.dart`, `test/database/photo_repository_test.dart` — Phase 3 adds "Add to case" / "Change case" from photo detail (and case selection at capture), so a case can hold photographs; deleting a case still leaves them |

## PRI / OFF — Privacy & offline

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| PRI-001 | Local-first | P0 | whole app | `DONE` | `test/privacy/network_policy_test.dart` |
| PRI-002 | No silent upload | P0 | `core/network/network_guard.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| PRI-003 | AI processing location disclosed | P0 | `services/ai/ai_service.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| PRI-004 | Privacy Mode | P0 | `features/settings/settings_screen.dart` | `DONE` | `test/unit/gallery_policy_test.dart` |
| PRI-010 | Anonymized export | P3 | `core/imaging/metadata_anonymizer.dart` | `DONE` | `test/privacy/anonymization_and_logging_test.dart` |
| OFF-001 | Full core workflow offline | P0 | whole app | `DONE` | `test/privacy/network_policy_test.dart` |
| OFF-002 | AI unavailable message | P4 | `services/ai/ai_service.dart` | `DONE` | `test/privacy/network_policy_test.dart` |

## DAT — Data

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| DB §4 | UUID identifiers | P0 | `models/enums.dart` | `DONE` | `test/database/*` |
| DB §35 | `PRAGMA foreign_keys = ON` | P0 | `core/database/database_service.dart` | `DONE` | `test/database/schema_test.dart` |
| DB §36–37 | Soft delete; deletion rules | P0 | `repositories/photo_repository.dart` | `DONE` | `test/database/photo_repository_test.dart` |
| DB §39 | SHA-256 checksums | P1 | `core/storage/image_storage_service.dart` | `DONE` | `test/database/photo_repository_test.dart` |
| DB §43–44 | Transactions; two-phase file/DB write; orphan cleanup | P0 | `core/storage/image_storage_service.dart`, `core/database/database_service.dart` | `DONE` | `test/database/photo_repository_test.dart` |
| DB §45–46 | Migrations 001–004 | P0 | `core/database/migrations/migration_001_core.dart` | `DONE` | `test/database/migration_test.dart` |
| DB §47 | Indexes | P1 | `core/database/migrations/migration_001_core.dart` | `DONE` | `test/database/schema_test.dart` |
| DB §49–50 | Validation incl. circular reference | P0 | `models/enums.dart`, `repositories/photo_repository.dart` | `DONE` | `test/database/photo_repository_test.dart` |
| DB §67 | No unrestricted cascade | P0 | `core/database/migrations/migration_001_core.dart` | `DONE` | `test/database/photo_repository_test.dart` |

## ERR — Errors

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ERR-001..005 | Typed failures, human-readable messages, never raw exceptions | P0 | `core/errors/failures.dart` | `DONE` | `test/unit/capture_readiness_test.dart` |

## AI

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| AI §3 | Core works with AI = OFF | P0 | `services/ai/ai_service.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| AI §44 | Provider abstraction | P4 | `services/ai/ai_service.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| AI §56 | AI feature flags | P4 | `core/config/feature_flags.dart` | `DONE` | `test/privacy/network_policy_test.dart` |
| AI §64 | Mandatory per-photo AI cost = $0 | P0 | no cloud call sites in core | `DONE` | `test/privacy/network_policy_test.dart` |
| AI Tier 2–4 | On-device ML / self-hosted / cloud implementations | — | interfaces only | `DEFERRED` | NONE |

## ACC — Accessibility (UX/UI §55, Build Spec §93)

UX/UI §55 has no numbered sub-requirements; the ACC IDs below are this matrix's
own decomposition of it, so each guideline area can be traced to code and a
test. "Software" status is a widget-tree assertion in CI; the on-device
screen-reader experience (VoiceOver/TalkBack) is a separate, device-blocked
gate — see `RELEASE_GATES.md`.

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ACC-001 | Action-oriented semantic labels on interactive controls (never bare "Button"/"Icon"/"Tool") | P1 | `shared/widgets/wise_mode_card.dart`, `features/library/photo_thumbnail.dart`, `features/capture/capture_screen.dart` | `DONE` | `test/widget/accessibility_test.dart` |
| ACC-002 | Interaction targets ≥ 48 dp; capture control dominant | P1 | `app/theme/wise_tokens.dart`, `features/home/home_screen.dart` | `DONE` | `test/widget/accessibility_test.dart` |
| ACC-003 | Content remains usable at larger text scale (clamped 1.4×) | P1 | `features/home/home_screen.dart` | `DONE` | `test/widget/accessibility_test.dart` |
| ACC-004 | Status never communicated by colour alone | P0 | `shared/widgets/wise_status_chip.dart`, `core/measurement/measurement_change.dart` | `DONE` | `test/widget/accessibility_test.dart` |
| ACC-005 | Sliders announce what they control, not only a value | P1 | `features/capture/capture_screen.dart`, `features/comparison/comparison_screen.dart` | `PARTIAL` — software implemented, awaiting Phase 3B CI | `test/widget/workflow_accessibility_test.dart` |
| ACC-006 | Action outcomes (export result, rejected calibration) announced via live regions | P1 | `features/export/export_sheet.dart`, `features/calibration/calibration_screen.dart` | `PARTIAL` — software implemented, awaiting Phase 3B CI | `test/widget/workflow_accessibility_test.dart` |
| ACC-007 | On-device VoiceOver / TalkBack pass | P1 | whole app | `PARTIAL` — device-blocked, tracked in `RELEASE_GATES.md` | MANUAL (`docs/testing/DEVICE_TEST_PLAN.md`) |
