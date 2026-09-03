# WISE Clinical Camera — Project Knowledge Map

**Generated:** repository analysis, Phase 1–2 of the master build prompt.
**Repository state at analysis time:** documentation-only. Ten v1.0 specification
documents, no source code, no assets, no datasets, no CI configuration.

All ten specifications were moved (via `git mv`, content unmodified) from the
repository root into [`docs/specifications/`](specifications/) so the root can
hold the Flutter project. They remain the **source of truth**.

---

## 1. Repository Contents

| File | Lines | Domain |
|---|---:|---|
| `docs/specifications/WISE_Clinical_Camera_PRD_v1.0.md` | 889 | Product |
| `docs/specifications/WISE_Clinical_Camera_Functional_Specification_v1.0.md` | 1,739 | Functional behaviour |
| `docs/specifications/WISE_Clinical_Camera_Technical_Architecture_v1.0.md` | 1,638 | Architecture |
| `docs/specifications/WISE_Clinical_Camera_Data_Model_Database_Specification_v1.0.md` | 2,066 | Database / storage |
| `docs/specifications/WISE_Clinical_Camera_Computer_Vision_Alignment_Specification_v1.0.md` | 1,770 | Computer vision |
| `docs/specifications/WISE_Clinical_Camera_Privacy_Security_Specification_v1.0.md` | 1,534 | Privacy / security |
| `docs/specifications/WISE_Clinical_Camera_UX_UI_Specification_v1.0.md` | 1,458 | UX / UI / design system |
| `docs/specifications/WISE_Clinical_Camera_AI_Cost_Strategy_v1.0.md` | 1,785 | AI strategy / cost |
| `docs/specifications/WISE_Clinical_Camera_Testing_Acceptance_Specification_v1.0.md` | 2,262 | Testing / acceptance |
| `docs/specifications/WISE_Clinical_Camera_Claude_Code_Build_Specification_v1.0.md` | 2,613 | Implementation directives |

### What does **not** exist in the repository

These were listed as expected uploads in the master prompt but are absent. Each
is recorded in [`SPECIFICATION_CONFLICTS.md`](SPECIFICATION_CONFLICTS.md) as a
missing input, with the safe fallback taken.

- The **WiseAiTechs Design MD System** source file. The UX/UI specification
  cites it throughout (`fileciteturn0file0…` markers) but the file itself was
  never uploaded. **Mitigation:** the design tokens, typography scale, component
  inventory and motion rules are quoted *inline* in the UX/UI spec §2–§4, §64–§68
  and restated in the Build spec §7, which is sufficient to implement the theme.
- Logos, app icon, splash assets.
- UI reference images / mockups.
- Clinical photography examples.
- CV test datasets and ground-truth transformation data.
- Poppins font files.
- Any prior source code, CI configuration or environment files.

---

## 2. Domain Map

### 2.1 Product

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_PRD_v1.0.md` |
| **Purpose** | Defines what the product is, why it exists, and the locked product principles. |
| **Authority** | **Highest** for product behaviour (priority rank 2 in the master prompt). §39 "Locked Product Principles" is the ceiling on scope. |
| **Major requirements** | Three capture modes BEFORE/AFTER/PHOTO (§3); reference image system (§4); ghost overlay (§5); alignment engine (§6); lighting (§7); focus (§8); grid (§9); level (§10); measurement (§11); calibration (§12–13); annotation (§16); layer system (§17); comparison (§18); body part/laterality (§20); protocols (§21); persistent preferences (§22); temporary override (§23); reference lock (§24); gallery saving (§26–27); privacy mode (§28); anonymized export (§29); offline-first (§30); optional AI (§31). |
| **Dependencies** | None — everything else derives from this. |
| **Implementation impact** | Sets the shape of the whole app. §2 ("must remain simple") and §35 ("V1 scope discipline") constrain every UI decision. §37 defines success: reproduce a photograph months later. |

### 2.2 UX / UI

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_UX_UI_Specification_v1.0.md` |
| **Purpose** | Applies the WiseAiTechs visual language; defines screens, states, copy and interaction. |
| **Authority** | Authoritative for visual design, screen composition and user-facing copy. |
| **Major requirements** | Brand tokens §2; typography §3; navigation §5; home screen §8; camera composition §10–11; persistent add-on model §12–15; AFTER workflow §16–22; warnings §23–24; review/save §25–27; measurement/calibration UI §28–32; comparison §34–40; export §41–43; library §44–46; settings §47–50; empty/loading/error states §51–53; accessibility §55; motion §56; dark camera §58; AI visual language §59–60; UX principles §69–75. |
| **Dependencies** | Design system (missing file — tokens inlined); PRD. |
| **Implementation impact** | Drives `lib/app/theme/`, every screen widget, and all user-facing strings. §63 "UX Priority Order" governs layout when space is tight. §70: the user must never wonder whether the original changed. |

### 2.3 Architecture

| | |
|---|---|
| **Documents** | `WISE_Clinical_Camera_Technical_Architecture_v1.0.md` (design), `WISE_Clinical_Camera_Claude_Code_Build_Specification_v1.0.md` (implementation directives) |
| **Purpose** | Layer model, module boundaries, camera abstraction, engine responsibilities, technology direction. |
| **Authority** | Technical Architecture is authoritative for structure; Build Spec is authoritative for build mechanics, ordering and discipline. |
| **Major requirements** | Layered architecture (TA §2); Flutter (TA §3); native boundary (TA §4); `CameraService`/`CameraEngine` abstraction (TA §5, BS §11); capability detection (TA §6, BS §12); immutable originals (TA §8); reference engine (TA §9); alignment engine stages (TA §11); tool architecture (TA §25); precedence chain (TA §27, BS §22); repository layer (BS §102); state management separation (BS §103); jobs (BS §104); typed errors (BS §90); feature flags (BS §89); debug mode (BS §87–88); no premature backend (BS §100); future-ready interfaces (BS §101). |
| **Dependencies** | PRD, Functional Spec. |
| **Implementation impact** | Defines `lib/core/`, `lib/features/`, `lib/services/`, `lib/repositories/`. TA §61 lists 16 architecture acceptance criteria used as the architecture definition-of-done. |

### 2.4 Functional

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_Functional_Specification_v1.0.md` |
| **Purpose** | Converts product/UX into numbered, testable requirements. |
| **Authority** | **Authoritative for behaviour** (priority rank 3). This is the requirement register. |
| **Major requirements** | 100+ IDs across prefixes CAM, MOD, REF, OVR, ALG, LGT, FOC, GRD, LVL, CAL, MES, ANN, CMP, SAV, EXP, SET, PRO, CAS, PRI, OFF, AI, ERR, DAT, TST. §46 defines the 13 core application states. §50 defines P0–P4 priority. §49 is the V1 definition of done. |
| **Dependencies** | PRD, UX/UI, Technical Architecture. |
| **Implementation impact** | Every requirement ID is tracked in [`REQUIREMENTS_TRACEABILITY.md`](REQUIREMENTS_TRACEABILITY.md). |

### 2.5 Database

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_Data_Model_Database_Specification_v1.0.md` |
| **Purpose** | SQLite schema, file storage model, relationships, lifecycle, migrations, sync readiness. |
| **Authority** | Authoritative for persistence. |
| **Major requirements** | Two-system storage §2–3; UUID identifiers §4; 15 core tables §6–33, §63; relationships §34; `PRAGMA foreign_keys = ON` §35; soft delete §36; photo deletion rules §37; immutability §38; SHA-256 checksums §39; thumbnails §40; two-phase file/DB write §43–44; numbered migrations §45–46; indexes §47; validation §49–50; settings precedence §54; sync readiness §55; no unrestricted cascade §67; 12 business rules §73; test requirements §74; acceptance §75; P0–P3 priority §76. |
| **Dependencies** | Functional Spec, Privacy Spec. |
| **Implementation impact** | Defines `lib/core/database/`, `lib/models/`, `lib/repositories/`. Migration history §46 is implemented literally as migrations 001–004. |

### 2.6 Computer Vision

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_Computer_Vision_Alignment_Specification_v1.0.md` |
| **Purpose** | The local alignment pipeline: reference preparation, feature matching, transform estimation, confidence, guidance. |
| **Authority** | Authoritative for CV. |
| **Major requirements** | Layered strategy §2; alignment dimensions §4; pipeline §5; reference cache §7; resolution strategy §8; orientation normalization §9; sensor assist §10–11; detectors §12–13; matching §14; RANSAC §15; transform selection order §16–21; homography acceptance §22; **spatial distribution §23**; template/edge/flow §24–27; subject motion §28; deformable anatomy §29; **confidence model §30–31**; guidance §32–33; manual fallback §36; readiness §38–40; lighting §41–42; focus §43–44; ROI §45; failure conditions/response §60–61; **fallback chain §62–63**; test dataset §65–69; acceptance §70; **§71 what the system must NOT claim**; **recommended V1 stack §72**; dev sequence §73; service interface §75; separation of concerns §77. |
| **Dependencies** | Technical Architecture, Testing Spec. |
| **Implementation impact** | Defines `lib/core/cv/`. §71 and §17 of the master prompt (alignment safety) make **false-confidence avoidance a P0 correctness requirement**, not a nicety. |

### 2.7 Privacy / Security

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_Privacy_Security_Specification_v1.0.md` |
| **Purpose** | Privacy architecture, permissions, storage security, logging, network policy, threat model. |
| **Authority** | Authoritative for privacy and security. Overrides convenience everywhere. |
| **Major requirements** | Data minimization PRI-001; local-first PRI-002; **no silent upload PRI-003**; **original image protection PRI-004**; privacy modes §4; least privilege §5–9; app-private storage §10–12; DB security §13–15; app lock §16; background/screenshot protection §17–18; logging §20–22; analytics §23–24; AI privacy §25–30; **network policy §31**; gallery §35–38; EXIF/anonymization §40–43; temp files §45; deletion model §47–50; backup/sync §51–56; secure development §59–61; threat model §71–77; security testing §78; **P0 security list §82**; definition of done §86. |
| **Dependencies** | All. |
| **Implementation impact** | Defines `lib/core/security/`, `lib/core/permissions/`, `lib/core/logging/`, and the network audit facility (BS §72–73). |

### 2.8 AI

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_AI_Cost_Strategy_v1.0.md` |
| **Purpose** | AI tiering, routing, cost control, provider abstraction, vendor-lock-in protection. |
| **Authority** | Authoritative for AI. Subordinate to Privacy Spec. |
| **Major requirements** | AI optional §3; **capability tiers 0–4 §4**; decision rule §5; not per-frame §6; upload policy §8; provider abstraction §44; feature flags §56; experimental separation §57; **V1 budget: mandatory per-photo AI cost = $0 §64**; V1 stack §65; V1 AI features §66; later features §67; anti-patterns §70. |
| **Dependencies** | Technical Architecture, Privacy Spec. |
| **Implementation impact** | Defines `lib/services/ai/`. V1 ships the abstraction with a disabled/no-op provider; **no vendor SDK is added**. |

### 2.9 Testing

| | |
|---|---|
| **Document** | `WISE_Clinical_Camera_Testing_Acceptance_Specification_v1.0.md` |
| **Purpose** | Test levels, priorities, per-module test cases, CV regression, acceptance gates, release checklist. |
| **Authority** | Authoritative for verification. |
| **Major requirements** | Test levels §2; priority §3; device matrix §5; **CV datasets §6–7, §61–62**; per-module tests §8–58; regression suite §59; automated tests §60; **end-to-end clinical workflow §69**; privacy E2E §71; release blockers §73; **false confidence testing §79**; measurement validation §80; migration/backup acceptance §82–83; release checklist §88; final gate §89; definition of done §90. |
| **Dependencies** | All. |
| **Implementation impact** | Defines `test/` structure (BS §74) and the CI workflow. |

### 2.10 Assets

Nothing shipped. See [`docs/deployment/ASSETS.md`](deployment/ASSETS.md) for the
declared-but-unshipped asset slots (icon, splash, logo, Poppins font, calibration
marker artwork, CV regression images) and the fallback in effect for each.

### 2.11 Deployment

No CI/CD configuration existed. Build Spec §96 lists the recommended checks;
these are implemented in `.github/workflows/ci.yml`. Build Spec §95 requires
development/staging/production build configurations — implemented as
`AppEnvironment` in `lib/core/config/`.

### 2.12 Future Features

Explicitly deferred by the specifications, and **not** built in V1:

| Feature | Deferred by |
|---|---|
| Cloud sync / multi-device | TA §56, DB §55–57, BS §100 |
| Backup / restore | DB §58–59 (P3), Privacy §51–53 |
| Cloud AI provider implementation | AI §4 Tier 4, BS §67 |
| On-device ML models | AI §52, CV §46 |
| Automatic marker detection | FS CAL-003, CV §47 |
| Optical flow | CV §26, §73 Stage 7 |
| Angle measurement | DB §20, BS §37 |
| Natural-language search / report generation | AI §67 |
| Authentication server, clinical image server | BS §100 |

---

## 3. Specification Priority Applied

Per master-prompt Phase 3, with the Build Specification inserted as
implementation guidance (it post-dates and synthesises the others):

```text
1. Explicit project decisions / latest approved specification
2. PRD                                   (product behaviour)
3. Functional Specification              (behavioural requirements)
4. Technical Architecture                (structure)
5. Data Model & Database Specification   (persistence)
6. Computer Vision & Alignment           (CV)
7. Privacy & Security                    (overrides convenience anywhere)
8. UX/UI Specification                   (visual design, copy)
9. AI & Cost Strategy                    (AI)
10. Testing & Acceptance                 (verification)
11. Claude Code Build Specification       (build mechanics, ordering, discipline)
12. General engineering conventions
```

**Exception:** where the Privacy & Security Specification states a "must not",
it wins over every document below rank 1. PRI-003 (no silent upload) and
PRI-004 (original image protection) are treated as inviolable.

---

## 4. Cross-Cutting Invariants

Six rules appear in five or more documents. They are implemented as enforced
invariants with dedicated tests, not as conventions:

| Invariant | Sources | Enforcement |
|---|---|---|
| **The original is never modified** | PRD §33, TA §8, DB §38, Privacy PRI-004, BS §2.1/§105, Testing §27 | Originals written once to `originals/`, never reopened for write. `test/privacy/original_immutability_test.dart` hashes before/after a full annotate-measure-export cycle. |
| **No silent upload** | PRD §31, TA §34, Privacy PRI-003, AI §8, BS §2.3, Testing §41 | All network access routed through `NetworkGuard`; core has zero call sites. `test/privacy/network_policy_test.dart` asserts the audit log is empty after the full workflow. |
| **No physical units without calibration** | PRD §13, FS CAL-001/MES-002, DB §50, BS §2.9/§38, Testing §24 | `Measurement.displayValue` returns a pixel-only result when `calibrationId == null`. Type system makes the physical branch unreachable without a valid `Calibration`. |
| **Preferences persist; session overrides do not** | PRD §22–23, FS SET-001..004, TA §27, DB §17, BS §2.6–2.7, Testing §30–31 | `EffectiveSettings` resolver + separate `SessionOverrides` runtime object. |
| **Capture must remain possible** | PRD §6, FS MOD-023/ALG-007, CV §38–40, UX §24/§72, BS §2.8/§30 | Warnings are advisory; only a protocol `hardThreshold` may block. |
| **Confidence is not clinical accuracy** | CV §31/§49/§71, TA §14, FS ALG-006, BS §28/§112–113, Testing §79 | `AlignmentResult.status` degrades to `poor`/`unavailable` on weak evidence; disclaimer strings are constants used at every display site. |

---

## 5. Where Each Domain Lands in Code

```text
Product / UX          → lib/app/theme/, lib/features/*/presentation/, lib/shared/
Architecture          → lib/core/, lib/services/, lib/repositories/
Database              → lib/core/database/, lib/models/, lib/repositories/
Computer Vision       → lib/core/cv/
Privacy / Security    → lib/core/security/, lib/core/permissions/, lib/core/logging/,
                        lib/core/network/
AI                    → lib/services/ai/
Testing               → test/{unit,widget,integration,database,cv,privacy,security,performance}/
Deployment            → .github/workflows/, lib/core/config/
```
