# WISE Clinical Camera

## Project Status & AI Handoff Document

**Document:** `docs/PROJECT_STATUS.md`
**Product:** WISE Clinical Camera
**Organization:** WiseAiTechs
**Tagline:** For All Medicos
**Document Version:** 1.0
**Status:** Phase 2 COMPLETE / Phase 3 IN PROGRESS
**Last Updated:** 2026-09-04

---

# 1. PURPOSE OF THIS DOCUMENT

This file is the **current-state source of truth for AI-assisted development** of WISE Clinical Camera.

Any developer or AI coding agent joining the project must be able to understand the current state of the project from the repository without relying on:

* previous Claude conversations
* ChatGPT conversations
* Slack/WhatsApp discussions
* undocumented decisions
* personal memory
* previous AI session context

If an important project decision, implementation status, limitation, defect, or release blocker exists, it should be recorded in the repository.

> **Permanent Rule: If the project needs to remember it, GitHub must remember it.**

This document must therefore be updated whenever the project's meaningful state changes.

---

# 2. PRODUCT IDENTITY

## Product Name

**WISE Clinical Camera**

## Ecosystem

WISE / WiseAiTechs

## Primary Purpose

WISE Clinical Camera is a standardized clinical photography application designed to make clinical photographs:

* reproducible
* comparable
* measurable where calibration permits
* annotatable
* organized
* privacy-preserving
* offline-first
* suitable for clinical documentation

The initial focus is dermatology, but the architecture must support broader clinical photography workflows.

Potential future areas include:

* dermatology
* wounds
* scars
* swelling
* bruising
* physiotherapy
* rehabilitation
* posture
* joints
* hands
* face
* dental documentation
* clinical reports
* other photographic clinical workflows

---

# 3. CORE PRODUCT CONCEPT

The main workflow is:

**MATCH → CHECK → CAPTURE → COMPARE → MEASURE → EXPORT**

The photograph must remain the hero of the experience.

The UI should not overwhelm the clinician with unnecessary controls.

Advanced tools should remain optional.

---

# 4. PRIMARY PHOTO MODES

## BEFORE

Creates the reference photograph.

The Before photograph establishes the reference state for future comparison.

## AFTER

Creates a follow-up photograph based on an existing Before/reference photograph.

The system should attempt to reproduce:

* camera orientation
* position
* framing
* scale
* zoom
* body region
* laterality
* capture protocol
* lighting conditions
* other available capture parameters

## PHOTO

Standalone photograph without requiring a Before reference.

---

# 5. CORE DIFFERENTIATOR

The main differentiator is **reproducibility**.

The system should help a clinician take the same photograph again rather than merely taking another photograph of the same patient.

The application should therefore preserve and reuse the original capture "recipe."

---

# 6. AGREED FEATURES

The following product capabilities have been approved conceptually.

## Reference / Ghost Overlay

* Display Before image as a reference overlay.
* Adjustable opacity.
* Used to reproduce framing and positioning.
* Reference image must never overwrite the new photograph.

## Automatic Alignment Guidance

Possible technologies include:

* sensor alignment
* feature detection
* descriptor matching
* optical flow
* image registration
* homography
* edge maps
* template matching
* SSIM
* perspective transformation

Thresholds must be experimentally validated.

## Lighting Check

Possible signals:

* luminance
* exposure
* histogram comparison
* white-balance state
* flash state
* brightness differences

Lighting guidance should not claim clinical equivalence unless validated.

## Focus / Blur Check

Possible techniques include:

* Laplacian variance
* sharpness metrics
* blur detection
* image-quality heuristics

The system must allow the user to override warnings.

## Grid

Supported grid concepts:

* 3 × 3
* 4 × 4
* center crosshair

## Level / Tilt Guide

Provide orientation guidance using device sensors where available.

## Measurement

Support:

* length
* width
* diameter
* perimeter
* area
* multiple measurements

Measurements may be displayed on the image and/or in an export footer.

## Calibration

Real-world measurements require calibration.

Possible calibration methods:

* physical ruler
* calibration marker
* calibration card
* manually entered known distance

The application must never present pixels as centimeters or millimeters without valid calibration.

Perspective can reduce measurement accuracy.

Measurements should therefore be described as photographic measurements unless validated otherwise.

No clinical measurement accuracy claims should be made without validation evidence.

## Annotation

Supported annotation concepts:

* pen
* arrow
* circle
* rectangle
* point
* line
* text
* measurement line

Annotations should be non-destructive.

## Non-Destructive Layers

Potential layers:

* reference
* measurements
* annotations
* labels
* grid
* export formatting

The original photograph must remain immutable.

## Comparison

Supported comparison concepts:

* side-by-side
* slider
* overlay
* blink
* difference

Comparison should reuse alignment information where possible.

## Before / After Measurement Comparison

If both photographs are calibrated, the system may calculate measurement changes.

No unsupported clinical interpretation should be generated.

## Metadata

Optional capture metadata:

* body part
* laterality
* case
* protocol
* timestamp
* camera metadata where available

## Capture Protocols

Reusable protocols should be supported.

Examples:

* Dermatology Standard
* Physiotherapy Standard

Protocol configuration may control:

* tools
* alignment
* lighting checks
* focus checks
* measurement
* grid
* capture thresholds
* export settings

## Reference Lock

Once the clinician has positioned the camera appropriately, the reference configuration can be locked.

## Capture Recipe

The Before photograph should retain the capture recipe.

The recipe can include:

* orientation
* zoom
* flash
* grid
* lighting configuration
* alignment configuration
* calibration
* body region
* laterality
* protocol
* other reproducibility settings

The recipe should be immutable for the historical Before capture.

## Gallery Saving

Preference:

* Ask every time
* Always
* Never

## WISE Clinical Photos Album

Use the platform's supported photo-library capabilities where available.

## Privacy Mode

Privacy Mode should support:

* no automatic Gallery copy
* no cloud upload
* no third-party AI processing
* local-first operation

## Anonymized Export

Support removal of metadata where applicable.

## Offline First

Core functionality must work without Internet connectivity.

## AI

AI is optional.

AI is not a core requirement for initial product functionality.

Preferred processing order:

1. device sensors
2. classical computer vision
3. on-device ML
4. self-hosted AI
5. cloud AI

Cloud AI must never be silently used.

## Account

Basic capture should not require an account.

## Case Linking

Case linking may be performed after capture where appropriate.

## Export Presets

Planned presets:

* Original
* Annotated
* Measured
* Before + After
* Before + After + Measurements
* Anonymized
* Report-ready

## Capture Quality Warnings

Warnings may be shown for:

* alignment
* lighting
* focus
* other quality issues

The user should normally have a:

**Capture Anyway**

override.

Future protocols may enforce hard thresholds where explicitly configured.

---

# 7. ORIGINAL IMAGE IMMUTABILITY

This is a fundamental architectural rule.

The original photograph must never be overwritten.

Derived outputs must be generated separately.

Conceptually:

```text
Original Photo
      |
      +---- Annotation Layer
      +---- Measurement Layer
      +---- Comparison
      +---- Export
```

Any editing or export operation must preserve the original.

---

# 8. ARCHITECTURE

Preferred architecture:

* Flutter
* native bridges for platform-specific capabilities
* SQLite for structured local data
* filesystem for photographs
* local-first operation
* reusable camera abstraction
* local CV first
* AI behind an abstraction
* optional future synchronization

Suggested structure:

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

---

# 9. CORE DATA ENTITIES

Primary entities:

* User
* Case
* Photo
* Calibration
* Measurement
* Annotation
* Protocol

Photo should contain concepts including:

```text
id
caseId
type
filePath
originalFilePath
capturedAt
bodyPart
laterality
metadata
referencePhotoId
protocolId
```

Stable IDs should be used so future synchronization remains possible.

---

# 10. PERSISTENT SETTINGS

Persistent preferences include concepts such as:

* overlay
* alignment
* lighting
* focus
* grid
* level
* measurement
* annotation
* difference
* comparison mode

There must be a clear precedence model between:

1. saved user preference
2. protocol settings
3. temporary session override
4. capture-specific state

Do not accidentally destroy unrelated settings when activating a protocol.

---

# 11. CURRENT REPOSITORY STATE

Phase 2 began with a documentation-only repository.

At the beginning of Phase 2:

* 10 specification documents
* approximately 17,754 lines of specification
* no application implementation
* no assets
* no CI

Phase 2 subsequently created the Flutter application foundation and implemented substantial portions of the planned architecture.

---

# 12. PHASE 2 IMPLEMENTATION

Phase 2 created:

* Flutter scaffolding
* design system
* domain models
* settings precedence
* SQLite database
* filesystem storage
* repositories
* measurement engine
* computer-vision engine
* camera abstraction
* sensor abstraction
* privacy layer
* AI abstraction
* UI foundation
* library
* reference picker
* comparison
* calibration
* cases
* protocols
* settings
* CI/documentation foundation
* reconciliation service
* lifecycle protections
* image rendering protections
* several regression tests

---

# 13. PHASE 2 VALIDATION

Final Phase 2 state reported:

```text
dart format --set-exit-if-changed lib test
150 files
0 changed

flutter analyze
No issues

flutter test
524 passed
0 failed

flutter test --coverage
77.6% line coverage
4576 / 5900 lines

flutter build linux --release
Successful
Approximately 7.6 MB libapp.so
```

These results describe the Phase 2 validation state.

They must not be interpreted as proof of mobile hardware readiness.

---

# 14. PHASE 2 DEFECTS FOUND AND FIXED

The following defects were identified and addressed during Phase 2:

1. Malformed image buffers could cause `RangeError`.
2. BRIEF descriptors lacked scale invariance.
3. Accelerometer roll calculation used incorrect sign/formula.
4. Measurement pairing mutated widget state during build.
5. Library grid thumbnail rendering was broken.
6. Protocol hard alignment threshold was not reaching capture decision.
7. Controllers could write state after disposal.
8. Arrowhead rendering differed between screen and export at low stroke.
9. Footer after resize could exceed max dimension.
10. Multiple full-resolution image widgets were unbounded.
11. DB/filesystem reconciliation service was missing.
12. Capture controller cleanup could throw.
13. Protocol activation could discard settings outside the tool list.
14. Widget tests could hang due fake-clock behavior.
15. Thumbnail/detail rendering regressions were identified and fixed.
16. Controller lifecycle tests were added.

---

# 15. CURRENT IMPORTANT LIMITATIONS

The following limitations existed at the end of Phase 2 and must be treated honestly.

## Mobile Build Validation

Android and iOS builds had not been fully validated because the required environment was not available.

At Phase 2 completion:

* Android SDK validation was unavailable
* macOS/Xcode validation was unavailable

Do not claim Android/iOS release readiness without actual build evidence.

## Real Camera Validation

No complete real-world camera workflow had been validated.

A Linux build passing is not equivalent to:

* Android camera validation
* iPhone camera validation
* physical-device validation

## Clinical Image Validation

No clinical image had been fully validated through the complete alignment pipeline.

## Computer Vision

CV thresholds remain provisional.

Synthetic tests are not sufficient evidence of clinical robustness.

## Camera Plugin

`plugin_camera_engine.dart` had effectively no meaningful test coverage at the Phase 2 report stage.

Real-device testing is required.

## Metadata Workflow

Data model support existed for:

* body part
* laterality
* case

but the complete UI caller workflow was incomplete at the Phase 2 stage.

## C-019

A specification conflict related to at-rest encryption was recorded as:

**C-019**

The conflict must be resolved/documented rather than silently ignored.

---

# 16. RELEASE STATUS

At the end of Phase 2:

**NOT RELEASE READY**

This statement must remain true until the relevant release gates have evidence.

Use these status labels accurately:

```text
IMPLEMENTED
IMPLEMENTED — NOT VALIDATED
SOFTWARE VERIFIED — HARDWARE VALIDATION PENDING
OPEN DECISION
BLOCKED — ENVIRONMENT
VALIDATED
RELEASE BLOCKER
```

Never convert an implementation into a validated feature without evidence.

---

# 17. PHASE 3 OBJECTIVE

Phase 3 is intended to move the project from a substantial software foundation toward a **functionally complete clinical photography workflow**.

Phase 3 must concentrate on:

* complete capture workflow
* body part
* laterality
* case linking
* capture context
* Before/After inheritance
* capture recipe
* camera capability honesty
* lifecycle correctness
* protocol behavior
* library
* filtering
* photo detail
* multiple After photos
* calibration
* measurements
* annotations
* comparison
* exports
* real-image validation
* CV validation protocol
* platform validation
* camera plugin validation
* permissions
* lifecycle
* rotation
* performance
* memory
* privacy
* security
* network audit
* database integrity
* accessibility
* test quality
* coverage
* documentation
* release gates

---

# 18. PHASE 3 NON-GOALS

Do not expand Phase 3 unnecessarily.

The following should not become uncontrolled scope:

* cloud backend
* authentication platform
* social features
* unnecessary AI features
* cloud image processing
* premature synchronization
* unrelated WISE products

AI integration is explicitly not required for Phase 3.

---

# 19. AI DEVELOPMENT RULES

Any AI coding agent working on this repository must:

1. Read the repository before making assumptions.
2. Treat repository documentation as the source of truth.
3. Inspect existing code before creating new architecture.
4. Avoid duplicating existing functionality.
5. Preserve existing APIs unless change is necessary.
6. Update documentation with meaningful implementation changes.
7. Add or update tests with behavior changes.
8. Never claim unsupported functionality.
9. Never fabricate validation evidence.
10. Never silently resolve specification conflicts.
11. Keep changes focused.
12. Avoid unnecessary dependencies.
13. Prefer open-source/local/on-device solutions.
14. Avoid cloud services unless explicitly approved.
15. Preserve original photographs.
16. Preserve privacy-first architecture.
17. Maintain offline-first functionality.
18. Keep AI optional.
19. Maintain future portability across AI coding tools.
20. Leave the repository in a state another AI can continue from.

---

# 20. DOCUMENTATION IS PART OF THE IMPLEMENTATION

Documentation is not an optional final step.

Whenever implementation changes, update the appropriate documentation.

Potential documents include:

```text
README.md
docs/PROJECT_STATUS.md
docs/PROJECT_KNOWLEDGE_MAP.md
docs/REQUIREMENTS_TRACEABILITY.md
docs/SPECIFICATION_CONFLICTS.md
docs/RELEASE_GATES.md
docs/PHASE_3_PLAN.md
docs/PHASE_3_COMPLETION_REPORT.md
docs/WISE_Clinical_Camera_PRD_v1.0.md
docs/WISE_Clinical_Camera_Technical_Architecture_v1.0.md
docs/WISE_Clinical_Camera_UX_UI_Specification_v1.0.md
docs/WISE_Clinical_Camera_Functional_Specification_v1.0.md
docs/WISE_Clinical_Camera_Data_Model_Database_Specification_v1.0.md
docs/WISE_Clinical_Camera_Computer_Vision_Alignment_Specification_v1.0.md
docs/WISE_Clinical_Camera_Privacy_Security_Specification_v1.0.md
docs/WISE_Clinical_Camera_AI_Cost_Strategy_v1.0.md
docs/WISE_Clinical_Camera_Testing_Acceptance_Specification_v1.0.md
docs/WISE_Clinical_Camera_Claude_Code_Build_Specification_v1.0.md
```

Do not update documents blindly.

Only update documents that are materially affected.

---

# 21. AI-TOOL INDEPENDENCE

This project must not depend on any specific AI vendor or chat history.

A new agent should be able to:

```text
git clone repository
        ↓
read README
        ↓
read PROJECT_STATUS.md
        ↓
read PROJECT_KNOWLEDGE_MAP.md
        ↓
read REQUIREMENTS_TRACEABILITY.md
        ↓
read RELEASE_GATES.md
        ↓
read current phase plan
        ↓
inspect code/tests
        ↓
continue development
```

No critical project state should exist only inside an AI conversation.

---

# 22. GITHUB SOURCE-OF-TRUTH MODEL

GitHub should contain:

* source code
* tests
* architecture
* requirements
* decisions
* conflicts
* release gates
* phase plans
* completion reports
* current project status
* validation evidence
* known limitations

Claude conversations and ChatGPT conversations are temporary working environments.

The repository is the permanent memory.

---

# 23. BRANCH / PHASE MODEL

Preferred workflow:

```text
main
  |
  +---- Phase 2 PR
  |
  +---- Phase 3 PR
  |
  +---- Phase 4 PR
  |
  +---- Phase 5 PR
```

Use phase-level pull requests rather than creating a pull request for every small implementation change.

Within a phase, use focused commits.

Example:

```text
Phase 3:
  commit: capture context
  commit: before-after inheritance
  commit: library workflow
  commit: measurement validation
  commit: export validation
  commit: platform hardening
  commit: documentation and release gates
```

Merge the phase PR only when the phase has been reviewed and its release gates are appropriately recorded.

---

# 24. CURRENT BRANCH HISTORY

Phase 2 branch reported:

```text
claude/wise-clinical-camera-build-p8mes8
```

Phase 2 was intended to be merged into `main` before beginning a clean Phase 3 Claude session.

If the branch has already been merged, verify the actual repository state rather than relying on this document.

---

# 25. CURRENT NEXT ACTION

The next AI agent should first verify:

1. Current branch.
2. Current commit.
3. Whether Phase 2 was merged into `main`.
4. Working tree status.
5. Current test count.
6. Current analyzer status.
7. Current documentation state.
8. Existing Phase 3 work, if any.
9. Actual available platform tooling.
10. Current release blockers.

Do not assume this document is newer than the code.

The repository itself must be inspected.

If this document conflicts with actual code or Git history:

**inspect → determine evidence → update the document → continue.**

---

# 26. PHASE 3 DEFINITION OF DONE

Phase 3 is not complete merely because code has been written.

Phase 3 requires evidence for:

### Functional

* complete Before workflow
* complete After workflow
* multiple After photographs per Before
* body part
* laterality
* case linking
* capture context
* recipe inheritance
* recipe immutability
* reference lock
* alignment
* lighting
* focus
* grid
* level
* calibration
* measurement
* annotations
* comparison
* exports
* library
* filtering
* photo detail
* privacy mode

### Technical

* analyzer clean
* formatter clean
* tests passing
* no known lifecycle regressions
* database integrity
* filesystem consistency
* migration safety
* memory-conscious image processing

### Camera

* camera permissions
* camera lifecycle
* rotation
* capability detection
* unsupported capability handling
* real camera plugin validation where environment permits

### Computer Vision

* synthetic validation
* real-image validation
* dataset protocol
* threshold documentation
* known limitations

### Security / Privacy

* no accidental network image transfer
* privacy mode behavior
* metadata handling
* local storage protections
* encryption decision documented
* C-019 resolved or explicitly tracked

### Platform

Where tooling exists:

* Android build
* Android device validation
* iOS build
* iOS device validation

If a platform cannot be tested because the environment does not provide it, record:

**BLOCKED — ENVIRONMENT**

Do not mark it as passed.

### Accessibility

Validate:

* readable text
* sufficient interaction targets
* semantics
* keyboard/navigation where applicable
* contrast
* non-color-only status communication

---

# 27. VALIDATION LANGUAGE

Always distinguish:

```text
IMPLEMENTED
```

from:

```text
VALIDATED
```

Example:

```text
Feature: Camera capture
Status:
IMPLEMENTED — NOT VALIDATED
Reason:
Camera abstraction exists, but physical-device capture has not yet been validated.
```

Another example:

```text
Feature: Android build
Status:
BLOCKED — ENVIRONMENT
Reason:
Android SDK/toolchain is unavailable in the current development environment.
```

---

# 28. CLINICAL SAFETY / CLAIMS

The software is a clinical photography/documentation tool.

Do not make unsupported claims regarding:

* diagnosis
* treatment
* clinical efficacy
* clinical accuracy
* measurement accuracy
* disease detection
* medical decision-making

Unless appropriate validation exists, use careful terminology such as:

* photographic measurement
* alignment guidance
* image-quality warning
* reference matching
* visual comparison

Do not imply that image-processing metrics are clinically validated.

---

# 29. PERFORMANCE PRINCIPLES

Clinical photographs may be large.

The application must avoid:

* loading unnecessary full-resolution images simultaneously
* memory spikes
* duplicate image buffers
* uncontrolled image widgets
* unnecessary image recomputation

Use:

* thumbnails
* bounded rendering
* lazy loading
* derived images
* careful disposal
* background processing where appropriate

Performance must be tested using realistic photograph sizes.

---

# 30. PRIVACY PRINCIPLES

Default architecture:

**LOCAL FIRST**

No image should be uploaded to:

* cloud AI
* third-party analytics
* external processing service
* remote backend

unless explicitly designed, disclosed, and approved.

Privacy Mode should be treated as a first-class feature.

---

# 31. FUTURE REUSABILITY

The camera engine and reusable clinical photography infrastructure should be designed so they can eventually support other WISE applications.

Potential reusable components:

* camera abstraction
* capture controller
* image storage
* metadata model
* alignment engine
* calibration engine
* measurement engine
* annotation engine
* comparison engine
* export engine
* privacy engine
* protocol engine
* image-quality engine

Avoid building the architecture so tightly around one screen that future WISE applications cannot reuse it.

---

# 32. PROJECT HANDOFF PRINCIPLE

A future AI agent should never need to ask:

> "What did the previous Claude session do?"

The repository should answer that.

A future AI agent should instead be able to ask:

> "What is the current state of the repository?"

and obtain the answer from:

```text
PROJECT_STATUS.md
PROJECT_KNOWLEDGE_MAP.md
REQUIREMENTS_TRACEABILITY.md
RELEASE_GATES.md
PHASE_*_PLAN.md
PHASE_*_COMPLETION_REPORT.md
Git history
Tests
Source code
```

---

# 33. REQUIRED UPDATE AFTER EVERY MEANINGFUL PHASE

At the end of every major phase:

1. Update `PROJECT_STATUS.md`.
2. Update `PROJECT_KNOWLEDGE_MAP.md`.
3. Update `REQUIREMENTS_TRACEABILITY.md`.
4. Update `RELEASE_GATES.md`.
5. Create/update phase completion report.
6. Record unresolved conflicts.
7. Record blocked environment validations.
8. Record test count.
9. Record coverage.
10. Record build results.
11. Record platform validation.
12. Record known defects.
13. Record next recommended action.

---

# 34. CURRENT PROJECT STATUS SUMMARY

| Area                               | Status                                         |
| ---------------------------------- | ---------------------------------------------- |
| Product definition                 | Established                                    |
| Architecture                       | Established                                    |
| Flutter foundation                 | Implemented                                    |
| Local database                     | Implemented                                    |
| Local filesystem storage           | Implemented                                    |
| Camera abstraction                 | Implemented                                    |
| Sensors                            | Implemented                                    |
| Measurement engine                 | Implemented                                    |
| CV foundation                      | Implemented                                    |
| Privacy architecture               | Implemented                                    |
| AI abstraction                     | Implemented                                    |
| UI foundation                      | Implemented                                    |
| Library                            | Implemented with remaining workflow validation |
| Before/After concept               | Implemented foundation                         |
| Complete clinical capture workflow | Phase 3 work                                   |
| Body part workflow                 | Phase 3                                        |
| Laterality workflow                | Phase 3                                        |
| Case linking workflow              | Phase 3                                        |
| Recipe inheritance                 | Phase 3                                        |
| Real camera validation             | Pending                                        |
| Real clinical-image CV validation  | Pending                                        |
| Android validation                 | Environment dependent                          |
| iOS validation                     | Environment dependent                          |
| Linux release build                | Previously verified                            |
| Automated tests                    | 524 at Phase 2 report                          |
| Coverage                           | 77.6% at Phase 2 report                        |
| Production readiness               | NOT RELEASE READY                              |

---

# 35. IMPORTANT FINAL RULE

**Do not treat this document as permission to skip repository inspection.**

This file is a handoff summary.

The actual repository is the authoritative implementation state.

Before changing anything:

```text
Inspect repository
→ inspect Git status
→ inspect current branch
→ inspect recent commits
→ inspect relevant documentation
→ inspect existing implementation
→ inspect tests
→ identify actual gap
→ implement
→ test
→ document
→ validate
→ update PROJECT_STATUS.md
```

This workflow must continue for the lifetime of WISE Clinical Camera.
