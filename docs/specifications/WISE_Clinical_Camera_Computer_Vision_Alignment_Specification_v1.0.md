# WISE Clinical Camera
## Computer Vision & Alignment Specification v1.0

**Product:** WISE Clinical Camera  
**Purpose:** Define the local computer-vision pipeline used to help reproduce a Before photograph when taking an After photograph.

**Primary objective:**

> The After photograph should be as similar as practically possible to the Before photograph in viewpoint, position, scale, rotation, framing and image conditions.

**Platforms:** iOS and Android  
**Architecture:** Flutter application with native camera/sensor bridges and local computer-vision processing.

---

# 1. Scope

This specification covers:

- reference-image preparation
- camera-frame preprocessing
- sensor-assisted guidance
- image feature detection
- feature matching
- translation estimation
- rotation estimation
- scale estimation
- perspective estimation
- homography
- template matching
- edge-based matching
- optical flow
- image registration
- confidence scoring
- alignment guidance
- reference overlay
- lighting comparison
- quality checks
- capture validation
- failure handling
- performance
- testing
- storage of alignment results

This specification does **not** define clinical diagnosis or medical interpretation.

---

# 2. Core Principle

WISE should not depend on one computer-vision algorithm.

The alignment system should use a layered strategy:

```text
Device Sensors
      ↓
Simple Geometric Checks
      ↓
Classical Computer Vision
      ↓
Image Registration
      ↓
Optional On-Device ML
      ↓
Optional Self-Hosted AI
      ↓
Optional Cloud AI
```

The earlier layer should be preferred when it provides sufficient confidence.

Cloud AI must never be required for ordinary Before/After alignment.

---

# 3. Alignment Problem

Given:

```text
R = Before/reference image
T = current live camera frame
```

the system estimates a transformation:

```text
T → R
```

The transformation may contain:

- translation
- rotation
- scale
- perspective distortion

Depending on the capture scenario, the transformation can be represented as:

```text
Similarity Transform
```

or:

```text
Affine Transform
```

or:

```text
Homography
```

The simplest valid model should be preferred.

---

# 4. Alignment Dimensions

WISE should evaluate at least:

| Dimension | Meaning |
|---|---|
| Position | Subject is centred similarly |
| Scale | Subject occupies similar image area |
| Rotation | Camera/subject orientation is similar |
| Framing | Important region appears in same location |
| Perspective | Viewpoint distortion is similar |
| Orientation | Portrait/landscape matches |
| Lighting | Image conditions are reasonably similar |
| Focus | Image is sufficiently sharp |

---

# 5. Capture Pipeline

Recommended live pipeline:

```text
Camera Frame
     ↓
Resize / Downsample
     ↓
Orientation Correction
     ↓
Optional Exposure Normalization
     ↓
Region Selection
     ↓
Feature / Template Analysis
     ↓
Transformation Estimation
     ↓
Confidence Calculation
     ↓
Guidance
     ↓
Capture Decision
```

The full-resolution image should not normally be used for every live-frame calculation.

---

# 6. Reference Preparation

When the user selects a Before image:

1. Load the original reference.
2. Read stored metadata where available.
3. Read capture recipe.
4. Generate a processing-resolution copy.
5. Detect useful visual information.
6. Store reference features.
7. Store reference geometry.
8. Store optional reference quality metrics.

The original reference must remain untouched.

---

# 7. Reference Processing Cache

A reference-processing cache may contain:

```text
reference image thumbnail
grayscale image
edge map
feature keypoints
feature descriptors
subject/region mask if available
reference dimensions
capture metadata
capture recipe
quality metrics
```

Cache data can be regenerated.

---

# 8. Resolution Strategy

The live preview may be high resolution, but CV calculations should use a reduced working resolution.

Recommended concept:

```text
Preview resolution
      ↓
CV working resolution
      ↓
Full-resolution capture
```

The exact working resolution should be selected through device benchmarking.

The implementation must prioritize smooth camera preview over unnecessary CV precision.

---

# 9. Orientation Normalization

Before image comparison:

1. Read camera orientation.
2. Read device orientation where available.
3. Normalize image coordinates.
4. Apply the same coordinate convention to reference and target.

The system must avoid false alignment failures caused only by portrait/landscape metadata differences.

---

# 10. Sensor-Assisted Alignment

Where available, use:

- accelerometer
- gyroscope
- device orientation
- camera orientation
- lens/camera identifier

Sensors should provide a fast coarse estimate.

They should not be treated as a complete substitute for visual registration.

---

# 11. Sensor Guidance

Example:

```text
Reference:
Portrait
Camera tilt: 1.5°

Current:
Landscape
Camera tilt: 8.2°
```

Guidance:

> Rotate device slightly.

Sensor guidance should be displayed only when the underlying measurement is reliable.

---

# 12. Feature Detection

Classical feature detectors may be evaluated, including:

- ORB
- AKAZE
- FAST
- BRISK
- other platform-supported efficient detectors

The implementation should favour algorithms that:

- run locally
- are computationally efficient
- have permissive licensing suitable for the project
- work across iOS and Android
- perform acceptably on clinical photographs

The exact detector should be selected through benchmarking rather than assumed in advance.

---

# 13. Feature Descriptors

Feature descriptors should encode local image structure sufficiently for matching.

Possible choices include descriptors associated with:

- ORB
- AKAZE
- BRISK

Descriptor selection must be validated against:

- skin
- wounds
- swelling
- posture
- body contours
- low-texture regions
- changing lighting

---

# 14. Feature Matching

Given:

```text
Reference descriptors
Target descriptors
```

the matcher should:

1. Find candidate matches.
2. Apply distance filtering.
3. Apply ratio or equivalent ambiguity filtering where appropriate.
4. Reject implausible spatial matches.
5. Estimate transformation from surviving correspondences.

---

# 15. Outlier Rejection

Feature matching can produce false correspondences.

Use a robust estimator such as:

```text
RANSAC
```

or an equivalent robust method.

The system should distinguish:

```text
candidate matches
```

from:

```text
inlier matches
```

Only reliable inliers should contribute strongly to transformation estimation.

---

# 16. Transformation Selection

The system should choose the least complex transformation that explains the image relationship.

Recommended order:

```text
Translation
   ↓
Similarity
   ↓
Affine
   ↓
Homography
```

A more complex model should not automatically be considered better.

---

# 17. Translation

Translation represents:

```text
x shift
y shift
```

Use when the subject and camera geometry are otherwise stable.

---

# 18. Rotation

Estimate:

```text
θ
```

Rotation should be expressed in degrees for user-facing guidance.

Example:

```text
Rotate left 2.1°
```

---

# 19. Scale

Estimate relative scale:

```text
scale = target_subject_size / reference_subject_size
```

User-facing guidance:

```text
Move closer
```

or:

```text
Move farther away
```

should normally be preferred over exposing numerical scale to the user.

---

# 20. Perspective

Perspective differences occur when the camera viewpoint changes.

The system may estimate perspective using:

```text
homography
```

where sufficient reliable correspondences exist.

However, a homography should not be interpreted as proof that the photograph has clinically identical geometry.

---

# 21. Homography

Represent a projective transformation as:

```text
H =
[h11 h12 h13
 h21 h22 h23
 h31 h32 h33]
```

The matrix should be normalized as required by the chosen implementation.

Store the transformation in the alignment record.

---

# 22. Homography Acceptance

A homography should only be accepted when:

- sufficient inliers exist
- spatial distribution is reasonable
- reprojection error is acceptable
- transformation is not degenerate
- scale is within plausible limits
- perspective is not excessively unstable

Thresholds must be established experimentally.

---

# 23. Spatial Distribution

A major failure mode is having all feature matches concentrated in one small region.

The system should evaluate the spatial spread of inliers.

Preferred:

```text
┌───────────────┐
│ •       •     │
│               │
│    •      •   │
│               │
│ •         •   │
└───────────────┘
```

Avoid relying on:

```text
┌───────────────┐
│               │
│ • • • • •     │
│               │
│               │
└───────────────┘
```

when that distribution cannot constrain the intended transformation reliably.

---

# 24. Template Matching

For low-feature clinical regions, template matching may supplement feature matching.

Examples:

- relatively stable body-region shape
- predefined framing
- known protocol
- visible marker

Template matching should not be used blindly for moving/deforming anatomy.

---

# 25. Edge Matching

Edge maps may help when colour/texture changes but shape remains relatively stable.

Possible process:

```text
Image
 ↓
Grayscale
 ↓
Edge Detection
 ↓
Edge Registration
```

Edge matching is supplementary, not universally reliable.

---

# 26. Optical Flow

Optical flow may estimate local motion between:

```text
reference
```

and:

```text
current frame
```

It can help refine alignment after a coarse transformation.

It may be unsuitable when:

- lighting changes substantially
- anatomy deforms
- image texture is insufficient
- motion blur is high

---

# 27. Image Registration

The system may use image-registration techniques to refine alignment.

Possible objective:

```text
maximize similarity(reference, transformed_target)
```

Similarity metrics may include:

- normalized correlation
- structural similarity
- gradient similarity
- mutual-information-style approaches where appropriate

The chosen metric must be benchmarked on representative clinical images.

---

# 28. Subject Motion

The system must distinguish:

```text
camera movement
```

from:

```text
subject movement
```

This is particularly important for:

- limbs
- joints
- posture
- facial expression
- swelling
- wounds on moving body regions

The application should avoid claiming perfect alignment when the subject itself has changed position.

---

# 29. Deformable Anatomy

Some regions cannot be perfectly aligned using one rigid transformation.

Examples:

- facial expression
- abdomen
- muscle contraction
- joint position
- posture

The system should report reduced confidence rather than forcing a misleading alignment.

---

# 30. Alignment Confidence

Alignment confidence should combine multiple signals.

Conceptual model:

```text
Confidence =
  feature quality
+ inlier ratio
+ spatial distribution
+ reprojection error
+ transform stability
+ sensor agreement
+ image similarity
```

The exact mathematical weighting must be determined experimentally.

---

# 31. Confidence States

Recommended user-facing states:

```text
GOOD
FAIR
POOR
UNAVAILABLE
```

Optional score:

```text
Alignment 92%
```

The percentage is an internal/reproducibility score, not a clinical accuracy percentage.

---

# 32. Guidance Engine

The guidance engine converts CV results into simple actions.

Examples:

```text
Translation:
Move left
Move right
Move up
Move down

Scale:
Move closer
Move farther

Rotation:
Rotate slightly left
Rotate slightly right

Tilt:
Tilt device upward
Tilt device downward

Perspective:
Raise camera
Lower camera
Move directly in front

Orientation:
Rotate device
```

---

# 33. Guidance Priority

When multiple corrections are required, show the most useful one first.

Recommended priority:

```text
Orientation
 ↓
Large position error
 ↓
Large scale error
 ↓
Rotation
 ↓
Perspective
 ↓
Fine alignment
```

Avoid displaying too many simultaneous instructions.

---

# 34. Alignment Visual Overlay

Possible visual guidance:

- target frame
- reference contour
- ghost image
- centre marker
- directional arrows
- alignment ring
- status indicator

The overlay must remain subordinate to the photograph.

---

# 35. Ghost Overlay Integration

Ghost Overlay and automatic alignment are separate modules.

```text
Ghost Overlay
    ↓
Reference rendered at chosen opacity

Alignment Engine
    ↓
Calculates transformation/guidance
```

Both can be active simultaneously.

---

# 36. Manual Alignment

If automatic alignment fails, the user must be able to manually position the reference.

Controls:

- move
- scale
- rotate
- reset
- lock

Manual alignment must still permit capture.

---

# 37. Reference Lock

After the user is satisfied:

```text
LOCK
```

stores the current reference transform for the session.

Lock prevents accidental changes.

---

# 38. Capture Readiness

The system can calculate:

```text
capture_ready = true / false
```

Recommended conditions:

- orientation acceptable
- alignment above configured threshold
- image not severely blurred
- lighting not severely unsuitable
- camera available

These should normally be advisory.

---

# 39. Capture Anyway

If a warning exists:

```text
Alignment: Fair

[Capture Anyway]
```

The user can proceed.

The captured photograph should store the quality/alignment status.

---

# 40. Hard Thresholds

A hard capture block should only be enabled by a protocol or future explicitly defined requirement.

Example:

```text
Protocol requires alignment ≥ threshold
```

Without such a rule, WISE should prefer warnings rather than blocking capture.

---

# 41. Lighting Comparison

Lighting analysis should compare the reference and target using available image statistics.

Potential measurements:

- average luminance
- luminance distribution
- histogram characteristics
- highlight proportion
- shadow proportion
- colour balance
- exposure metadata
- flash state

---

# 42. Lighting Normalization

For alignment processing, the CV engine may normalize images to reduce sensitivity to lighting differences.

Examples:

- grayscale
- contrast normalization
- local normalization
- histogram-based normalization

Normalization must be used for processing only.

The original photograph remains unchanged.

---

# 43. Focus Quality

Focus/blur analysis may use:

- Laplacian variance
- edge sharpness
- camera focus state where available

The result should be stored as a quality check.

---

# 44. Blur Thresholds

Initial blur thresholds must be treated as provisional.

They must be tested against:

- different devices
- different resolutions
- clinical conditions
- skin texture
- wounds
- low-light images

Do not use one universal threshold without validation.

---

# 45. Region of Interest

Where possible, the alignment system should work with a relevant region rather than the entire image.

Possible ROI sources:

- manual crop
- protocol-defined framing
- detected body region
- reference frame
- landmark model

ROI detection should be optional.

---

# 46. Body-Region Assistance

Future on-device ML may identify:

- face
- hand
- knee
- shoulder
- back
- limb
- wound region

This can improve alignment robustness.

It must remain optional.

---

# 47. Marker-Based Alignment

A future protocol may support a visual calibration/alignment marker.

Possible workflow:

```text
Place marker
 ↓
Detect marker
 ↓
Estimate scale/orientation
 ↓
Estimate camera position
 ↓
Guide user
```

This may significantly improve reproducibility for controlled clinical photography.

---

# 48. Scale and Alignment Relationship

Scale calibration and alignment are related but distinct.

```text
Alignment:
Where and how the image is positioned

Calibration:
How image distance maps to physical units
```

An aligned photograph is not automatically physically calibrated.

---

# 49. Perspective and Measurement

Perspective differences can change apparent size.

Therefore:

```text
Alignment confidence ≠ measurement accuracy
```

A good alignment score must never be presented as proof that a centimetre measurement is accurate.

---

# 50. Comparison Registration

When a Before/After comparison is requested:

1. Load reference.
2. Load After.
3. Check stored alignment.
4. Reuse valid alignment.
5. Recalculate if necessary.
6. Generate comparison view.

The comparison engine should not silently discard existing valid alignment data.

---

# 51. Difference Image

Difference generation should occur after registration.

Conceptual pipeline:

```text
Before
   ↓
Alignment
   ↓
Transform
   ↓
Aligned Before
   ↓
Compare with After
   ↓
Difference
```

The resulting image is a visual aid only.

---

# 52. Alignment Record Storage

Store:

```text
alignment_id
reference_photo_id
target_photo_id
method
score
confidence
translation_x
translation_y
rotation
scale
transform_matrix
status
created_at
engine_version
```

The database structure is defined in the Data Model & Database Specification.

---

# 53. Engine Versioning

Every CV result should record the algorithm/engine version.

Example:

```text
engine_version = cv-1.0.0
```

This allows future reprocessing when algorithms improve.

---

# 54. Reproducibility Metadata

The system should retain:

- camera
- lens
- zoom
- orientation
- flash
- capture recipe
- alignment result
- calibration
- protocol

where available.

This metadata improves repeatability and future analysis.

---

# 55. Real-Time Processing

The live guidance engine should not require full-resolution processing on every frame.

Recommended architecture:

```text
Camera Preview
      ↓
Frame Sampling
      ↓
Low/Medium Resolution CV
      ↓
Guidance
```

Full-resolution processing occurs after capture when required.

---

# 56. Frame Sampling

The application may process only selected preview frames rather than every camera frame.

The target should be smooth enough to feel real-time without unnecessarily consuming:

- CPU
- GPU
- battery
- memory

Exact frame rate should be established through device testing.

---

# 57. Adaptive Processing

If device performance is limited:

```text
Reduce CV resolution
 ↓
Reduce processing frequency
 ↓
Use simpler algorithm
```

Do not sacrifice camera-preview responsiveness merely to maintain expensive CV processing.

---

# 58. Device Capability Tiers

Possible tiers:

### Tier A

High-performance modern devices:

- frequent CV updates
- feature matching
- optical flow
- richer guidance

### Tier B

Mid-range devices:

- reduced resolution
- less frequent matching
- simpler transforms

### Tier C

Low-performance devices:

- sensor guidance
- ghost overlay
- manual alignment
- post-capture analysis

All devices should retain core capture functionality.

---

# 59. Memory Management

The CV engine must:

- reuse buffers
- downsample preview frames
- release temporary images
- avoid duplicate full-resolution copies
- process asynchronously
- use thumbnails for browsing

Memory pressure must never cause loss of the original photograph.

---

# 60. Failure Conditions

Alignment may fail because of:

- insufficient features
- low texture
- blur
- lighting change
- occlusion
- subject movement
- large viewpoint change
- excessive perspective
- different body position
- camera/lens change
- image crop mismatch

---

# 61. Failure Response

Do not show technical errors such as:

> Homography matrix singular.

Instead show:

> Automatic alignment unavailable.

Then offer:

```text
Use Ghost Overlay
Manual alignment
Capture anyway
```

Technical details may be logged locally for development builds.

---

# 62. Algorithm Fallback Chain

Recommended:

```text
1. Sensor guidance
2. Feature matching
3. Robust geometric estimation
4. Template/edge matching
5. Optical-flow refinement
6. Optional ML assistance
7. Manual alignment
```

Not every step needs to run for every photograph.

---

# 63. Algorithm Selection Logic

Conceptual:

```text
if sensors_available:
    use sensor guidance

if sufficient_visual_features:
    estimate similarity/affine transform

if perspective evidence is strong:
    evaluate homography

if visual texture is weak:
    try template/edge approach

if confidence remains low:
    manual alignment

always:
    preserve ability to capture
```

The final implementation should optimize this flow through benchmarking.

---

# 64. Clinical Image Considerations

The system must be tested on:

- skin lesions
- wounds
- swelling
- bruising
- scars
- postoperative sites
- joint regions
- posture
- dental images
- varied skin tones
- low-texture skin
- hair-bearing areas
- bandages/dressings

The system should not assume that ordinary natural-image benchmarks represent clinical photography.

---

# 65. Test Dataset

Create a controlled internal dataset containing:

### Same capture

- same device
- same position
- same lighting

### Controlled changes

- translation
- rotation
- scale
- distance
- zoom
- tilt
- perspective

### Real-world variation

- lighting changes
- flash changes
- device changes
- lens changes
- subject movement
- partial occlusion
- different clinical conditions

---

# 66. Ground Truth Dataset

For quantitative testing, record known transformations.

Example:

```text
translation: +20 px
rotation: +3°
scale: 1.05
perspective: controlled
```

This allows comparison between estimated and known transformations.

---

# 67. Alignment Metrics

Measure:

- translation error
- rotation error
- scale error
- reprojection error
- inlier ratio
- confidence calibration
- false-positive alignment
- alignment failure rate
- processing latency
- memory use
- battery impact

---

# 68. Guidance Metrics

Test whether users can successfully achieve the target frame.

Measure:

```text
time to acceptable alignment
number of guidance actions
number of failed attempts
capture success rate
```

---

# 69. Quality Metrics

Lighting:

```text
brightness difference
histogram similarity
exposure difference
```

Focus:

```text
sharpness score
blur detection accuracy
```

The exact thresholds should be learned from the test dataset.

---

# 70. Acceptance Criteria

The CV engine is acceptable when:

1. It operates locally.
2. It does not require cloud connectivity.
3. It can process a selected Before image.
4. It can evaluate live frames.
5. It provides useful position guidance.
6. It provides useful scale guidance.
7. It provides useful rotation/orientation guidance.
8. It can estimate transformations on supported image classes.
9. It rejects obviously unreliable matches.
10. It supports manual fallback.
11. It never overwrites originals.
12. It records the algorithm version.
13. It records alignment results.
14. It remains responsive on representative devices.
15. Thresholds are validated experimentally.

---

# 71. What the System Must NOT Claim

The CV engine must not claim that:

- two images are medically identical
- alignment proves clinical equivalence
- a difference image represents disease progression
- a percentage score represents medical accuracy
- photographic measurement is clinically accurate without validation
- AI/CV can replace professional clinical judgment

---

# 72. Recommended V1 Algorithm Stack

A practical first implementation should start with:

```text
Device Orientation
        +
Ghost Overlay
        +
ORB/AKAZE-style feature detection
        +
Descriptor Matching
        +
RANSAC
        +
Similarity/Affine estimation
        +
Optional Homography
        +
Luminance/Histogram checks
        +
Laplacian-style focus check
```

Then benchmark whether optical flow, edge registration, or ML materially improves results.

Do not add expensive algorithms merely because they are technically available.

---

# 73. V1 Development Sequence

### Stage 1

Implement:

- reference loading
- preview processing
- orientation normalization
- ghost overlay

### Stage 2

Implement:

- feature detection
- descriptor matching
- robust matching
- translation/rotation/scale estimation

### Stage 3

Implement:

- alignment confidence
- user guidance
- capture warnings

### Stage 4

Implement:

- homography
- perspective handling
- edge/template fallback

### Stage 5

Implement:

- lighting check
- focus check

### Stage 6

Benchmark:

- devices
- body regions
- lighting
- clinical image types

### Stage 7

Only then evaluate:

- optical flow
- on-device ML

---

# 74. Flutter Architecture

The CV engine should be isolated behind an interface.

Conceptually:

```text
Flutter UI
    ↓
AlignmentController
    ↓
AlignmentService
    ↓
CV Engine Interface
    ↓
Native/OpenCV/Platform Implementation
```

The Flutter layer should not contain platform-specific CV implementation details.

---

# 75. CV Service Interface

Conceptual API:

```dart
abstract class AlignmentEngine {
  Future<ReferenceFeatures> prepareReference(
    ImageFrame reference,
  );

  Future<AlignmentResult> analyzeFrame(
    ImageFrame frame,
    ReferenceFeatures reference,
  );

  Future<AlignmentResult> align(
    ImageFrame reference,
    ImageFrame target,
  );
}
```

Actual implementation can use platform-native libraries or a shared native CV layer.

---

# 76. Alignment Result

Conceptual object:

```text
AlignmentResult
├── status
├── confidence
├── translation
├── rotation
├── scale
├── perspective
├── transform
├── guidance
├── metrics
└── engineVersion
```

---

# 77. Separation of Concerns

Do not combine:

```text
CV calculation
```

with:

```text
UI decision
```

For example:

CV engine:

```text
rotation = -2.4°
```

Guidance engine:

```text
Rotate slightly right
```

UI:

```text
Show instruction
```

This allows the CV engine to be reused by future WISE products.

---

# 78. Security and Privacy

CV processing should happen locally by default.

No image should be transmitted externally for alignment.

If a future external AI/CV service is added:

1. user must explicitly enable it
2. privacy implications must be disclosed
3. transmission must be secured
4. processing status must be visible
5. original image must remain under application control

---

# 79. Logging

Development builds may log:

- algorithm selected
- number of keypoints
- number of matches
- number of inliers
- transform
- confidence
- processing time

Production logs must avoid unnecessary sensitive image information.

Do not log image pixels or clinical image contents.

---

# 80. Final Architecture

```text
                    BEFORE PHOTO
                         │
                         ▼
                Reference Preparation
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Metadata       Features       Geometry
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                 Reference Model
                         │
                         ▼
                 LIVE CAMERA FRAME
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Sensors       Feature CV      Quality
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                Transformation
                         │
                         ▼
                 Confidence Engine
                         │
                         ▼
                 Guidance Engine
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
          READY                   WARNING
             │                       │
             └───────────┬───────────┘
                         ▼
                       CAPTURE
                         │
                         ▼
                 Alignment Record
                         │
                         ▼
                  After Photograph
```

---

# 81. Final Principle

The WISE Clinical Camera alignment system should be **practical rather than magical**.

Its goal is not to claim that computer vision can make two clinical photographs mathematically identical.

Its goal is to make the user consistently achieve:

```text
same orientation
+
same framing
+
same scale
+
same position
+
similar viewpoint
+
similar lighting
+
sufficient focus
```

with the least possible effort.

When automatic vision is confident, it should quietly guide the user.

When it is uncertain, it should say so.

When it fails, the photograph must still be possible.

That behaviour is essential to making WISE Clinical Camera dependable in real clinical workflows.
