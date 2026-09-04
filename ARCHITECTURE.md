# Architecture

How WISE Clinical Camera is put together, and why.

Companion to [`docs/PROJECT_KNOWLEDGE_MAP.md`](docs/PROJECT_KNOWLEDGE_MAP.md),
which maps the specifications, and
[`docs/SPECIFICATION_CONFLICTS.md`](docs/SPECIFICATION_CONFLICTS.md), which
records the decisions that were not fully determined by them.

---

## 1. Shape

```text
                        UI  (features/*/…_screen.dart)
                                    │
                     Controllers / StateNotifiers
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
   Repositories                  Engines                    Services
   photo, clinical,        camera, cv, imaging,        ai, gallery, export
   case, protocol,         measurement, sensors
   preference
        │                           │                           │
        └───────────────────────────┼───────────────────────────┘
                                    │
                          DatabaseService · ImageStorageService
                                    │
                            SQLite  ·  Filesystem
```

Two rules hold this together (Data Model §65, Build Specification §102):

1. **No widget touches SQLite or a camera plugin.** UI reads providers,
   providers expose repositories and engines.
2. **`package:camera` is imported only inside `lib/core/camera/`** — by
   `PluginCameraEngine` and by `CameraPreviewSurface`, which owns the preview
   widget so no feature screen needs the plugin. Everything platform-specific
   is contained in that directory.

The second rule is what makes the camera engine reusable by other WISE
applications (Technical Architecture §57, master prompt Phase 54), and it is
also what lets the entire capture workflow be tested with `FakeCameraEngine`.

---

## 2. Storage: two systems, one lifecycle

```text
                    WISE Clinical Camera
                             │
              ┌──────────────┴──────────────┐
          SQLite                        Filesystem
   structured records                 image binaries
   relationships                      thumbnails
   measurements                       derived assets
   annotations                        exports
```

Originals are never stored as BLOBs (Data Model §2.1), and derived assets are
kept apart from them so that regenerating one can never endanger the other.

```text
WISE/
├── originals/          written once, never rewritten
├── thumbnails/
├── derived/{annotated,measured,comparison,exports}/
├── temp/               swept on a schedule
└── backups/
```

Filenames are opaque UUIDs. A filename never carries a patient name or a
diagnosis (Privacy §12).

### The two-phase write

`PhotoRepository.createPhoto` follows Data Model §44 exactly:

```text
1. generate the UUID
2. write a temporary file
3. verify it       ← decodes the header; a short write fails here
4. move into originals/
5. commit the rows
   └─ on failure: discardOrphan() removes the file from step 4
```

Step 3 is where image dimensions are established, which is why
`photos.width_px` and `height_px` can be `NOT NULL` without ever holding a
placeholder (SPECIFICATION_CONFLICTS C-008).

### Immutability, concretely

`ImageStorageService` exposes `storeOriginal`, `storeDerived`, `readBytes`,
`discardOrphan`, `deleteDerived`, `verifyOriginal` and `cleanTemporaryFiles`.
There is no update, no overwrite, no edit-in-place. `storeOriginal` refuses if
a file already exists at the target path, so even a crash-retry cannot
overwrite one. `LayerRenderer` decodes into `img.Image.from(decoded)` — a copy —
and every drawing call targets that.

Deletion is soft (Data Model §36): the row is marked, the bytes stay, and the
Gallery copy is never touched.

---

## 3. Settings precedence

Five specifications state the same chain. It is implemented once, as a pure
function, in `EffectiveSettings.resolve`:

```text
Platform capability   ← a veto, applied last and unconditionally
        ↓
User default          ← persisted in SQLite
        ↓
Protocol              ← the active capture protocol
        ↓
Session override      ← this capture only, runtime state
        ↓
Effective setting
```

The platform layer is applied **last, as a veto**, not first as a value: a
device that cannot do something must end up off regardless of what the layers
below asked for.

Because resolution is pure and writes nothing, a session override cannot
silently become a saved default — the property Build Specification §2.7
requires. Promoting a session state to a default is a separate explicit action
in the Tools drawer.

`EffectiveSettings.sourceOf(tool)` reports which layer decided, so the UI can
tell the clinician *why* a tool is off rather than leaving them guessing.

---

## 4. The computer vision pipeline

```text
Before photograph
      │
  normalise (grayscale, downsample to working resolution)
      │
  scale pyramid  ──  FAST-9  ──  orientation  ──  rBRIEF descriptors
      │                                              │
      └──────────────── ReferenceFeatures ───────────┘
                              │
Live frame ── normalise ── detect ── match (Lowe ratio + cross-check)
                              │
                    RANSAC similarity estimate
                              │
                    confidence gates, then score
                              │
                    guidance ("Move closer")
```

### Why a similarity transform

CV §16 requires the least complex model that explains the relationship. A
similarity transform has four parameters where a homography has eight, and a
hand-held camera moving relative to a roughly planar subject is what it
describes. Four parameters overfit noise far less readily — and overfitting
noise is precisely how a confident wrong answer is produced. Homography sits
behind a feature flag, off by default, pending the benchmarking CV §73 places
at stage 4.

### Why a scale pyramid

A BRIEF descriptor samples a fixed-size patch, so it is not scale-invariant:
the same corner photographed 20 % further away produces a different descriptor
and stops matching. Without a pyramid the engine would fail exactly when the
clinician is standing at the wrong distance — the case that "Move closer"
exists to fix. Four levels at a 1.3 ratio cover roughly a 2.2× range of subject
size. This was found by a failing test, not by inspection.

### How false confidence is prevented

The dangerous failure is not "cannot align" — that is handled and reported. It
is "reports a good alignment that is wrong", because the clinician then
captures an After believing it matches. Three mechanisms:

1. **Hard gates run before any score.** Too few inliers, a poor inlier ratio,
   inliers concentrated in one region, too few quadrants covered, or an
   excessive reprojection error each yield `UNAVAILABLE` — not a low number. A
   number still reads as an estimate, and in those cases there isn't one.
2. **Multiplicative gating.** The weighted mean is multiplied by factors from
   inlier ratio and spatial spread, so a strong signal cannot mask a weak one.
   A plain weighted average would let a high inlier count paper over a spread
   that cannot constrain the transform (CV §23).
3. **Readiness needs more than a score.** `isReady` requires `GOOD` *and* every
   dimension satisfied.

`test/cv/false_confidence_test.dart` exercises all of it, including repeating
patterns, corner-only detail, occlusion and unrelated scenes.

### Separation of concerns

CV §77 requires that "rotation = -2.4°" and "Rotate slightly right" live in
different places. `TransformEstimator` produces the former, `GuidanceEngine`
the latter. No user-facing string in the CV layer contains a CV term, and a
test asserts it.

---

## 5. Non-destructive layers

```text
Original  (read-only)
   ├── Reference
   ├── Measurements
   ├── Annotations
   ├── Grid
   ├── Labels
   └── Footer
              ↓
       Derived export
```

`LayerStack` holds **no pixels**. It names an original by path and describes
what should be drawn over it. Two renderers consume it:

- `MarkupPainter` draws to the screen. It cannot write a file.
- `LayerRenderer` composes onto a decoded copy for export.

Keeping them separate is what makes on-screen markup provably non-destructive.

Geometry is stored in **original-image pixel coordinates**, never screen
coordinates. That is what lets a measurement survive a rotation, a re-display
at a different size, or a recalculation against a calibration added later
(Data Model §21).

---

## 6. Measurement and calibration

```text
pixelsPerUnit = pixelDistance / knownDistance
```

`Calibration.create` returns `null` for a non-positive or non-finite input, so
an invalid scale cannot be stored. `Calibration.isUsable` is the single gate for
producing physical units, and `Measurement.hasPhysicalValue` is the single gate
for displaying them. With no calibration, `displayValue` returns pixels.

A calibration is bound to one photograph and is never borrowed from another,
even when alignment is good, because "alignment confidence ≠ measurement
accuracy" (CV §49, SPECIFICATION_CONFLICTS C-011).

Change is `((after − before) / before) × 100`, with a `null` percentage when the
baseline is zero. `null` rather than `0`, `∞` or `NaN`: any of those would read
as a real figure in a clinical record (SPECIFICATION_CONFLICTS C-010).

Physical values render to one decimal place, matching every worked example in
the specifications. Two decimals would assert a precision that photographic
measurement does not have.

---

## 7. Privacy architecture

```text
Feature code
     │
     ├── (core workflow)  ─────────────────────►  no network call site at all
     │
     └── (optional service)  ──►  NetworkGuard  ──►  allowed, and audited
                                       │
                                  refused under
                                  Privacy Mode or
                                  cloud AI disabled
```

The guarantee is the **absence** of call sites in the core, not the presence of
the guard. The guard exists so that any future call site is visible and
auditable, and so a test can assert the whole clinical workflow produced an
empty audit log.

Reinforced at the platform layer: the Android manifest declares no `INTERNET`
permission, and CI fails if one appears. That turns a convention into something
the operating system enforces.

---

## 8. AI

```text
AiService
   ├── (V1: no provider registered)
   ├── OnDeviceAIProvider      ─┐
   ├── SelfHostedAIProvider     ├── ordered cheapest and most private first
   └── CloudAIProvider         ─┘
```

V1 registers no provider. Every call returns `AiUnavailable`, and nothing in
capture, storage, CV, measurement, annotation, comparison or export notices —
which is what "the core application must function with AI = OFF" means in
practice. No vendor SDK is imported anywhere in the codebase. A provider that
would leave the device must clear `NetworkGuard`, and fails closed when no
audited route is configured.

---

## 9. Errors

Services return `Result<T>` carrying a typed `Failure` rather than throwing, so
a caller cannot ignore a failure by accident and the UI always has a
`userMessage` to show. `WiseErrorView` is the only place a failure becomes
visible text, and it renders `userMessage`, never `technicalDetail`.

`ImageCodec` exists because `package:image`'s `decodeImage` throws `RangeError`
on short or malformed buffers rather than returning null — a truncated file
would otherwise crash the app. Every decode in the application goes through it.
That bug was found by the immutability test.

---

## 10. Threading and memory

- CV works on a downsampled grayscale image, never a full-resolution
  photograph.
- Preview frames are **sampled**, and a frame arriving while one is being
  analysed is dropped rather than queued. A backlog would make guidance lag
  behind what the clinician is seeing, which is worse than a lower rate.
- Rendering, thumbnailing and differencing are pure Dart with no Flutter
  binding, so they can run in a background isolate.
- Checksums stream the file rather than buffering it.
- The library browses on thumbnails; a full original is decoded only when one
  photograph is opened.

---

## 11. Decisions and their reasons

| Decision | Reason |
|---|---|
| Flutter | Technical Architecture §3 |
| Riverpod | Compile-safe, testable, keeps persistent / session / processing / UI state visibly separate (Build Specification §103) |
| Pure-Dart CV | Runs in CI with no device, no native attack surface in an app holding clinical images, no 20-40 MB per ABI. Behind an interface, so replaceable after benchmarking (C-013) |
| `sqflite` + `sqflite_common_ffi` | The real SQLite engine in tests: migrations, foreign keys and CHECK constraints are exercised rather than mocked |
| Similarity over homography | Fewer parameters, far less prone to overfitting noise into a confident wrong answer (CV §16) |
| No `google_fonts` | It fetches fonts over the network at runtime, breaching offline-first and the network policy |
| No `INTERNET` permission | Makes "no silent upload" enforceable by the platform, not only by convention |
| One `ClinicalRepository` | Calibrations, measurements, annotations, alignments and exports are read and written together for one photograph; eight near-identical classes would add indirection without a boundary |
| Fifteen tables from the start | Data Model §46's migration history, applied literally. §64's smaller subset was an optional fallback, not needed (C-007) |

---

## 12. What is deliberately absent

Per Build Specification §100 and PRD §35: no authentication server, no clinical
image server, no cloud database, no mandatory AI API, no analytics platform.
Interfaces exist for `AiService`, gallery and export so those can be added
later without redesigning the local model, but no unused infrastructure is
built.

Also not implemented, and marked as such in
[`docs/cv/THRESHOLDS.md`](docs/cv/THRESHOLDS.md) §6: optical flow, template and
edge matching fallbacks, region-of-interest detection, on-device ML, and
automatic marker detection. Each is placed after benchmarking by the CV
specification's own staging, and none blocks the V1 workflow.
