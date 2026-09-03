# WISE Clinical Camera
## Technical Architecture Document v1.0

**Related product:** WISE Clinical Camera  
**Related PRD:** WISE Clinical Camera PRD v1.0  
**Primary platforms:** iOS and Android  
**Primary architecture:** Offline-first, local-first, modular  
**Primary engineering objective:** Reproducible clinical photography at the lowest practical operating cost

---

# 1. Architecture Goals

The architecture must support:

1. Fast camera startup.
2. Reliable photography on iOS and Android.
3. Before, After and Photo capture modes.
4. Persistent optional camera add-ons.
5. Reference-image ghost overlay.
6. Live Before/After alignment guidance.
7. Lighting and focus checks.
8. Physical-scale calibration.
9. Length, width, perimeter and area measurement.
10. Non-destructive annotations.
11. Before/After comparison.
12. Gallery export.
13. Offline operation.
14. Privacy-first local storage.
15. Optional AI without making AI a core dependency.
16. Future cloud synchronization without redesigning the entire application.
17. Low development and operating cost.
18. A modular architecture that can later be reused by other WISE applications.

---

# 2. Recommended High-Level Architecture

The recommended architecture is:

```text
                    WISE CLINICAL CAMERA
                             |
                    ┌────────┴────────┐
                    |   UI / UX Layer |
                    └────────┬────────┘
                             |
                    Application Layer
                             |
          ┌──────────────────┼──────────────────┐
          |                  |                  |
     Capture Engine     Reference Engine   Tool Manager
          |                  |                  |
          ├──────────────┐   |   ┌──────────────┤
          |              |   |   |              |
      Camera HAL     Sensor HAL | Measurement  Annotation
          |              |      |              |
          └──────────────┴──────┴──────────────┘
                             |
                    Image Processing Layer
                             |
          ┌──────────────────┼──────────────────┐
          |                  |                  |
     Vision Engine      Quality Engine     Comparison Engine
          |                  |                  |
          └──────────────────┼──────────────────┘
                             |
                    Local Data Layer
                             |
          ┌──────────────────┼──────────────────┐
          |                  |                  |
       SQLite          File Storage       Secure Metadata
          |
          └──────────────────────┐
                                 |
                         Optional Services
                                 |
                 ┌───────────────┼───────────────┐
                 |               |               |
              Cloud Sync      Optional AI     Backup
```

The important principle is that **the camera and core computer-vision system do not depend on the cloud**.

---

# 3. Recommended Technology Direction

## 3.1 Cross-platform framework

### Recommended first choice: Flutter

Reasons:

- One primary codebase for iOS and Android.
- Strong UI consistency.
- Good support for custom camera interfaces.
- Good performance for image-heavy workflows.
- Suitable for offline applications.
- Mature ecosystem.
- Can integrate native iOS/Android camera functionality where necessary.
- Good fit for a modular WISE application family.

### Alternative: React Native

React Native remains a valid alternative, especially if the development team already has strong TypeScript/React expertise.

However, for this application, Flutter is the preferred baseline because the product needs a highly controlled visual camera interface and substantial native image-processing integration.

---

# 4. Native Platform Boundary

The application should use Flutter for most product functionality but maintain a clean native boundary.

```text
Flutter
   |
   +-- UI
   +-- Navigation
   +-- State
   +-- Settings
   +-- Database abstraction
   +-- Image workflow
   |
   +-- Native platform bridge
           |
           +-- iOS camera APIs
           +-- Android camera APIs
           +-- Sensors
           +-- Photo library
           +-- File system
           +-- Native image processing where needed
```

The native bridge should only be used where platform-specific functionality is required.

---

# 5. Camera Architecture

The camera is the central subsystem.

Required capabilities:

- rear camera
- front camera where appropriate
- preview
- still image capture
- zoom
- focus
- exposure
- flash
- orientation
- lens selection where supported
- camera switching
- image dimensions
- capture metadata
- device sensor integration

The camera layer should expose a platform-independent interface to the application.

Example conceptual API:

```text
CameraService
 ├── initialize()
 ├── startPreview()
 ├── stopPreview()
 ├── capture()
 ├── setZoom()
 ├── setFocus()
 ├── setExposure()
 ├── setFlash()
 ├── switchCamera()
 └── getCameraMetadata()
```

The exact implementation should be selected based on the final Flutter camera stack and platform capabilities during development.

---

# 6. Camera Capability Detection

Different devices have different capabilities.

At application startup, WISE should detect:

- available cameras
- supported resolutions
- zoom range
- optical/digital lenses
- flash availability
- autofocus availability
- exposure controls
- orientation sensors
- depth capability where available
- device-specific restrictions

The application must never assume that every device supports every feature.

Unsupported functionality should gracefully disappear or be marked unavailable.

---

# 7. Image Capture Pipeline

Recommended pipeline:

```text
Camera Preview
      |
      v
Quality Pre-check
      |
      v
Capture Original
      |
      v
Immutable Original File
      |
      +----> Metadata
      |
      +----> Processing Pipeline
      |
      +----> Thumbnail
      |
      +----> WISE Database Record
```

The original image should be stored before any destructive processing.

---

# 8. Original Image Principle

The original capture is immutable.

Never modify the original photograph.

All transformations create derived assets.

Example:

```text
photo_001_original.jpg
photo_001_preview.jpg
photo_001_annotated.jpg
photo_001_measurement.jpg
photo_001_comparison.jpg
photo_001_export.jpg
```

The database should maintain relationships between the derived files and the original.

---

# 9. Reference Image Engine

The Reference Engine is responsible for:

- selecting a Before photograph
- importing an external reference
- displaying the reference
- applying opacity
- transforming the reference
- locking/unlocking
- storing transformation state

Reference state:

```text
ReferenceState
 ├── photoId
 ├── opacity
 ├── scale
 ├── rotation
 ├── translationX
 ├── translationY
 ├── flipX
 ├── flipY
 └── locked
```

---

# 10. Ghost Overlay

The live camera preview and reference image are rendered as two synchronized layers.

Conceptually:

```text
┌─────────────────────────────┐
│                             │
│     LIVE CAMERA             │
│                             │
│    + REFERENCE IMAGE        │
│      opacity = 50%          │
│                             │
└─────────────────────────────┘
```

The overlay must have minimal latency.

It should not require uploading the camera stream to a server.

---

# 11. Alignment Engine

The Alignment Engine determines how closely the current camera composition matches the reference.

It should operate in stages.

## Stage 1: Device orientation

Use:

- gyroscope
- accelerometer
- orientation APIs

to estimate:

- roll
- pitch
- orientation

## Stage 2: Image geometry

Compare:

- feature points
- edges
- dominant contours
- subject position
- reference scale
- image rotation

## Stage 3: Perspective

Where possible, estimate perspective transformation.

## Stage 4: Confidence

Produce a normalized alignment score.

Example:

```text
Angle       96
Position    94
Scale       91
Rotation    99
Framing     95

Overall     95
```

The exact scoring algorithm must be validated experimentally rather than assumed.

---

# 12. Alignment Algorithms

The implementation should prefer inexpensive local computer vision.

Possible techniques:

- feature detection
- feature descriptors
- feature matching
- optical flow
- homography estimation
- edge maps
- template matching
- image registration
- structural similarity
- perspective transformation

The final algorithm should be selected after testing against real clinical photography examples.

AI should not be used merely because it is available.

---

# 13. Alignment Guidance

The user should receive simple actionable instructions.

Examples:

- Move left
- Move right
- Move closer
- Move farther
- Tilt upward
- Tilt downward
- Rotate slightly
- Centre subject
- Reduce perspective difference

Avoid displaying complex technical information to normal users.

Advanced diagnostic information can be available in an optional details panel.

---

# 14. Alignment Threshold

The system should define a configurable acceptance threshold.

Example:

```text
0–69     Poor
70–84    Acceptable
85–94    Good
95–100   Excellent
```

These numbers are placeholders for engineering validation.

The final thresholds must be determined from testing.

The application should allow:

- capture at any alignment
- warning before capture
- hard threshold in selected protocols

Default behaviour should be non-blocking.

---

# 15. Lighting Analysis Engine

The lighting engine operates locally.

Potential measurements:

- average luminance
- luminance distribution
- histogram
- highlight clipping
- shadow clipping
- colour temperature approximation
- white-balance difference
- flash state
- illumination direction where measurable

Output:

```text
Lighting
✓ Similar

or

Lighting
⚠ 18% brighter than reference
```

The exact wording and thresholds should be calibrated during testing.

---

# 16. Focus and Blur Engine

Possible local techniques:

- Laplacian variance
- edge sharpness
- high-frequency energy
- autofocus state where available

Output:

```text
Focus
✓ Good
```

or:

```text
Focus
⚠ Possible blur
```

No cloud processing is required.

---

# 17. Measurement Engine

Measurement must be based on calibrated image geometry.

The engine should support:

```text
Point → Point
Point → Point → Point
Closed Polygon
Freehand Region
Circle / Ellipse
```

Outputs:

- length
- width
- diameter
- perimeter
- area

---

# 18. Calibration Engine

Calibration establishes:

```text
pixels per physical unit
```

Example:

```text
Known reference = 50 mm
Measured image distance = 420 pixels

Scale = 8.4 pixels/mm
```

The exact implementation should account for perspective where necessary.

---

# 19. Calibration Methods

Supported methods:

### Ruler calibration

User photographs a physical ruler.

### Calibration marker

Known-size marker/card.

### Manual calibration

User identifies a known length.

### Future advanced calibration

Depth-aware or multi-plane calibration where supported by device hardware.

The system must record:

- calibration method
- known physical length
- pixel measurement
- calibration date/time
- reference area
- confidence/quality

---

# 20. Perspective Limitation

A scale reference on a plane does not automatically provide accurate measurements for objects at a different depth or plane.

Therefore:

> WISE measurements should be treated as photographic measurements unless the capture geometry supports the required accuracy.

The application must not claim clinical measurement accuracy beyond what the calibration method supports.

---

# 21. Measurement Layer

Measurements must be stored separately from the image.

Example:

```text
Measurement
 ├── id
 ├── photoId
 ├── type
 ├── points
 ├── calibrated
 ├── value
 ├── unit
 ├── label
 └── style
```

---

# 22. Annotation Engine

Annotations are vector objects stored independently.

Supported objects:

- line
- arrow
- circle
- rectangle
- polygon
- freehand
- text
- measurement

This allows:

- editing
- hiding
- moving
- resizing
- exporting

without altering the original.

---

# 23. Comparison Engine

The Comparison Engine accepts:

```text
Before Image
After Image
```

and produces:

- side-by-side
- slider
- overlay
- blink
- difference visualization

The comparison engine should use the alignment data already generated rather than independently reinventing alignment.

---

# 24. Difference Visualization

Difference mode can use:

- absolute pixel difference
- normalized difference
- structural similarity difference
- aligned image subtraction

However, the UI must warn:

> Differences can result from changes in lighting, camera position, focus and other photographic conditions. This view is not a medical diagnostic tool.

---

# 25. Add-on / Tool Architecture

Tools should be modular.

Conceptual interface:

```text
Tool
 ├── id
 ├── name
 ├── enabled
 ├── persistent
 ├── applicableModes
 └── configuration
```

Examples:

```text
overlay
alignment
lighting
focus
grid
level
measurement
annotation
comparison
difference
footer
```

The Tool Manager determines which tools are active.

---

# 26. Persistent Preferences

Preferences should be stored locally.

Example:

```text
UserPreferences
 ├── overlayEnabled
 ├── alignmentEnabled
 ├── lightingEnabled
 ├── focusEnabled
 ├── gridEnabled
 ├── levelEnabled
 ├── measurementEnabled
 ├── annotationEnabled
 ├── differenceEnabled
 └── comparisonMode
```

If user accounts are introduced later, these preferences can optionally synchronize.

---

# 27. Temporary Overrides

Persistent preferences must be separate from session overrides.

```text
User Default
     +
Session Override
     =
Effective Setting
```

Example:

```text
Default:
Measurement = ON

Session:
Measurement = OFF

Effective:
Measurement = OFF
```

The default remains ON.

---

# 28. Capture Protocol Architecture

Protocols are saved configurations.

Example:

```text
Protocol
 ├── id
 ├── name
 ├── tools
 ├── cameraDefaults
 ├── qualityRules
 ├── exportRules
 └── version
```

A protocol can specify:

- active add-ons
- preferred camera settings
- required orientation
- measurement requirement
- alignment threshold
- lighting requirement
- export layout

---

# 29. Local Storage Architecture

Recommended conceptual storage:

### SQLite

For:

- cases
- photographs
- references
- protocols
- measurements
- annotations
- preferences
- metadata

### File system

For:

- original images
- thumbnails
- derived images
- comparison exports

Do not store large original photographs directly as database BLOBs unless there is a compelling implementation reason.

---

# 30. Database Relationship

Conceptual structure:

```text
User
 |
 +-- Preferences
 |
 +-- Protocols
 |
 +-- Cases
       |
       +-- Photos
              |
              +-- Reference
              +-- Measurements
              +-- Annotations
              +-- Derived Assets
```

A standalone photograph may exist without a Case.

---

# 31. Suggested Core Entities

## User

- id
- preferences
- createdAt

## Case

- id
- optional name
- optional external identifier
- createdAt
- updatedAt

## Photo

- id
- caseId
- type
- filePath
- originalFilePath
- capturedAt
- bodyPart
- laterality
- metadata
- referencePhotoId
- protocolId

## Calibration

- id
- photoId
- method
- knownLength
- unit
- pixelLength
- confidence

## Measurement

- id
- photoId
- type
- coordinates
- value
- unit

## Annotation

- id
- photoId
- type
- geometry
- text
- style

## Protocol

- id
- name
- configuration
- version

---

# 32. File Naming

Files should use non-identifying internal IDs.

Example:

```text
photo_<uuid>_original.jpg
photo_<uuid>_thumb.jpg
photo_<uuid>_export.jpg
```

Do not put patient names, diagnoses or other sensitive information into filenames by default.

---

# 33. Security

Local application data should be protected using platform security mechanisms.

Requirements:

- encrypted sensitive database fields where appropriate
- protected local storage
- platform keychain/keystore for secrets
- no hard-coded credentials
- no patient information in logs
- no image content in crash reports
- secure deletion workflows where technically appropriate

---

# 34. Privacy Architecture

Default principle:

> The photograph stays on the device.

No image should be uploaded unless the user explicitly enables a feature that requires it.

Cloud AI should be opt-in.

Cloud synchronization should be opt-in.

Analytics should avoid collecting image content.

---

# 35. Gallery Permissions

The application must request only the permissions required.

iOS and Android permission flows must be handled separately.

The app should explain why Gallery access is needed.

If the user denies permission:

- WISE capture should continue
- local WISE storage should continue where permitted
- Gallery export should display a clear explanation

---

# 36. Offline Architecture

Core functionality must not depend on:

- Internet
- cloud authentication
- remote API
- AI API
- external database

The application should function in airplane mode.

Optional services can synchronize later.

---

# 37. Sync-Ready Design

Even if cloud synchronization is not implemented in V1, the local data model should use stable IDs.

Example:

```text
UUID
createdAt
updatedAt
deletedAt
syncStatus
```

This allows future:

```text
Device
   ↕
Cloud
   ↕
Other Device
```

without redesigning every entity.

---

# 38. Conflict Handling

Future synchronization should use explicit conflict rules.

Examples:

- latest metadata update
- immutable original files
- append-only derived assets
- versioned annotations
- protocol versioning

Original photographs should never be silently replaced.

---

# 39. AI Boundary

AI should exist behind an abstraction.

Example:

```text
AIService
 ├── detectBodyPart()
 ├── detectLandmarks()
 ├── assessPhotoQuality()
 ├── describeImage()
 └── extractDocumentText()
```

The application should be able to provide:

```text
No AI provider
Local AI provider
Self-hosted AI provider
Cloud AI provider
```

without changing the main camera workflow.

---

# 40. AI Cost Strategy

Priority order:

1. No AI where normal algorithms work.
2. Device sensors.
3. Classical computer vision.
4. On-device ML.
5. Self-hosted models.
6. Low-cost cloud APIs only where justified.

Every AI feature should have a non-AI fallback where practical.

---

# 41. Performance Requirements

Target:

- camera launch should feel immediate
- preview should remain smooth
- overlay latency should be low enough for real-time positioning
- image processing should occur asynchronously
- UI should never freeze while processing a large image
- thumbnails should be generated separately
- large images should be processed using memory-efficient pipelines

Exact numerical performance targets should be finalized during device testing.

---

# 42. Memory Management

High-resolution clinical photographs can consume substantial memory.

Requirements:

- avoid loading multiple full-resolution copies unnecessarily
- use thumbnails for galleries
- process images in bounded memory
- release camera resources when leaving capture
- use background/isolate processing where appropriate
- handle low-memory conditions gracefully

---

# 43. Export Architecture

Exports should be generated from:

```text
Original
+
Selected layers
+
Comparison configuration
+
Footer configuration
```

Export presets:

- Original
- Annotated
- Measured
- Before + After
- Before + After + Measurements
- Anonymized
- Report-ready

---

# 44. Export Resolution

The application should preserve the maximum practical resolution of the original unless the user selects a reduced-size export.

Options may include:

- Original resolution
- High quality
- Standard
- Compact

The original must remain available.

---

# 45. Logging

Logs must be designed for debugging without exposing clinical information.

Never log:

- patient names
- photograph pixels
- diagnoses
- identifiable image metadata
- credentials

Use:

- anonymous device/session IDs
- feature state
- error codes
- performance timings

---

# 46. Error Handling

Every subsystem must fail gracefully.

Examples:

### Camera unavailable

> Camera unavailable. Check device permissions.

### Gallery denied

> Gallery access is disabled. You can continue using WISE storage.

### Alignment unavailable

> Automatic alignment is unavailable on this device. Ghost Overlay remains available.

### Calibration missing

> Add a scale reference before measuring in centimetres.

### AI unavailable

> AI assistance is unavailable. Core photography continues normally.

---

# 47. Accessibility

The application should support:

- readable text
- sufficient contrast
- large touch targets
- VoiceOver
- TalkBack
- dynamic text where practical
- clear non-colour-only status indicators

Critical camera guidance must not depend solely on colour.

For example:

**✓ Good**

rather than a green dot alone.

---

# 48. Architecture Modularity

Recommended module structure:

```text
core/
  camera/
  imaging/
  sensors/
  storage/
  security/

features/
  capture/
  reference/
  alignment/
  lighting/
  focus/
  measurement/
  calibration/
  annotation/
  comparison/
  export/
  protocols/
  settings/

services/
  ai/
  sync/

ui/
  screens/
  widgets/
  themes/
```

Exact repository naming can be adapted to the chosen framework.

---

# 49. Testing Architecture

Testing should exist at several levels.

## Unit tests

- measurement calculations
- calibration calculations
- preference resolution
- protocol loading
- metadata parsing
- comparison calculations

## Integration tests

- capture → storage
- reference → overlay
- calibration → measurement
- Before → After → comparison
- export workflows

## Device tests

- iPhone models
- Android devices
- different screen sizes
- different camera capabilities

---

# 50. Computer Vision Test Dataset

A controlled internal test dataset should be created for development.

It should contain examples of:

- same angle
- different angle
- same distance
- different distance
- different zoom
- different lighting
- shadows
- rotation
- perspective changes
- different devices
- different body regions
- skin tones and varied clinical photography conditions

This dataset is for validating the photography engine, not for making diagnostic claims.

---

# 51. Measurement Validation

Measurement must be validated using physical objects with known dimensions.

Test:

- 1 cm
- 5 cm
- 10 cm
- larger distances
- different image resolutions
- different angles
- different calibration methods

Report:

- measured value
- expected value
- absolute error
- percentage error

Do not claim an accuracy level until this testing is completed.

---

# 52. Alignment Validation

Create a test protocol where the same subject is photographed repeatedly.

Measure:

- translation error
- rotation error
- scale error
- perspective error
- lighting difference
- successful capture rate

The engineering team should determine practical acceptance thresholds from actual data.

---

# 53. Device Compatibility Strategy

Use a capability matrix rather than assuming identical functionality.

Example:

| Capability | iOS | Android |
|---|---|---|
| Camera | Required | Required |
| Orientation | Required | Required |
| Gallery export | Required | Required |
| Zoom | Device-dependent | Device-dependent |
| Flash | Device-dependent | Device-dependent |
| Depth | Optional | Optional |
| Advanced lens data | Device-dependent | Device-dependent |

---

# 54. Recommended Development Sequence

## Sprint/Stage 1

Create:

- project
- navigation
- camera
- local storage
- Before
- After
- Photo

## Stage 2

Add:

- reference selection
- ghost overlay
- opacity
- transformation
- reference lock

## Stage 3

Add:

- orientation
- grid
- level
- focus
- lighting

## Stage 4

Add:

- alignment engine
- scoring
- guidance

## Stage 5

Add:

- calibration
- measurement
- annotation

## Stage 6

Add:

- comparison
- export
- anonymization

## Stage 7

Add:

- protocols
- persistent tools
- temporary overrides

## Stage 8

Add optional AI.

---

# 55. Technology Cost Principles

The product should avoid recurring costs wherever possible.

### Prefer

- Flutter
- SQLite
- local filesystem
- native device APIs
- open-source computer vision
- on-device processing
- local ML where practical

### Avoid for V1

- mandatory cloud backend
- paid AI on every photograph
- remote image-processing pipeline
- unnecessary third-party SaaS
- expensive analytics platforms
- mandatory authentication infrastructure

---

# 56. Future Cloud Architecture

Cloud should be an extension:

```text
                    DEVICE
                      |
              Local WISE Database
                      |
              Optional Sync Layer
                      |
               Secure API
                      |
        ┌─────────────┼─────────────┐
        |             |             |
     Storage       Database       AI
```

Possible future services:

- encrypted backup
- multi-device synchronization
- team sharing
- case collaboration
- centralized protocols
- AI processing
- reporting

None should be required by the core camera.

---

# 57. Future WISE Platform Reuse

The camera engine should eventually be reusable by other WISE applications.

Potential consumers:

- dermatology
- wound documentation
- physiotherapy
- rehabilitation
- posture assessment
- swelling documentation
- dental photography
- general clinical records
- educational case documentation

Therefore the camera engine should be treated as a reusable WISE platform component rather than hard-coded specifically for dermatology.

---

# 58. Architectural Non-Goals

The architecture should not initially attempt to build:

- autonomous diagnosis
- disease classification
- treatment recommendations
- automated clinical decision making
- mandatory cloud infrastructure
- enterprise hospital management
- universal medical measurement certification

These can be considered separately in future products.

---

# 59. Key Engineering Risks

## Risk 1 — Camera differences

Different devices produce different images.

**Mitigation:** capability detection and device testing.

## Risk 2 — Alignment accuracy

No single algorithm will work perfectly for every body part.

**Mitigation:** combine overlay, sensors and local computer vision. Always provide manual control.

## Risk 3 — Measurement accuracy

Photographic perspective can invalidate naive centimetre calculations.

**Mitigation:** explicit calibration and accuracy warnings.

## Risk 4 — Memory pressure

High-resolution photographs can cause mobile memory issues.

**Mitigation:** streaming/efficient image processing and thumbnails.

## Risk 5 — Privacy

Clinical photographs are sensitive.

**Mitigation:** local-first architecture and explicit cloud/AI opt-in.

## Risk 6 — Feature overload

Too many controls could make the camera difficult to use.

**Mitigation:** persistent optional add-ons and a clean basic camera.

---

# 60. Architecture Decision Summary

| Decision | Direction |
|---|---|
| Primary framework | Flutter preferred |
| Platforms | iOS + Android |
| Storage | Local filesystem + SQLite |
| Network dependency | None for core camera |
| Camera | Native capability through cross-platform abstraction |
| Computer vision | Local first |
| AI | Optional |
| Cloud | Optional future extension |
| Original images | Immutable |
| Measurements | Separate layer |
| Annotations | Separate layer |
| Add-ons | Modular |
| Preferences | Persistent per user |
| Overrides | Temporary per capture |
| Protocols | Reusable |
| Privacy | Local-first |
| Export | Local |
| Authentication | Not required for basic V1 |
| Cost strategy | Minimize recurring services |

---

# 61. Architecture Acceptance Criteria

The architecture is considered ready for implementation when:

1. A single codebase can support the core iOS and Android workflows.
2. Core photography works without Internet.
3. Original images remain immutable.
4. Before images can become references for After capture.
5. Reference overlay works in real time.
6. Add-ons can be independently enabled or disabled.
7. Add-on defaults persist across sessions.
8. Per-capture overrides do not alter defaults.
9. Alignment can operate locally.
10. Measurement requires valid calibration for physical units.
11. Measurements and annotations remain non-destructive.
12. Comparison modes can reuse stored alignment information.
13. Gallery saving is optional.
14. Cloud and AI are not required for core functionality.
15. Future cloud synchronization can be added without replacing the local data model.
16. The camera engine can eventually be reused by other WISE applications.

---

# 62. Final Architecture Principle

The most important architectural decision is:

> **Build WISE Clinical Camera as a local clinical photography engine first, and add AI, cloud synchronization and advanced services around it later.**

The camera, image alignment, measurement, annotation and comparison capabilities should remain useful even if:

- there is no Internet,
- there is no cloud account,
- there is no AI provider,
- the user has an older supported device.

This keeps the product inexpensive, resilient, privacy-conscious and reusable across the wider WISE software ecosystem.
