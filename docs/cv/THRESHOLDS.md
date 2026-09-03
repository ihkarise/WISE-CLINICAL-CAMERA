# Computer Vision Thresholds — Validation Status

**Every threshold in the CV engine is provisional.** None has been validated
against real clinical photography. This document records what each one is, why
it has the value it has, and what has to be measured before it can be treated
as production-ready.

This is not a formality. The specifications say so directly:

> "Do not define arbitrary clinical accuracy percentages. Instead establish
> experimentally…" — Computer Vision & Alignment Specification §78

> "Initial blur thresholds must be treated as provisional… Do not use one
> universal threshold without validation." — CV §44

> "The product shall not claim that an arbitrary percentage represents clinical
> accuracy. Thresholds must be validated using test images." — Functional
> ALG-006

> "Use configuration for CV thresholds, blur thresholds, lighting thresholds,
> alignment thresholds… This allows testing without rebuilding the
> architecture." — Build Specification §86

Accordingly **no threshold is hard-coded at a call site**. They live in
`lib/core/cv/alignment_config.dart` and `lib/core/cv/quality_config.dart` and
are injected into every engine.

---

## 1. What the current tests do and do not establish

`test/cv/` runs against a **synthetic** ground-truth dataset generated at test
time (`test/support/cv_dataset.dart`). No clinical photographs were supplied
with the repository, and real ones must not be committed to it (Privacy §52,
Build Specification §97).

**Established by the current suite**

| Property | Evidence |
|---|---|
| Translation is recovered with the correct sign and magnitude | `ALG-T002`, ±30 px on a 320 px canvas |
| Rotation is recovered to within ~2° | `ALG-T003`, 6° input → 6.03° estimated |
| Scale is recovered to within ~2% | `ALG-T004`, 1.2× → 1.200, 0.82× → 0.819, 1.4× → 1.401 |
| A flat, low-texture reference is refused, not guessed at | `ALG-T006` |
| A repeating pattern does not produce a ready-to-capture verdict | `ALG-T007` |
| Detail concentrated in one region does not read as GOOD | `ALG-T008` |
| An unrelated scene never reports ready | `ALG-T009` |
| Occlusion lowers confidence | `false_confidence_test.dart` |
| Every gate in `ConfidenceModel` rejects what it claims to | `false_confidence_test.dart` |
| Blur monotonically reduces the focus score | `quality_engines_test.dart` |
| Brightness and histogram differences are detected and described | `quality_engines_test.dart` |

**Not established, and not claimed**

- Behaviour on real skin, wounds, scars, swelling, bruising or dressings.
- Behaviour across skin tones.
- Hair-bearing areas, which produce dense unstable texture.
- Real lighting change (direction, colour temperature, flash) as opposed to a
  uniform brightness shift.
- Real lens and device variation, including different focal lengths between the
  Before and After device.
- Subject movement and deformable anatomy (CV §28-29).
- Latency, memory, battery and thermal behaviour on real hardware.

**A threshold is not validated because these tests pass.** They demonstrate the
engine is geometrically correct and fails safely on degenerate input.

---

## 2. Alignment thresholds

From `AlignmentConfig`.

| Constant | Default | Basis | To validate |
|---|---:|---|---|
| `workingResolution` | 320 px | CV §8 requires a reduced working resolution; the figure is a guess balancing latency against keypoint count | Per-device benchmark: latency and alignment error versus resolution |
| `fastThreshold` | 20 | Conventional FAST value for 8-bit images | Keypoint yield on real skin, which is far lower contrast than the synthetic scenes |
| `pyramidLevels` / `pyramidScaleFactor` | 4 / 1.3 | Covers roughly a 2.2× subject-size range | The range of distance error clinicians actually produce between visits |
| `maxKeypoints` | 400 | Bounds per-frame cost (CV §56) | Latency budget on a Tier-B device |
| `loweRatio` | 0.8 | Standard ratio-test value | False-match rate on repeated clinical texture |
| `minInliers` | 8 | A similarity transform needs 2; 8 gives margin | False-alignment rate as this varies |
| `minInlierRatio` | 0.25 | CV §22 requires "sufficient inliers"; no figure given | Measured distribution on true and false pairs |
| `minSpatialSpread` | 0.12 | CV §23's failure mode, quantified as normalised σ of inlier positions | Distribution on real images where detail is naturally uneven |
| `minQuadrantsCovered` | 2 | CV §23 | As above |
| `ransacInlierThresholdPx` | 3 px | At 320 px working resolution, ~1% of the frame | Reprojection error distribution on true pairs |
| `goodConfidence` | 0.85 | Technical Architecture §14's "85–94 Good" band, explicitly called a placeholder | **Required.** See below |
| `fairConfidence` | 0.70 | TA §14's "70–84 Acceptable" band, same caveat | **Required** |
| `translationToleranceFraction` | 0.04 | 4% of frame; no specification figure exists | What offset actually degrades a clinical comparison |
| `rotationToleranceDegrees` | 2.0 | No specification figure exists | As above |
| `scaleTolerance` | 0.05 | No specification figure exists | As above |
| `temporalSmoothing` | 0.6 | Chosen so guidance does not flip between contradictory instructions | Perceived responsiveness in human-factors testing (Testing §78) |

### Status vocabulary

`AlignmentStatus` is `GOOD / FAIR / POOR / UNAVAILABLE` per CV §31 and Build
Specification §26. Technical Architecture §14's four numeric bands are carried
as the provisional defaults, with "Excellent" collapsed into `GOOD` because no
specification gives it distinct behaviour. See SPECIFICATION_CONFLICTS C-004.

---

## 3. Confidence weighting

CV §30 names seven signals and states the weighting "must be determined
experimentally". `ConfidenceWeights` gives five of them explicit weights;
sensor agreement and image similarity are not yet inputs (see §6 below).

The model is **deliberately biased toward under-confidence**, and this is a
design decision rather than a tuning artefact. The costly failure is a high
score on a wrong alignment: the clinician captures an After believing it
reproduces the Before, and the pair is then compared as though it matched
(CV §71, Testing §79). Under-confidence merely means the user keeps adjusting.

Two mechanisms implement that bias:

1. **Hard gates run before any score.** Failing one yields `UNAVAILABLE`, not a
   low number — a number still reads as an estimate, and in that situation
   there isn't one.
2. **Multiplicative gating.** The weighted mean is multiplied by factors
   derived from inlier ratio and spatial spread, so a strong signal cannot mask
   a weak one. A plain weighted average would let a high inlier count paper
   over a spread that cannot constrain the transform.

**To validate:** collect true-pair and false-pair distributions from a real
dataset, then choose weights and thresholds that put the false-alignment rate
where the clinical risk assessment requires it.

---

## 4. Quality thresholds

From `QualityConfig`.

| Constant | Default | Basis | To validate |
|---|---:|---|---|
| `focusVarianceThreshold` | 120 | Laplacian variance, normalised to a 480 px long edge | **Required across devices.** CV §44 explicitly forbids one universal threshold |
| `focusWorkingResolution` | 480 px | Normalisation basis, so the score is comparable across sensor resolutions | Confirm the normalisation actually holds across real sensors |
| `luminanceDifferenceThreshold` | 25 / 255 | ~10% mean luminance | What difference actually impairs clinical comparison |
| `histogramSimilarityThreshold` | 0.75 | Histogram intersection; catches a redistributed histogram (a hard shadow) that leaves the mean unchanged | Distribution on real lighting change |
| `tooDarkMeanLuminance` | 45 | Under-exposure heuristic | Real low-light clinical captures |
| `tooBrightMeanLuminance` | 215 | Over-exposure heuristic | Real flash captures, and pale skin under a clinical lamp |
| `maxClippedFraction` | 0.15 | Clipping tolerance | As above |

The focus score is normalised by working resolution so the number means roughly
the same thing on a 12 MP and a 48 MP sensor. **That makes it comparable across
devices; it does not make it validated.**

---

## 5. How to validate

Following CV §65-69 and Testing §61-62:

1. **Build the ground-truth dataset.** Same subject, same device, controlled
   translation, rotation, scale, distance, zoom, tilt and perspective, with the
   applied transform recorded. Then real-world variation: lighting, flash,
   device, lens, subject movement, occlusion, and the clinical conditions
   CV §64 lists.
2. **Record per-case metrics.** Translation, rotation and scale error;
   reprojection error; inlier ratio; false-alignment rate; failure rate;
   latency; memory (CV §67).
3. **Choose thresholds from the distributions**, not from intuition. The
   false-alignment rate is the binding constraint.
4. **Run human-factors testing** (Testing §78): time to acceptable alignment,
   number of guidance actions, capture success rate.
5. **Record the outcome here**, replace the defaults, and bump
   `LocalAlignmentEngine.version` so earlier stored results remain
   distinguishable (CV §53).

Governance for any clinical dataset follows AI & Cost Strategy §59. **Clinical
photographs must not be committed to this repository** (Privacy §52, Build
Specification §97).

---

## 6. Known gaps in the engine itself

| Gap | Specification | Status |
|---|---|---|
| Sensor agreement is not yet a confidence input | CV §30 | The level/tilt sensor feeds guidance and the capture recipe, but does not cross-check the visual estimate |
| Image similarity is not yet a confidence input | CV §30 | Would need a normalised-correlation pass over the warped frame |
| Homography / perspective estimation | CV §20-22, §73 stage 4 | Behind the `homography` feature flag, off by default. A similarity transform is the least complex model that explains the relationship (CV §16), and eight parameters overfit noise far more readily than four |
| Optical flow refinement | CV §26, §73 stage 7 | Not implemented. The specification places it after benchmarking |
| Template and edge matching fallback | CV §24-25, §62 step 4 | Not implemented. The manual-alignment fallback covers the same failure |
| Region-of-interest detection | CV §45 | Not implemented; optional in the specification |
| On-device ML body-region assistance | CV §46 | Deferred; no model ships in V1 |

None of these blocks the V1 workflow: when the engine cannot align, it says so
and the ghost overlay plus manual positioning carry the capture (CV §36,
Functional ALG-007).
