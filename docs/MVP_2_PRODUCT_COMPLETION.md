# MVP-2 — Product Completion + Brand Polish

**Document:** `docs/MVP_2_PRODUCT_COMPLETION.md`
**Product:** WISE Clinical Camera · WiseAiTechs · For All Medicos
**Created:** 2026-09-04
**Status:** software-implemented; **device validation pending** (owner action)

> MVP-2 closes the highest-value product gaps found after the first real-device
> validation and gives the app a recognisable WiseAiTechs identity. It is
> **functionally complete + product-polished**, not production-release approval.
> Real-device validation remains the final authority (see
> [`DEVICE_TEST_RESULTS.md`](DEVICE_TEST_RESULTS.md)).

---

## 1. Gaps discovered during real-device validation

The core capture workflow was already working on a real Android device (MVP-1).
Inspecting the tree against the MVP-2 scope, the real gaps were:

| # | Area | Finding (verified against the code, not the docs) |
|---|---|---|
| G1 | User-created protocols | The data model, repository CRUD and versioning existed, but **there was no UI to create, edit, duplicate or delete a protocol** — `ProtocolsScreen` only *selected* a protocol. Nothing protected the built-in protocols from a future edit path. |
| G2 | Import a BEFORE reference | Import from Gallery/Files existed, but the imported image was saved as a bare BEFORE with **no chance to add body part / laterality / case**, so an imported reference carried no clinical context. |
| G3 | App identity | The launcher icon and splash were the **default Flutter assets** (green Flutter logo, plain white splash). Nothing on first launch said "WISE". |
| G4 | In-app brand | The theme/design system was strong, but the home screen carried no WISE mark or the "by WiseAiTechs · For All Medicos" identity. |

Confirmed **already implemented** (left untouched, per "do not rebuild"):

- Capture context (type BEFORE/AFTER/PHOTO, body part, laterality, case,
  create-case, protocol) flowing into the `Photo` entity.
- Persistent BEFORE references: references are DB-backed, so a BEFORE saved in
  one session is selectable for an AFTER in a later session.
- Reference sources: recent BEFORE, from case, from library, import from
  Gallery, import from Files.
- Before + After combined output: all five comparison modes
  (side-by-side, slider, overlay, blink, difference) and the `BEFORE_AFTER`
  / `BEFORE_AFTER_MEASUREMENTS` export presets rendered by `LayerRenderer`.
- Non-destructive, offline, anonymized export; immutable originals.

---

## 2. Requirements implemented

### A. User-created protocols (priority 5, master prompt §7)

- New `ProtocolEditorScreen` (create + edit) wiring the full `ProtocolSettings`:
  name, description, per-tool capture guides / quality checks, grid layout,
  required-measurement prompt, preferred orientation/flash, default export
  preset. Every control feeds the existing settings precedence chain, so a
  switch actually changes capture behaviour — **no inert controls**.
- `ProtocolsScreen` rewritten to separate **Built-in** from **Your protocols**,
  with create (FAB), edit, duplicate and delete (with confirmation) actions.
- **Built-in immutability enforced at the repository layer**, not just hidden in
  the UI: `ProtocolRepository.updateProtocol` and `deleteProtocol` refuse a
  `is_system` protocol. Built-ins can still be *duplicated* into an editable
  user copy.
- Reachable from **Settings → Capture → Protocols** and from Home.
- Existing guarantees kept: an edit bumps the protocol version; a deleted
  protocol still names historical captures (Functional PRO-005).

### B. Import a BEFORE reference with metadata (priority 2, master prompt §4)

- Importing from Gallery/Files now opens a **"Save as reference"** sheet before
  the photo is created, collecting body part, laterality and case (all
  optional). The imported original is copied into WISE storage **unmodified**
  (`PhotoSource.import`), so it is distinguishable from a native capture and
  reusable as a BEFORE across sessions. Dismissing the sheet aborts the import.

### C. Brand / product identity (priorities 6-7, master prompt §8-9)

- Production launcher icon: a white **camera aperture** over a Deep Navy → Wise
  Blue gradient with a single Wise Red focus point, generated at every density
  plus an **adaptive icon** (`mipmap-anydpi-v26`) and round icon.
- Branded **splash**: the aperture centred on Deep Navy (`@color/wise_navy`),
  replacing the blank white launch screen.
- New `WiseLogo` widget paints the same aperture in-app; the home screen now
  shows the mark with the **"by WiseAiTechs · For All Medicos"** byline and the
  product tagline.

---

## 3. Requirements intentionally deferred

Kept out of this change to hold scope and honour "do not rebuild working
features":

- Legacy pre-Android-8 launcher PNGs use the new mark too, but a fully
  hand-tuned legacy raster set (vs. the adaptive icon that covers API 26+) is
  not separately produced.
- A dedicated "pick any Before + any After to compare" browser: comparison is
  still launched from a BEFORE's detail (it already resolves its AFTERs). Not a
  regression; a convenience for a later pass.
- Font: Poppins is still declared with a fallback chain; the font files remain
  unsupplied (SPECIFICATION_CONFLICTS C-015). Unchanged by MVP-2.
- iOS launcher/splash assets (Android-first per the current milestone).
- No AI, no cloud/backend, no encryption decision (C-019) — all out of scope.

---

## 4. Architecture reused (no second systems created)

- **Protocols:** existing `CaptureProtocol` / `ProtocolSettings` / `ToolOverrides`
  model and `ProtocolRepository` CRUD; the editor only builds settings and calls
  the repository.
- **Metadata:** the existing `Photo` fields (`bodyPart`, `laterality`, `caseId`,
  `source`) and `PhotoRepository.createPhoto` — no parallel metadata store.
- **Comparison/export:** unchanged; reused as-is.
- **Design:** all colours/spacing/typography from `WiseTokens`; the icon and the
  in-app `WiseLogo` share one aperture construction.

## 5. Data model changes

**None.** No schema migration was required — every field MVP-2 needed already
existed. Behavioural change only: `updateProtocol`/`deleteProtocol` now reject
system protocols.

## 6. UX changes

- Protocols screen: grouped Built-in vs Your protocols; per-item menu; New
  protocol FAB; protocol editor screen.
- Reference import: metadata sheet before save.
- Settings: a Capture section linking to Protocols.
- Home: WISE brand header (mark + byline + tagline).

## 7. Branding changes

- Adaptive + legacy launcher icons, round icon, splash (all densities).
- `@color/wise_navy`, `mipmap-anydpi-v26/ic_launcher(.round).xml`,
  `drawable-*/wise_splash_logo.png`, updated `launch_background.xml`.
- `AndroidManifest.xml` gains `android:roundIcon`.
- Assets are generated from `tool/gen_icons.py` (documented, reproducible; uses
  only the WiseAiTechs tokens — no third-party logo).

## 8. Tests added

All run in CI (`flutter test`); the suite is green (**563 tests**).

- `test/database/persistence_roundtrip_test.dart`: built-in protocol cannot be
  edited; cannot be deleted; can still be duplicated into an editable user copy.
- `test/database/photo_repository_test.dart`: an imported BEFORE keeps its
  metadata, is `PhotoSource.import`, and is a reusable reference candidate.
- `test/widget/protocols_test.dart`: built-in vs user grouping; a built-in
  offers Duplicate but not Edit/Delete; the editor creates a user protocol.

Existing tests were **not weakened**.

## 9. Verification performed in this change

- `dart format` — clean.
- `flutter analyze --fatal-infos --fatal-warnings` — **No issues found**.
- `flutter test` — **All 563 tests passed**.
- Launcher/foreground/splash rasters visually inspected.

## 10. Device validation checklist (owner action)

Software tests passing is **not** device validation. On the next CI APK, the
owner must exercise and record in [`DEVICE_TEST_RESULTS.md`](DEVICE_TEST_RESULTS.md):

1. Launcher icon shows the WISE aperture (home screen + app drawer + recents).
2. Splash shows the WISE mark on Deep Navy, no white flash.
3. Home shows the brand header.
4. Settings → Capture → Protocols opens; create a protocol; it appears under
   "Your protocols"; the enabled tools take effect on the next capture.
5. Edit / duplicate / delete a user protocol; a built-in offers only Duplicate.
6. Import a Gallery/Files image as a BEFORE, add body part/laterality/case;
   it appears in the library as an imported reference and is selectable for a
   later AFTER after fully closing and reopening the app.
7. Before + After combined export still produces a file; original unchanged.

## 11. Remaining production blockers (unchanged by MVP-2)

- Real-device validation of every MVP-2 item above.
- CV / measurement clinical validation (separate evidence milestone).
- At-rest encryption / security decision (C-019).
- iOS device validation; production signing and store metadata.
