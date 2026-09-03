# WISE Clinical Camera
## Product Requirements Document (PRD) v1.0

**Product:** WISE Clinical Camera  
**Primary purpose:** Standardized clinical photography with reproducible Before/After images  
**Platforms:** iOS + Android  
**Architecture principle:** Offline-first, privacy-first, low-cost, modular  
**AI principle:** AI optional, on-device/open-source first  
**Core capture modes:** Before / After / Photo

---

## 1. Product Vision

WISE Clinical Camera is a clinical photography application designed to make photographs taken at different points in time as visually comparable as possible.

Its primary purpose is not diagnosis.

Its primary purpose is:

> **Take the same photograph again.**

The application assists the user in reproducing the original:

- camera angle
- orientation
- position
- framing
- scale
- zoom
- lighting conditions
- focus
- body-part positioning

The application also provides optional tools for:

- reference-image overlay
- measurement
- scale calibration
- annotation
- grids
- level guidance
- comparison
- image-quality checking
- standardized export

---

# 2. Core Design Principle

The application must remain simple for users who only want a camera.

### Basic mode

**BEFORE | AFTER | PHOTO**

Everything else is an optional add-on.

Users can activate the features they personally require.

### Persistent Add-on Requirement

Add-ons must be persistent.

If a user enables:

> Ghost Overlay = ON

it remains ON when the application is reopened later.

The setting changes only when the user explicitly changes it.

---

# 3. Capture Modes

## 3.1 BEFORE

Creates a reference photograph.

Workflow:

**BEFORE → Optional body part → Optional protocol → Camera → Quality checks → Capture → Review → Save**

The photograph becomes available as a reference for future After photographs.

## 3.2 AFTER

The user selects a Before photograph.

Workflow:

**Select Before → Load reference → Activate enabled tools → Open camera → Alignment guidance → Lighting/focus checks → Capture → Review → Compare → Save**

## 3.3 PHOTO

Normal photography.

No reference is required.

Useful for:

- clinical documentation
- reports
- scans
- documents
- prescriptions
- certificates
- wounds
- skin findings
- general photographs

---

# 4. Reference Image System

The user must be able to select a reference from:

- previously captured WISE photographs
- device Gallery
- Files/document picker
- another case
- an existing Before photograph

The selected image becomes the **REFERENCE**.

---

# 5. Ghost / Reference Overlay

This is a core feature.

When enabled, the reference image is displayed over the live camera feed.

### Controls

- opacity slider
- rotate
- flip
- reset
- lock
- unlock

Example:

**Reference opacity: 10%–100%**

The user moves the device until the live image matches the reference.

---

# 6. Automatic Alignment Engine

Optional persistent add-on.

When ON, WISE evaluates the live camera against the reference.

### Parameters

- translation
- rotation
- scale
- perspective
- framing
- orientation
- subject position

The system can provide simple instructions such as:

- Move slightly left
- Move closer
- Move farther
- Tilt downward
- Rotate device slightly

When sufficiently aligned:

> **✓ READY**

The user can still override:

> **Capture anyway**

The alignment system should not unnecessarily prevent legitimate clinical documentation.

---

# 7. Lighting Matching

Optional persistent add-on.

WISE compares current camera conditions with the reference.

Possible checks:

- overall brightness
- exposure
- colour temperature
- white balance where accessible
- shadow distribution
- highlights
- flash state
- major lighting direction

Example:

> **Lighting ✓**

or:

> **Lighting ⚠ Different from reference**

The user can override the warning.

---

# 8. Focus / Blur Detection

Optional persistent add-on.

Before capture:

> **Focus ✓**

or:

> **Image may be blurred**

The user can:

- Retake
- Capture anyway

---

# 9. Grid

Optional persistent add-on.

Available guides:

- 3×3
- 4×4
- centre crosshair

The grid must not become part of the saved original photograph unless explicitly requested.

---

# 10. Level / Tilt Guide

Optional persistent add-on.

Uses device orientation sensors where available.

Example:

> **0.2°**

The guide indicates when the device is level.

---

# 11. Measurement System

Optional persistent add-on.

Supported measurements:

- point-to-point length
- width
- diameter
- perimeter
- area
- multiple measurements

Example:

- Length: 2.8 cm
- Width: 1.7 cm
- Area: 3.6 cm²

---

# 12. Scale Calibration

Real-world centimetre measurements require calibration.

WISE supports:

### Method A — Physical ruler

Photograph a known scale.

### Method B — Calibration marker

Use a known-size reference object/card.

### Method C — Manual calibration

User identifies a known distance:

> This line = 5 cm

WISE calculates the image scale.

Calibration information should be stored with the image/session.

---

# 13. Measurement Validation

WISE must distinguish between:

### Calibrated

Measurements can be expressed in physical units.

### Uncalibrated

Measurements can only be expressed in pixels or relative image units.

The application must never present pixel measurements as centimetres without calibration.

---

# 14. Measurement Overlay

Measurements should be editable and movable.

Example:

```text
        ← 2.8 cm →
       ┌──────────┐
       │  lesion  │
       └──────────┘
            ↑
          1.7 cm
```

Measurements remain a separate layer.

---

# 15. Measurement Footer

Optional persistent add-on.

The user can place measurement information at the bottom of an exported image.

Example:

> **WISE CLINICAL PHOTO**  
> Lesion: 2.8 × 1.7 cm  
> Area: 3.6 cm²

Footer can be ON/OFF.

---

# 16. Annotation System

Optional persistent add-on.

Tools:

- freehand pen
- arrow
- circle
- rectangle
- point
- line
- text
- measurement line

Annotations are non-destructive.

---

# 17. Layer System

The original photograph must remain untouched.

Conceptually:

```text
ORIGINAL
   │
   ├── Reference
   ├── Measurements
   ├── Annotations
   ├── Labels
   ├── Grid
   └── Export formatting
```

Each layer can be turned ON/OFF.

---

# 18. Comparison Modes

After an After photograph is captured:

### Side-by-side

**BEFORE | AFTER**

### Slider

Drag a vertical divider between the two photographs.

### Overlay

Control Before/After opacity.

### Blink

Rapidly alternate Before and After.

### Difference

Visualize photographic differences.

Difference mode must clearly state that it is a visual comparison, not a medical diagnosis.

---

# 19. Before/After Measurements

When both photographs are calibrated, WISE can calculate changes.

Example:

**BEFORE**  
4.2 × 3.1 cm

**AFTER**  
2.8 × 2.0 cm

**Length change:** −33%  
**Width change:** −35%  
**Area change:** calculated from measurements

Calculations should be transparent.

---

# 20. Body Part

Optional.

Possible categories:

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

Laterality:

- Left
- Right
- Both
- Not applicable

The user can skip body-part classification.

---

# 21. Capture Protocols

Users can create reusable photography protocols.

### Example: Dermatology Standard

- Ghost Overlay: ON
- Alignment: ON
- Lighting Check: ON
- Focus Check: ON
- Grid: ON
- Level: ON
- Measurement: ON
- Annotation: OFF
- Flash: OFF
- Portrait orientation

Another user can create a different protocol, such as Physiotherapy Standard.

---

# 22. Persistent User Preferences

Every user has their own camera-tool preferences.

Example:

| Tool | Status |
|---|---|
| Ghost Overlay | ON |
| Alignment | ON |
| Lighting Check | ON |
| Focus Check | ON |
| Grid | ON |
| Level | OFF |
| Measurement | ON |
| Annotation | OFF |
| Difference | OFF |

These preferences survive app restarts.

---

# 23. Temporary Override

A persistent preference can be overridden for one capture.

Example:

> Measurement is normally ON.

The user switches it OFF.

WISE offers:

- **Turn off for this capture**
- **Change my default**

This prevents persistent settings from becoming inconvenient.

---

# 24. Reference Lock

When the Before photograph is positioned:

> **🔒 Reference Locked**

The reference cannot accidentally move.

To modify:

**Unlock → Adjust → Lock**

---

# 25. Camera Metadata

Where available, WISE should retain:

- capture date/time
- device
- camera/lens
- focal information
- zoom
- orientation
- flash state
- image dimensions
- calibration information
- reference image ID
- capture protocol ID

Device capabilities vary. Unsupported information should be marked unavailable.

---

# 26. Gallery Saving

After capture:

- **Save to WISE**
- **Save to Device Gallery**

User preference:

- Ask every time
- Always
- Never

The WISE copy and Gallery copy are separate destinations.

---

# 27. WISE Album

Where supported by the operating system, the application can provide a dedicated:

> **WISE Clinical Photos**

album.

This must respect iOS and Android permissions and platform limitations.

---

# 28. Privacy Mode

Optional.

When enabled:

- no automatic Gallery copy
- no cloud upload
- no third-party AI processing
- local storage by default
- anonymized export available

---

# 29. Anonymized Export

Before sharing an image:

### Remove metadata

Options:

- location
- device information
- identifying metadata
- timestamps where applicable

Create:

> **Anonymized Copy**

The original remains untouched.

---

# 30. Offline-First Requirement

The core camera must work without Internet.

Required offline functions:

- camera
- Before
- After
- overlay
- alignment
- measurement
- annotation
- comparison
- local storage
- Gallery export

Internet must not be required for normal photography.

---

# 31. AI Architecture

AI must not be required for the core product.

Preferred processing hierarchy:

```text
Device sensors
      ↓
Classical computer vision
      ↓
On-device ML
      ↓
Self-hosted AI
      ↓
Cloud AI
```

AI may later provide:

- body-part recognition
- automatic landmarks
- automatic lesion region selection
- intelligent cropping
- image-quality assessment
- OCR
- report assistance
- automated descriptions

AI must not silently upload clinical photographs.

---

# 32. Data Architecture

A photograph should have an associated record:

```text
Photo
 ├── ID
 ├── Original file
 ├── Capture type
 ├── Date/time
 ├── Case ID
 ├── Body part
 ├── Laterality
 ├── Reference ID
 ├── Capture protocol
 ├── Camera metadata
 ├── Calibration
 ├── Measurements
 ├── Annotations
 └── Export versions
```

---

# 33. Non-Destructive Editing

Never overwrite the original.

Example:

```text
Original.jpg
       │
       ├── Annotated version
       ├── Measurement version
       ├── Before-After version
       └── Export version
```

---

# 34. User Experience

The camera should open quickly.

Primary screen:

```text
              CAMERA VIEW

        [ reference / guides ]

              ─────────

       BEFORE   AFTER   PHOTO

             [ CAPTURE ]

             + TOOLS
```

Active tools appear as controls.

Inactive tools remain hidden or inside **Tools**.

---

# 35. V1 Scope Discipline

The first build should deliberately exclude:

- medical diagnosis
- treatment recommendations
- automatic disease classification
- complicated patient management
- mandatory cloud accounts
- expensive AI APIs
- unnecessary analytics
- social features
- automatic medical claims

The first product should perfect photographic reproducibility.

---

# 36. Development Strategy

## Phase 1 — Camera Foundation

- iOS
- Android
- Before
- After
- Photo
- local storage
- Gallery export

## Phase 2 — Reference System

- reference selection
- ghost overlay
- opacity
- lock
- transformation

## Phase 3 — Reproducibility

- alignment
- grid
- level
- lighting
- focus
- zoom guidance

## Phase 4 — Measurement

- calibration
- ruler
- measurements
- area
- annotation
- footer

## Phase 5 — Comparison

- side-by-side
- slider
- overlay
- blink
- difference

## Phase 6 — Protocols

- saved configurations
- persistent add-ons
- temporary overrides

## Phase 7 — AI

Only after the non-AI system is stable.

---

# 37. Success Criteria

The application succeeds if a user can:

> Take a Before photograph today, return weeks or months later, select that photograph, and use WISE to reproduce the same photographic composition closely enough that the two images can be compared confidently.

The central product objective is **photographic consistency**, not the number of AI calls or number of features.

---

# 38. Final Product Definition

> **WISE Clinical Camera is a privacy-first, offline-first clinical photography application that helps users reproduce standardized photographs over time, with persistent optional tools for reference overlay, alignment, lighting, focus, measurement, calibration, annotation and Before/After comparison.**

The architecture should allow the product to start free or nearly free, then add cloud synchronization and AI only where they provide genuine value.

---

# 39. Locked Product Principles

The following principles are considered the baseline for the next stage of development:

1. Any body part.
2. Any supported iOS/Android device.
3. Three core modes: Before, After and Photo.
4. Before becomes the photographic reference.
5. After uses live reference alignment.
6. Angle, scale, framing and lighting checks.
7. Ghost/reference overlay with adjustable opacity.
8. Measurement and scale calibration.
9. Annotations as separate layers.
10. Side-by-side, slider, overlay, blink and difference comparison.
11. Optional Gallery saving.
12. Original photograph is never destroyed.
13. Offline-first.
14. No account required for basic capture.
15. No mandatory cloud.
16. No mandatory AI.
17. Privacy-first.
18. Persistent per-user add-on preferences.
19. Temporary per-capture overrides.
20. Reusable capture protocols.
21. Device-independent design.
22. Prefer free, open-source and on-device technologies wherever practical.
23. AI should be an optional extension, not a core dependency.
24. The system should remain useful for dermatology, wounds, physiotherapy, rehabilitation, posture, swelling and general clinical documentation.
25. The primary purpose is reproducible photography, not diagnosis.
