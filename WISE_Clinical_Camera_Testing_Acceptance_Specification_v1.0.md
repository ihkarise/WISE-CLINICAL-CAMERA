# WISE Clinical Camera
## Testing & Acceptance Specification v1.0

**Product:** WISE Clinical Camera  
**Purpose:** Define the test strategy, test cases, acceptance criteria, quality gates, device matrix, computer-vision validation, privacy/security validation, performance testing, regression testing, and release criteria for WISE Clinical Camera.

**Platforms:** iOS and Android  
**Architecture:** Flutter + native camera/sensor bridges + local SQLite/filesystem + local computer vision + optional on-device/self-hosted/cloud AI.

---

# 1. Testing Philosophy

WISE Clinical Camera is a clinical photography tool.

The primary quality objective is:

> The application must reliably help the user create reproducible Before/After photographs without compromising the original photograph or unnecessarily exposing clinical data.

Testing must therefore validate five major areas:

```text
FUNCTION
+
REPRODUCIBILITY
+
IMAGE INTEGRITY
+
PRIVACY/SECURITY
+
PERFORMANCE
```

A feature is not considered complete merely because its UI works.

---

# 2. Test Levels

Testing shall occur at:

1. Unit level
2. Component level
3. Integration level
4. Device level
5. End-to-end level
6. Computer-vision validation level
7. Privacy/security level
8. Performance level
9. Regression level
10. Release acceptance level

---

# 3. Test Priority

| Priority | Meaning |
|---|---|
| P0 | Must pass. Release blocker. |
| P1 | High importance. Normally release blocker. |
| P2 | Important. Can be deferred with approval. |
| P3 | Enhancement/edge case. |

---

# 4. Test Environment

The test environment should include:

### iOS

Representative:

- recent flagship iPhone
- previous-generation iPhone
- mid-range/older supported iPhone
- multiple iOS versions within the supported range

### Android

Representative:

- flagship device
- mid-range device
- lower-performance supported device
- multiple Android versions
- devices with different camera vendors

Exact supported OS versions must be fixed before release.

---

# 5. Device Capability Matrix

For every test device record:

```text
Device model
OS version
RAM
CPU/GPU class
Camera count
Main camera
Front camera
Supported resolutions
Zoom capability
Flash capability
Orientation sensors
Biometric capability
Storage availability
```

---

# 6. Test Dataset

Create a controlled WISE clinical photography dataset.

Include:

- skin lesions
- wounds
- scars
- swelling
- bruising
- postoperative sites
- joints
- posture
- hands
- face
- dental images
- low-texture regions
- hair-bearing areas
- varied skin tones

Do not use identifiable clinical photographs for testing unless appropriate authorization and governance exist.

---

# 7. Controlled Alignment Dataset

Create reference/target pairs with known transformations.

Examples:

```text
Translation
Rotation
Scale
Distance
Zoom
Tilt
Perspective
Lighting
Blur
Occlusion
```

Store ground truth for each pair.

Example:

```text
translation_x = +20 px
translation_y = -10 px
rotation = +3°
scale = 1.05
```

---

# 8. Core Camera Tests

## CAM-T001 Open Camera

**Action**

Open capture screen.

**Expected**

- camera initializes
- preview appears
- controls are responsive
- no crash

**Priority:** P0

---

## CAM-T002 Camera Permission Granted

Expected:

- preview starts
- capture works

**Priority:** P0

---

## CAM-T003 Camera Permission Denied

Expected:

- clear explanation
- no crash
- Settings route where supported
- non-camera functions remain usable

**Priority:** P0

---

## CAM-T004 Capture

Expected:

- photograph captured
- original saved
- database record created
- timestamp recorded

**Priority:** P0

---

## CAM-T005 Capture During Processing

Expected:

- UI prevents accidental duplicate capture where appropriate
- original is not duplicated accidentally
- processing state is clear

**Priority:** P1

---

# 9. Capture Mode Tests

## MOD-T001 BEFORE

Expected:

- Before workflow opens
- capture succeeds
- image becomes eligible as reference

**Priority:** P0

---

## MOD-T002 AFTER Without Reference

Expected:

- user is prompted to select a reference
- capture does not proceed as a normal After workflow without a reference unless explicitly designed as an exception

**Priority:** P0

---

## MOD-T003 AFTER With Reference

Expected:

- selected Before image loads
- overlay/alignment tools work
- After image references the Before record

**Priority:** P0

---

## MOD-T004 PHOTO

Expected:

- normal photograph
- no reference requirement

**Priority:** P0

---

# 10. Reference Tests

## REF-T001 Select Before

Expected:

- Before images are listed
- thumbnails load
- selected reference displays correctly

**Priority:** P0

---

## REF-T002 Reference Metadata

Expected:

- capture recipe loads where available
- camera metadata loads where available
- calibration relationship loads where valid

**Priority:** P1

---

## REF-T003 Deleted Reference

Expected:

- invalid/deleted reference is detected
- user receives a clear message
- app does not crash

**Priority:** P0

---

# 11. Ghost Overlay Tests

## OVR-T001 Enable

Expected:

- reference appears over live preview

**Priority:** P0

---

## OVR-T002 Opacity

Test:

```text
10%
25%
50%
75%
100%
```

Expected:

- opacity changes smoothly
- camera preview remains responsive

**Priority:** P1

---

## OVR-T003 Transform

Test:

- move
- scale
- rotate
- reset

Expected:

- reference transforms correctly
- original image is unchanged

**Priority:** P0

---

## OVR-T004 Lock

Expected:

- transform controls disabled when locked
- unlock restores editing

**Priority:** P1

---

# 12. Alignment Tests

## ALG-T001 Basic Alignment

Reference and target have:

```text
same camera
same distance
same orientation
same lighting
```

Expected:

- high alignment confidence
- useful guidance

**Priority:** P0

---

## ALG-T002 Translation

Move target horizontally/vertically.

Expected:

- system detects positional difference
- guidance points toward correction

**Priority:** P0

---

## ALG-T003 Rotation

Rotate target.

Expected:

- rotation detected
- direction is correct

**Priority:** P0

---

## ALG-T004 Scale

Change camera distance.

Expected:

- scale difference detected
- Move closer/farther guidance is appropriate

**Priority:** P0

---

## ALG-T005 Perspective

Change camera viewpoint.

Expected:

- perspective difference detected where supported
- confidence decreases if the transformation is unreliable

**Priority:** P1

---

## ALG-T006 Low Texture

Use low-feature skin region.

Expected:

- feature matching does not produce false high confidence
- fallback/manual alignment is available

**Priority:** P0

---

## ALG-T007 False Matches

Introduce repeated or misleading patterns.

Expected:

- outlier rejection prevents obviously incorrect transformation
- confidence decreases when matching is unreliable

**Priority:** P0

---

## ALG-T008 Spatially Concentrated Features

All useful features occur in one small region.

Expected:

- system recognizes weak geometric constraint
- confidence is reduced

**Priority:** P1

---

## ALG-T009 Large Viewpoint Change

Expected:

- automatic alignment may fail gracefully
- user receives useful fallback

**Priority:** P1

---

## ALG-T010 Subject Movement

Change body position between reference and target.

Expected:

- system does not claim perfect alignment
- confidence reflects uncertainty

**Priority:** P0

---

# 13. Alignment Accuracy Tests

For controlled ground-truth pairs calculate:

```text
translation error
rotation error
scale error
reprojection error
```

Example:

```text
ground truth rotation = 3°
estimated rotation = 3.4°

error = 0.4°
```

Acceptance thresholds must be established from empirical testing.

No universal clinical accuracy threshold should be assumed.

---

# 14. Alignment Stability Tests

Hold the camera approximately stationary.

Expected:

- guidance does not oscillate excessively
- confidence does not jump unpredictably
- transformation remains stable

Test under:

- good light
- low light
- moving subject
- different textures

---

# 15. Guidance Tests

For every guidance direction verify:

```text
Move left
Move right
Move up
Move down
Move closer
Move farther
Rotate left
Rotate right
Tilt up
Tilt down
```

Expected:

- direction is correct
- instruction is understandable
- instruction corresponds to actual required movement

---

# 16. Capture Readiness Tests

When alignment is acceptable:

Expected:

```text
Ready
```

When alignment is poor:

Expected:

```text
Warning / guidance
```

Capture should remain possible unless a hard protocol threshold explicitly applies.

---

# 17. Capture Anyway Tests

When a warning appears:

Expected:

```text
Capture Anyway
```

allows capture.

The resulting image stores the relevant quality/alignment state.

**Priority:** P0

---

# 18. Lighting Tests

## LGT-T001 Similar Lighting

Expected:

```text
Good / Similar
```

---

## LGT-T002 Dark Image

Expected:

```text
Too dark
```

or equivalent warning.

---

## LGT-T003 Overexposure

Expected:

```text
Too bright
```

or equivalent warning.

---

## LGT-T004 Different White Balance

Expected:

- meaningful difference detected where supported
- warning is not falsely absolute

---

## LGT-T005 Flash Difference

Expected:

- flash state difference is detected when camera metadata is available

---

# 19. Focus Tests

## FOC-T001 Sharp Image

Expected:

```text
Good
```

---

## FOC-T002 Blurred Image

Expected:

```text
Image may be blurred
```

with:

```text
Retake
Capture Anyway
```

---

## FOC-T003 Low-Texture Image

Expected:

- no excessive false blur warnings
- algorithm confidence may be lower

---

# 20. Grid Tests

Test:

- 3×3
- 4×4
- centre crosshair

Expected:

- correct rendering
- no permanent modification to original
- export includes grid only when selected

---

# 21. Level Tests

Test device orientations:

- level
- slight left tilt
- slight right tilt
- upward tilt
- downward tilt

Expected:

- correct direction
- stable reading
- no misleading status when sensors are unavailable

---

# 22. Calibration Tests

## CAL-T001 Known Ruler

Use a known physical ruler.

Expected:

- calibration created
- pixels-per-unit calculated
- measurement produces expected approximate value

---

## CAL-T002 Manual Calibration

Expected:

```text
Draw line
→ Enter known distance
→ Confirm
```

---

## CAL-T003 Invalid Calibration

Test:

- zero distance
- negative distance
- missing unit
- extremely short line

Expected:

- calibration rejected

---

## CAL-T004 Perspective

Use a ruler at an angle.

Expected:

- warning where geometry may compromise accuracy
- no claim of clinical-grade accuracy

---

# 23. Measurement Tests

Test:

- length
- width
- diameter
- perimeter
- area
- multiple measurements

Expected:

- geometry is correct
- values are recalculated correctly
- annotations remain editable

---

# 24. Uncalibrated Measurement Test

Attempt centimetre measurement without calibration.

Expected:

```text
Set a scale before measuring in centimetres.
```

The application must not invent a physical measurement.

**Priority:** P0

---

# 25. Measurement Mathematics

For:

```text
Before = 4.2 cm
After = 2.8 cm
```

expected:

```text
Change = -1.4 cm
Percentage change = -33.33%
```

Formula:

```text
((After - Before) / Before) × 100
```

Test:

```text
Before = 0
```

Expected:

- no division-by-zero error
- meaningful fallback

---

# 26. Annotation Tests

Test every tool:

- pen
- arrow
- circle
- rectangle
- point
- line
- text
- measurement line

Expected:

- add
- move
- edit
- hide
- delete
- export

---

# 27. Non-Destructive Editing Test

Procedure:

1. Capture original.
2. Add annotation.
3. Add measurement.
4. Export.
5. Reopen original.

Expected:

> Original photograph is unchanged.

**Priority:** P0

---

# 28. Comparison Tests

Test:

- side-by-side
- slider
- overlay
- blink
- difference

Expected:

- Before and After remain identifiable
- alignment is reused where available
- controls are responsive
- original images remain unchanged

---

# 29. Difference Test

Use identical images.

Expected:

```text
Minimal/no meaningful difference
```

Use controlled transformation.

Expected:

```text
Difference corresponds to transformation
```

Do not interpret the result as clinical diagnosis.

---

# 30. Persistence Tests

For each optional tool:

1. Turn ON.
2. Close application.
3. Reopen.
4. Start a new capture.

Expected:

> Setting remains ON.

Repeat for OFF.

**Priority:** P0

---

# 31. Temporary Override Tests

Example:

```text
Default Measurement = ON
Current capture override = OFF
```

After capture:

Expected:

```text
Default Measurement = ON
```

**Priority:** P0

---

# 32. Protocol Tests

Test:

- create protocol
- edit protocol
- activate protocol
- capture using protocol
- version protocol

Expected:

- correct tools activate
- historical photographs retain their original capture context

---

# 33. Case Tests

Test:

- create case
- capture without case
- attach photo to case
- move/associate photo where supported
- delete case

Expected:

- deleting a case does not unexpectedly delete photographs

---

# 34. Storage Tests

Test:

- sufficient storage
- low storage
- storage unavailable
- interrupted save
- app restart during processing

Expected:

- original image is protected
- error is understandable
- partial files are cleaned/recovered appropriately

---

# 35. Database Tests

Test:

- create
- read
- update
- soft delete
- restore
- migrations
- foreign-key constraints
- invalid relationships

Expected:

- no orphaned mandatory relationships
- migrations preserve data

---

# 36. File/Database Consistency Tests

Test:

```text
DB record exists + file exists
DB record exists + file missing
File exists + DB record missing
```

Expected:

- inconsistencies are detectable
- originals are not automatically deleted

---

# 37. Thumbnail Tests

Expected:

- thumbnail generated
- thumbnail displayed in library
- missing thumbnail can be regenerated
- original remains unaffected

---

# 38. Import Tests

Import:

- standard JPEG
- PNG
- large image
- rotated image
- image with EXIF
- image without EXIF

Expected:

- import succeeds where format is supported
- orientation handled correctly
- original import preserved

---

# 39. Gallery Tests

Test settings:

```text
Ask Every Time
Always
Never
```

Expected:

- correct behaviour persists
- Gallery permission is handled
- WISE original remains independent

---

# 40. Privacy Mode Tests

Enable Privacy Mode.

Expected:

- no automatic Gallery copy
- no cloud AI
- no third-party image upload
- local functionality remains available

**Priority:** P0

---

# 41. Network Tests

Test:

- airplane mode
- Wi-Fi
- mobile data
- intermittent connection
- network loss during AI
- network loss during export

Expected:

- core camera continues working
- local CV continues where supported
- network-dependent operations fail gracefully

---

# 42. Cloud AI Privacy Test

When cloud AI is disabled:

Expected:

```text
No network request containing clinical image
```

When enabled:

Expected:

- explicit configured provider
- secure connection
- user-approved action
- only required image sent

---

# 43. AI Failure Tests

Test:

- provider unavailable
- timeout
- malformed response
- quota exhausted
- network failure

Expected:

- AI error is understandable
- core WISE functions continue
- no photograph is lost

---

# 44. AI Cost Tests

Verify that:

- real-time camera does not invoke cloud AI continuously
- cloud AI is triggered only by defined events
- usage is recorded where enabled
- budget limits work
- provider/model information is recorded

---

# 45. Security Tests

Test:

- app sandbox access
- file permissions
- database protection
- secret storage
- logging
- export
- deletion
- share sheet
- background state

Expected:

- sensitive information is not unnecessarily exposed

---

# 46. Logging Tests

Generate:

- camera error
- CV error
- database error
- network error
- AI error

Inspect logs.

Expected:

No:

- image pixels
- patient identifiers
- clinical notes
- secrets
- encryption keys

---

# 47. Metadata Tests

Capture/import image with EXIF.

Expected:

- required metadata retained where appropriate
- anonymized export removes configured sensitive metadata
- original remains unchanged

---

# 48. Deletion Tests

Delete a photograph.

Verify:

- database record
- original
- thumbnail
- measurements
- annotations
- alignment
- comparison
- derived exports

behave according to deletion policy.

Verify an independent Gallery copy remains.

---

# 49. Reference Deletion Tests

Delete a Before referenced by several After images.

Expected:

- warning displayed
- references handled safely
- no broken application state

---

# 50. Performance Tests

Measure:

- app startup
- camera startup
- preview latency
- overlay latency
- CV processing time
- capture-to-review time
- export time
- memory use
- battery impact
- database query latency

---

# 51. Performance Acceptance

Exact numeric thresholds must be established using representative hardware.

Initial targets should prioritize:

```text
smooth camera preview
+
responsive controls
+
fast local guidance
+
no memory crashes
```

Do not sacrifice preview responsiveness for unnecessary CV frequency.

---

# 52. Memory Tests

Use:

- large photographs
- long capture sessions
- repeated Before/After captures
- multiple comparisons
- large annotation sets

Expected:

- no uncontrolled memory growth
- no frequent crashes
- original images remain recoverable

---

# 53. Battery Tests

Run:

```text
30-minute camera session
```

with:

- overlay OFF
- overlay ON
- alignment ON
- lighting ON
- focus ON
- all tools ON

Measure battery consumption and device temperature.

---

# 54. Thermal Tests

Run continuous camera/CV use on representative devices.

Expected:

- no unsafe thermal behaviour
- graceful performance reduction where necessary
- no crash due to thermal pressure

---

# 55. Offline Tests

In airplane mode verify:

```text
Before ✓
After ✓
Photo ✓
Overlay ✓
Alignment ✓
Lighting ✓
Focus ✓
Grid ✓
Level ✓
Calibration ✓
Measurement ✓
Annotation ✓
Comparison ✓
Export ✓
```

AI functions may display:

```text
AI assistance unavailable offline.
```

---

# 56. Accessibility Tests

Test:

- VoiceOver
- TalkBack
- large text
- high contrast
- reduced motion
- screen readers
- touch target sizes

Expected:

- core workflows remain usable
- status is not communicated only through colour

---

# 57. Orientation Tests

Test:

- portrait → portrait
- landscape → landscape
- portrait reference → landscape attempt
- landscape reference → portrait attempt

Expected:

- orientation mismatch is detected
- guidance is clear
- image coordinates remain correct

---

# 58. Device Camera Variation Tests

Test devices with:

- different focal lengths
- optical zoom
- digital zoom
- different sensor sizes
- different aspect ratios
- different image processing

Expected:

- unavailable metadata is handled gracefully
- app does not assume identical camera hardware

---

# 59. Regression Suite

Every release candidate should execute the P0 regression suite.

Minimum:

```text
Camera
Before
After
Photo
Reference
Overlay
Alignment
Capture
Saving
Measurement
Annotation
Comparison
Persistence
Privacy
Offline
Deletion
Export
```

---

# 60. Automated Tests

Automate where practical:

### Unit

- measurement mathematics
- percentage change
- calibration calculations
- state transitions
- preference precedence
- validation

### Integration

- database relationships
- photo lifecycle
- export pipeline
- settings persistence

### UI

- navigation
- capture controls
- tool drawer
- review screen
- settings

---

# 61. Computer Vision Regression Dataset

Maintain a fixed test set.

Every CV algorithm change must run against:

```text
same-device pairs
different-device pairs
lighting variation
rotation
translation
scale
perspective
low texture
occlusion
subject movement
```

Track changes in:

- success rate
- false alignment
- confidence
- processing time

---

# 62. CV Model/Algorithm Regression

If an algorithm changes from:

```text
cv-1.0
```

to:

```text
cv-1.1
```

compare:

```text
old result
vs
new result
```

Do not assume that a newer algorithm is automatically better.

---

# 63. AI Regression

For AI features, maintain a controlled evaluation set.

Track:

- correctness
- hallucination/error rate
- latency
- cost
- privacy behaviour
- model version

AI output should not be used as a clinical truth source.

---

# 64. Security Regression

For every release verify:

- no hard-coded secrets
- no unexpected network calls
- no sensitive logs
- permissions unchanged unexpectedly
- export metadata policy intact
- originals remain immutable

---

# 65. Crash Testing

Test:

- camera initialization failure
- permission denial
- storage full
- corrupted image
- corrupted database
- CV failure
- AI timeout
- app backgrounding
- device rotation during capture
- interruption by phone call where applicable

Expected:

- no unrecoverable data loss
- app returns to a stable state

---

# 66. Interruption Tests

Interrupt capture with:

- incoming call
- notification
- app background
- screen lock
- device rotation
- low-memory event where reproducible

Expected:

- capture state recovers safely
- original data is not corrupted

---

# 67. Data Integrity Tests

After thousands of test captures verify:

```text
Photo count
Original file count
Database records
Reference relationships
Derived asset relationships
```

No unexplained mismatch should remain.

---

# 68. Long-Session Test

Perform a long workflow:

```text
100+ captures
multiple Before/After pairs
measurements
annotations
comparisons
exports
```

Expected:

- no progressive slowdown that makes the application unusable
- no memory leak severe enough to crash
- no database corruption

---

# 69. End-to-End Clinical Workflow

Test:

```text
Create Before
 ↓
Enable Overlay
 ↓
Enable Alignment
 ↓
Enable Lighting
 ↓
Capture
 ↓
Save
 ↓
Select Before
 ↓
Take After
 ↓
Measure
 ↓
Annotate
 ↓
Compare
 ↓
Export
```

Expected:

- complete workflow succeeds without manual database intervention
- original images remain intact

---

# 70. Protocol End-to-End Test

```text
Create Dermatology Standard
 ↓
Enable required tools
 ↓
Activate protocol
 ↓
Capture Before
 ↓
Capture After
 ↓
Compare
 ↓
Export
```

Expected:

- protocol settings are correctly applied
- historical capture context is preserved

---

# 71. Privacy End-to-End Test

```text
Privacy Mode ON
 ↓
Capture Before
 ↓
Capture After
 ↓
Annotate
 ↓
Measure
 ↓
Compare
 ↓
Export Anonymized
```

Expected:

- no cloud upload
- no automatic Gallery copy
- anonymized export follows metadata policy
- originals remain local

---

# 72. Acceptance Criteria by Module

| Module | Acceptance |
|---|---|
| Camera | Capture works reliably |
| Before | Creates valid reference |
| After | Uses reference correctly |
| Overlay | Stable real-time rendering |
| Alignment | Useful reproducibility guidance |
| Lighting | Detects meaningful lighting differences |
| Focus | Detects significant blur |
| Grid | Correct rendering |
| Level | Correct orientation guidance |
| Calibration | Valid scale can be created |
| Measurement | Correct calibrated geometry |
| Annotation | Non-destructive editing |
| Comparison | All selected modes work |
| Export | Correct layers and metadata |
| Privacy | No silent exposure |
| Offline | Core functions continue |
| Database | Relationships remain valid |
| AI | Optional and isolated |

---

# 73. Release Blockers

A release must be blocked if any P0 condition fails, including:

- camera cannot reliably capture
- original photograph can be overwritten
- Before/After relationship is corrupted
- measurement displays false physical units
- privacy mode leaks images
- unexpected cloud upload occurs
- serious data loss occurs
- persistent preferences corrupt
- database migration loses data
- critical crash affects core workflow

---

# 74. Conditional Release Issues

A P1 issue may be accepted only if:

- workaround exists
- impact is documented
- no patient-data/privacy risk exists
- product owner approves
- fix is scheduled

---

# 75. Beta Testing

Before production:

### Internal Alpha

Developers and product team.

### Clinical Beta

A controlled group of intended users.

Test:

- real workflow speed
- reproducibility
- tool usefulness
- false warnings
- measurement usability
- device variation

No identifiable clinical dataset should be used without appropriate authorization.

---

# 76. Beta Feedback

Collect structured feedback on:

```text
Ease of capture
Alignment usefulness
Overlay usefulness
Warning quality
Measurement usability
Comparison usefulness
Export usefulness
Performance
Privacy confidence
```

Avoid collecting unnecessary patient information.

---

# 77. Reproducibility Acceptance Study

A key product validation should compare:

```text
Without WISE guidance
vs
With WISE guidance
```

Measure:

- framing variation
- scale variation
- rotation variation
- position variation
- time to acceptable capture

This tests whether WISE actually improves the problem it is designed to solve.

---

# 78. Human Factors Testing

Observe users performing:

```text
Before → After
```

without detailed technical instructions.

Measure:

- errors
- hesitation
- incorrect control use
- time to capture
- ability to understand guidance

The interface should be understandable without knowledge of computer vision.

---

# 79. False Confidence Testing

Intentionally create cases where:

- features are misleading
- subject moves
- perspective changes
- lighting changes
- texture is weak

Expected:

> System lowers confidence rather than presenting false certainty.

This is a critical safety test.

---

# 80. Measurement Validation

Use physical objects with known dimensions.

Examples:

- ruler
- calibration card
- known-size circles
- known rectangular objects

Test:

- different distances
- different angles
- different lighting
- different devices

Record measurement error.

Do not describe results as clinically validated until appropriate validation is completed.

---

# 81. Export Validation

For every export preset verify:

```text
Original
Annotated
Measured
Before + After
Before + After + Measurements
Anonymized
Report-ready
```

Verify:

- correct resolution
- correct orientation
- correct layers
- correct metadata policy
- correct filenames
- original unaffected

---

# 82. Database Migration Acceptance

For every schema migration:

1. Create database using previous version.
2. Populate realistic data.
3. Upgrade.
4. Verify every entity.
5. Verify relationships.
6. Verify files.
7. Verify settings.
8. Verify measurements.
9. Verify annotations.
10. Verify references.

No data loss is acceptable in required fields.

---

# 83. Backup/Restore Acceptance

When backup is implemented:

```text
Capture
 ↓
Backup
 ↓
Delete local data
 ↓
Restore
```

Expected:

- originals restored
- relationships restored
- measurements restored
- annotations restored
- protocols restored
- settings restored as designed

---

# 84. Security Acceptance

Before release:

- dependency scan completed
- secrets scan completed
- network inspection completed
- privacy mode tested
- permission flows tested
- export metadata tested
- deletion tested
- logging reviewed

---

# 85. Performance Acceptance

Before release, confirm on representative devices:

```text
Camera remains responsive
Overlay remains usable
CV does not freeze UI
Large images do not crash
Long sessions remain stable
Exports complete reliably
```

Numerical performance thresholds should be based on real device measurements.

---

# 86. Test Reporting

Every release candidate should produce:

```text
Test run
Build number
Commit/version
Device
OS
Test suite
Passed
Failed
Blocked
Known issues
CV metrics
Performance metrics
Security status
```

---

# 87. Defect Severity

### Critical

- data loss
- privacy breach
- security vulnerability
- original image corruption
- application unusable

### High

- core workflow failure
- incorrect alignment guidance
- incorrect measurement
- persistent data corruption

### Medium

- major tool malfunction
- export problem
- significant usability issue

### Low

- cosmetic
- minor wording
- non-critical edge case

---

# 88. Release Checklist

## Core

- [ ] Camera tested
- [ ] Before tested
- [ ] After tested
- [ ] Photo tested
- [ ] Reference tested
- [ ] Saving tested

## CV

- [ ] Overlay tested
- [ ] Alignment tested
- [ ] Lighting tested
- [ ] Focus tested
- [ ] Level tested
- [ ] Ground-truth dataset tested

## Clinical Tools

- [ ] Calibration tested
- [ ] Measurement tested
- [ ] Annotation tested
- [ ] Comparison tested
- [ ] Export tested

## Data

- [ ] Database tests passed
- [ ] Migration tests passed
- [ ] File integrity tested
- [ ] Deletion tested

## Privacy/Security

- [ ] Permissions tested
- [ ] Privacy Mode tested
- [ ] No unexpected uploads
- [ ] Logs reviewed
- [ ] EXIF/anonymization tested
- [ ] Secrets scan passed

## Performance

- [ ] Memory tested
- [ ] Thermal tested
- [ ] Battery tested
- [ ] Long session tested
- [ ] Representative devices tested

---

# 89. Final Release Gate

WISE Clinical Camera can be considered V1 release-ready when:

```text
P0 tests                  PASS
Core workflow             PASS
Original integrity        PASS
Before/After workflow     PASS
CV safety tests           PASS
Measurement validation    PASS
Privacy tests             PASS
Security checks           PASS
Offline tests             PASS
Performance tests         PASS
Migration tests           PASS
Representative devices   PASS
```

No unresolved Critical defect may remain.

---

# 90. Definition of Done

A feature is considered complete only when:

```text
Implementation
      ↓
Unit Tests
      ↓
Integration Tests
      ↓
Device Tests
      ↓
Edge Cases
      ↓
Privacy/Security
      ↓
Performance
      ↓
Regression
      ↓
Acceptance
```

A feature that works only in the developer environment is not complete.

---

# 91. Final Product Acceptance Principle

The ultimate test for WISE Clinical Camera is not:

> “Does the button work?”

It is:

> **“Does WISE help the user take a more reproducible photograph, preserve the original clinical evidence, protect the photograph, and remain usable when the technology is uncertain?”**

The release should therefore prioritize:

```text
Reliability
+
Reproducibility
+
Image Integrity
+
Privacy
+
Usability
```

over unnecessary AI complexity or feature count.
