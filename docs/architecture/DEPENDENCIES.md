# Dependencies

Build Specification §5 and master-prompt Phase 52 require every dependency to
be justified against a checklist before it is added:

1. Can Flutter/Dart already do it?
2. Is a native platform API sufficient?
3. Does an existing dependency already provide it?
4. Maintenance status
5. Licence compatibility
6. iOS and Android support
7. Size and performance
8. Security history

Sixteen direct runtime dependencies. Each is answered below.

---

## Runtime

### `flutter_riverpod`

**Need:** state management with a clear separation of persistent, session,
processing and UI state (Build Specification §103).

**Why not built in:** `InheritedWidget` and `ChangeNotifier` work, but neither
makes the *layering* visible. Riverpod's provider graph maps directly onto the
architecture: `preferencesProvider` is persistent, `sessionOverridesProvider` is
runtime-only, and `effectiveSettingsProvider` derives from both. That the
session layer is a separate provider is what makes "an override never becomes a
default" structural rather than a convention.

**Assessment:** actively maintained, MIT, both platforms, compile-time safe,
no platform channels.

### `camera`

**Need:** the platform bridge behind `CameraEngine`.

**Why not native directly:** writing and maintaining two native camera
implementations is a large, high-risk surface for no gain over the first-party
plugin. Where the plugin is insufficient, the abstraction lets a native bridge
be added behind it.

**Assessment:** Flutter-team maintained, BSD-3, both platforms. Imported by
exactly one file (`plugin_camera_engine.dart`), so replacing it touches nothing
else.

### `sqflite`

**Need:** local structured storage (Data Model §2).

**Why not alternatives:** the data model is relational — foreign keys, indexed
queries, CHECK constraints, numbered migrations. A key-value store would mean
reimplementing referential integrity in Dart, which Data Model §35 explicitly
does not want.

**Assessment:** widely used, MIT, both platforms, and it is SQLite, whose
security history is exceptionally good.

### `path_provider` and `path`

**Need:** application-private directories (Data Model §3, Privacy §10-11), and
path manipulation.

**Why not built in:** `dart:io` cannot resolve the platform-specific private
support directory. `path` is Dart-team maintained and avoids a hand-rolled
cross-platform join.

**Assessment:** both Flutter/Dart team, BSD-3.

### `image`

**Need:** decode and encode for thumbnails, derived assets, exports and the CV
working image.

**Why not `dart:ui`:** `dart:ui` image handling requires a Flutter binding, so
it cannot run in a plain unit test or a background isolate without one. Pure
Dart is what lets the immutability test, the export tests and the CV suite run
in CI.

**Caveat, and the reason `ImageCodec` exists:** `decodeImage` throws
`RangeError` on short or malformed buffers rather than returning null. Every
decode in the application goes through `ImageCodec`, which cannot throw.

**Assessment:** widely used, MIT, pure Dart.

### `sensors_plus`

**Need:** accelerometer for the level tool (Functional LVL-002).

**Why not native:** no Dart API exists for platform sensors.

**Assessment:** Flutter Community maintained, BSD-3. Used in one file, which
also handles the no-sensor case.

### `crypto`

**Need:** SHA-256 for original-file integrity (Data Model §39).

**Why not hand-rolled:** never implement a hash primitive when a
Dart-team-maintained one exists.

**Assessment:** Dart team, BSD-3, pure Dart, supports chunked conversion so a
large photograph is never fully buffered.

### `uuid`

**Need:** stable globally unique identifiers (Data Model §4).

**Why not hand-rolled:** `Random.secure()` plus manual formatting is easy to get
subtly wrong, and identifier collisions in clinical records are unrecoverable.

**Assessment:** widely used, MIT, pure Dart.

### `permission_handler`

**Need:** contextual permission requests with a permanent-denial distinction
(Privacy §5-9).

**Why not native:** the permanent-denial state and the settings route differ
substantially between iOS and Android, and getting that wrong means either
re-prompting a user who cannot be prompted (Privacy §9 forbids it) or dead-ending
them.

**Assessment:** widely used, MIT, both platforms. Wrapped behind
`PermissionHandlerPlatformShim` so `PermissionService` is testable.

### `image_picker`

**Need:** importing a reference from the device gallery (Functional MOD-002).

**Why it is the right choice for privacy:** it uses the platform photo picker,
which on modern Android and iOS returns a single chosen image **without**
granting broad library access. That directly serves Privacy §7-8: WISE should
not need unrestricted gallery access to import one photograph.

**Assessment:** Flutter team, BSD-3.

### `file_selector`

**Need:** the Files/document import source (Functional MOD-002).

**Assessment:** Flutter team, BSD-3. Small; could be dropped if the Files source
is cut.

### `gal`

**Need:** explicit, user-initiated gallery export (Functional SAV-002).

**Why not `image_picker`:** it reads, it does not write.

**Why this one:** it requests the *add-only* permission where the platform
offers one, which is the least privilege that achieves the task. Album support
covers PRD §27's `WISE Clinical Photos`.

**Assessment:** actively maintained, MIT, both platforms. Wrapped behind
`GalleryPlatform` so the policy is testable without a channel.

### `share_plus`

**Need:** the share sheet for a user-initiated export (Privacy §44).

**Assessment:** Flutter Community, BSD-3.

### `cupertino_icons`

Flutter template default. Retained for iOS-style glyphs.

---

## Development

### `flutter_lints`

The lint baseline, extended in `analysis_options.yaml` with strict casts,
strict inference, and `unawaited_futures` and `only_throw_errors` promoted to
errors. Dropping a future that writes a file or commits a row is a data-loss
bug, so it should not compile.

### `sqflite_common_ffi`

**Need:** the real SQLite engine on the test host.

**Why it matters:** migrations, foreign keys, CHECK constraints and transaction
rollback are tested for real rather than against a mock. A mocked database
would happily accept a self-referencing photo row; real SQLite rejects it, and
`photo_repository_test.dart` proves it.

---

## Deliberately not added

| Package | Why not |
|---|---|
| `google_fonts` | Fetches font files over the network at runtime, breaching offline-first (PRD §30) and the network policy (Privacy §31). Poppins is declared with a fallback chain instead; drop the files into `assets/fonts/` to enable it |
| OpenCV bindings | 20-40 MB per ABI, a large native attack surface in an app holding clinical images, and it would not run in CI without a device. Full reasoning in SPECIFICATION_CONFLICTS C-013 |
| `http` / `dio` | The core makes no network request. Adding an HTTP client would create the call site the privacy architecture exists to prevent |
| Any analytics or crash-reporting SDK | Privacy §23-24 and §42: no analytics on image content, no image content in crash reports. A future addition must be assessed against those sections first |
| Any AI vendor SDK | AI §47 (vendor lock-in) and Build Specification §64. Providers register against `AiProvider`; the abstraction imports nothing |
| A code-generation stack (`freezed`, `json_serializable`) | The models are hand-written and readable. Generated code would add a build step and obscure the `toRow`/`fromRow` mapping, which is where schema mistakes are easiest to spot |
| A routing package | `onGenerateRoute` covers ten screens with typed arguments |

---

## Reviewing a new dependency

Answer all eight checklist questions in the pull request. For anything that
touches images, storage, the network or a permission, also state:

- what it can access that the app could not before
- whether it opens a network connection, ever
- whether it can read or write an original photograph
- how it fails, and whether that failure becomes a typed `Failure`
