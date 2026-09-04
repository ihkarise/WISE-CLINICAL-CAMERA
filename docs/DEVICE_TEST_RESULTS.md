# Device Test Results

**Document:** `docs/DEVICE_TEST_RESULTS.md`
**Product:** WISE Clinical Camera
**Purpose:** Evidence log for the MVP-1 milestone
([`FAST_TRACK_MVP.md`](FAST_TRACK_MVP.md)).

This file records **only observed behaviour on real devices**. Do not mark any
row as a pass from source inspection, CI, or an emulator alone — say what was
actually seen. An untested row stays `PENDING`.

**Do not commit clinical photographs here or anywhere in the repository.** Use
synthetic / non-identifiable test subjects (Privacy §52, Build Specification §97).

### Status vocabulary

| Marker | Meaning |
|---|---|
| `PENDING` | not yet exercised on a device |
| `PASS` | observed working on the device below |
| `FAIL` | observed broken (link the defect / commit) |
| `PARTIAL` | works with a caveat (describe it) |
| `BLOCKED — ENVIRONMENT` | could not test for an environmental reason |
| `N/A` | not applicable to this device |

---

## Test session template

Copy this block for each device/build session and fill it in from real use.

### Session — <date>

| Field | Value |
|---|---|
| Device model | _e.g. Pixel 7_ |
| Android version | _e.g. Android 14 (API 34)_ |
| App version / build | _pubspec `1.0.0+1`; APK from run # / commit sha_ |
| APK source | _GitHub Actions artifact `android-debug-apk`, run URL_ |
| Tester | _name/initials_ |
| Test subjects | _synthetic / non-identifiable — describe_ |

#### Core workflow (MVP-1 definition of done)

| Step | Result | Notes / evidence |
|---|---|---|
| A. Launch — app opens, no crash, usable initial screen | PENDING | |
| B. Camera — enter camera | PENDING | |
| B. Camera — permission prompt (grant) | PENDING | |
| B. Camera — preview appears | PENDING | |
| B. Camera — capture photograph | PENDING | |
| B. Camera — photograph saved | PENDING | |
| B. Camera — original intact (unchanged after edits/export) | PENDING | |
| C. Before — create Before | PENDING | |
| C. Before — body part | PENDING | |
| C. Before — laterality | PENDING | |
| C. Before — associate case (optional) | PENDING | |
| C. Before — save + appears in library | PENDING | |
| D. After — select Before, choose After | PENDING | |
| D. After — reference appears | PENDING | |
| D. After — overlay works | PENDING | |
| D. After — alignment guidance appears | PENDING | |
| D. After — capture + save | PENDING | |
| D. After — Before/After relationship recorded | PENDING | |
| E. Library — view photographs | PENDING | |
| E. Library — thumbnails render | PENDING | |
| E. Library — open detail | PENDING | |
| E. Library — filter (where applicable) | PENDING | |
| E. Library — Before/After relationship visible | PENDING | |
| F. Measurement — calibrate | PENDING | |
| F. Measurement — create measurement | PENDING | |
| F. Measurement — display correct | PENDING | |
| F. Measurement — persists (after restart) | PENDING | |
| G. Annotation — open, create | PENDING | |
| G. Annotation — select / move / resize / edit | PENDING | |
| G. Annotation — save, reopen, persists | PENDING | |
| H. Comparison — compare Before/After | PENDING | |
| H. Comparison — at least one mode renders | PENDING | |
| I. Export — original | PENDING | |
| I. Export — annotated | PENDING | |
| I. Export — measured (where applicable) | PENDING | |
| I. Export — output exists | PENDING | |
| I. Export — original unchanged | PENDING | |

#### Camera robustness (see DEVICE_TEST_PLAN §1)

| Check | Result | Notes |
|---|---|---|
| Camera initialization | PENDING | |
| Camera disposal | PENDING | |
| Returning from camera | PENDING | |
| Orientation (portrait/landscape) | PENDING | |
| Repeated capture | PENDING | |
| App background / foreground during preview | PENDING | |
| Navigate away / back | PENDING | |
| Permission deny → Settings route, no crash | PENDING | |

#### Privacy spot-check (see DEVICE_TEST_PLAN §6, §8)

| Check | Result | Notes |
|---|---|---|
| No unexpected network request (airplane-mode full workflow works) | PENDING | |
| No unexpected image upload | PENDING | |
| Privacy Mode behaviour (Gallery save always asks) | PENDING | |
| Gallery preference (`ALWAYS` / `NEVER`) honoured | PENDING | |
| Anonymized export | PENDING | |
| Original image preservation | PENDING | |

#### CV observations (NOT clinical validation — see DEVICE_TEST_PLAN §3)

Record observations only. Do **not** claim alignment is clinically accurate.

| Observation | Result | Notes |
|---|---|---|
| Reference image loads | PENDING | |
| Overlay works | PENDING | |
| Alignment guidance responds | PENDING | |
| Obvious position/angle change is detected | PENDING | |
| Capture remains possible throughout | PENDING | |

#### Measurement observations (photographic, NOT clinically validated — §5)

Describe as **photographic measurement** unless separately validated.

| Observation | Result | Notes |
|---|---|---|
| Calibration completes | PENDING | |
| Measurement value is plausible | PENDING | |
| Measurement persists | PENDING | |

#### Performance observations (qualitative unless measured — §7)

Do **not** invent numeric figures. Leave blank if not measured.

| Observation | Note |
|---|---|
| Launch time | |
| Camera startup | |
| Capture responsiveness | |
| Image save time | |
| Library scrolling | |
| Comparison | |
| Annotation | |
| Export | |
| Memory behaviour | |

#### Crashes / visual defects / known limitations

| Item | Severity | Notes / link |
|---|---|---|

---

## Log

No device test session has been recorded yet. Every workflow above is
`IMPLEMENTED — NOT VALIDATED` on hardware.

The build agent's environment has no Android SDK, no adb and no physical device,
and the CI artifact host is blocked by egress policy, so device testing is
performed by the project owner using the CI-produced APK
(see [`FAST_TRACK_MVP.md`](FAST_TRACK_MVP.md) §4).

---

## MVP-2 checklist (Product Completion + Brand Polish)

Added 2026-09-04. These rows are for the **next** CI APK. `SW-TESTED` means
covered by automated tests / analyzer only (not device evidence); `PENDING`
means not yet exercised on hardware. See
[`MVP_2_PRODUCT_COMPLETION.md`](MVP_2_PRODUCT_COMPLETION.md) §10.

| Item | Software | Device |
|---|---|---|
| Launcher icon shows the WISE aperture (drawer, home, recents) | SW-TESTED (assets generated) | PENDING |
| Splash shows WISE mark on Deep Navy, no white flash | N/A | PENDING |
| Home shows the WISE brand header + byline | SW-TESTED (widget) | PENDING |
| Settings → Capture → Protocols opens | SW-TESTED (widget) | PENDING |
| Create a user protocol; appears under "Your protocols" | SW-TESTED (widget + repo) | PENDING |
| Enabled protocol tools actually change capture behaviour | SW-TESTED (settings chain) | PENDING |
| Edit / duplicate / delete a user protocol | SW-TESTED (repo) | PENDING |
| Built-in protocol offers only Duplicate (immutable) | SW-TESTED (repo + widget) | PENDING |
| Import Gallery/Files image as BEFORE + add metadata | SW-TESTED (repo path) | PENDING |
| Imported BEFORE selectable as reference after app restart | SW-TESTED (persistence) | PENDING |
| Before + After combined export still works; original intact | SW-TESTED (existing) | PENDING |

**Do not mark any Device column PASS from CI or source inspection.** Record real
behaviour, including failures, and keep synthetic/non-identifiable subjects only.
