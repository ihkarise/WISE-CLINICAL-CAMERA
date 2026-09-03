# WISE Clinical Camera
## Data Model & Database Specification v1.0

**Product:** WISE Clinical Camera  
**Purpose:** Define the persistent data model, SQLite schema, file-storage model, relationships, indexes, lifecycle rules, migrations, and synchronization readiness for the WISE Clinical Camera application.

**Platforms:** iOS and Android  
**Architecture:** Flutter + native platform bridges, local-first, SQLite + filesystem  
**Core principle:** Original clinical photographs are immutable. Structured information and derived assets are stored separately.

---

# 1. Scope

This specification defines how WISE Clinical Camera stores:

- users
- cases
- photographs
- Before/After relationships
- reference information
- protocols
- persistent preferences
- temporary capture settings
- calibration
- measurements
- annotations
- comparison configurations
- exports
- device/camera metadata
- privacy state
- derived assets
- deletion state
- future synchronization identifiers

The database must support the current V1 application while remaining extensible for future WISE products.

---

# 2. Storage Architecture

WISE uses two complementary storage systems.

```text
                 WISE Clinical Camera
                         │
              ┌──────────┴──────────┐
              │                     │
          SQLite DB             File Storage
              │                     │
      structured metadata      image binaries
      relationships             thumbnails
      settings                  derived exports
      measurements              comparison images
      annotations
```

## 2.1 SQLite

SQLite stores structured data.

Use SQLite for:

- IDs
- relationships
- metadata
- settings
- calibration records
- measurements
- annotations
- protocols
- cases
- export records
- processing state

Do not store full-resolution photographs as SQLite BLOBs in the normal architecture.

---

# 3. File Storage

Full-resolution images shall be stored in application-controlled filesystem storage.

Recommended logical structure:

```text
WISE/
├── originals/
├── thumbnails/
├── derived/
│   ├── annotated/
│   ├── measured/
│   ├── comparison/
│   └── exports/
├── temp/
└── backups/
```

Actual platform-specific paths shall be resolved by the application storage service.

---

# 4. Identifier Strategy

Every persistent entity shall have a globally unique ID.

Recommended format:

```text
UUID
```

Example:

```text
550e8400-e29b-41d4-a716-446655440000
```

IDs must not depend on auto-increment values.

This prepares the application for:

- future synchronization
- migration
- backup/restore
- multi-device use
- conflict resolution
- cross-table references

---

# 5. Common Entity Fields

Persistent entities should use common fields where appropriate:

| Field | Type | Purpose |
|---|---|---|
| id | TEXT | UUID |
| created_at | INTEGER/TEXT | Creation timestamp |
| updated_at | INTEGER/TEXT | Last modification |
| deleted_at | INTEGER/TEXT nullable | Soft deletion |
| version | INTEGER | Record version |
| sync_status | TEXT | Future synchronization state |

The implementation may omit fields from entities where they have no meaningful use.

---

# 6. User Entity

Table:

```text
users
```

Purpose:

Store local application user preferences and identity-independent configuration.

### Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| id | TEXT PK | Yes | UUID |
| display_name | TEXT | No | Optional local display name |
| created_at | INTEGER | Yes | Creation timestamp |
| updated_at | INTEGER | Yes | Last update |
| version | INTEGER | Yes | Record version |

No online account is required for basic capture.

---

# 7. Case Entity

Table:

```text
cases
```

A case is optional.

A photograph may exist without a case.

### Fields

| Field | Type | Required |
|---|---|---:|
| id | TEXT PK | Yes |
| user_id | TEXT FK | No |
| local_reference | TEXT | No |
| title | TEXT | No |
| notes | TEXT | No |
| created_at | INTEGER | Yes |
| updated_at | INTEGER | Yes |
| deleted_at | INTEGER | No |
| version | INTEGER | Yes |

`local_reference` can be used for a user-created case identifier.

Avoid storing unnecessary patient-identifying information unless explicitly required by a future product requirement.

---

# 8. Photo Entity

Table:

```text
photos
```

This is the central entity.

### Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| id | TEXT PK | Yes | UUID |
| user_id | TEXT FK | No | Owner |
| case_id | TEXT FK | No | Optional case |
| type | TEXT | Yes | BEFORE / AFTER / PHOTO |
| original_path | TEXT | Yes | Immutable original |
| thumbnail_path | TEXT | No | Generated thumbnail |
| captured_at | INTEGER | Yes | Capture timestamp |
| imported_at | INTEGER | No | Import timestamp |
| body_part | TEXT | No | Optional body region |
| laterality | TEXT | No | LEFT / RIGHT / BOTH / NA |
| reference_photo_id | TEXT FK | No | Reference Before image |
| protocol_id | TEXT FK | No | Protocol used |
| width_px | INTEGER | Yes | Original width |
| height_px | INTEGER | Yes | Original height |
| file_size_bytes | INTEGER | Yes | Original file size |
| mime_type | TEXT | Yes | Image MIME type |
| checksum | TEXT | No | Integrity/deduplication |
| source | TEXT | Yes | CAMERA / IMPORT |
| metadata_json | TEXT | No | Camera metadata |
| capture_recipe_json | TEXT | No | Reproduction settings |
| status | TEXT | Yes | ACTIVE / PROCESSING / FAILED / DELETED |
| created_at | INTEGER | Yes |
| updated_at | INTEGER | Yes |
| deleted_at | INTEGER | No |
| version | INTEGER | Yes |

---

# 9. Photo Type Rules

Allowed values:

```text
BEFORE
AFTER
PHOTO
```

Rules:

### BEFORE

- may be used as a reference
- `reference_photo_id` normally NULL

### AFTER

- should normally contain `reference_photo_id`
- reference must point to a compatible local photo

### PHOTO

- no reference required

The database should not enforce every business rule using SQL constraints alone. Application-level validation is also required.

---

# 10. Reference Relationship

An After photo points to its Before/reference photograph:

```text
photos.reference_photo_id
        ↓
photos.id
```

Example:

```text
Before A
   ↑
   │ reference_photo_id
   │
After A
```

The reference relationship must be retained even if the user later creates comparisons.

---

# 11. Capture Recipe

The capture recipe records information useful for reproducing the Before image.

Recommended JSON structure:

```json
{
  "camera": {
    "lens": "rear_main",
    "zoom": 1.0,
    "flash": "off",
    "focus_mode": "auto"
  },
  "orientation": "portrait",
  "grid": "3x3",
  "level_enabled": true,
  "overlay_enabled": true,
  "alignment_enabled": true,
  "lighting_check_enabled": true,
  "focus_check_enabled": true
}
```

The recipe is informational and reproducibility-oriented.

The system must not assume that a later device can reproduce every camera parameter exactly.

---

# 12. Capture Recipe Version

Store:

```text
capture_recipe_version
```

Recommended integer version:

```text
1
```

Future versions can add fields without invalidating historical captures.

---

# 13. Camera Metadata

Table:

```text
photo_metadata
```

Separate metadata storage is recommended where metadata becomes complex.

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK UNIQUE |
| camera_position | TEXT |
| lens_identifier | TEXT |
| focal_length | REAL |
| zoom_factor | REAL |
| exposure_time | REAL |
| iso | REAL |
| aperture | REAL |
| flash_mode | TEXT |
| white_balance | TEXT |
| orientation | TEXT |
| device_model | TEXT |
| os_version | TEXT |
| app_version | TEXT |
| raw_metadata_json | TEXT |
| created_at | INTEGER |

Fields may be NULL because camera APIs differ between iOS and Android.

---

# 14. Protocol Entity

Table:

```text
protocols
```

A protocol is a reusable capture configuration.

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| user_id | TEXT FK |
| name | TEXT |
| description | TEXT |
| settings_json | TEXT |
| version | INTEGER |
| is_system | INTEGER |
| is_active | INTEGER |
| created_at | INTEGER |
| updated_at | INTEGER |
| deleted_at | INTEGER |

Examples:

```text
Dermatology Standard
Physiotherapy Standard
Wound Documentation
Posture Standard
General Clinical Photo
```

---

# 15. Protocol Settings

Recommended JSON:

```json
{
  "tools": {
    "overlay": true,
    "alignment": true,
    "lighting": true,
    "focus": true,
    "grid": true,
    "level": true,
    "measurement": true,
    "annotation": false
  },
  "camera": {
    "preferred_orientation": "portrait",
    "flash": "off"
  },
  "export": {
    "preset": "report_ready",
    "footer": true
  }
}
```

---

# 16. User Preferences

Table:

```text
user_preferences
```

### Fields

| Field | Type |
|---|---|
| user_id | TEXT PK/FK |
| overlay_enabled | INTEGER |
| overlay_opacity | REAL |
| alignment_enabled | INTEGER |
| lighting_enabled | INTEGER |
| focus_enabled | INTEGER |
| grid_enabled | INTEGER |
| grid_type | TEXT |
| level_enabled | INTEGER |
| measurement_enabled | INTEGER |
| annotation_enabled | INTEGER |
| difference_enabled | INTEGER |
| comparison_mode | TEXT |
| gallery_save_mode | TEXT |
| privacy_mode | INTEGER |
| updated_at | INTEGER |
| version | INTEGER |

Allowed Gallery modes:

```text
ASK
ALWAYS
NEVER
```

Boolean values should use SQLite INTEGER:

```text
0 = false
1 = true
```

---

# 17. Temporary Session Settings

Persistent preferences must not be confused with capture-session overrides.

Session settings should normally remain in memory and not be persisted as user defaults.

Example:

```text
User default:
Measurement = ON

Current capture:
Measurement = OFF

After capture:
Default remains ON
```

If session recovery is required in a future version, session state may be stored separately.

---

# 18. Calibration Entity

Table:

```text
calibrations
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK |
| method | TEXT |
| known_value | REAL |
| unit | TEXT |
| pixel_distance | REAL |
| pixels_per_unit | REAL |
| reference_geometry_json | TEXT |
| confidence | REAL |
| is_valid | INTEGER |
| created_at | INTEGER |
| updated_at | INTEGER |

Methods:

```text
RULER
MARKER
MANUAL
```

---

# 19. Calibration Rules

A calibration belongs to a specific image unless a future workflow explicitly supports shared calibration.

A calibration must not automatically be reused on a different photograph unless the application can establish that the same scale relationship is valid.

This prevents false centimetre measurements.

---

# 20. Measurement Entity

Table:

```text
measurements
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK |
| calibration_id | TEXT FK |
| type | TEXT |
| unit | TEXT |
| value | REAL |
| pixel_value | REAL |
| geometry_json | TEXT |
| label | TEXT |
| visible | INTEGER |
| created_at | INTEGER |
| updated_at | INTEGER |
| deleted_at | INTEGER |

Types:

```text
LENGTH
WIDTH
DIAMETER
PERIMETER
AREA
ANGLE
```

ANGLE may be included for future posture/orthopaedic workflows.

---

# 21. Measurement Geometry

Geometry should be stored independently from the displayed measurement value.

Example:

```json
{
  "points": [
    {"x": 122.4, "y": 248.1},
    {"x": 388.7, "y": 251.9}
  ]
}
```

For an area:

```json
{
  "points": [
    {"x": 100, "y": 100},
    {"x": 200, "y": 100},
    {"x": 210, "y": 200},
    {"x": 90, "y": 200}
  ]
}
```

This permits recalculation if calibration changes.

---

# 22. Annotation Entity

Table:

```text
annotations
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK |
| type | TEXT |
| geometry_json | TEXT |
| text | TEXT |
| properties_json | TEXT |
| z_index | INTEGER |
| visible | INTEGER |
| created_at | INTEGER |
| updated_at | INTEGER |
| deleted_at | INTEGER |

Types:

```text
PEN
ARROW
CIRCLE
RECTANGLE
POINT
LINE
TEXT
MEASUREMENT
```

---

# 23. Annotation Properties

Example:

```json
{
  "stroke_width": 4,
  "font_size": 18,
  "rotation": 0,
  "opacity": 1
}
```

The exact visual properties can evolve without changing the core entity.

---

# 24. Layer Model

The application should treat visual additions as layers.

Conceptual order:

```text
Original Photo
      ↓
Reference Layer
      ↓
Measurement Layer
      ↓
Annotation Layer
      ↓
Grid Layer
      ↓
Label Layer
      ↓
Footer Layer
```

Original photo data remains separate.

---

# 25. Derived Asset Entity

Table:

```text
derived_assets
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| source_photo_id | TEXT FK |
| asset_type | TEXT |
| file_path | TEXT |
| width_px | INTEGER |
| height_px | INTEGER |
| file_size_bytes | INTEGER |
| checksum | TEXT |
| configuration_json | TEXT |
| created_at | INTEGER |
| version | INTEGER |

Types:

```text
THUMBNAIL
ANNOTATED
MEASURED
COMPARISON
EXPORT
ANONYMIZED
```

Derived files can always be regenerated where sufficient source data remains.

---

# 26. Comparison Entity

Table:

```text
comparisons
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| before_photo_id | TEXT FK |
| after_photo_id | TEXT FK |
| mode | TEXT |
| alignment_json | TEXT |
| opacity | REAL |
| configuration_json | TEXT |
| derived_asset_id | TEXT FK |
| created_at | INTEGER |
| updated_at | INTEGER |

Modes:

```text
SIDE_BY_SIDE
SLIDER
OVERLAY
BLINK
DIFFERENCE
```

---

# 27. Alignment Record

Table:

```text
alignments
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| reference_photo_id | TEXT FK |
| target_photo_id | TEXT FK |
| method | TEXT |
| score | REAL |
| translation_x | REAL |
| translation_y | REAL |
| rotation | REAL |
| scale | REAL |
| transform_matrix_json | TEXT |
| confidence | REAL |
| status | TEXT |
| created_at | INTEGER |

Possible methods:

```text
SENSOR
FEATURE_MATCH
OPTICAL_FLOW
HOMOGRAPHY
TEMPLATE
EDGE
MANUAL
HYBRID
```

---

# 28. Alignment and Comparison Relationship

The comparison engine should reuse an existing alignment record when valid.

```text
Before
  │
  ├── Alignment
  │
After
  │
  └── Comparison
```

This avoids calculating incompatible transformations independently.

---

# 29. Lighting Analysis

Table:

```text
quality_checks
```

This can contain image quality assessments.

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK |
| check_type | TEXT |
| score | REAL |
| status | TEXT |
| details_json | TEXT |
| engine_version | TEXT |
| created_at | INTEGER |

Check types:

```text
LIGHTING
FOCUS
ALIGNMENT
EXPOSURE
```

Status examples:

```text
GOOD
WARNING
FAIL
UNAVAILABLE
```

---

# 30. Export Entity

Table:

```text
exports
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK |
| comparison_id | TEXT FK |
| preset | TEXT |
| output_path | TEXT |
| configuration_json | TEXT |
| anonymized | INTEGER |
| created_at | INTEGER |
| status | TEXT |

Presets:

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

# 31. Export Configuration

Example:

```json
{
  "include_annotations": true,
  "include_measurements": true,
  "include_grid": false,
  "include_footer": true,
  "include_metadata": false,
  "include_date": true
}
```

---

# 32. Gallery Export Record

If tracking Gallery saves is required:

Table:

```text
gallery_exports
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| photo_id | TEXT FK |
| derived_asset_id | TEXT FK |
| platform_asset_identifier | TEXT |
| album_name | TEXT |
| created_at | INTEGER |
| status | TEXT |

The database must not assume that a Gallery asset remains available forever.

---

# 33. Audit/Event Log

A lightweight local event table may be used for troubleshooting and future synchronization.

Table:

```text
events
```

### Fields

| Field | Type |
|---|---|
| id | TEXT PK |
| entity_type | TEXT |
| entity_id | TEXT |
| event_type | TEXT |
| payload_json | TEXT |
| created_at | INTEGER |

Do not place sensitive image contents in event payloads.

Events should be disabled or minimized in production logging if they create unnecessary privacy risk.

---

# 34. Relationships

High-level relationship model:

```text
User
 │
 ├── Cases
 │     │
 │     └── Photos
 │
 ├── Protocols
 │
 └── Preferences

Photo
 │
 ├── Reference Photo
 ├── Metadata
 ├── Calibration
 ├── Measurements
 ├── Annotations
 ├── Quality Checks
 ├── Alignments
 ├── Derived Assets
 ├── Comparisons
 └── Exports
```

---

# 35. Referential Integrity

Foreign keys should be enabled in SQLite:

```sql
PRAGMA foreign_keys = ON;
```

Recommended behaviour:

- deleting a Case should not automatically delete its Photos
- deleting a Photo should remove dependent structured records only according to application deletion policy
- reference relationships must be checked before deletion
- Gallery copies must not be deleted as a side effect unless explicitly supported and permitted

---

# 36. Soft Delete

Important records may use soft deletion.

Recommended:

```text
deleted_at
```

instead of immediate database deletion.

This supports:

- recovery
- synchronization
- safe reference handling
- future audit functionality

Permanent deletion may be implemented separately.

---

# 37. Photo Deletion Rules

When a photo is deleted:

1. Mark the photo deleted.
2. Preserve enough information for relationship cleanup.
3. Mark dependent derived assets for deletion.
4. Remove or invalidate measurements and annotations.
5. Check whether another After photo references it.
6. Inform the user if references will be affected.
7. Do not silently remove independent Gallery copies.

---

# 38. Original Image Immutability

The original image is immutable.

Never:

```text
overwrite original
```

Instead:

```text
original
  +
layers
  ↓
derived export
```

If the user edits an image, the edited version is a derived asset.

---

# 39. File Integrity

The application may calculate a checksum for originals.

Recommended:

```text
SHA-256
```

The checksum can be used to:

- detect accidental corruption
- identify duplicate imports
- verify backup restoration
- support future synchronization

---

# 40. Thumbnail Strategy

Thumbnails should be generated for library browsing.

Suggested sizes:

```text
small: 256 px
medium: 512 px
```

Exact sizes can be optimized through device testing.

The thumbnail is never the source of truth.

---

# 41. Image Processing Lifecycle

```text
Capture
 ↓
Write Original
 ↓
Create DB Record
 ↓
Generate Thumbnail
 ↓
Run Optional Quality Checks
 ↓
Save Derived Results
```

If processing fails:

```text
Original remains available.
```

The application must not lose the original because a derived processing step failed.

---

# 42. Processing State

Photo status:

```text
PROCESSING
ACTIVE
FAILED
DELETED
```

A partially processed image should remain recoverable.

---

# 43. Transaction Rules

Operations affecting multiple related records should use database transactions.

Example:

```text
Create Photo
+
Create Metadata
+
Create Reference Relationship
+
Create Quality Records
```

Either all required records are committed or the transaction rolls back.

The image file itself requires separate filesystem recovery handling because SQLite transactions cannot atomically include normal filesystem writes.

---

# 44. File/Database Consistency

Use a two-phase style process:

```text
1. Generate unique asset ID
2. Write temporary file
3. Verify file
4. Move into final storage
5. Commit database record
6. Remove temporary file
```

If the DB transaction fails after file creation, the storage service must clean up the orphaned file.

---

# 45. Migration Strategy

Database schema must use numbered migrations.

Example:

```text
Migration 001
Migration 002
Migration 003
...
```

The application must never assume the user is starting from a clean database.

---

# 46. Example Migration History

### Migration 001

Core:

- users
- cases
- photos
- user_preferences

### Migration 002

Clinical tools:

- calibrations
- measurements
- annotations

### Migration 003

Reproducibility:

- alignments
- quality_checks
- protocols

### Migration 004

Exports:

- derived_assets
- comparisons
- exports
- gallery_exports

Future migrations may extend this structure.

---

# 47. Database Indexes

Recommended indexes:

```sql
CREATE INDEX idx_photos_case_id
ON photos(case_id);

CREATE INDEX idx_photos_type
ON photos(type);

CREATE INDEX idx_photos_reference
ON photos(reference_photo_id);

CREATE INDEX idx_photos_captured_at
ON photos(captured_at);

CREATE INDEX idx_photos_body_part
ON photos(body_part);

CREATE INDEX idx_measurements_photo
ON measurements(photo_id);

CREATE INDEX idx_annotations_photo
ON annotations(photo_id);

CREATE INDEX idx_calibrations_photo
ON calibrations(photo_id);

CREATE INDEX idx_alignments_reference
ON alignments(reference_photo_id);

CREATE INDEX idx_alignments_target
ON alignments(target_photo_id);

CREATE INDEX idx_derived_source
ON derived_assets(source_photo_id);
```

---

# 48. Query Examples

## Recent Before Photos

```sql
SELECT *
FROM photos
WHERE type = 'BEFORE'
  AND deleted_at IS NULL
ORDER BY captured_at DESC;
```

## After Photos for a Before

```sql
SELECT *
FROM photos
WHERE type = 'AFTER'
  AND reference_photo_id = ?
  AND deleted_at IS NULL
ORDER BY captured_at ASC;
```

## Case Photos

```sql
SELECT *
FROM photos
WHERE case_id = ?
  AND deleted_at IS NULL
ORDER BY captured_at ASC;
```

---

# 49. Data Validation

Application-level validation must check:

### Photo

- valid UUID
- valid type
- original file exists
- dimensions > 0
- timestamp valid

### After

- reference photo exists
- reference is not itself an invalid deleted record
- reference relationship is not circular

### Calibration

- known value > 0
- pixel distance > 0
- supported unit

### Measurement

- geometry valid
- calibration valid for physical unit output

---

# 50. Measurement Validation

If:

```text
calibration_id IS NULL
```

then a measurement may store pixel geometry/value but must not claim a physical unit.

Example:

```text
Pixel length: 382 px
Physical length: unavailable
```

---

# 51. Before/After Measurement Changes

Change calculations should be derived from stored measurements.

Do not permanently store calculated percentage change unless there is a clear reason.

Example:

```text
before_measurement.value
after_measurement.value
```

Then calculate:

```text
change = after - before

percentage_change =
((after - before) / before) × 100
```

Handle:

```text
before = 0
```

without division errors.

---

# 52. Privacy Data Rules

The database should avoid unnecessary patient-identifying information.

Do not store:

- patient name unless explicitly required
- government ID
- contact information
- unnecessary location information

unless a future WISE clinical record integration explicitly defines those requirements.

---

# 53. Sensitive Metadata

Metadata such as:

- GPS location
- device identifiers
- raw EXIF

should be retained only where useful and permitted.

Anonymized export must be able to exclude such metadata.

---

# 54. Settings Precedence

Effective settings are calculated in this order:

```text
Platform capability
        ↓
User default
        ↓
Protocol
        ↓
Session override
        ↓
Effective capture setting
```

The database stores user defaults and protocols.

Session overrides normally remain runtime state.

---

# 55. Future Synchronization Readiness

Although V1 is local-first, records should be designed for future sync.

Recommended fields:

```text
id
created_at
updated_at
deleted_at
version
sync_status
```

Future sync should operate on structured records and files separately.

---

# 56. Synchronization Principle

Future architecture:

```text
Device A
   │
   ├── SQLite
   └── Files
        │
        ↓
    Sync Service
        │
        ↓
Device B
```

No V1 feature should depend on this service.

---

# 57. Conflict Strategy

Future sync should use entity-level conflict handling.

Potential strategy:

- immutable originals: no content conflict
- preferences: latest valid version
- annotations: entity-level merge where possible
- measurements: entity-level conflict
- cases: explicit conflict resolution
- protocols: versioned rather than silently overwritten

Do not implement complex synchronization in V1 unless required.

---

# 58. Backup

A future backup system should include:

```text
SQLite database
+
Original files
+
Required derived configuration
```

Derived images can often be regenerated and may be excluded from minimal backups.

Original photographs must be included in a complete backup.

---

# 59. Restore

Restore sequence:

```text
Validate backup
 ↓
Restore database
 ↓
Restore originals
 ↓
Verify checksums
 ↓
Rebuild thumbnails
 ↓
Rebuild missing derived assets
 ↓
Mark application ready
```

A failed derived asset should not invalidate the original photograph.

---

# 60. Database Encryption

The product should evaluate platform-appropriate encryption for sensitive local data.

At minimum:

- protect application storage using OS sandboxing
- protect secrets with platform secure storage
- avoid plaintext credentials
- avoid sensitive logging

Full database encryption can be added where product/security requirements justify it.

---

# 61. JSON Usage Rules

JSON is appropriate for:

- camera recipe
- camera metadata that varies by platform
- geometry
- annotation properties
- protocol settings
- export configuration
- alignment transforms

Relational columns should be used for:

- IDs
- foreign keys
- timestamps
- types
- status
- values used frequently for filtering/sorting

Do not place all application data into one large JSON document.

---

# 62. Entity Diagram

```text
USER
 │
 ├───────────────┐
 │               │
 ▼               ▼
CASES         PROTOCOLS
 │               │
 │               ▼
 └──────────► PHOTOS ◄──────── USER_PREFERENCES
                │
       ┌────────┼──────────┐
       │        │          │
       ▼        ▼          ▼
 METADATA   CALIBRATION  QUALITY_CHECKS
                │
                ▼
          MEASUREMENTS

PHOTOS
 │
 ├── ANNOTATIONS
 ├── ALIGNMENTS
 ├── DERIVED_ASSETS
 ├── EXPORTS
 └── COMPARISONS
          │
          └── BEFORE_PHOTO
          └── AFTER_PHOTO
```

---

# 63. Recommended SQLite Table Set

V1 target:

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

Future:

```text
sync_records
backup_records
ai_processing_jobs
```

---

# 64. Minimal V1 Database

If development needs a smaller first milestone, start with:

```text
users
user_preferences
photos
protocols
cases
calibrations
measurements
annotations
alignments
derived_assets
comparisons
```

Then add:

```text
quality_checks
exports
gallery_exports
events
```

---

# 65. Recommended Data Access Layers

Do not allow UI screens to directly manipulate SQLite.

Use:

```text
UI
 ↓
Feature Controller / State Management
 ↓
Repository
 ↓
Database Service
 ↓
SQLite
```

For files:

```text
Feature
 ↓
Repository
 ↓
Image Storage Service
 ↓
Filesystem
```

---

# 66. Repository Interfaces

Recommended conceptual interfaces:

```dart
abstract class PhotoRepository {
  Future<Photo> createPhoto(...);
  Future<Photo?> getPhoto(String id);
  Future<List<Photo>> getPhotos(...);
  Future<void> updatePhoto(...);
  Future<void> deletePhoto(String id);
}
```

Similar repositories:

```text
CaseRepository
ProtocolRepository
CalibrationRepository
MeasurementRepository
AnnotationRepository
ComparisonRepository
ExportRepository
PreferenceRepository
```

Exact Dart interfaces belong in the implementation architecture, not the database schema itself.

---

# 67. Cascading Behaviour

Avoid unrestricted:

```sql
ON DELETE CASCADE
```

for clinical photographs.

Deletion should be controlled by application logic.

Reason:

A single Before photograph may be referenced by many After photographs and comparisons.

---

# 68. Orphan Detection

A maintenance service may periodically detect:

- DB records without files
- files without DB records
- broken reference IDs
- missing thumbnails
- invalid derived assets

The repair service should never delete an original automatically merely because it appears orphaned.

---

# 69. Storage Quotas

The application may display:

- database size
- original image storage
- derived storage
- available device storage

Automatic deletion of clinical originals must never occur without explicit user action.

---

# 70. Performance Requirements

Database operations should:

- use indexed queries
- paginate large photo lists
- avoid loading full image binaries into memory
- use thumbnails for browsing
- perform image processing outside the UI thread
- batch related writes where appropriate

---

# 71. Threading / Isolate Strategy

Flutter image processing should use background isolates or native background processing where appropriate.

SQLite operations should not block the UI thread.

Large image decoding should be controlled to prevent memory spikes.

---

# 72. Data Lifecycle

Typical photograph lifecycle:

```text
Capture
 ↓
Temporary file
 ↓
Original saved
 ↓
Photo DB record
 ↓
Thumbnail
 ↓
Optional analysis
 ↓
Optional annotations
 ↓
Optional measurements
 ↓
Optional comparison
 ↓
Optional export
```

The original remains the permanent source asset unless explicitly deleted by the user.

---

# 73. Important Business Rules

1. No Before/After relationship without a reference photo.
2. No centimetre measurement without valid calibration.
3. No derived export may replace the original.
4. User defaults must survive app restart.
5. Temporary overrides must not silently change user defaults.
6. Core capture must work without Internet.
7. Cloud AI must never be silently invoked.
8. Deleting a WISE record must not silently delete an independent Gallery copy.
9. Protocol changes must not rewrite historical capture recipes.
10. Device-specific camera metadata may be unavailable and must therefore be nullable.
11. All persistent IDs should be stable and globally unique.
12. Original files should be integrity-verifiable.

---

# 74. Test Requirements

Database tests must cover:

### CRUD

- create
- read
- update
- soft delete
- restore where supported

### Relationships

- Before → After
- Case → Photos
- Photo → Measurements
- Photo → Annotations
- Photo → Calibration
- Before + After → Comparison

### Validation

- invalid IDs
- invalid measurement
- missing calibration
- deleted reference
- circular reference
- missing file

### Migration

- fresh install
- migration from each prior schema
- interrupted migration recovery
- backup restore

### Integrity

- checksum validation
- orphan detection
- database/file mismatch

---

# 75. Acceptance Criteria

The data layer is acceptable when:

- every photograph has a stable unique ID
- original file location is stored
- Before/After relationships are retrievable
- cases are optional
- protocols are versioned
- preferences persist
- temporary session settings remain separate
- calibration can be associated with a photograph
- measurements reference calibration
- annotations remain independent
- comparisons reference Before and After
- derived assets never replace originals
- database migrations work
- foreign-key integrity is enabled
- large image binaries are not stored in SQLite by default
- missing derived assets do not destroy originals
- offline operation requires no remote database

---

# 76. Implementation Priority

## P0

```text
users
user_preferences
photos
cases
protocols
```

## P1

```text
photo_metadata
calibrations
measurements
annotations
alignments
```

## P2

```text
derived_assets
comparisons
quality_checks
exports
```

## P3

```text
gallery_exports
events
backup/restore
```

## Future

```text
sync_records
AI processing jobs
cloud storage
multi-device synchronization
```

---

# 77. Final Data Architecture

The final V1 data architecture should follow:

```text
                 WISE Clinical Camera
                         │
              ┌──────────┴──────────┐
              │                     │
          STRUCTURED              FILES
              │                     │
            SQLite             Original Images
              │                 Thumbnails
              │                 Derived Assets
              │                 Exports
              │
     ┌────────┼─────────┐
     │        │         │
   Photos   Cases    Protocols
     │
 ┌───┼────┬──────┬────────┬─────────┐
 │   │    │      │        │         │
Meta Calib Measure Annot Align  Quality
             │
             └────── Comparison
                         │
                       Export
```

The architecture deliberately separates **original clinical evidence**, **structured clinical/photo information**, and **derived presentation outputs**.

That separation is fundamental to WISE Clinical Camera and must be preserved throughout implementation.
