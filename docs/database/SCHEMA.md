# Database Schema

Sixteen tables across four migrations, implementing the Data Model & Database
Specification. `PRAGMA foreign_keys = ON` on every connection.

---

## Migrations

Applied in order; the stored `user_version` decides where to resume. A fresh
install walks the same list rather than applying a snapshot, so the two paths
cannot drift (Data Model §45-46).

| # | Name | Tables |
|---|---|---|
| 001 | core | `users`, `user_preferences`, `cases`, `photos`, `photo_metadata` |
| 002 | clinical tools | `calibrations`, `measurements`, `annotations` |
| 003 | reproducibility | `protocols`, `alignments`, `quality_checks` |
| 004 | exports | `derived_assets`, `comparisons`, `exports`, `gallery_exports`, `events` |

`photo_metadata` is created in 001 rather than later: it is a 1:1 extension of
`photos` written inside the same transaction, so it must exist wherever `photos`
does. Data Model §46 does not say where it belongs.

Each migration runs in its own transaction, so an interruption leaves the
database at a completed version rather than half-applied (Data Model §74).

---

## Relationships

```text
users
  ├── user_preferences   (1:1)
  ├── cases              (1:N, SET NULL on delete)
  └── protocols          (1:N)

photos
  ├── reference_photo_id ──► photos      (RESTRICT)
  ├── photo_metadata     (1:1, RESTRICT)
  ├── calibrations       (1:N, RESTRICT)
  │     └── measurements (1:N, SET NULL)
  ├── annotations        (1:N, RESTRICT)
  ├── quality_checks     (1:N, RESTRICT)
  ├── alignments         (as reference or target, RESTRICT)
  ├── derived_assets     (1:N, RESTRICT)
  ├── comparisons        (as before or after, RESTRICT)
  ├── exports            (1:N, RESTRICT)
  └── gallery_exports    (1:N, RESTRICT)
```

**No unrestricted `ON DELETE CASCADE` anywhere.** Data Model §67 is explicit
about why: one Before photograph may be referenced by many After photographs and
comparisons, so deletion is decided by application policy, not by SQL. `RESTRICT`
means an accidental delete fails loudly instead of quietly removing a chain of
clinical records.

Deleting a case is the exception that proves it: `cases → photos` is `SET NULL`,
so a photograph becomes uncategorised rather than deleted (Data Model §35).

---

## Constraints worth knowing about

| Table | Constraint | Why |
|---|---|---|
| `photos` | `type IN ('BEFORE','AFTER','PHOTO')` | Only three modes exist |
| `photos` | `width_px > 0 AND height_px > 0` | Dimensions are established before the row is committed, so a placeholder is impossible |
| `photos` | `reference_photo_id <> id` | A photograph cannot be its own reference (Data Model §49). Enforced in SQL so no code path can bypass it |
| `calibrations` | `known_value > 0`, `pixel_distance > 0` | The schema half of "no physical units without a valid scale" |
| `measurements` | a physical value requires both a `calibration_id` and a `unit` | The other half. `Measurement.hasPhysicalValue` is the application-level gate |

The `measurements` CHECK deserves particular note: it makes "centimetres without
calibration" not merely a bug the code avoids, but a row the database refuses to
store.

---

## Conventions

- **UUID primary keys**, never auto-increment (Data Model §4), so future
  synchronization, backup and multi-device use need no renumbering.
- **Timestamps as INTEGER** milliseconds since epoch: sortable, indexable,
  timezone-free.
- **Booleans as INTEGER** 0/1 (Data Model §16).
- **Enums as their `wireName` string**, never a Dart index, so reordering an
  enum cannot corrupt historical rows.
- **Soft deletes** via `deleted_at`; every default query filters it out.
- **`version`** incremented on update, for future conflict resolution.

---

## JSON columns

Used where the shape varies by platform or evolves independently (Data Model
§61): `capture_recipe_json`, `metadata_json`, `raw_metadata_json`,
`geometry_json`, `properties_json`, `settings_json`, `configuration_json`,
`transform_matrix_json`, `details_json`, `alignment_json`.

Relational columns are used for anything filtered, sorted or joined on. The
specification's rule — "do not place all application data into one large JSON
document" — is respected: identifiers, foreign keys, timestamps, types, statuses
and frequently queried values are all real columns.

---

## Indexes

Every index Data Model §47 lists, plus `idx_photos_deleted_at`, because every
screen opens with a "recent, not deleted" query.

---

## Access

```text
UI  →  Controller  →  Repository  →  DatabaseService  →  SQLite
```

`DatabaseService` is the only class that **opens or configures** a connection.
Repositories use `sqflite`'s `Transaction` and `ConflictAlgorithm` types inside
`DatabaseService.transaction`, which is what lets a multi-table write roll back
as one unit (Data Model §43) — but they never open a database, set a pragma, or
run a migration.

No widget imports `sqflite` at all. Repositories return `Result<T>` with a typed
`Failure` rather than throwing (Data Model §65-66, Build Specification §102).

---

## Testing

`test/database/` runs against real SQLite via `sqflite_common_ffi`, so
constraints, foreign keys and transactions are exercised rather than mocked. The
migration suite stands up a v1 database with rows, upgrades it, and asserts the
rows survive.
