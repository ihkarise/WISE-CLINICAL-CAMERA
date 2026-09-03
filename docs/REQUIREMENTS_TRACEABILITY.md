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

<!-- STATUS-TABLE-START -->
_Status column is updated at the end of each milestone. See `CHANGELOG.md` for
milestone completion._
<!-- STATUS-TABLE-END -->

---

## Non-Negotiable Principles (Build Spec §2)

| Req | Source | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| 2.1 Original is immutable | BS §2.1, PRD §33, DB §38, Privacy PRI-004 | P0 | `core/storage/image_storage_service.dart` | | `test/privacy/original_immutability_test.dart` |
| 2.2 Local first | BS §2.2, PRD §30, Privacy PRI-002 | P0 | whole app; `core/network/network_guard.dart` | | `test/privacy/offline_workflow_test.dart` |
| 2.3 No silent upload | BS §2.3, Privacy PRI-003 | P0 | `core/network/network_guard.dart` | | `test/privacy/network_policy_test.dart` |
| 2.4 AI is optional | BS §2.4, AI §3 | P0 | `services/ai/ai_service.dart` | | `test/unit/ai_service_test.dart` |
| 2.5 Advanced tools optional | BS §2.5, PRD §2 | P0 | `features/settings/tool_manager.dart` | | `test/unit/effective_settings_test.dart` |
| 2.6 Preferences persist | BS §2.6, FS SET-002 | P0 | `repositories/preference_repository.dart` | | `test/database/preference_persistence_test.dart` |
| 2.7 Session overrides temporary | BS §2.7, FS SET-003 | P0 | `features/settings/session_overrides.dart` | | `test/unit/effective_settings_test.dart` |
| 2.8 Capture remains possible | BS §2.8, FS MOD-023 | P0 | `features/capture/capture_readiness.dart` | | `test/unit/capture_readiness_test.dart` |
| 2.9 Measurements require calibration | BS §2.9, FS CAL-001 | P0 | `core/measurement/measurement_calculator.dart` | | `test/unit/measurement_test.dart` |
| 2.10 Privacy is a default | BS §2.10, Privacy §69 | P0 | `core/config/`, seeded preferences | | `test/privacy/defaults_test.dart` |

## CAM — Camera

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| CAM-001 | Camera initialization, capability detection, permission, preview | P0 | `core/camera/` | | `test/unit/camera_capabilities_test.dart` + MANUAL |
| CAM-002 | Front/rear selection, rear default | P0 | `core/camera/camera_engine.dart` | | MANUAL |
| CAM-003 | Zoom exposure and recording for matching | P1 | `core/camera/`, `models/capture_recipe.dart` | | AUTO (recipe) + MANUAL |
| CAM-004 | Flash modes; state stored; difference vs reference indicated | P1 | `core/camera/`, `features/capture/` | | AUTO (recipe) + MANUAL |
| CAM-005 | Orientation detection and AFTER guidance | P1 | `core/sensors/`, `core/cv/guidance_engine.dart` | | `test/unit/guidance_engine_test.dart` |
| CAM-006 | Autofocus / focus state | P1 | `core/camera/` | | MANUAL |

## MOD — Capture modes

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| MOD-001 | BEFORE starts reference-capture workflow | P0 | `features/capture/` | | `test/widget/mode_flow_test.dart` |
| MOD-002 | AFTER requires a reference; five sources | P0 | `features/reference/` | | `test/widget/reference_picker_test.dart` |
| MOD-003 | PHOTO standalone capture | P0 | `features/capture/` | | `test/widget/mode_flow_test.dart` |
| MOD-010 | Before capture workflow | P0 | `features/capture/` | | `test/integration/before_after_workflow_test.dart` |
| MOD-011 | Before becomes reference-eligible; unique ID | P0 | `repositories/photo_repository.dart` | | `test/database/photo_repository_test.dart` |
| MOD-012 | Before metadata optional | P0 | `features/capture/` | | `test/database/photo_repository_test.dart` |
| MOD-020 | Select reference before AFTER camera | P0 | `features/reference/` | | `test/widget/reference_picker_test.dart` |
| MOD-021 | Reference preparation loads image/metadata/transform/calibration/protocol | P0 | `features/reference/reference_loader.dart` | | `test/integration/reference_loader_test.dart` |
| MOD-022 | AFTER camera shows live feed + overlay + alignment | P0 | `features/capture/`, `features/overlay/` | | `test/widget/after_camera_test.dart` |
| MOD-023 | Capture possible despite non-critical warnings | P0 | `features/capture/capture_readiness.dart` | | `test/unit/capture_readiness_test.dart` |
| MOD-030 | Body part, 18 categories | P1 | `models/body_part.dart` | | `test/unit/enums_test.dart` |

## REF / OVR — Reference & ghost overlay

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| OVR-001 | Enable/disable, persistent | P0 | `features/settings/tool_manager.dart` | | `test/unit/effective_settings_test.dart` |
| OVR-002 | Opacity 10–100 % | P0 | `features/overlay/` | | `test/widget/ghost_overlay_test.dart` |
| OVR-003 | Translate / scale / rotate / flip | P0 | `models/reference_transform.dart` | | `test/unit/reference_transform_test.dart` |
| OVR-004 | Reset | P0 | `models/reference_transform.dart` | | `test/unit/reference_transform_test.dart` |
| OVR-005 | Lock disables all transforms | P0 | `models/reference_transform.dart` | | `test/unit/reference_transform_test.dart` |
| OVR-006 | Live rendering, no cloud | P0 | `features/overlay/ghost_overlay.dart` | | `test/privacy/network_policy_test.dart` |

## ALG — Alignment

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ALG-001 | Enable/disable, persistent | P1 | `features/settings/` | | `test/unit/effective_settings_test.dart` |
| ALG-002 | Multi-signal inputs | P1 | `core/cv/` | | `test/cv/alignment_engine_test.dart` |
| ALG-003 | Per-dimension status (angle/position/scale/rotation/framing) | P1 | `core/cv/alignment_result.dart` | | `test/cv/alignment_engine_test.dart` |
| ALG-004 | Plain-language guidance | P1 | `core/cv/guidance_engine.dart` | | `test/unit/guidance_engine_test.dart` |
| ALG-005 | Optional score + detail panel | P1 | `features/alignment/` | | `test/widget/alignment_panel_test.dart` |
| ALG-006 | Thresholds configurable, not clinical claims | P1 | `core/cv/alignment_config.dart` | | `test/cv/threshold_config_test.dart` |
| ALG-007 | Failure → "Automatic alignment unavailable", overlay still usable | P1 | `core/cv/`, `features/alignment/` | | `test/cv/alignment_failure_test.dart` |

## LGT / FOC / GRD / LVL — Quality & guides

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| LGT-001..004 | Lighting check, comparison, states, non-blocking | P1 | `core/cv/lighting_engine.dart` | | `test/cv/lighting_engine_test.dart` |
| FOC-001..003 | Focus check, Laplacian variance, warn + override | P1 | `core/cv/focus_engine.dart` | | `test/cv/focus_engine_test.dart` |
| GRD-001..003 | Grid 3×3 / 4×4 / crosshair; never in original | P1 | `features/grid/` | | `test/widget/grid_test.dart`, `test/privacy/original_immutability_test.dart` |
| LVL-001..003 | Level from device sensors, graceful absence | P1 | `core/sensors/` | | `test/unit/level_test.dart` + MANUAL |

## CAL / MES — Calibration & measurement

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| CAL-001 | No physical units without calibration | P0 | `core/measurement/` | | `test/unit/measurement_test.dart` |
| CAL-002 | Ruler calibration | P2 | `features/calibration/` | | `test/unit/calibration_test.dart` |
| CAL-003 | Marker calibration (manual placement; auto-detect deferred) | P2 | `features/calibration/` | | `test/unit/calibration_test.dart` |
| CAL-004 | Manual known-distance calibration | P2 | `features/calibration/` | | `test/unit/calibration_test.dart` |
| CAL-005 | Units mm / cm / m | P2 | `models/length_unit.dart` | | `test/unit/calibration_test.dart` |
| CAL-006 | Calibration record fields | P2 | `models/calibration.dart` | | `test/database/calibration_repository_test.dart` |
| CAL-007 | Warn when calibration may be invalid | P2 | `features/calibration/` | | `test/unit/calibration_test.dart` |
| MES-001..009 | Length/width/diameter/perimeter/area, multiple, editable, separate layer | P2 | `core/measurement/` | | `test/unit/measurement_test.dart` |

## ANN — Annotation & layers

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ANN-001..002 | Eight annotation tools | P2 | `features/annotation/` | | `test/unit/annotation_test.dart` |
| ANN-003 | Select / move / resize / edit / delete / hide | P2 | `features/annotation/` | | `test/unit/annotation_test.dart` |
| ANN-004 | Non-destructive | P0 | `core/imaging/layer_renderer.dart` | | `test/privacy/original_immutability_test.dart` |
| ANN-010 | Layer visibility control | P2 | `core/imaging/layer_stack.dart` | | `test/unit/layer_stack_test.dart` |
| ANN-011 | Export layer selection | P2 | `features/export/` | | `test/integration/export_test.dart` |

## CMP — Comparison

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| CMP-001..005 | Side-by-side / slider / overlay / blink / difference | P2 | `features/comparison/` | | `test/widget/comparison_test.dart` |
| CMP-005 | Difference disclaimer displayed | P0 | `shared/constants/disclaimers.dart` | | `test/widget/comparison_test.dart` |
| CMP-006 | Reuse stored alignment | P2 | `features/comparison/` | | `test/integration/comparison_alignment_reuse_test.dart` |
| §19 | Change and percentage change; zero-safe | P2 | `core/measurement/measurement_change.dart` | | `test/unit/measurement_change_test.dart` |

## SAV / EXP — Saving & export

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| SAV-001 | Save original to WISE storage | P0 | `core/storage/` | | `test/integration/capture_persistence_test.dart` |
| SAV-002/003 | Gallery save; ASK / ALWAYS / NEVER | P0 | `services/gallery/` | | `test/unit/gallery_policy_test.dart` + MANUAL |
| SAV-004 | Gallery/derived never replace original | P0 | `core/storage/` | | `test/privacy/original_immutability_test.dart` |
| EXP-001..004 | Seven presets, layer selection, footer, faithful original | P2 | `features/export/` | | `test/integration/export_test.dart` |

## SET / PRO / CAS — Settings, protocols, cases

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| SET-001..004 | Defaults, persistence, override, save-as-default | P0 | `features/settings/` | | `test/unit/effective_settings_test.dart`, `test/database/preference_persistence_test.dart` |
| PRO-001..003 | Create / configure / activate protocol | P3 | `features/protocols/` | | `test/database/protocol_repository_test.dart` |
| PRO-004 | Precedence: capability → default → protocol → session | P0 | `features/settings/effective_settings.dart` | | `test/unit/effective_settings_test.dart` |
| PRO-005 | Protocol versioning; history not rewritten | P3 | `repositories/protocol_repository.dart` | | `test/database/protocol_versioning_test.dart` |
| CAS-001..003 | Optional cases, attach, contents | P3 | `features/cases/` | | `test/database/case_repository_test.dart` |

## PRI / OFF — Privacy & offline

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| PRI-001 | Local-first | P0 | whole app | | `test/privacy/offline_workflow_test.dart` |
| PRI-002 | No silent upload | P0 | `core/network/` | | `test/privacy/network_policy_test.dart` |
| PRI-003 | AI processing location disclosed | P0 | `services/ai/` | | `test/unit/ai_service_test.dart` |
| PRI-004 | Privacy Mode | P0 | `features/privacy/` | | `test/privacy/privacy_mode_test.dart` |
| PRI-010 | Anonymized export | P3 | `features/export/anonymizer.dart` | | `test/privacy/anonymization_test.dart` |
| OFF-001 | Full core workflow offline | P0 | whole app | | `test/privacy/offline_workflow_test.dart` |
| OFF-002 | AI unavailable message | P4 | `services/ai/` | | `test/unit/ai_service_test.dart` |

## DAT — Data

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| DB §4 | UUID identifiers | P0 | `models/` | | `test/database/*` |
| DB §35 | `PRAGMA foreign_keys = ON` | P0 | `core/database/database_service.dart` | | `test/database/schema_test.dart` |
| DB §36–37 | Soft delete; deletion rules | P0 | `repositories/photo_repository.dart` | | `test/database/deletion_test.dart` |
| DB §39 | SHA-256 checksums | P1 | `core/storage/` | | `test/database/integrity_test.dart` |
| DB §43–44 | Transactions; two-phase file/DB write; orphan cleanup | P0 | `core/storage/`, `core/database/` | | `test/database/file_db_consistency_test.dart` |
| DB §45–46 | Migrations 001–004 | P0 | `core/database/migrations/` | | `test/database/migration_test.dart` |
| DB §47 | Indexes | P1 | `core/database/migrations/` | | `test/database/schema_test.dart` |
| DB §49–50 | Validation incl. circular reference | P0 | `models/`, `repositories/` | | `test/database/validation_test.dart` |
| DB §67 | No unrestricted cascade | P0 | `core/database/migrations/` | | `test/database/deletion_test.dart` |

## ERR — Errors

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| ERR-001..005 | Typed failures, human-readable messages, never raw exceptions | P0 | `core/errors/` | | `test/unit/errors_test.dart` |

## AI

| Req | Description | Priority | Module | Status | Test |
|---|---|---|---|---|---|
| AI §3 | Core works with AI = OFF | P0 | `services/ai/` | | `test/unit/ai_service_test.dart` |
| AI §44 | Provider abstraction | P4 | `services/ai/ai_provider.dart` | | `test/unit/ai_service_test.dart` |
| AI §56 | AI feature flags | P4 | `core/config/feature_flags.dart` | | `test/unit/feature_flags_test.dart` |
| AI §64 | Mandatory per-photo AI cost = $0 | P0 | no cloud call sites in core | | `test/privacy/network_policy_test.dart` |
| AI Tier 2–4 | On-device ML / self-hosted / cloud implementations | — | interfaces only | `DEFERRED` | NONE |
