# WISE Clinical Camera
## Functional Specification v1.0

**Product:** WISE Clinical Camera  
**Related documents:**  
- WISE Clinical Camera PRD v1.0
- WISE Clinical Camera Technical Architecture v1.0
- WISE Clinical Camera UX/UI Specification v1.0
- WiseAiTechs Design MD System

**Platforms:** iOS and Android  
**Primary modes:** BEFORE / AFTER / PHOTO  
**Architecture:** Offline-first, privacy-first, modular  
**Core principle:** Help the user reproduce the same photograph over time.

---

# 1. Purpose

This Functional Specification defines the exact functional behaviour of WISE Clinical Camera.

It converts the product and UX requirements into implementable requirements covering:

- camera capture
- Before/After workflows
- reference images
- ghost overlay
- alignment
- lighting
- focus
- grid
- level
- measurement
- calibration
- annotation
- comparison
- saving
- Gallery export
- persistent add-ons
- protocols
- privacy
- offline behaviour
- error handling
- acceptance criteria

This document is intended to be usable by a software developer or coding agent such as Claude Code.

---

# 2. Product Behaviour Model

The application has three primary capture modes:

```text
BEFORE
AFTER
PHOTO
```

Advanced functionality is implemented as optional add-ons.

```text
Core Camera
   +
Optional Tools
   +
Optional Protocol
   =
Capture Workflow
```

The application must remain functional when all optional tools are OFF.

---

# 3. Functional Requirement IDs

Requirements use the following prefixes:

| Prefix | Area |
|---|---|
| CAM | Camera |
| MOD | Capture modes |
| REF | Reference image |
| OVR | Ghost overlay |
| ALG | Alignment |
| LGT | Lighting |
| FOC | Focus |
| GRD | Grid |
| LVL | Level |
| CAL | Calibration |
| MES | Measurement |
| ANN | Annotation |
| CMP | Comparison |
| SAV | Saving |
| EXP | Export |
| SET | Settings |
| PRO | Protocols |
| CAS | Cases |
| PRI | Privacy |
| OFF | Offline |
| AI | AI |
| ERR | Errors |
| DAT | Data |
| TST | Testing |

---

# 4. Camera Requirements

## CAM-001 Camera Initialization

When the user enters a capture workflow, WISE shall initialize the selected camera.

The application shall:

1. Detect available cameras.
2. Detect supported camera capabilities.
3. Request camera permission if required.
4. Start preview.
5. Apply the effective user/protocol settings.

If the camera is unavailable, the application shall show a clear error.

---

## CAM-002 Camera Selection

Where supported, the user shall be able to select:

- rear camera
- front camera

The default should favour the rear camera for clinical photography.

---

## CAM-003 Zoom

The application shall expose zoom where supported.

WISE shall remember the relevant capture information for Before/After matching.

If the reference photograph has known zoom information, the After workflow should guide the user toward matching it.

---

## CAM-004 Flash

The application shall support available flash modes.

Where technically possible, the selected flash state shall be stored with the photograph.

When capturing an After image, WISE should indicate whether the flash state differs from the reference.

---

## CAM-005 Orientation

WISE shall detect device orientation.

Supported states may include:

- portrait
- landscape

The After workflow should guide the user to reproduce the reference orientation.

---

## CAM-006 Focus

Where camera APIs permit, WISE shall support autofocus and/or focus state detection.

---

# 5. Capture Modes

## MOD-001 Before Mode

Selecting BEFORE shall start a reference-capture workflow.

The user may optionally specify:

- body part
- laterality
- protocol
- case

All metadata fields remain optional.

---

## MOD-002 After Mode

Selecting AFTER shall require a reference image.

The user shall be able to select a Before image from:

- WISE library
- device Gallery
- Files
- case
- recent Before images

---

## MOD-003 Photo Mode

PHOTO shall provide ordinary image capture without requiring a reference.

---

# 6. Before Workflow

## MOD-010 Before Capture

Workflow:

```text
Before
→ Optional metadata
→ Optional protocol
→ Camera
→ Optional tools
→ Capture
→ Review
→ Save
```

---

## MOD-011 Reference Creation

After a successful Before capture, the photograph shall be eligible as a reference image.

The system shall store a unique photo ID.

---

## MOD-012 Before Metadata

Optional metadata:

- body part
- laterality
- case ID
- protocol
- capture date/time

Metadata must not be required to complete the photograph.

---

# 7. After Workflow

## MOD-020 Select Reference

The user shall select a reference photograph before the After camera starts.

---

## MOD-021 Reference Preparation

WISE shall load:

- reference image
- available capture metadata
- reference transformation
- calibration information if present
- protocol information if applicable

---

## MOD-022 After Camera

The After camera shall display the live camera feed.

If enabled, the reference shall appear as a ghost overlay.

If enabled, alignment analysis shall run against the reference.

---

## MOD-023 After Capture

The user shall be able to capture even when non-critical warnings are present.

The system may prevent capture only when a deliberately configured protocol specifies a hard requirement.

---

# 8. Ghost Overlay

## OVR-001 Enable/Disable

Ghost Overlay shall be an optional persistent tool.

---

## OVR-002 Opacity

The user shall be able to adjust reference opacity.

Recommended range:

```text
10% → 100%
```

The exact UI range can be adapted during implementation.

---

## OVR-003 Transform

The reference shall support:

- translation
- scaling
- rotation
- horizontal flip
- vertical flip if required

---

## OVR-004 Reset

A RESET action shall return the reference transformation to the initial state.

---

## OVR-005 Lock

The user shall be able to lock the reference.

When locked:

- translation disabled
- scaling disabled
- rotation disabled
- flip disabled

Unlock restores editing.

---

## OVR-006 Live Rendering

The overlay must be rendered over the live camera preview without requiring cloud processing.

---

# 9. Alignment

## ALG-001 Enable/Disable

Alignment shall be an optional persistent tool.

---

## ALG-002 Alignment Inputs

Where available, the engine may use:

- camera orientation
- accelerometer
- gyroscope
- image features
- image edges
- subject position
- scale
- perspective
- framing

---

## ALG-003 Alignment Output

The engine shall provide individual status values for:

- angle
- position
- scale
- rotation
- framing

---

## ALG-004 User Guidance

The application shall provide concise instructions such as:

- Move left
- Move right
- Move closer
- Move farther
- Tilt up
- Tilt down
- Rotate slightly
- Centre subject

---

## ALG-005 Alignment Score

Where the engine can calculate a reliable score, display:

```text
Alignment: XX%
```

Detailed scores may be shown in an expandable panel.

---

## ALG-006 Alignment Threshold

Initial thresholds shall be configurable during development.

The product shall not claim that an arbitrary percentage represents clinical accuracy.

Thresholds must be validated using test images.

---

## ALG-007 Alignment Failure

If automatic alignment cannot be calculated:

> Automatic alignment unavailable.

The user shall still be able to use Ghost Overlay if available.

---

# 10. Lighting

## LGT-001 Enable/Disable

Lighting Check shall be an optional persistent tool.

---

## LGT-002 Lighting Analysis

Where technically possible, compare:

- brightness
- exposure
- highlights
- shadows
- colour characteristics
- flash state

---

## LGT-003 Lighting Status

Possible states:

- Good
- Similar
- Different
- Too dark
- Too bright
- Strong shadow
- Backlit

---

## LGT-004 Capture Override

Lighting warnings shall not normally block capture.

---

# 11. Focus and Blur

## FOC-001 Enable/Disable

Focus Check shall be an optional persistent tool.

---

## FOC-002 Quality Evaluation

WISE shall evaluate image sharpness using available camera focus information and/or local image analysis.

---

## FOC-003 Warning

If blur is suspected:

> Image may be blurred.

Actions:

- Retake
- Capture anyway

---

# 12. Grid

## GRD-001 Enable/Disable

Grid shall be an optional persistent tool.

---

## GRD-002 Grid Options

At minimum:

- 3×3
- 4×4
- centre crosshair

---

## GRD-003 Saved Image

The grid shall not be permanently included in the original photograph.

It may be included in an explicitly configured export.

---

# 13. Level

## LVL-001 Enable/Disable

Level shall be an optional persistent tool.

---

## LVL-002 Sensor Use

Where supported, use device orientation sensors.

---

## LVL-003 Guidance

Display tilt information in a simple manner.

Example:

> 0.2°

The exact visual threshold for a “level” state shall be validated during testing.

---

# 14. Calibration

## CAL-001 Calibration Requirement

Physical measurements require calibration.

If no valid calibration exists, WISE shall not display centimetre measurements.

---

## CAL-002 Ruler Calibration

User shall be able to identify a known physical distance on an image.

Example:

> Known distance: 5 cm

The application calculates pixels per physical unit.

---

## CAL-003 Marker Calibration

A known-size marker may be used.

The implementation may later support automatic marker detection.

---

## CAL-004 Manual Calibration

Workflow:

```text
Draw calibration line
→ Enter known distance
→ Select unit
→ Confirm
```

---

## CAL-005 Calibration Units

At minimum support:

- mm
- cm
- m

Additional units can be added later.

---

## CAL-006 Calibration Record

Store:

- method
- known length
- unit
- pixel length
- photo ID
- calibration timestamp
- confidence where available

---

## CAL-007 Calibration Warning

If calibration is likely invalid due to perspective or insufficient reference information, warn the user.

Do not present the result as clinically validated.

---

# 15. Measurement

## MES-001 Enable/Disable

Measurement shall be an optional persistent tool.

---

## MES-002 Length

User selects two points.

Output:

> Length: 2.8 cm

Only show physical units when calibrated.

---

## MES-003 Width

User can create a second measurement perpendicular or otherwise specified.

---

## MES-004 Area

User traces a closed region.

Output:

> Area: 3.6 cm²

---

## MES-005 Perimeter

User traces a closed region.

Output:

> Perimeter: X cm

---

## MES-006 Diameter

Support circle/ellipse-based diameter measurements.

---

## MES-007 Multiple Measurements

A photograph may contain multiple measurement objects.

---

## MES-008 Measurement Editing

Measurements shall be:

- movable
- editable
- deletable
- hideable

---

## MES-009 Measurement Layer

Measurements shall remain separate from the original image.

---

# 16. Annotation

## ANN-001 Enable/Disable

Annotation shall be an optional persistent tool.

---

## ANN-002 Tools

Minimum tools:

- pen
- arrow
- circle
- rectangle
- point
- line
- text
- measurement line

---

## ANN-003 Editing

Annotations shall be:

- selectable
- movable
- resizable where applicable
- editable
- deletable
- hideable

---

## ANN-004 Non-Destructive

Annotations shall never overwrite the original image.

---

# 17. Layer Management

## ANN-010 Layer Visibility

The user shall be able to control visibility of:

- reference
- measurements
- annotations
- grid
- labels
- footer

---

## ANN-011 Export Layer Selection

The user shall be able to choose which layers appear in an export.

---

# 18. Comparison

## CMP-001 Side-by-Side

Display Before and After with matched dimensions where possible.

---

## CMP-002 Slider

Provide a draggable divider.

---

## CMP-003 Overlay Comparison

Blend Before and After using adjustable opacity.

---

## CMP-004 Blink

Alternate between Before and After.

Provide play/pause.

---

## CMP-005 Difference

Generate a visual difference view.

The UI shall display:

> Visual difference only. This does not provide a medical diagnosis.

---

## CMP-006 Comparison Alignment

Where alignment data exists, reuse it for comparison.

Do not independently create a conflicting alignment transformation.

---

# 19. Before/After Change Calculation

If valid calibrated measurements exist:

WISE may calculate:

- absolute change
- percentage change

Example:

```text
Before: 4.2 cm
After:  2.8 cm

Change: -1.4 cm
Change: -33.3%
```

The mathematical formula shall be:

```text
percentage change =
((after - before) / before) × 100
```

The application must handle zero and invalid values safely.

---

# 20. Body Part

## MOD-030 Body Part

Optional body-part selection.

Minimum categories:

- Face
- Scalp
- Neck
- Chest
- Abdomen
- Back
- Shoulder
- Arm
- Elbow
- Forearm
- Hand
- Hip
- Thigh
- Knee
- Leg
- Ankle
- Foot
- Other

---

# 21. Laterality

Options:

- Left
- Right
- Both
- Not applicable

This information remains optional.

---

# 22. Case System

## CAS-001 Optional Case

A photograph may exist without a case.

---

## CAS-002 Attach Photo

After capture:

> Attach to case

Options:

- existing case
- create case
- skip

---

## CAS-003 Case Photos

A case may contain:

- Before
- After
- Photo
- comparison outputs
- measurements
- annotations

---

# 23. Persistent Add-On System

## SET-001 User Defaults

Each user has persistent defaults for:

- Ghost Overlay
- Alignment
- Lighting
- Focus
- Grid
- Level
- Measurement
- Annotation
- Difference View
- Comparison Mode
- Gallery saving preference

---

## SET-002 Persistence

Defaults survive:

- app close
- app restart
- device restart

---

## SET-003 Temporary Override

A capture session can override a default without modifying it.

---

## SET-004 Change Default

The user can explicitly save the current setting as the new default.

---

# 24. Protocol System

## PRO-001 Create Protocol

User can create a reusable protocol.

---

## PRO-002 Protocol Configuration

A protocol may define:

- enabled tools
- camera preferences
- orientation preference
- flash preference
- measurement requirement
- alignment threshold
- lighting requirement
- export settings

---

## PRO-003 Activate Protocol

The user selects a protocol before capture.

---

## PRO-004 Protocol Precedence

Recommended precedence:

```text
System capability
      ↓
User default
      ↓
Protocol
      ↓
Session override
      ↓
Effective setting
```

Where a safety/platform limitation exists, it overrides all preferences.

---

## PRO-005 Protocol Version

Protocols should be versioned so future changes do not silently alter historical capture records.

---

# 25. Saving

## SAV-001 WISE Storage

The application shall save the original photograph to WISE local storage.

---

## SAV-002 Gallery

The user may save to the device Gallery.

---

## SAV-003 Gallery Preference

Options:

- Ask every time
- Always
- Never

---

## SAV-004 Original Preservation

Gallery export and WISE processing must never replace the original WISE image.

---

# 26. Export

## EXP-001 Export Types

Minimum:

- Original
- Annotated
- Measured
- Before + After
- Before + After + Measurements
- Anonymized

---

## EXP-002 Export Layers

User selects included layers.

---

## EXP-003 Footer

Optional footer may include:

- WISE Clinical Photo
- measurement information
- date
- custom text

---

## EXP-004 Original

Original export must preserve original image content and should not include optional overlays unless explicitly requested.

---

# 27. Privacy

## PRI-001 Local-First

Photographs remain on the device by default.

---

## PRI-002 No Silent Upload

WISE must not upload clinical photographs without an explicit feature and user permission requiring it.

---

## PRI-003 AI Privacy

AI processing must identify whether processing is:

- local
- self-hosted
- cloud-based

Cloud processing must require explicit consent/configuration.

---

## PRI-004 Privacy Mode

Privacy Mode should support:

- no automatic Gallery saving
- no cloud upload
- no third-party AI image processing

---

# 28. Anonymization

## PRI-010 Anonymized Export

User can create an anonymized copy.

Where available, remove:

- location metadata
- device metadata
- identifying metadata
- timestamps where selected

The original remains unchanged.

---

# 29. Offline Behaviour

## OFF-001 Core Offline

The following must work offline:

- camera
- Before
- After
- Photo
- reference selection from local storage
- overlay
- alignment where local processing is supported
- lighting
- focus
- grid
- level
- calibration
- measurement
- annotation
- comparison
- local saving
- export

---

## OFF-002 AI Offline

AI features may be unavailable offline.

If unavailable:

> AI assistance unavailable. Core camera features continue normally.

---

# 30. AI Functions

AI is optional.

Potential future functions:

- body-part recognition
- landmark detection
- automatic region selection
- quality assessment
- OCR
- image description
- report assistance

AI must not be required for core photography.

---

# 31. Data Requirements

Every photo should have:

- unique ID
- capture type
- original file path
- capture timestamp
- optional case ID
- optional body part
- optional laterality
- optional reference ID
- optional protocol ID
- camera metadata
- calibration relationship
- measurement relationship
- annotation relationship
- derived asset relationships

---

# 32. Original and Derived Assets

Original:

```text
photo_<id>_original
```

Derived assets may include:

```text
photo_<id>_thumbnail
photo_<id>_annotated
photo_<id>_measured
photo_<id>_comparison
photo_<id>_export
```

Derived assets must reference the original.

---

# 33. Gallery and File Import

When importing an external reference image:

1. Request required permission.
2. Let user select image.
3. Create internal WISE reference record.
4. Preserve the imported original.
5. Generate thumbnail.
6. Allow use as an After reference.

The app should not silently alter the imported original.

---

# 34. Photo Deletion

Deletion must distinguish:

- original
- derived assets
- database metadata
- Gallery copy

Deleting a WISE photograph should not silently delete an independently saved Gallery copy.

The user should be informed of the scope of deletion.

---

# 35. Search and Filtering

Future library functionality should support filtering by:

- date
- Before/After/Photo
- body part
- laterality
- case
- protocol

This may be implemented progressively.

---

# 36. User Interface Behaviour

The UX specification defines the visual hierarchy.

Functional rule:

> The camera preview and capture action have highest priority.

Secondary tools must not obscure the subject.

The supplied WiseAiTechs design system emphasizes clean, smart, structured, premium and action-oriented interfaces, with rounded geometry, strong readability and modular components. fileciteturn0file0L45-L70

---

# 37. Tool Drawer Behaviour

The Tools drawer shall:

1. Display all supported tools.
2. Show current ON/OFF state.
3. Allow activation/deactivation.
4. Allow configuration where applicable.
5. Preserve persistent defaults unless the user explicitly chooses to change them.

---

# 38. Capture Review Behaviour

After capture:

```text
Image
↓
Quality status
↓
Retake / Use Photo
```

If warnings exist, display them clearly.

Example:

> Lighting slightly different from Before.

---

# 39. User Override Behaviour

Warnings should normally be advisory.

Example:

```text
⚠ Alignment 76%

Move slightly closer.

[ Capture Anyway ]
```

The application should not unnecessarily block the user.

---

# 40. Error Handling

## ERR-001 Camera Permission

> Camera access is required to take a photograph.

Actions:

- Open Settings
- Cancel

---

## ERR-002 Gallery Permission

> Gallery access is unavailable.

Actions:

- Open Settings
- Continue with WISE

---

## ERR-003 Alignment Failure

> Automatic alignment is unavailable on this device.

Continue with:

- Ghost Overlay
- Manual positioning

---

## ERR-004 Measurement Without Calibration

> Set a scale before measuring in centimetres.

---

## ERR-005 Insufficient Storage

> Device storage is low. Free some space before saving additional photographs.

The exact platform-specific handling must be implemented safely.

---

# 41. Performance Requirements

The application should:

- start the camera quickly
- keep preview responsive
- minimize overlay latency
- process images asynchronously
- avoid blocking the UI
- use thumbnails for libraries
- manage high-resolution images efficiently

Exact numerical targets must be established through device testing.

---

# 42. Accessibility Requirements

Support:

- VoiceOver
- TalkBack
- accessible labels
- readable text
- high contrast
- non-colour-only status
- reduced-motion preferences
- adequate touch targets

Camera guidance must be understandable without relying solely on colour.

---

# 43. Security Requirements

The application must:

- avoid sensitive data in logs
- avoid hard-coded credentials
- use platform secure storage for secrets
- protect sensitive local data where appropriate
- avoid uploading photographs by default
- keep original image files protected by application storage controls

---

# 44. AI Safety Requirements

AI output must be clearly identified.

AI must not silently:

- diagnose
- recommend treatment
- claim clinical improvement
- alter original clinical photographs

If AI is used for image quality or organization, the UI should describe the specific function.

---

# 45. Measurement Safety

WISE shall describe physical measurements as photographic measurements unless validated otherwise.

The application must not claim:

- medical-grade measurement accuracy
- diagnostic accuracy
- disease progression based solely on photographic difference

---

# 46. State Management

Core application states:

```text
Idle
CameraInitializing
Previewing
ReferenceLoading
Aligning
Ready
Capturing
Processing
Reviewing
Saving
Comparing
Exporting
Error
```

Transitions must be deterministic.

---

# 47. Example State Flow

```text
Idle
 ↓
Before
 ↓
CameraInitializing
 ↓
Previewing
 ↓
Capturing
 ↓
Processing
 ↓
Reviewing
 ↓
Saving
 ↓
Complete
```

After:

```text
Idle
 ↓
After
 ↓
SelectReference
 ↓
ReferenceLoading
 ↓
Previewing
 ↓
Aligning
 ↓
Ready
 ↓
Capturing
 ↓
Reviewing
 ↓
Comparison
 ↓
Export
```

---

# 48. Functional Acceptance Criteria

## Core Camera

- User can open camera.
- User can capture an image.
- Original image is preserved.
- User can save locally.

## Before

- User can create a Before image.
- Before image can become a reference.

## After

- User can select a Before image.
- Reference appears in camera.
- User can capture an After image.

## Overlay

- User can adjust opacity.
- User can transform reference.
- User can lock reference.

## Alignment

- Alignment can be enabled/disabled.
- System provides useful guidance when supported.
- Capture remains possible when warnings are advisory.

## Lighting

- Lighting check can be enabled/disabled.
- User receives useful warning when conditions differ.

## Focus

- Focus/blur check can be enabled/disabled.
- User can retake or override.

## Measurement

- User can calibrate.
- User can measure length/area.
- Uncalibrated photographs cannot falsely display centimetres.

## Annotation

- User can add and remove annotations.
- Original remains unchanged.

## Comparison

- Side-by-side works.
- Slider works.
- Overlay works.
- Blink works.
- Difference works.

## Persistence

- Tool preferences survive app restart.
- Temporary overrides do not change defaults.

## Privacy

- Core photography works without cloud.
- Images are not silently uploaded.
- Gallery saving is controlled by user preference.

---

# 49. Definition of Done for V1

V1 is complete when:

1. iOS and Android can capture photographs.
2. Before, After and Photo modes work.
3. Before images can be selected as references.
4. Ghost Overlay works in real time.
5. Reference transformation and locking work.
6. Core alignment guidance works on supported devices.
7. Lighting and focus checks work locally.
8. Grid and level tools work where supported.
9. Calibration works.
10. Physical measurement works after calibration.
11. Annotation works.
12. Comparison modes work.
13. Gallery export works with permissions.
14. Persistent add-ons work.
15. Temporary overrides work.
16. Original images remain untouched.
17. Core functions work offline.
18. Privacy requirements are implemented.
19. Basic testing passes across representative iOS and Android devices.
20. No mandatory AI or cloud service is required.

---

# 50. Recommended Implementation Priority

### P0 — Essential

- camera
- Before
- After
- Photo
- local storage
- reference selection
- ghost overlay
- opacity
- reference lock
- Gallery saving

### P1 — Core differentiation

- alignment
- scale matching
- orientation
- lighting
- focus
- grid
- level

### P2 — Clinical documentation tools

- calibration
- measurement
- annotation
- comparison
- export

### P3 — Workflow improvements

- protocols
- cases
- advanced metadata
- anonymization
- advanced library filtering

### P4 — AI and cloud extensions

- on-device AI
- self-hosted AI
- cloud AI
- synchronization
- backup
- multi-device collaboration

---

# 51. Final Functional Principle

The application must always preserve this hierarchy:

```text
                    PHOTOGRAPH
                         ↓
                 REPRODUCIBILITY
                         ↓
                OPTIONAL TOOLS
                         ↓
                    WORKFLOW
                         ↓
                 OPTIONAL AI/CLOUD
```

The user should never need to understand the underlying computer vision, AI or cloud architecture to take a high-quality Before/After photograph.

The system should quietly perform the complex work while presenting the user with simple actions:

> **Match → Check → Capture → Compare → Measure → Export**

---

# 52. Implementation Directive

When this specification is given to a coding agent, implementation should proceed incrementally.

The agent must:

1. Build and test one functional module at a time.
2. Preserve existing functionality when adding modules.
3. Avoid introducing cloud dependencies into the core camera.
4. Keep original photographs immutable.
5. Keep optional tools modular.
6. Keep persistent preferences separate from temporary overrides.
7. Use device capability detection.
8. Never assume identical camera capabilities across iOS and Android.
9. Add automated tests for calculations and state transitions.
10. Validate computer-vision thresholds using real test data before treating them as production thresholds.
11. Document platform-specific limitations rather than silently approximating unsupported functionality.
12. Keep the codebase ready for future WISE applications to reuse the camera engine.
