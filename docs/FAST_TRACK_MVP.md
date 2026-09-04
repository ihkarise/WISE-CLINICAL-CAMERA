# Fast-Track MVP — First Usable Device Build

**Document:** `docs/FAST_TRACK_MVP.md`
**Product:** WISE Clinical Camera
**Created:** 2026-09-04
**Owner action required:** yes (see §4)

---

## Purpose

Get the first usable WISE Clinical Camera build onto a real Android device as
fast as reasonably possible, so the project owner can physically exercise the
core clinical workflow and generate real feedback.

This is an **internal validation milestone**. It is **not** production release
approval. "Buildable", "installable", "usable", "device-validated" and
"production-ready" are distinct states; MVP-1 targets *installable → usable*
only.

---

## MVP-1 — First Usable Device Build

### Definition of done

A build is MVP-1-complete when, on at least one real Android device:

- [ ] installable APK obtained and installed
- [ ] app launches without crash; initial screen is usable
- [ ] camera opens
- [ ] camera permission flow works (grant path)
- [ ] a photograph can be captured
- [ ] the photograph persists (survives app restart) and the original is intact
- [ ] Before capture works (body part / laterality / optional case, saved)
- [ ] After capture works (reference appears, overlay works, capture + relationship saved)
- [ ] library works (thumbnails render, detail opens, Before/After relationship visible)
- [ ] basic photographic measurement works (calibrate → measure → persists)
- [ ] annotation works (create → edit → save → reopen → persists)
- [ ] comparison works (at least one mode renders correctly)
- [ ] export works (original exports; original unchanged afterward)
- [ ] no known blocking crash in the tested workflow
- [ ] privacy behaviour spot-checked (no unexpected network / upload)
- [ ] results recorded in [`docs/DEVICE_TEST_RESULTS.md`](DEVICE_TEST_RESULTS.md)

Every box is checked from **observed device behaviour**, never from source
inspection or CI. Until a box is checked against a real device it stays
`IMPLEMENTED — NOT VALIDATED`.

### Explicitly out of scope for MVP-1

Do **not** block MVP-1 on, and do **not** add, any of:

- clinical CV / alignment dataset validation (separate milestone)
- final encryption / at-rest security decision (C-019)
- iOS physical-device testing
- production signing, store metadata, store listing
- cloud backend, authentication, AI, sync, social features, new clinical features

These are later release gates. MVP-1 exists to expose reality early, not to be
perfect.

---

## Current state (2026-09-04)

| Item | State |
|---|---|
| `main` HEAD | `751004b` (Merge PR #4) |
| CI on `main` | **green** (run #15) |
| Android debug APK artifact | **exists, not expired** — `android-debug-apk`, ~76 MB, expires 2026-12-03 |
| Artifact run | https://github.com/ihkarise/WISE-CLINICAL-CAMERA/actions/runs/33893783197 |
| Production camera engine | real `PluginCameraEngine` (camera plugin) — `IMPLEMENTED — NOT VALIDATED` on hardware |
| Android manifest | CAMERA declared, no INTERNET (privacy-correct) |
| Device test evidence | **none yet** — no device exercised (see `DEVICE_TEST_RESULTS.md`) |

**A rebuild is not required to start.** A green, installable APK already exists
for the current `main`. The fastest path to MVP-1 is to install *that* APK and
run the workflow.

---

## §4 — Fastest route to a device (owner action)

The build agent's environment has **no Android SDK, no adb, no device, and the
egress proxy blocks the CI artifact host**, so the agent cannot download the APK
binary or install it. The project owner retrieves it directly from GitHub:

1. Open the workflow run:
   https://github.com/ihkarise/WISE-CLINICAL-CAMERA/actions/runs/33893783197
2. Under **Artifacts**, download **`android-debug-apk`** (a `.zip`).
3. Unzip to get `app-debug.apk`.
4. Transfer to an Android phone and install (enable "install unknown apps" for
   the file manager / browser used). Or, on a machine with platform-tools:
   `adb install app-debug.apk`.
5. Launch **WISE Clinical Camera** and run the MVP-1 workflow.
6. Record what actually happens in
   [`docs/DEVICE_TEST_RESULTS.md`](DEVICE_TEST_RESULTS.md) — including failures.

Notes:
- This is a **debug** APK: unsigned for release, larger, and slower than a
  release build. That is expected for internal validation.
- Use **synthetic / non-identifiable test subjects only**. Do **not** commit
  clinical photographs to the repository (Privacy §52).

---

## The fast-track loop

```
Existing green APK
      ↓
Install on Android device
      ↓
Run MVP-1 workflow
      ↓
Record real failures (DEVICE_TEST_RESULTS.md)
      ↓
Fix only what is necessary (+ regression test)
      ↓
CI (unchanged, not weakened)
      ↓
New APK
      ↓  (repeat)
```

Fix the highest-impact real-device problems first (camera crash, permissions,
navigation, storage, overlay, measurement, export). Do not polish low-value
features while a core step is broken.

---

## Release path after MVP-1

```
MVP-1  First usable Android build
   ↓
MVP-2  Android device hardening
   ↓
MVP-3  iOS device validation
   ↓
Validation  CV + measurement + performance (evidence-based)
   ↓
Security decision  C-019
   ↓
Release Candidate → Pilot → Production Release
```

No evidence is skipped. MVP-1 being usable does not make the product
production-ready.
