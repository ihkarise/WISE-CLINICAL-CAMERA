# Device Test Plan

Everything that cannot be verified without real hardware.

This build environment has no Android SDK, no Xcode, no emulator and no device
(the egress proxy also blocks Google's SDK host, so the Android toolchain could
not be installed). `flutter analyze` and `flutter test` run and pass; nothing
below has been executed against a real camera.

See [SPECIFICATION_CONFLICTS C-017](../SPECIFICATION_CONFLICTS.md) and
[RELEASE_GATES.md](../deployment/RELEASE_GATES.md).

---

## What automated tests already establish

Do not re-test these by hand; they run in CI on every change.

- Settings precedence, session-override isolation, Privacy Mode interaction
- Schema, foreign keys, indexes, migrations from v1 to current with data intact
- Photo CRUD, Before/After relationships, deletion policy, checksum integrity
- Calibration and measurement mathematics, including the specification's own
  worked examples and the zero-baseline case
- Alignment geometry against synthetic ground truth; every false-confidence gate
- Lighting and focus thresholds and their configurability
- The complete BEFORE-to-export workflow
- Original immutability across a full annotate/measure/export/anonymize cycle
- An empty network audit log after the entire clinical workflow

---

## 1. Camera (P0)

| ID | Test | Expected |
|---|---|---|
| D-CAM-01 | Cold start on each device tier | Preview appears promptly; note the time |
| D-CAM-02 | Grant camera permission at the prompt | Preview starts |
| D-CAM-03 | Deny camera permission | The specified message and a route to Settings; no crash |
| D-CAM-04 | Deny permanently, return, reopen | Settings route offered; no repeated prompt (Privacy §9) |
| D-CAM-05 | Capability detection | Reported zoom range, flash modes and camera count match the hardware |
| D-CAM-06 | A device without flash | The flash control is absent, not inert (UX/UI §74) |
| D-CAM-07 | Switch front/rear | Preview and capture both follow |
| D-CAM-08 | Zoom across the full range | Smooth; the value is recorded in the capture recipe |
| D-CAM-09 | Capture at maximum resolution | Original written; dimensions correct |
| D-CAM-10 | Interrupt with a phone call mid-capture | No crash; the original is intact or absent, never partial |
| D-CAM-11 | Background and resume during preview | Camera resumes or reports cleanly |
| D-CAM-12 | Low storage | `InsufficientStorage` message; no corrupt file |

**Preview frame format** deserves particular attention: the luminance
extraction handles Android YUV420 with row-stride padding and iOS BGRA8888
separately. A stride bug would shear the CV working image without any visible
symptom in the preview itself. Verify on a device whose preview width is not a
multiple of 16.

## 2. Sensors (P1)

| ID | Test | Expected |
|---|---|---|
| D-SEN-01 | Hold the device level | Reads within about 1° |
| D-SEN-02 | Tilt through ±45° | Tracks smoothly without jitter |
| D-SEN-03 | Rotate past vertical | No wrap to 359° |
| D-SEN-04 | A device without an accelerometer | The Level tool disappears; no dead readout |

## 3. Alignment on real clinical images (P0)

**This is the substantive gap.** The regression suite validates geometry
against synthetic images. Nothing validates behaviour on real anatomy, and no
threshold may be treated as validated until this is done (CV §44, §64, §78).

Photograph each of the following, then re-photograph from a known offset:

| ID | Subject | Watching for |
|---|---|---|
| D-ALN-01 | Skin lesion, high contrast | Baseline; should behave like the synthetic case |
| D-ALN-02 | Low-texture skin (forearm, back) | Likely `UNAVAILABLE`. That is correct if it is |
| D-ALN-03 | Hair-bearing area | Dense unstable texture; watch for a confident wrong match |
| D-ALN-04 | Wound with a dressing | Dressing changes between visits |
| D-ALN-05 | Across skin tones | Detection rates must not vary systematically |
| D-ALN-06 | Joint or limb, repositioned | Subject movement, not camera movement (CV §28) |
| D-ALN-07 | Face with a changed expression | Deformable anatomy; confidence should drop (CV §29) |
| D-ALN-08 | Different device between Before and After | Different sensor, lens and colour science |
| D-ALN-09 | Daylight versus clinical lamp versus flash | Real lighting change, not a uniform shift |
| D-ALN-10 | Two visually similar but different sites | **Must not** report a good match |

Record per case: translation, rotation and scale error against the known
offset; inlier ratio; reported confidence; latency; whether the reported
confidence was warranted. Feed the result into
[`docs/cv/THRESHOLDS.md`](../cv/THRESHOLDS.md).

## 4. Guidance and human factors (P1)

Testing §78. With clinicians, not developers:

- Time to acceptable alignment
- Number of guidance actions needed
- Whether an instruction was ever confusing or contradictory
- Whether temporal smoothing feels responsive or laggy
- Whether anyone read the confidence percentage as a clinical figure — if so,
  that is a finding, not a user error (CV §71)

## 5. Measurement validation (P0)

Technical Architecture §51 and Testing §80. Photograph objects of known size:

| ID | Object | Method | Record |
|---|---|---|---|
| D-MES-01 | 1 cm | Ruler | Measured, expected, absolute and percentage error |
| D-MES-02 | 5 cm | Ruler | As above |
| D-MES-03 | 10 cm | Ruler | As above |
| D-MES-04 | 5 cm at 15°, 30°, 45° to the plane | Ruler | Error versus angle |
| D-MES-05 | 5 cm at three distances | Ruler | Error versus distance |
| D-MES-06 | Known area | Manual | Area error, which compounds the linear error |
| D-MES-07 | The same object on three devices | Manual | Cross-device variation |

**No accuracy figure may be published until this is complete** (Technical
Architecture §51: "Do not claim an accuracy level until this testing is
completed").

## 6. Gallery and permissions (P0)

| ID | Test | Expected |
|---|---|---|
| D-GAL-01 | Save with Privacy Mode on | Never automatic; always asks |
| D-GAL-02 | Save with `ALWAYS` and Privacy Mode off | Copies without asking |
| D-GAL-03 | Save with `NEVER` | No copy under any circumstance |
| D-GAL-04 | Deny gallery permission | WISE capture and storage continue |
| D-GAL-05 | Delete a WISE photograph after a Gallery save | The Gallery copy survives (Data Model §37.7) |
| D-GAL-06 | The `WISE Clinical Photos` album | Created where the platform allows |
| D-GAL-07 | iOS limited photo access | Import still works, or explains clearly |

## 7. Performance (P1)

Testing §50-54. Numeric targets come from this testing, not from assumption.

| ID | Measure | Note |
|---|---|---|
| D-PRF-01 | Camera cold start | Per device tier |
| D-PRF-02 | Preview frame rate with alignment on | Preview smoothness wins over CV rate (CV §57) |
| D-PRF-03 | Alignment latency per frame | Roughly 70-120 ms at 320 px on a desktop VM; unknown on a phone |
| D-PRF-04 | Peak memory over a 30-minute session | Watch for growth |
| D-PRF-05 | Thermal state after 15 minutes of alignment | Consider dropping to `AlignmentConfig.reducedPerformance` |
| D-PRF-06 | Battery drain per 100 captures | |
| D-PRF-07 | Export at full resolution | |
| D-PRF-08 | Library scroll with 1,000 photographs | Thumbnails only |

## 8. Offline (P0)

| ID | Test | Expected |
|---|---|---|
| D-OFF-01 | Airplane mode, full workflow | Everything works |
| D-OFF-02 | Airplane mode, first launch | The app initialises |
| D-OFF-03 | Network monitor during the full workflow | Zero outbound requests |

D-OFF-03 is the device-level counterpart of the automated network-policy test.

## 9. Accessibility (P1)

| ID | Test | Expected |
|---|---|---|
| D-ACC-01 | VoiceOver through the whole workflow | Every control reachable and labelled |
| D-ACC-02 | TalkBack, same | As above |
| D-ACC-03 | Largest system text size | Capture control still obvious and reachable |
| D-ACC-04 | Reduced motion on | Blink comparison does not auto-animate |
| D-ACC-05 | Greyscale display | Every status still legible (non-colour-only) |
| D-ACC-06 | One-handed reach | Capture and opacity within reach |

## 10. Data integrity (P0)

| ID | Test | Expected |
|---|---|---|
| D-DAT-01 | Force-quit during capture | No orphaned file; no partial row |
| D-DAT-02 | Fill storage mid-capture | Clean failure; the original is intact or absent |
| D-DAT-03 | Upgrade over an installed older build | Photographs and preferences survive |
| D-DAT-04 | 500 photographs, then verify integrity | Every checksum matches |
| D-DAT-05 | OS restore to a new device | Excluded from backup by design; confirm expected behaviour |

---

## Reporting

Per Testing §86, record for each: device, OS version, build, steps, expected,
actual, severity, and a screenshot or recording where it helps.

Anything CV-related feeds
[`docs/cv/THRESHOLDS.md`](../cv/THRESHOLDS.md). Anything blocking updates
[`docs/deployment/RELEASE_GATES.md`](../deployment/RELEASE_GATES.md).

**Clinical photographs from this testing must not be committed to the
repository** (Privacy §52, Build Specification §97).
