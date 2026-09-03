# WISE Clinical Camera

A privacy-first, offline-first clinical photography application that helps
clinicians reproduce standardized photographs over time.

> **Take the same photograph again.**

The product is not a diagnostic tool. Its purpose is photographic
reproducibility: create a **Before** reference today, and months later use WISE
to reproduce its position, angle, scale, framing and lighting closely enough
that the two images can be compared with confidence.

```text
BEFORE          AFTER           PHOTO
reference       match it        simple
```

```text
Match  ->  Check  ->  Capture  ->  Compare  ->  Measure  ->  Export
```

---

## Status

**Milestones 1-5 implemented. Not yet verified on hardware.**

| Area | State |
|---|---|
| Foundation, design system, data model, storage | Implemented, tested |
| Camera abstraction and capability detection | Implemented; **needs a device** |
| BEFORE / AFTER / PHOTO workflows | Implemented, tested end to end |
| Reference picker, ghost overlay, lock, transform | Implemented |
| Alignment, guidance, lighting, focus, grid, level | Implemented, tested |
| Calibration, measurement, annotation | Implemented, tested |
| Comparison (five modes) and difference view | Implemented |
| Cases, protocols, library, export, anonymization | Implemented, tested |
| AI abstraction | Implemented; **no provider ships** — the core runs with AI off |
| iOS and Android builds | **Not verified.** See below |

Everything verifiable without a device is verified: `flutter analyze` is clean
and the test suite passes. Everything that needs real hardware — the camera,
sensors, gallery permissions, performance, thermal and battery behaviour — is
implemented but **unverified**, because this repository was built in an
environment with no Android SDK, no Xcode and no device.

What must be run on hardware before V1: `docs/testing/DEVICE_TEST_PLAN.md`.
Which release gates are met and which are not:
`docs/deployment/RELEASE_GATES.md`.

---

## The rules this codebase is built around

Six invariants appear across five or more specifications. They are enforced in
code with dedicated tests, not treated as conventions.

| Invariant | How it is enforced |
|---|---|
| **The original is never modified** | `ImageStorageService` has no method that rewrites an original. Rendering decodes into a copy. `test/privacy/original_immutability_test.dart` SHA-256s a file before and after a full annotate/measure/export/anonymize cycle. |
| **No silent upload** | The core has no network call site. `NetworkGuard` is the only gate and it audits every attempt; the end-to-end privacy test asserts the audit log is empty after the whole clinical workflow. The Android manifest declares no `INTERNET` permission, and CI fails if one appears. |
| **No physical units without calibration** | `Measurement.displayValue` returns pixels when `calibrationId` is null. There is no code path that produces centimetres without a validated `Calibration`. |
| **Preferences persist; session overrides do not** | `EffectiveSettings.resolve` is a pure function. A one-capture override lives in runtime state and is never written to the database. |
| **Capture stays possible** | `CaptureReadiness` returns `canCapture: true` through every advisory warning. Only a deliberately configured protocol may block, and no shipped protocol does. |
| **Confidence is not clinical accuracy** | The confidence model gates before it scores: weak evidence yields `UNAVAILABLE`, not a low number. Readiness requires a good score *and* every dimension satisfied. |

---

## Getting started

Requires Flutter 3.35.5 or later.

```bash
flutter pub get
flutter run                     # a connected device or simulator
```

Development build, which enables CV debug overlays and verbose logging:

```bash
flutter run --dart-define=WISE_ENV=development
```

Production is the default, so a build that forgets the flag is the safe one.

### Checks

```bash
dart format lib test
flutter analyze                 # must be clean; CI treats every diagnostic as fatal
flutter test                    # full suite
tool/test.sh                    # the same, printing only the summary and failures

flutter test test/privacy/      # the P0 privacy suite
flutter test test/cv/           # alignment regression and false-confidence
flutter test test/integration/  # the end-to-end clinical workflow
```

---

## Architecture at a glance

```text
lib/
├── app/          theme, routes, provider wiring
├── core/         camera, cv, imaging, measurement, storage, database,
│                 sensors, permissions, logging, network, config, errors
├── features/     one directory per feature, UI plus its controller
├── models/       entities and value types
├── repositories/ the only code that talks to the database service
├── services/     ai, gallery, export
└── shared/       widgets, constants
```

Layering, per Data Model section 65 and Build Specification section 102:

```text
UI  ->  Controller  ->  Repository  ->  DatabaseService  ->  SQLite
UI  ->  Controller  ->  Repository  ->  ImageStorageService  ->  Filesystem
```

No widget imports `sqflite` or a camera plugin. `PluginCameraEngine` is the
only file that imports `package:camera`, which is what keeps the camera engine
reusable by other WISE applications.

Full detail: [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Computer vision

The alignment engine is a pure-Dart implementation of the stack the CV
specification recommends for V1: FAST-9 corner detection over a scale pyramid,
intensity-centroid orientation, rotated BRIEF descriptors, Hamming matching
with a Lowe ratio test and cross-check, and RANSAC similarity estimation.

It is pure Dart rather than an OpenCV binding for a reason worth stating: it
runs in `flutter test` with no device and no emulator, which is the only way the
regression and false-confidence suites can actually execute. It sits behind the
`AlignmentEngine` interface, so a native implementation can replace it after
benchmarking without touching a caller. The full reasoning is
[SPECIFICATION_CONFLICTS C-013](docs/SPECIFICATION_CONFLICTS.md).

**Every threshold is provisional.** None has been validated against real
clinical photography. They are configuration, never constants at a call site,
and [`docs/cv/THRESHOLDS.md`](docs/cv/THRESHOLDS.md) records what each one is
and what must be measured before it can be trusted.

---

## Privacy

- Photographs live in application-private storage. Nothing is written to the
  device Gallery unless the clinician asks.
- The core workflow makes no network request. There is no `INTERNET` permission
  on Android.
- Privacy Mode is **on** for a new user, and downgrades "always save to
  Gallery" to "ask" rather than obeying it.
- Clinical photographs and the database are excluded from Android cloud backup
  and device transfer.
- No GPS is collected. `PhotoMetadata` has no field for it.
- Logs take scalar fields only, redact sensitive keys and reduce paths to their
  basename. Image pixels cannot be logged.
- AI ships disabled with no provider registered. No vendor SDK is imported.

Details: [`docs/privacy/`](docs/privacy/).

---

## Documentation

| Document | Contents |
|---|---|
| [`docs/PROJECT_KNOWLEDGE_MAP.md`](docs/PROJECT_KNOWLEDGE_MAP.md) | Every specification mapped by domain, authority and impact |
| [`docs/REQUIREMENTS_TRACEABILITY.md`](docs/REQUIREMENTS_TRACEABILITY.md) | Each requirement ID to module, priority and test |
| [`docs/SPECIFICATION_CONFLICTS.md`](docs/SPECIFICATION_CONFLICTS.md) | Conflicts, configurable decisions and missing inputs |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Layers, engines, data flow, decisions |
| [`docs/cv/THRESHOLDS.md`](docs/cv/THRESHOLDS.md) | Every CV constant and its validation status |
| [`docs/testing/DEVICE_TEST_PLAN.md`](docs/testing/DEVICE_TEST_PLAN.md) | What must be run on hardware |
| [`docs/deployment/RELEASE_GATES.md`](docs/deployment/RELEASE_GATES.md) | V1 gates, met and unmet |
| [`docs/architecture/DEPENDENCIES.md`](docs/architecture/DEPENDENCIES.md) | Every dependency and why it earns its place |
| [`docs/specifications/`](docs/specifications/) | The ten source specifications, unmodified |

---

## What this application does not do

Deliberately, per PRD section 35:

- No diagnosis, disease classification or treatment recommendation
- No automatic clinical decision making
- No mandatory cloud account or backend
- No mandatory AI
- No analytics on image content
- No claim of medical-grade measurement accuracy

A photographic measurement is described as exactly that: *"Photographic
measurement. Accuracy depends on calibration and capture geometry."* The
difference view carries *"Visual difference only. This does not provide a
medical diagnosis."*

---

## Licence and clinical data

No clinical photographs are committed to this repository, and none should be
(Privacy §52, Build Specification §97). The CV regression suite generates its
own synthetic images at test time.
