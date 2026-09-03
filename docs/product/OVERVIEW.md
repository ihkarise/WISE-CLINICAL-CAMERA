# Product Overview

For anyone joining the project. The specifications are the authority; this is
the orientation.

---

## What it is for

A clinician photographs a lesion, a wound, a joint, a posture. Weeks or months
later they photograph it again. If the second photograph was taken from a
different distance, angle or height, the two cannot honestly be compared — the
lesion may look smaller because the camera moved, not because it healed.

WISE exists to make the second photograph match the first.

> **Take the same photograph again.** — PRD §1

Not diagnosis. Not measurement certification. Reproducibility.

---

## The three modes

```text
BEFORE          AFTER           PHOTO
reference       match it        simple
```

**BEFORE** creates a reference and records how it was taken — camera, zoom,
flash, orientation, which tools were on, the device tilt — as a *capture
recipe*.

**AFTER** loads a chosen Before, shows it as a translucent ghost over the live
preview, and guides the clinician into position: *Move closer. Rotate slightly
left.* When everything matches, it says so.

**PHOTO** is an ordinary camera, for documentation that needs no reference.

Everything else is optional and off until switched on.

---

## Why it stays simple

The PRD returns to this repeatedly, and it is the easiest thing to get wrong:

> "The application must remain simple for users who only want a camera."
> — PRD §2
>
> "Do not turn the home screen into a complex medical dashboard."
> — Build Specification §8
>
> "The photograph is the hero." — master prompt Phase 36

Nine optional tools exist. Four are on by default. A clinician who wants a
camera gets a camera. A clinician who wants measurement, calibration,
annotation, protocols and difference views can have all of it, and their
choices persist.

---

## The reproducibility loop

```text
Match  →  Check  →  Capture  →  Compare  →  Measure  →  Export
```

**Match** — ghost overlay plus alignment guidance.
**Check** — lighting and focus, advisory only.
**Capture** — always possible; warnings never block.
**Compare** — side by side, slider, overlay, blink, difference.
**Measure** — after calibration, and only then in physical units.
**Export** — original, annotated, measured, paired, anonymized, report-ready.

---

## What it deliberately will not do

PRD §35 excludes from V1: diagnosis, treatment recommendation, automatic disease
classification, complicated patient management, mandatory cloud accounts,
expensive AI APIs, unnecessary analytics, social features, automatic medical
claims.

The product's own language reflects that. A measurement is *"Photographic
measurement. Accuracy depends on calibration and capture geometry."* A
difference view says *"Visual difference only. This does not provide a medical
diagnosis."* An alignment percentage is a reproducibility score, and the
specification says plainly it must never be presented as clinical accuracy
(CV §31, §49, §71).

---

## Where the difficulty actually is

Not the camera. Two places:

**1. Knowing when the system does not know.** A confident wrong alignment is the
worst outcome: the clinician captures believing the frames match, and the pair
is later compared as though they did. The engine gates hard before it scores,
and says "unavailable" rather than offering a low number. Most of the CV test
suite is about declining, not matching.

**2. Never damaging the original.** The original photograph is clinical
evidence. Annotations, measurements, grids, comparisons, exports and
anonymization are all layers or derived files. Nothing in the codebase can
rewrite an original, and a test proves it by hashing a file before and after
everything the app can do to it.

---

## Vocabulary

| Term | Meaning |
|---|---|
| **Reference** | The Before photograph an After is reproducing |
| **Ghost overlay** | The reference drawn translucently over the live preview |
| **Capture recipe** | What a photograph remembers about how it was taken |
| **Alignment confidence** | A reproducibility score, 0-1. Not clinical accuracy |
| **Calibration** | The pixels-to-millimetres relationship for one photograph |
| **Derived asset** | Any file generated from an original: thumbnail, export, comparison |
| **Session override** | A one-capture tool change that never becomes a default |
| **Protocol** | A reusable, versioned set of capture settings |
| **Privacy Mode** | On by default. No automatic Gallery copy, no cloud, no third-party processing |

---

## Where to go next

- [`docs/PROJECT_KNOWLEDGE_MAP.md`](../PROJECT_KNOWLEDGE_MAP.md) — the
  specifications, mapped
- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — how it is built
- [`docs/SPECIFICATION_CONFLICTS.md`](../SPECIFICATION_CONFLICTS.md) — the
  decisions that were not fully determined
- [`docs/cv/THRESHOLDS.md`](../cv/THRESHOLDS.md) — what is not yet validated
