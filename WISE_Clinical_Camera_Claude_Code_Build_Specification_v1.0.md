# WISE Clinical Camera
## Claude Code Build Specification v1.0

**Purpose:** Provide a direct implementation specification for Claude Code or another coding agent to build WISE Clinical Camera from the approved product, UX/UI, functional, data, computer-vision, privacy/security, AI/cost, and testing specifications.

**Platforms:** iOS and Android  
**Framework:** Flutter  
**Architecture:** Local-first, modular, privacy-first  
**Primary capture modes:** BEFORE / AFTER / PHOTO

---

# 1. Build Objective

Build a production-oriented cross-platform application named:

```text
WISE Clinical Camera
```

The application is part of the WiseAiTechs / WISE ecosystem.

The core purpose is standardized clinical photography.

The defining workflow is:

```text
BEFORE
   ↓
Reference
   ↓
AFTER
   ↓
Match
   ↓
Check
   ↓
Capture
   ↓
Compare
   ↓
Measure
   ↓
Export
```

The application must help reproduce the original photograph rather than simply act as a generic camera.

---

# 2. Non-Negotiable Principles

Claude Code must preserve these principles throughout implementation.

## 2.1 Original Is Immutable

Never overwrite the original photograph.

```text
Original
   +
Layers
   ↓
Derived Export
```

## 2.2 Local First

Core functionality must work without Internet access.

## 2.3 No Silent Upload

Clinical images must never be silently uploaded to a cloud service.

## 2.4 AI Is Optional

No mandatory AI API call is allowed for core photography.

## 2.5 Advanced Tools Are Optional

Users can enable or disable tools.

## 2.6 Preferences Persist

Persistent tool settings survive application restart.

## 2.7 Session Overrides Are Temporary

A one-capture override must not silently modify the saved default.

## 2.8 Capture Must Remain Possible

Advisory CV/quality warnings should normally not prevent capture.

## 2.9 Measurements Require Calibration

Never display centimetres, millimetres, area, or physical dimensions without valid scale calibration.

## 2.10 Privacy Is a Default

Secure/local behaviour must be the default, not an advanced configuration.

---

# 3. Recommended Project Structure

Create the Flutter project with a modular structure:

```text
lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── routes.dart
│   └── theme/
│
├── core/
│   ├── camera/
│   ├── imaging/
│   ├── sensors/
│   ├── cv/
│   ├── storage/
│   ├── database/
│   ├── security/
│   ├── permissions/
│   ├── logging/
│   └── platform/
│
├── features/
│   ├── home/
│   ├── capture/
│   ├── reference/
│   ├── alignment/
│   ├── overlay/
│   ├── lighting/
│   ├── focus/
│   ├── grid/
│   ├── level/
│   ├── calibration/
│   ├── measurement/
│   ├── annotation/
│   ├── comparison/
│   ├── export/
│   ├── cases/
│   ├── protocols/
│   ├── library/
│   ├── settings/
│   └── privacy/
│
├── services/
│   ├── ai/
│   ├── export/
│   └── sync/
│
├── models/
│
├── repositories/
│
└── shared/
    ├── widgets/
    ├── constants/
    ├── utils/
    └── extensions/
```

The exact structure may be adjusted if a cleaner architecture is achieved, but responsibilities must remain separated.

---

# 4. Technology Direction

Recommended:

```text
Flutter
Dart
SQLite
Filesystem
Native Camera APIs
Native Sensor APIs
Local CV
Optional On-Device ML
Optional AI Provider Adapter
```

Do not introduce a mandatory backend for V1.

---

# 5. Dependency Rules

Before adding a dependency:

1. Determine whether Flutter/Dart already provides the capability.
2. Determine whether a native platform API is sufficient.
3. Check maintenance status.
4. Check license compatibility.
5. Check iOS/Android support.
6. Check security history.
7. Check package size/performance.
8. Add only if justified.

Avoid dependency bloat.

---

# 6. Initial Setup

Claude Code should:

1. Create Flutter project.
2. Configure iOS and Android.
3. Configure supported minimum OS versions.
4. Add required permissions.
5. Configure application identifier.
6. Add app icon/splash assets when available.
7. Configure WiseAiTechs visual theme.
8. Establish linting.
9. Establish formatting.
10. Establish test structure.
11. Establish build scripts.

---

# 7. Design System

Use the WiseAiTechs design language already established for the product.

Primary characteristics:

- clean
- medical
- modern
- AI-aware
- structured
- premium
- readable
- restrained
- rounded
- action-oriented

Use the established brand tokens:

```text
Wise Blue     #243E8F
Wise Red      #D61F4B
Deep Navy     #101828
Slate Gray    #475467
Light Gray    #EAECF0
Soft BG       #F8FAFC
AI Blue       #3B82F6
System Cyan   #06B6D4
Success Green #16A34A
Warning Red   #DC2626
```

Primary font:

```text
Poppins
```

with appropriate fallbacks.

The camera screen must remain visually dominant.

---

# 8. Initial Navigation

The baseline application should be simple.

Primary actions:

```text
BEFORE
AFTER
PHOTO
```

Secondary navigation may include:

```text
Library
Cases
Protocols
Settings
```

Do not turn the home screen into a complex medical dashboard.

---

# 9. Home Screen

Implement:

```text
WISE Clinical Camera

[ BEFORE ] [ AFTER ] [ PHOTO ]

Recent
Library
Protocols
Settings
```

The exact visual layout should follow the UX/UI specification.

---

# 10. Capture Screen

The camera screen must contain:

```text
Live Camera Preview
Capture Button
Mode Indicator
Tools
Gallery/Reference Access
```

Optional tools should appear only when enabled.

---

# 11. Capture Architecture

Create:

```dart
abstract class CameraEngine {
  Future<void> initialize();
  Future<void> dispose();
  Stream<CameraFrame> get frames;
  Future<CapturedImage> capture();
  Future<void> setZoom(double value);
  Future<void> setFlash(FlashMode mode);
  Future<void> setFocus(...);
}
```

The implementation must be platform-aware.

Do not place iOS/Android camera-specific logic directly in feature screens.

---

# 12. Camera Capability Detection

At initialization detect:

- camera availability
- front/rear cameras
- supported resolutions
- zoom range
- flash
- focus support
- orientation
- sensor availability

Store capabilities in a runtime model.

Never assume identical camera features across devices.

---

# 13. BEFORE Implementation

Flow:

```text
Home
 ↓
BEFORE
 ↓
Optional protocol
 ↓
Optional metadata
 ↓
Camera
 ↓
Capture
 ↓
Review
 ↓
Save
```

After capture:

- save immutable original
- create database record
- create thumbnail
- store capture recipe
- store available camera metadata
- mark image as reference-capable

---

# 14. AFTER Implementation

Flow:

```text
Home
 ↓
AFTER
 ↓
Select Before
 ↓
Load reference
 ↓
Camera
 ↓
Overlay/Alignment
 ↓
Quality Checks
 ↓
Capture
 ↓
Review
 ↓
Save
```

An After image should store:

```text
referencePhotoId
```

---

# 15. PHOTO Implementation

PHOTO is a standalone camera workflow.

No reference is required.

The user can still use enabled tools where logically applicable.

---

# 16. Reference Picker

Implement a reusable reference picker.

Sources:

- WISE library
- recent Before images
- case
- device Gallery
- Files/import

The reference picker should prioritize Before images.

---

# 17. Reference Loader

When a reference is selected:

Load:

```text
original image
thumbnail
capture recipe
camera metadata
orientation
calibration if valid
protocol context
cached CV features where available
```

---

# 18. Ghost Overlay

Implement a local overlay layer.

Required controls:

```text
Opacity
Move
Scale
Rotate
Reset
Lock
```

Overlay must not modify the original.

---

# 19. Tool Manager

Create a central tool manager.

Conceptually:

```dart
class ToolState {
  bool overlay;
  bool alignment;
  bool lighting;
  bool focus;
  bool grid;
  bool level;
  bool measurement;
  bool annotation;
  bool difference;
}
```

The actual model can use immutable state management.

The tool manager must distinguish:

```text
User Default
Protocol Setting
Session Override
Effective Setting
```

---

# 20. Persistent Preferences

Persist:

```text
overlay
overlayOpacity
alignment
lighting
focus
grid
gridType
level
measurement
annotation
difference
comparisonMode
gallerySaveMode
privacyMode
```

Use SQLite or a dedicated local preferences store.

Do not use session memory for persistent preferences.

---

# 21. Session Override

Create a runtime-only override layer.

Example:

```text
Default:
Measurement = ON

Session:
Measurement = OFF
```

After the capture:

```text
Default remains ON
```

---

# 22. Settings Precedence

Implement:

```text
Platform Capability
       ↓
User Default
       ↓
Protocol
       ↓
Session Override
       ↓
Effective Setting
```

A platform limitation always wins.

---

# 23. Computer Vision Module

Create:

```text
AlignmentEngine
ReferenceFeatureEngine
TransformEstimator
GuidanceEngine
QualityEngine
```

The UI must not implement CV algorithms.

---

# 24. CV Pipeline

Implement the initial pipeline:

```text
Reference
 ↓
Normalize
 ↓
Feature Detection
 ↓
Descriptor Generation
 ↓
Live Frame
 ↓
Feature Matching
 ↓
Outlier Rejection
 ↓
Transform Estimation
 ↓
Confidence
 ↓
Guidance
```

---

# 25. Initial CV Technology

Evaluate an efficient local CV stack using:

- ORB/AKAZE-style feature detection
- descriptor matching
- RANSAC
- similarity/affine transformation
- homography when justified
- optional edge/template matching

Do not assume the first algorithm selected is production-ready.

Benchmark it.

---

# 26. Alignment Result Model

Create:

```text
AlignmentResult
├── status
├── confidence
├── translationX
├── translationY
├── rotation
├── scale
├── perspective
├── transform
├── guidance
├── metrics
└── engineVersion
```

Statuses:

```text
GOOD
FAIR
POOR
UNAVAILABLE
```

---

# 27. Alignment Guidance

Translate CV output into human instructions.

Examples:

```text
Move left
Move right
Move up
Move down
Move closer
Move farther
Rotate slightly left
Rotate slightly right
Tilt upward
Tilt downward
```

Do not expose technical CV errors to normal users.

---

# 28. Alignment Confidence

Confidence must be based on multiple signals, potentially including:

- feature quality
- inlier ratio
- spatial distribution
- reprojection error
- transformation stability
- sensor agreement
- image similarity

The weighting must be benchmarked.

Do not label the result as clinical accuracy.

---

# 29. Manual Alignment Fallback

If automatic alignment is unavailable:

```text
Automatic alignment unavailable.
```

Then allow:

```text
Manual Position
Manual Scale
Manual Rotation
Reset
Lock
Capture
```

---

# 30. Capture Warning System

Warnings may include:

```text
Alignment Fair
Lighting Different
Image May Be Blurred
Orientation Different
```

Default action:

```text
Capture Anyway
```

Hard blocking is only allowed when explicitly configured by a protocol.

---

# 31. Lighting Engine

Implement locally using image statistics.

Potential metrics:

- average luminance
- luminance distribution
- highlights
- shadows
- histogram similarity
- flash state
- exposure metadata

Return:

```text
GOOD
SIMILAR
DIFFERENT
TOO_DARK
TOO_BRIGHT
UNAVAILABLE
```

---

# 32. Focus Engine

Implement local focus/blur detection.

Potential method:

```text
Laplacian variance
```

where technically suitable.

Return:

```text
GOOD
MAY_BE_BLURRED
UNAVAILABLE
```

Thresholds must be configurable for testing.

---

# 33. Grid

Implement:

```text
3×3
4×4
Centre Crosshair
```

The grid exists only as a display/export layer.

Never burn it into the original.

---

# 34. Level

Use available:

- accelerometer
- gyroscope
- device orientation

Provide a simple visual level.

Handle unavailable sensors gracefully.

---

# 35. Calibration

Implement:

```text
CalibrationService
```

Supported methods:

```text
RULER
MARKER
MANUAL
```

Manual flow:

```text
Draw known-distance line
 ↓
Enter value
 ↓
Select unit
 ↓
Save
```

---

# 36. Calibration Mathematics

Given:

```text
pixelDistance
knownDistance
```

calculate:

```text
pixelsPerUnit =
pixelDistance / knownDistance
```

Validate:

```text
knownDistance > 0
pixelDistance > 0
```

---

# 37. Measurement Engine

Implement:

```text
Length
Width
Diameter
Perimeter
Area
```

Optional future:

```text
Angle
```

Store geometry separately from calculated display values.

---

# 38. Measurement Safety

Without calibration:

```text
Pixel measurement available
Physical measurement unavailable
```

Never display:

```text
3.4 cm
```

without valid calibration.

---

# 39. Annotation Engine

Implement:

```text
Pen
Arrow
Circle
Rectangle
Point
Line
Text
Measurement Line
```

Annotations are independent objects.

---

# 40. Layer Engine

Implement a non-destructive layer model:

```text
Original
Reference
Measurements
Annotations
Grid
Labels
Footer
```

Each layer can be:

```text
visible
hidden
edited
deleted
exported
```

---

# 41. Comparison Engine

Implement:

```text
SIDE_BY_SIDE
SLIDER
OVERLAY
BLINK
DIFFERENCE
```

Reuse existing alignment data where valid.

---

# 42. Difference View

Pipeline:

```text
Before
 ↓
Registration
 ↓
Aligned Before
 ↓
After
 ↓
Difference
```

Display disclaimer:

```text
Visual difference only.
This does not provide a medical diagnosis.
```

---

# 43. Measurement Change

When both Before and After measurements are valid:

```text
change = after - before

percentage =
((after - before) / before) × 100
```

Handle:

```text
before == 0
```

without crashing.

---

# 44. Case System

Implement optional cases.

A photo can exist without a case.

Case fields:

```text
id
localReference
title
notes
createdAt
updatedAt
```

Avoid unnecessary patient-identifying fields.

---

# 45. Protocol System

Implement reusable protocols.

Example:

```text
Dermatology Standard
Physiotherapy Standard
Wound Documentation
Posture Standard
General Clinical Photo
```

Protocol configuration should include:

```text
tools
camera preferences
alignment threshold
lighting requirements
measurement requirement
export configuration
```

---

# 46. Protocol Versioning

Every protocol must have a version.

Historical photographs must retain the protocol version/context used during capture.

Editing a protocol must not rewrite historical capture records.

---

# 47. Export System

Implement presets:

```text
ORIGINAL
ANNOTATED
MEASURED
BEFORE_AFTER
BEFORE_AFTER_MEASUREMENTS
ANONYMIZED
REPORT_READY
```

---

# 48. Export Architecture

Never modify original.

```text
Original
+
Selected Layers
+
Export Configuration
 ↓
Derived Export
```

---

# 49. Anonymized Export

Allow removal of unnecessary metadata.

Potentially remove:

- GPS
- device-specific information
- unnecessary timestamps
- identifying EXIF fields

Document exactly what is removed.

---

# 50. Gallery Saving

Implement:

```text
ASK
ALWAYS
NEVER
```

Respect Privacy Mode.

Gallery copy must remain independent from the WISE original.

---

# 51. Privacy Mode

When ON:

```text
No automatic Gallery saving
No cloud AI
No third-party image processing
Local processing preferred
```

---

# 52. Permission Manager

Create:

```text
PermissionService
```

Handle:

```text
Camera
Photos/Gallery
Files
```

Request permissions only when required.

---

# 53. Local Storage

Use application-private storage for originals.

Suggested logical folders:

```text
originals/
thumbnails/
derived/annotated/
derived/measured/
derived/comparison/
derived/exports/
temp/
backups/
```

Use opaque UUID-based filenames.

---

# 54. Database

Implement SQLite with migrations.

Core tables:

```text
users
user_preferences
cases
protocols
photos
photo_metadata
calibrations
measurements
annotations
alignments
quality_checks
derived_assets
comparisons
exports
gallery_exports
```

Optional:

```text
events
```

---

# 55. Database Rules

Enable:

```sql
PRAGMA foreign_keys = ON;
```

Use UUID primary keys.

Do not rely on auto-increment IDs for core entities.

---

# 56. Photo Record

Minimum fields:

```text
id
user_id
case_id
type
original_path
thumbnail_path
captured_at
body_part
laterality
reference_photo_id
protocol_id
width_px
height_px
file_size_bytes
mime_type
checksum
source
metadata_json
capture_recipe_json
status
created_at
updated_at
deleted_at
version
```

---

# 57. File/Database Transaction

Use:

```text
Create temporary file
 ↓
Verify file
 ↓
Move to final location
 ↓
Commit DB record
```

If database write fails, clean the orphan file.

If processing fails, retain the original.

---

# 58. Photo Lifecycle

Implement:

```text
CAPTURE
 ↓
TEMPORARY
 ↓
ORIGINAL SAVED
 ↓
DB RECORD
 ↓
THUMBNAIL
 ↓
OPTIONAL PROCESSING
 ↓
DERIVED ASSETS
```

---

# 59. Deletion

Do not use unrestricted database cascade deletion.

When deleting a photo:

1. Warn if referenced.
2. Soft delete where appropriate.
3. Remove/invalidate dependent derived assets.
4. Handle measurements and annotations.
5. Handle comparisons.
6. Keep independent Gallery copies separate.

---

# 60. Thumbnail System

Generate thumbnails asynchronously.

Use thumbnails for:

- library
- reference picker
- recent images

Do not load full-resolution originals unnecessarily.

---

# 61. Performance Architecture

Use background processing for:

- image decoding
- thumbnail generation
- CV
- exports
- large image processing

Keep the camera preview responsive.

---

# 62. Memory Rules

Never keep unnecessary copies of full-resolution images.

Use:

```text
preview frame
↓
CV working image
↓
full-resolution capture only when required
```

Release buffers promptly.

---

# 63. Offline Architecture

The following must work in airplane mode:

```text
Capture
Reference
Overlay
Alignment
Lighting
Focus
Grid
Level
Calibration
Measurement
Annotation
Comparison
Export
```

Cloud AI may be unavailable.

---

# 64. AI Architecture

Create:

```text
AIService
```

behind provider abstraction.

Conceptually:

```text
AIProvider
├── OnDeviceAIProvider
├── SelfHostedAIProvider
└── CloudAIProvider
```

No feature should directly depend on a specific vendor SDK.

---

# 65. AI Defaults

Recommended:

```text
Cloud AI = OFF
```

Core application must work with:

```text
AI = OFF
```

---

# 66. AI Routing

Use:

```text
Sensors
 ↓
CV
 ↓
On-device ML
 ↓
Self-hosted AI
 ↓
Cloud AI
```

Only move to a higher-cost layer when required.

---

# 67. Cloud AI

If implemented:

- explicit user configuration
- explicit permission/authorization
- secure transport
- clear destination
- no silent fallback
- usage tracking
- cost controls

---

# 68. AI Cost Controls

Support future:

```text
request limits
monthly budget
provider selection
model selection
Wi-Fi-only
usage statistics
```

Do not implement unnecessary billing infrastructure in V1.

---

# 69. Security

Implement:

- application sandbox
- secure local storage
- secure secrets
- platform secure storage
- privacy-safe logs
- no hard-coded API keys
- no image analytics
- no silent upload

---

# 70. Secrets

Never commit:

```text
API keys
passwords
tokens
private certificates
encryption secrets
```

Use secure development configuration.

---

# 71. Logging

Production logs must not contain:

- image pixels
- patient names
- clinical notes
- sensitive identifiers
- API keys
- passwords
- encryption keys

Development logs may contain technical CV metrics without image content.

---

# 72. Network Control

Core camera functionality should make no network request.

Any network feature must be isolated behind a service.

This allows network traffic to be audited.

---

# 73. Privacy Testing Hook

Add a development/test facility that can record or inspect outbound network requests.

V1 should be able to demonstrate:

```text
Core capture
→ no external image request
```

---

# 74. Testing Structure

Create:

```text
test/
├── unit/
├── integration/
├── widget/
├── database/
├── cv/
├── privacy/
├── security/
└── performance/
```

---

# 75. Mandatory Unit Tests

Implement tests for:

- calibration mathematics
- measurement mathematics
- percentage change
- zero handling
- settings precedence
- protocol precedence
- validation
- state transitions
- UUID/reference relationships

---

# 76. Mandatory Database Tests

Test:

- photo CRUD
- case CRUD
- protocol CRUD
- Before/After relationships
- calibration relationships
- measurement relationships
- annotation relationships
- comparison relationships
- soft deletion
- migration

---

# 77. Mandatory CV Tests

Test:

```text
translation
rotation
scale
perspective
low texture
false matches
spatially concentrated features
subject movement
lighting change
blur
```

Maintain a fixed regression dataset.

---

# 78. CV Acceptance

Do not define arbitrary clinical accuracy percentages.

Instead establish experimentally:

```text
translation error
rotation error
scale error
reprojection error
inlier ratio
false-alignment rate
failure rate
latency
```

---

# 79. Mandatory Privacy Tests

Verify:

- no cloud request in core workflow
- Gallery preference
- Privacy Mode
- anonymized export
- metadata stripping
- secure logs
- deletion behaviour
- independent Gallery copy

---

# 80. Mandatory Performance Tests

Test:

- camera startup
- preview responsiveness
- overlay
- CV latency
- memory
- thermal
- battery
- long sessions
- large images

---

# 81. End-to-End Test

The coding agent must implement and verify:

```text
Create Before
 ↓
Save
 ↓
Select Before
 ↓
Enable Overlay
 ↓
Enable Alignment
 ↓
Capture After
 ↓
Review
 ↓
Calibrate
 ↓
Measure
 ↓
Annotate
 ↓
Compare
 ↓
Export
```

---

# 82. First Build Milestone

Do not attempt every feature simultaneously.

Build in this order:

## Milestone 1 — Camera Foundation

```text
Home
Before
Photo
Camera
Capture
Local Storage
Review
```

## Milestone 2 — Reference Workflow

```text
After
Reference Picker
Ghost Overlay
Opacity
Transform
Lock
```

## Milestone 3 — Reproducibility

```text
Sensors
Alignment
Guidance
Lighting
Focus
Grid
Level
```

## Milestone 4 — Clinical Tools

```text
Calibration
Measurement
Annotation
Comparison
```

## Milestone 5 — Workflow

```text
Cases
Protocols
Library
Export
Anonymization
```

## Milestone 6 — AI

```text
AI abstraction
On-device ML
Optional external provider
```

---

# 83. Build Discipline

After each milestone:

```text
Build
 ↓
Run tests
 ↓
Run on iOS
 ↓
Run on Android
 ↓
Fix regressions
 ↓
Commit
```

Do not stack many untested features together.

---

# 84. Claude Code Instructions

Claude Code should work in small, verifiable increments.

For each task:

1. Inspect current project.
2. Read relevant specification.
3. Identify dependencies.
4. Implement the smallest complete change.
5. Add tests.
6. Run formatter.
7. Run analyzer.
8. Run relevant tests.
9. Build affected platform(s).
10. Report files changed.
11. Report tests run.
12. Report known limitations.

---

# 85. Never Guess Missing Requirements

If a requirement is genuinely unspecified:

```text
Do not invent a clinical rule.
```

Prefer:

```text
configurable constant
+
documented TODO
+
safe fallback
```

Do not silently invent clinical thresholds.

---

# 86. Configuration Over Hard-Coding

Use configuration for:

- CV thresholds
- blur thresholds
- lighting thresholds
- alignment thresholds
- thumbnail sizes
- supported units
- feature flags
- export defaults

This allows testing without rebuilding the architecture.

---

# 87. Debug Mode

Implement a development-only diagnostics mode.

Possible information:

```text
FPS
CV processing time
Keypoints
Matches
Inliers
Alignment confidence
Transform
Memory
Camera capability
```

Do not expose sensitive image data.

---

# 88. CV Debug Overlay

Development builds may display:

```text
Keypoints
Match lines
Inliers
ROI
Transform
Confidence
```

This must be disabled in production builds.

---

# 89. Feature Flags

Implement feature flags for:

```text
alignment
homography
optical_flow
lighting_check
focus_check
on_device_ai
cloud_ai
difference_view
protocols
```

This makes experimental features easy to isolate.

---

# 90. Error Handling

All services should return typed errors.

Examples:

```text
CameraPermissionDenied
CameraUnavailable
StorageUnavailable
ReferenceUnavailable
AlignmentUnavailable
CalibrationInvalid
MeasurementInvalid
ExportFailed
AIUnavailable
NetworkUnavailable
```

UI translates technical errors into understandable messages.

---

# 91. User-Facing Error Rule

Never display raw exceptions.

Avoid:

```text
PlatformException(...)
```

Use:

```text
Camera access is unavailable.
```

---

# 92. Crash Prevention

Handle:

- permission denial
- camera initialization failure
- missing file
- corrupt image
- database error
- CV failure
- export failure
- network timeout
- AI timeout
- low storage
- app interruption

---

# 93. Accessibility

Implement:

- semantic labels
- VoiceOver
- TalkBack
- accessible touch targets
- readable text
- non-colour-only status
- reduced-motion support

The capture action must remain easy to identify.

---

# 94. Platform Differences

Do not force identical implementation where platforms differ.

Document differences in:

- camera APIs
- Gallery permissions
- background behaviour
- biometrics
- screenshot controls
- sensor availability
- filesystem behaviour

---

# 95. Build Configuration

Create:

```text
development
staging
production
```

where useful.

Development may enable:

```text
CV debug
verbose logs
test datasets
mock providers
```

Production must disable these.

---

# 96. CI/CD

Recommended automated checks:

```text
flutter analyze
flutter test
format check
dependency audit
secret scan
iOS build
Android build
```

Add platform-specific checks where CI infrastructure permits.

---

# 97. Git Discipline

Use small commits.

Recommended pattern:

```text
feat: add camera foundation
feat: add before capture
feat: add reference picker
feat: add ghost overlay
feat: add alignment engine
test: add alignment regression suite
fix: preserve original image
```

Never commit secrets or generated sensitive test images.

---

# 98. Documentation During Build

Maintain:

```text
README.md
ARCHITECTURE.md
CHANGELOG.md
docs/
```

Document:

- setup
- build commands
- platform requirements
- CV dependencies
- test instructions
- privacy behaviour
- known limitations

---

# 99. Required Developer Documentation

The repository should contain:

```text
docs/
├── product/
├── architecture/
├── database/
├── cv/
├── privacy/
├── ai/
├── testing/
└── deployment/
```

The specifications supplied for WISE should be referenced from this documentation.

---

# 100. No Premature Backend

Do not build:

```text
User authentication server
Clinical image server
Mandatory cloud database
Mandatory AI API
```

unless a later approved requirement explicitly requires them.

---

# 101. Future-Ready Interfaces

Even when the implementation is local-only, create interfaces for:

```text
SyncService
AIService
BackupService
CloudStorageService
```

These can initially have:

```text
NotImplemented
```

or local-only implementations.

Do not build unused infrastructure.

---

# 102. Repository Layer

UI must not access SQLite directly.

Use:

```text
UI
 ↓
Controller/ViewModel
 ↓
Repository
 ↓
Database Service
```

For images:

```text
Feature
 ↓
Repository
 ↓
ImageStorageService
 ↓
Filesystem
```

---

# 103. State Management

Use a consistent state-management pattern.

The exact package can be selected based on project preference, but state must clearly separate:

```text
persistent state
session state
processing state
UI state
```

---

# 104. Processing Jobs

Long operations should use jobs.

Examples:

```text
ThumbnailJob
CVJob
ExportJob
ComparisonJob
AIJob
```

Jobs should expose:

```text
queued
running
complete
failed
cancelled
```

---

# 105. Original Recovery

If:

```text
CV fails
AI fails
Export fails
Thumbnail fails
Comparison fails
```

the original photograph must remain usable.

This is a P0 requirement.

---

# 106. Storage Recovery

Implement safe cleanup for:

- temporary files
- orphaned derived files
- incomplete exports

Do not automatically delete suspicious original files.

---

# 107. Library

The library should use:

```text
thumbnail
+
metadata
```

rather than loading full images for every item.

Future filters:

```text
date
type
body part
laterality
case
protocol
```

---

# 108. Search

Search should remain local in V1.

Do not upload the user's library to implement search.

---

# 109. Body Part

Support at minimum:

```text
Face
Scalp
Neck
Chest
Abdomen
Back
Shoulder
Arm
Elbow
Forearm
Hand
Hip
Thigh
Knee
Leg
Ankle
Foot
Other
```

---

# 110. Laterality

Support:

```text
Left
Right
Both
Not Applicable
```

All optional.

---

# 111. Metadata Policy

Store only useful metadata.

Potentially sensitive metadata such as GPS should be controlled.

Anonymized exports must follow the configured metadata policy.

---

# 112. Clinical Measurement Disclaimer

Where appropriate, display:

```text
Photographic measurement. Accuracy depends on calibration and capture geometry.
```

Do not claim medical-grade measurement accuracy without validation.

---

# 113. AI Disclaimer

For non-clinical AI assistance, clearly distinguish:

```text
AI-generated assistance
```

from:

```text
clinical fact
```

Do not present experimental AI output as validated diagnosis.

---

# 114. Acceptance Gates

Before moving to the next milestone:

```text
P0 tests PASS
No critical data-loss issue
No original-image corruption
No unexpected network upload
No unresolved build failure
```

---

# 115. Final V1 Acceptance

The build is V1-ready only when:

```text
✓ iOS build works
✓ Android build works
✓ Camera works
✓ BEFORE works
✓ AFTER works
✓ PHOTO works
✓ Reference works
✓ Overlay works
✓ Alignment works on supported test cases
✓ Lighting check works
✓ Focus check works
✓ Grid works
✓ Level works
✓ Calibration works
✓ Measurement works
✓ Annotation works
✓ Comparison works
✓ Export works
✓ Privacy Mode works
✓ Offline core workflow works
✓ Preferences persist
✓ Session overrides work
✓ Original images remain immutable
✓ Database migrations work
✓ P0 test suite passes
```

---

# 116. Final Build Order

Claude Code should follow this exact broad order:

```text
1. Project Foundation
        ↓
2. Design System
        ↓
3. Camera Engine
        ↓
4. Local Storage
        ↓
5. BEFORE
        ↓
6. PHOTO
        ↓
7. Reference Picker
        ↓
8. AFTER
        ↓
9. Ghost Overlay
        ↓
10. Persistent Tools
        ↓
11. Sensors
        ↓
12. Alignment CV
        ↓
13. Lighting/Focus
        ↓
14. Grid/Level
        ↓
15. Calibration
        ↓
16. Measurement
        ↓
17. Annotation
        ↓
18. Comparison
        ↓
19. Cases
        ↓
20. Protocols
        ↓
21. Export/Anonymization
        ↓
22. Privacy/Security Hardening
        ↓
23. Testing
        ↓
24. Optional AI
        ↓
25. Release
```

---

# 117. Definition of Done for the Coding Agent

Claude Code must not declare the project complete merely because the application compiles.

Completion requires:

```text
Implementation
+
Automated tests
+
iOS test
+
Android test
+
CV validation
+
Privacy validation
+
Security validation
+
Performance validation
+
Regression testing
+
Documentation
```

---

# 118. Final Instruction to Claude Code

Build WISE Clinical Camera as a **reliable clinical photography engine**, not as a generic camera app and not as an AI demo.

The central experience must remain:

```text
BEFORE
AFTER
PHOTO
```

The technical complexity should remain behind the interface.

When possible:

```text
Sensors solve it.
```

Otherwise:

```text
Computer vision solves it.
```

Otherwise:

```text
On-device ML solves it.
```

Otherwise:

```text
Self-hosted AI.
```

Only when justified:

```text
Cloud AI.
```

Always:

```text
Protect the original.
Protect the user's data.
Keep the core offline.
Keep the camera usable.
Keep the architecture reusable.
```

The first implementation should prioritize a stable camera and Before/After reference workflow. Advanced CV, measurement, AI and cloud functionality must be added incrementally with tests at every stage.

The final product should make sophisticated technology feel simple:

> **Match → Check → Capture → Compare → Measure → Export**
