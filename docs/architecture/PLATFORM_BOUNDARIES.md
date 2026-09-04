# Reusable WISE platform boundaries

Phase 2 §51. Technical Architecture §18 and §57 ask for "a modular architecture
that can later be reused by other WISE applications", and name the consumers:
dermatology, wound documentation, physiotherapy, rehabilitation, posture
assessment, swelling documentation, dental photography, general clinical
records, educational case documentation.

That is a real constraint, not an aspiration, and it is testable: a module is
reusable if extracting it would not drag the rest of the product with it. This
document says which modules pass that test today, which do not, and why.

## The layers

```
app/          providers, routing, theme          product-specific
features/     screens and controllers            product-specific
shared/       WISE-styled widgets                product-specific
repositories/ persistence over the schema        product-shaped
models/       the clinical domain                mostly portable
core/         engines and services               portable
```

The dependency rule is that arrows point downward. It holds, with the one
exception recorded below.

## Verified dependency map

Generated from the imports in `lib/`, not from intent.

| Module | Depends on |
|---|---|
| `core/cv` | `core/errors`, `core/imaging`, `core/logging`, `models` |
| `core/imaging` | `core/errors`, `models` |
| `core/measurement` | `models` |
| `core/database` | `core/errors`, `core/logging` |
| `core/storage` | `core/database`, `core/errors`, `core/imaging`, `core/logging` |
| `core/network` | `core/config`, `core/errors` |
| `core/camera` | `core/errors`, `core/logging`, `models` |
| `core/permissions` | `core/errors`, `core/logging` |
| `core/sensors` | — |
| `repositories` | `core/*`, `models` |
| `features/*` | `app`, `core/*`, `models`, `repositories`, `shared` |

No `core/` module imports `features/`. One imported `app/`, and does not any
more — see below.

## What is reusable today

### `core/cv` — the alignment engine

Pure Dart. FAST-9 corner detection over a scale pyramid, intensity-centroid
orientation, rotated BRIEF descriptors, Hamming matching with a ratio test and
cross-check, RANSAC similarity estimation with a least-squares refit, plus the
lighting and focus engines and the confidence model.

It knows nothing about photographs, patients or clinics. Its input is a
`WorkingImage` — width, height, and a luminance buffer — and its output is a
transform, a confidence and a set of metrics. Any application that needs to
know "is this frame the same view as that one" can use it unchanged.

**Reusable as-is.** 87% line coverage, no platform dependency, no Flutter
dependency beyond `package:image`.

The one caveat is not structural: every threshold in `AlignmentConfig` and
`QualityConfig` is provisional and calibrated against synthetic imagery. A
consumer must revalidate them for its own subject matter. Dental photography
and wound photography do not have the same feature density.

### `core/imaging` — composition and metadata

Layer rendering, the shared markup geometry, EXIF anonymisation, thumbnails,
codec handling. Depends on `models` for the annotation and measurement shapes,
which is the boundary worth noting: the *renderer* is generic, the *things it
renders* are this product's vocabulary.

**Reusable with a small seam.** Extracting it would mean parameterising the
annotation and measurement types, or accepting them as a shared domain package.

### `core/storage` and `core/database` — integrity

The two-phase write (temp → verify → move → commit row → orphan cleanup),
SHA-256 verification, the path layout, the migration runner and the maintenance
service. None of it knows what an image contains.

**Reusable as-is.** This is arguably the most portable code in the repository:
"store a file so that a crash cannot leave a row pointing at nothing" is a
problem every clinical application has.

### `core/camera` — the camera engine

The `CameraEngine` interface, its capability model, the plugin implementation
and the scriptable fake. Technical Architecture §57 singles this out as the
component that should become a platform primitive.

**Reusable as-is, as of this phase.** `CameraPreviewSurface` previously imported
`app/theme/wise_tokens.dart` for two placeholder colours, which meant taking the
camera engine into another product would have brought WISE's design tokens with
it. The colours are now parameters with neutral defaults, and the product passes
its own.

That was the only `core/` → `app/` import in the repository, and it is the
category of dependency worth watching: it costs nothing to add and quietly
converts a platform component into a product component.

### `core/permissions`, `core/sensors`, `core/network`, `core/logging`

Small, self-contained, no product vocabulary. The permission service and level
service both take an injectable source, which is what makes them testable
without a device and reusable without a rewrite.

**Reusable as-is.**

## What is not reusable, and correctly so

### `models/`

The clinical domain: `Photo`, `Measurement`, `Annotation`, `Calibration`,
`CaptureProtocol`, `ClinicalCase`. A different WISE application would share much
of this vocabulary and not all of it — posture assessment has no wound, dental
photography has no laterality in the same sense.

**Shared domain package candidate,** not a lift-and-shift. The split would be
between the geometry and measurement primitives (portable) and the clinical
entities (negotiable).

### `repositories/`

Written against this schema. Portable in shape, not in substance.

### `features/`, `app/`, `shared/`

The product. Screens, routing, the provider graph, WISE-styled widgets. Not
intended to be reusable and no effort should be spent making them so.

## The rule worth keeping

A `core/` module may depend on `core/` and on `models/`. It may not depend on
`app/`, `features/`, `repositories/` or `shared/`.

That single rule is what the reusability requirement reduces to in practice, and
it is cheap to check:

```sh
grep -rn "import '.*\(app\|features\|repositories\|shared\)/" lib/core/
```

Empty output means the boundary holds. It returned one line before this phase.

## What reuse would actually require

Being honest about the distance, since §57 says "eventually":

1. **A package split.** `core/` is not a published package; it is a directory.
   Extracting it means a `wise_camera` / `wise_cv` / `wise_storage` package
   layout, a versioning policy, and a decision about whether `models` splits.
2. **Threshold revalidation per domain.** See above. This is the real work, and
   it needs the same governed-dataset process `test_data/README.md` describes.
3. **A camera engine tested on hardware.** `plugin_camera_engine.dart` has 0%
   coverage because there is no camera in this environment. Publishing it as a
   platform component before it has ever run on a device would be premature in
   a way no amount of structure fixes.

None of that is blocked by the current architecture, which is the point of
recording the boundary now rather than discovering it later.
