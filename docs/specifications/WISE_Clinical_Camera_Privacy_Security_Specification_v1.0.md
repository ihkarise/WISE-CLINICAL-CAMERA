# WISE Clinical Camera
## Privacy & Security Specification v1.0

**Product:** WISE Clinical Camera  
**Purpose:** Define the privacy, security, data-protection, local-storage, permission, export, AI, deletion, logging, and future synchronization requirements for clinical photographs.

**Platforms:** iOS and Android  
**Architecture:** Local-first, privacy-first  
**Primary principle:**

> Clinical photographs belong to the user and must remain private by default.

---

# 1. Scope

This specification defines security and privacy behaviour for:

- camera access
- photo storage
- Gallery access
- imported photographs
- clinical metadata
- cases
- Before/After relationships
- measurements
- annotations
- exports
- anonymization
- AI processing
- cloud services
- permissions
- local encryption
- application logs
- deletion
- backups
- future synchronization
- incident handling

The specification applies to V1 and establishes requirements for future WISE Clinical Camera extensions.

---

# 2. Privacy Architecture

WISE shall follow:

```text
                 WISE Clinical Camera
                         │
                 LOCAL BY DEFAULT
                         │
          ┌──────────────┴──────────────┐
          │                             │
     Local Database                Local Files
       SQLite                       Originals
          │                         Derived Assets
          │                         Exports
          │
       Settings
       Metadata
       Relationships
```

External processing is optional.

```text
Local Device
    ↓
Optional Self-Hosted Service
    ↓
Optional Cloud Service
```

The default application must not require external transmission of clinical photographs.

---

# 3. Privacy Principles

## PRI-001 Data Minimization

WISE should collect and store only information required for the selected workflow.

Optional information must remain optional.

Examples:

- body part
- laterality
- case reference
- notes
- device metadata

---

## PRI-002 Local First

Core functions must operate locally whenever technically possible.

The following should not require an Internet connection:

- camera
- Before
- After
- Photo
- reference selection
- Ghost Overlay
- alignment
- lighting check
- focus check
- grid
- level
- calibration
- measurement
- annotation
- comparison
- local export

---

## PRI-003 No Silent Upload

WISE must never silently upload clinical photographs.

No image may be transmitted to:

- cloud AI
- analytics service
- synchronization service
- remote storage
- third-party image processor

without an explicit product feature and appropriate user authorization.

---

## PRI-004 Original Image Protection

The original photograph must never be overwritten by:

- annotations
- measurements
- comparison rendering
- anonymization
- compression
- AI processing
- export

All such outputs must be derived assets.

---

# 4. Privacy Modes

WISE should provide a simple privacy configuration.

## Standard Mode

Normal local operation.

## Privacy Mode

When enabled:

- do not automatically save to Gallery
- do not upload to cloud
- do not send images to third-party AI
- minimize metadata
- keep processing local where possible

The exact implementation should remain consistent across iOS and Android.

---

# 5. User Permission Model

Permissions should be requested only when required.

Potential permissions:

- Camera
- Photos/Gallery
- Files/document access
- Notifications if a future feature requires them

Do not request unrelated permissions during first launch.

---

# 6. Camera Permission

The camera permission is required to capture photographs.

If denied:

```text
Camera access is required to take photographs.
```

Actions:

```text
Open Settings
Cancel
```

The app should still allow non-camera functions that do not require camera access.

---

# 7. Gallery Permission

Gallery access is required only for functions that need it.

Examples:

- importing a reference image
- saving an image to Gallery where platform permissions require it

WISE should not require unrestricted Gallery access simply to take a photograph and store it internally.

---

# 8. Least Privilege

The application should request the minimum platform permission necessary for each action.

Avoid:

```text
Request all permissions at startup
```

Prefer:

```text
User chooses Import
        ↓
Request required photo permission
```

---

# 9. Permission Failure

If permission is denied:

1. Explain why it is required.
2. Provide a path to platform Settings where appropriate.
3. Continue with functions that do not require that permission.

Never repeatedly request a denied permission without user action.

---

# 10. Local Storage

Application-controlled storage should be used for WISE originals.

The app should not place every clinical photograph directly into the public Gallery by default.

Recommended:

```text
App-private storage
    ↓
WISE originals
```

Optional:

```text
Export
    ↓
Device Gallery
```

---

# 11. File Storage Security

Original images should be stored inside the platform's application sandbox where possible.

The application should avoid:

- world-readable files
- public temporary folders
- predictable filenames containing patient information
- sensitive information in filenames

---

# 12. File Naming

Do not use:

```text
PatientName_Diagnosis_2026.jpg
```

Prefer opaque identifiers:

```text
photo_<UUID>.jpg
```

or an equivalent non-identifying naming scheme.

---

# 13. Database Security

SQLite stores:

- photo relationships
- metadata
- measurements
- annotations
- preferences
- protocols
- cases

The database should not contain unnecessary identifying information.

---

# 14. Database Encryption

The project should evaluate encrypted SQLite storage for sensitive deployments.

Where full database encryption is used:

- encryption keys must not be hard-coded
- keys must not be stored in plain text
- keys should be protected using platform secure storage

If encryption is not enabled in an initial build, the application must still rely on OS sandboxing and secure device storage.

---

# 15. Key Management

Encryption keys and sensitive secrets should use:

### iOS

Platform secure credential/key storage.

### Android

Android Keystore-backed secure storage.

Never store encryption keys in:

- source code
- Git repository
- plain JSON
- SharedPreferences/UserDefaults as ordinary text
- logs

---

# 16. App Lock

A future optional App Lock may use:

- device passcode authentication
- Face ID
- Touch ID
- Android biometric authentication

WISE should prefer platform authentication mechanisms rather than implementing its own password cryptography.

---

# 17. App Background Protection

When the application moves to the background, sensitive content should be protected where platform APIs permit.

Possible behaviour:

```text
App enters background
        ↓
Blur/hide clinical image
```

The exact behaviour should follow platform UX conventions.

---

# 18. Screenshot Protection

Where technically possible and appropriate, sensitive screens may discourage screenshots.

Android may support stronger screenshot controls than iOS.

The application must document platform differences rather than pretending the behaviour is identical.

---

# 19. Clipboard

WISE should not copy clinical images or sensitive metadata to the clipboard unless the user explicitly requests it.

Temporary clipboard contents should be minimized.

---

# 20. Logging

Production logging must never include:

- image pixels
- full image paths containing identifying information
- patient names
- patient identifiers
- clinical notes
- raw OCR text
- authentication secrets
- encryption keys

---

# 21. Development Logging

Development builds may log technical information such as:

- processing duration
- algorithm selected
- image dimensions
- CV confidence
- number of feature matches
- database operation status

Sensitive content must still be excluded.

---

# 22. Crash Reporting

If crash reporting is introduced:

1. Do not attach clinical photographs automatically.
2. Do not attach image pixels.
3. Minimize metadata.
4. Review third-party data collection.
5. Make the privacy implications clear.

Crash reporting should not become an indirect clinical-image upload mechanism.

---

# 23. Analytics

Analytics should be privacy-minimized.

Do not send:

- clinical photographs
- patient data
- image-derived medical content
- free-text clinical notes

Prefer anonymous product events such as:

```text
capture_started
capture_completed
alignment_used
export_used
```

Only collect analytics when justified by product needs.

---

# 24. Telemetry

Telemetry should be:

- minimized
- documented
- configurable where appropriate
- free of clinical image content

Avoid telemetry that can reconstruct sensitive user activity unnecessarily.

---

# 25. AI Privacy

AI is optional.

Preferred processing order:

```text
Device Sensors
      ↓
Classical Computer Vision
      ↓
On-Device ML
      ↓
Self-Hosted AI
      ↓
Cloud AI
```

Use the earliest layer that provides the required functionality.

---

# 26. On-Device AI

On-device AI is preferred for image processing because:

- photographs remain local
- no network transmission is required
- latency is low
- offline use remains possible

Models must be packaged and updated securely.

---

# 27. Self-Hosted AI

A future self-hosted AI option may be provided.

Example:

```text
WISE Device
      ↓
User/Clinic-controlled server
      ↓
AI Processing
```

The user/organization must explicitly configure the endpoint.

---

# 28. Cloud AI

Cloud AI must be treated as an explicit privacy-sensitive feature.

Before sending an image:

- clearly identify that remote processing will occur
- identify the configured service where appropriate
- obtain required user authorization
- use encrypted transport
- avoid unnecessary retention

The core application must continue to function without cloud AI.

---

# 29. AI Result Storage

AI results should be stored separately from originals.

Example:

```text
Original Image
     │
     └── AI Result
```

AI must never overwrite the source photograph.

---

# 30. AI Safety

AI output must not silently become a clinical diagnosis.

For example:

```text
Image quality assessment
```

is acceptable as a technical function.

The system should not silently transform it into:

```text
Disease diagnosis
```

without a separately validated clinical product and appropriate safeguards.

---

# 31. Network Policy

V1 core camera functions should not require network connectivity.

Network access should be used only by features that explicitly require it.

Examples:

- optional AI
- future sync
- future backup
- software/model updates

---

# 32. Network Failure

If network-dependent functionality fails:

```text
Cloud processing unavailable.
```

The user should retain access to local functions.

No local photograph should be lost because an external service is unavailable.

---

# 33. TLS

Any future network communication must use secure transport.

Do not send clinical images over unencrypted HTTP.

Certificate and platform networking best practices must be followed.

---

# 34. External Services

Every third-party service must be reviewed for:

- what data it receives
- retention period
- geographic storage
- processing purpose
- data ownership
- deletion mechanisms
- breach notification
- subcontractors
- training/model-use policy

Do not add third-party image services merely for convenience.

---

# 35. Gallery Saving

Gallery saving is a user-controlled feature.

Preference:

```text
ASK EVERY TIME
ALWAYS
NEVER
```

---

# 36. Gallery Privacy

When Privacy Mode is enabled:

```text
Default Gallery saving = OFF
```

A user may explicitly export a photograph if desired.

---

# 37. WISE Clinical Photos Album

Where platform APIs support creating or targeting an application album:

```text
WISE Clinical Photos
```

may be used.

The app must handle platform differences gracefully.

---

# 38. Gallery Copies

A Gallery copy is separate from the WISE original.

Deleting the WISE copy must not silently delete a Gallery copy.

Similarly, deleting a Gallery copy must not delete the WISE original.

---

# 39. Import Privacy

When importing a photograph:

1. Obtain required permission.
2. Copy the image into WISE-controlled storage.
3. Preserve the imported original.
4. Record only necessary metadata.
5. Do not silently upload it.

---

# 40. EXIF Metadata

Imported/captured photographs may contain EXIF metadata.

Potentially sensitive fields include:

- GPS
- device model
- timestamps
- orientation
- camera parameters

WISE should retain only what is necessary for the workflow.

---

# 41. Anonymized Export

The user can create an anonymized copy.

The export process may remove:

- GPS
- device-specific metadata
- unnecessary timestamps
- identifying EXIF fields

The exact fields removed should be documented by the export engine.

---

# 42. Original Metadata Preservation

Anonymization must never modify the original photograph.

```text
Original
   │
   ├── Normal Export
   │
   └── Anonymized Export
```

---

# 43. Export Security

Exports should:

- use user-selected destination
- use non-identifying filenames by default
- never silently upload
- preserve the user's chosen privacy configuration

---

# 44. Share Sheet

If the platform share sheet is used:

1. Create the selected export.
2. Apply selected metadata policy.
3. Pass only the selected file.
4. Do not pass the original unless explicitly selected.

---

# 45. Temporary Files

Temporary processing files should:

- be stored in app-controlled temporary storage
- have non-identifying names
- be deleted after successful processing
- be cleaned after failures where safe

Do not leave unnecessary clinical images in temporary storage.

---

# 46. Failed Processing

If an operation fails:

```text
Original remains safe.
```

The system may retain a temporary file briefly for recovery but should clean it when no longer required.

---

# 47. Deletion Model

Deletion should distinguish:

```text
WISE database record
WISE original file
Derived files
Gallery copy
Backup copy
Cloud copy
```

Deleting one must not imply deletion of all others unless explicitly defined.

---

# 48. User-Initiated Deletion

When deleting a photograph:

1. Show what will be removed.
2. Warn about dependent After/comparison records if relevant.
3. Preserve or mark relationships appropriately.
4. Remove derived assets.
5. Apply soft deletion where supported.
6. Provide permanent deletion according to product policy.

---

# 49. Reference Deletion

If a Before photo is referenced by After photos:

```text
Before A
  ├── After 1
  ├── After 2
  └── After 3
```

the application must warn before deleting the reference.

It should not silently leave broken references.

---

# 50. Permanent Deletion

Permanent deletion should remove:

- database record
- original file
- derived files
- associated measurements
- annotations
- quality results
- alignment records

subject to the retention policy and any future backup/sync rules.

---

# 51. Backup Privacy

A future backup system must protect clinical photographs.

Backups should:

- be encrypted where appropriate
- use secure transport for remote backup
- avoid public/shared storage
- provide clear retention information
- support deletion

---

# 52. Backup Scope

A complete backup may contain:

```text
SQLite
+
Original photographs
+
Required metadata
+
Configuration
```

Derived images may be regenerated when possible.

---

# 53. Restore Security

Before restore:

1. Verify backup integrity.
2. Verify source.
3. Verify encryption where applicable.
4. Restore into application-controlled storage.
5. Validate file/database relationships.
6. Rebuild derived assets as needed.

---

# 54. Synchronization

Future synchronization must be opt-in.

Default:

```text
No cloud sync
```

If enabled:

```text
Local
 ↓
Encrypted Sync
 ↓
Configured Server
```

---

# 55. Sync Scope

Users should be able to understand what is synchronized.

Potential categories:

- photographs
- metadata
- cases
- measurements
- annotations
- protocols
- preferences

Do not assume that all data must be synchronized.

---

# 56. Sync Conflict

Future synchronization should treat originals as immutable.

Structured data can use:

- versions
- timestamps
- stable IDs
- conflict resolution

Do not silently overwrite a user's local clinical record.

---

# 57. Device Security

The app should rely on the platform's security model.

Recommended:

- iOS application sandbox
- Android application sandbox
- secure storage
- OS-level permissions
- platform biometric authentication where implemented

The user should also be encouraged to use a device passcode.

---

# 58. Rooted/Jailbroken Devices

The application may detect compromised device environments where technically appropriate.

The product should not make unsupported security claims.

If high-security deployment is required, future versions may warn users when the platform security model is materially weakened.

---

# 59. Secure Development

Source code must never contain:

- production API keys
- encryption secrets
- passwords
- service credentials

Use:

```text
environment configuration
secure CI secrets
platform secure storage
```

---

# 60. Dependency Security

Third-party dependencies should be:

- reviewed
- version controlled
- kept updated
- scanned for known vulnerabilities where practical
- limited to required functionality

Avoid unnecessary dependencies in the core camera.

---

# 61. Open-Source CV Libraries

Before using a computer-vision library:

1. Review its license.
2. Verify commercial/redistribution compatibility.
3. Check transitive dependencies.
4. Record the selected version.
5. Monitor security updates.

---

# 62. Data in Memory

Full-resolution clinical photographs may exist temporarily in memory.

The application should:

- minimize duplicate copies
- release buffers promptly
- avoid retaining unnecessary images
- avoid writing sensitive memory contents to logs

Complete memory wiping is platform-dependent and should not be claimed unless actually implemented.

---

# 63. Screen Privacy

Clinical images should not appear unnecessarily in:

- notifications
- widgets
- system shortcuts
- recent-content previews
- analytics dashboards

---

# 64. Notifications

Notifications should not contain:

- patient names
- clinical photographs
- diagnoses
- clinical notes

Example acceptable:

> WISE Clinical Camera export completed.

Avoid:

> Patient X wound photograph is ready.

---

# 65. App Search

If the operating system indexes application content, WISE should avoid exposing sensitive clinical information through system search unless explicitly designed and protected.

---

# 66. URL/Deep Link Security

Future deep links must not expose sensitive data in URLs.

Do not encode:

- patient names
- clinical notes
- photograph content
- sensitive identifiers

in externally visible links.

---

# 67. Access Control

V1 may operate without an account.

If multi-user access is added later, access control must be implemented at the application/service layer.

Potential roles:

```text
Owner
Clinician
Assistant
Viewer
Administrator
```

This is future scope and should not be assumed in V1.

---

# 68. Multi-User Data Isolation

If multi-user functionality is introduced:

```text
User A
   ↓
Data A

User B
   ↓
Data B
```

Cross-user access must require explicit authorization.

---

# 69. Privacy by Default

Default settings should favour:

- local storage
- no Gallery copy
- no cloud upload
- no cloud AI
- minimal metadata
- no unnecessary analytics

The user can explicitly enable additional functionality.

---

# 70. Privacy by Design

Privacy must be considered during:

```text
Feature design
 ↓
Architecture
 ↓
Implementation
 ↓
Testing
 ↓
Release
 ↓
Maintenance
```

Privacy should not be added only after the product is built.

---

# 71. Threat Model

Important threats:

| Threat | Mitigation |
|---|---|
| Unauthorized image upload | Local-first/no silent upload |
| File leakage | App sandbox |
| Metadata leakage | Minimized/anonymized export |
| Third-party AI exposure | Explicit opt-in |
| Lost device | OS security/App Lock |
| Database theft | Encryption evaluation |
| Sensitive logs | Log filtering |
| Cloud compromise | Minimize cloud dependency |
| Broken deletion | Controlled lifecycle |
| Accidental Gallery exposure | Gallery preference/privacy mode |
| Dependency vulnerability | Dependency review |
| Credential leakage | Secure secrets |

---

# 72. Threat: Accidental Gallery Exposure

Risk:

A clinical photograph is automatically copied to public Gallery.

Mitigation:

```text
Gallery Save Preference
+
Privacy Mode
+
Explicit Export
```

---

# 73. Threat: Cloud Processing Without Awareness

Risk:

An image is transmitted to a remote AI service without clear user understanding.

Mitigation:

- local-first architecture
- explicit cloud configuration
- visible processing destination
- no silent fallback to cloud

---

# 74. Threat: Original Image Modification

Risk:

Annotation or export destroys original evidence.

Mitigation:

```text
Immutable Original
+
Non-destructive Layers
+
Derived Exports
```

---

# 75. Threat: Broken Reference

Risk:

Deleting a Before image leaves After photographs pointing to missing data.

Mitigation:

- foreign-key validation
- deletion warnings
- soft deletion
- relationship checks

---

# 76. Threat: Sensitive Debug Logs

Risk:

Clinical image information appears in development or production logs.

Mitigation:

- structured logging
- redaction
- production log filtering
- no image payloads

---

# 77. Threat: Compromised Third-Party Dependency

Risk:

A library introduces a security vulnerability.

Mitigation:

- dependency inventory
- vulnerability monitoring
- version pinning/controlled upgrades
- minimal dependency footprint

---

# 78. Security Testing

Test:

### Storage

- unauthorized file access
- predictable filenames
- temporary file cleanup
- database integrity

### Permissions

- camera denied
- Gallery denied
- permission revoked after use

### Network

- offline operation
- TLS
- failed connection
- cloud service unavailable

### Deletion

- original deletion
- derived deletion
- reference deletion
- Gallery copy independence

### Privacy

- anonymized export
- EXIF stripping
- logs
- notifications
- screenshots/background state

---

# 79. Penetration Testing

Before production deployment, security testing should evaluate:

- local storage exposure
- API security if network services exist
- authentication if introduced
- authorization
- transport security
- file upload/download controls
- dependency vulnerabilities
- reverse engineering risks appropriate to the deployment

---

# 80. Privacy Testing Matrix

| Test | Expected Result |
|---|---|
| Capture offline | Works |
| Alignment offline | Works where supported |
| Cloud disabled | No upload |
| Gallery = Never | No automatic Gallery copy |
| Privacy Mode | No cloud/third-party image processing |
| Anonymized export | Sensitive metadata removed according to policy |
| Delete WISE photo | Gallery copy remains |
| Delete Gallery copy | WISE original remains |
| Annotation | Original unchanged |
| Measurement | Original unchanged |
| Comparison | Original unchanged |

---

# 81. Security Acceptance Criteria

V1 is acceptable when:

1. Core photography works without cloud services.
2. Clinical photographs are stored locally by default.
3. No photograph is silently uploaded.
4. Gallery saving is user-controlled.
5. Original images are immutable.
6. Derived images are separate.
7. Sensitive information is excluded from production logs.
8. Secrets are not hard-coded.
9. Platform permissions follow least privilege.
10. Anonymized export can remove unnecessary metadata.
11. Deletion does not unexpectedly remove independent Gallery copies.
12. CV and AI processing do not modify originals.
13. Cloud AI is optional.
14. Offline mode remains functional.
15. Security-sensitive dependencies are reviewed.
16. Backup/sync are not mandatory for core use.

---

# 82. Recommended V1 Security Priority

## P0 — Mandatory

- local-first storage
- no silent upload
- application sandbox
- immutable originals
- permission handling
- secure secret management
- privacy-safe logging
- controlled Gallery saving
- anonymized export
- secure deletion workflow

## P1

- encrypted database evaluation
- biometric App Lock
- background screen protection
- dependency security scanning

## P2

- encrypted backup
- opt-in synchronization
- server-side security architecture

## P3

- multi-user access control
- advanced enterprise security
- centralized policy management

---

# 83. Implementation Rules

A coding agent implementing WISE Clinical Camera must follow these rules:

1. Do not add a cloud backend merely to implement local features.
2. Do not add a third-party AI service when classical/local processing is sufficient.
3. Do not send images to analytics.
4. Do not overwrite originals.
5. Do not put sensitive data into logs.
6. Do not hard-code secrets.
7. Do not request unnecessary permissions.
8. Do not automatically copy clinical photographs to Gallery unless the user preference permits it.
9. Do not silently fall back from local processing to cloud processing.
10. Do not claim security controls that have not actually been implemented.
11. Document platform-specific security differences.
12. Keep privacy controls modular so future WISE applications can reuse them.

---

# 84. Security Architecture

```text
                 WISE Clinical Camera
                         │
                    Privacy Layer
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   Permissions       Local Storage    Secure Storage
        │                │                │
     Camera           SQLite          Secrets/Keys
     Gallery          Originals
                      Derived
                         │
                         ▼
                 Local Processing
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
          CV / ML                Export
              │                     │
              └──────────┬──────────┘
                         ▼
                  Optional Network
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
         Self-Hosted AI          Cloud AI
```

---

# 85. Final Security Principle

WISE Clinical Camera should operate under this default assumption:

> **A clinical photograph is sensitive even when the application does not know the patient's identity.**

Therefore:

```text
Collect less
Store locally
Protect originals
Minimize metadata
Process locally
Ask before exporting
Ask before sending
Delete deliberately
```

The application should make the secure choice the easy choice.

The user should be able to take, compare, measure and export clinical photographs without creating an unnecessary cloud trail.

---

# 86. Definition of Done

The Privacy & Security implementation is complete when:

```text
Local capture                  ✓
Local CV                       ✓
No silent upload               ✓
Controlled Gallery saving     ✓
Immutable originals            ✓
Non-destructive editing        ✓
Privacy Mode                   ✓
Anonymized export              ✓
Secure permissions             ✓
Privacy-safe logging            ✓
Secret protection              ✓
Deletion controls              ✓
Offline operation              ✓
Security testing               ✓
```

Any feature that requires a new privacy or security capability must update this specification before being treated as production-ready.
