# Changelog

All notable changes to WISE Clinical Camera.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The initial implementation, built from the ten v1.0 specifications. Milestones
1-5 of the Build Specification's ordering are implemented; milestone 6 (AI)
ships as an abstraction with no provider, which is the specified V1 state.

### Added

**Foundation**
- Flutter project targeting iOS and Android, with development, staging and
  production build configurations.
- `AppEnvironment` and `FeatureFlags`. CV debug overlays are forced off outside
  development; cloud AI, on-device ML, homography and optical flow default off.
- Typed `Failure` hierarchy and `Result<T>`; no service throws, and no raw
  exception can reach a user.
- `AppLogger`, which accepts scalar fields only, redacts sensitive keys and
  reduces paths to their basename.
- `NetworkGuard`: the single gate and audit log for outbound requests.

**Design system**
- `WiseTokens` and `WiseTheme` implementing the WiseAiTechs brand colours,
  mobile type scale, spacing, geometry and motion quoted in the UX/UI
  specification. Light application theme plus a dark camera theme.

**Data**
- Sixteen tables across migrations 001-004, foreign keys enforced, no
  unrestricted `ON DELETE CASCADE`, UUID identifiers throughout.
- Entities: photo, case, user, preferences, protocol, calibration, measurement,
  annotation, alignment, quality check, derived asset, comparison, export,
  gallery export, photo metadata, capture recipe.
- `EffectiveSettings`, implementing the settings precedence chain as a pure
  function.
- `ImageStorageService` with the two-phase file/database write and orphan
  cleanup.
- `PhotoRepository` deletion policy: refuses to delete a referenced Before,
  soft-deletes, keeps the original on disk, never touches a Gallery copy.

**Camera and sensors**
- `CameraEngine` interface with capability detection, plus the plugin-backed
  implementation and a fake for testing.
- `DeviceLevelService` for tilt, degrading quietly on a device without a
  sensor.
- `PermissionService` requesting contextually and never re-prompting a
  permanent denial.

**Computer vision**
- FAST-9 detection over a scale pyramid, intensity-centroid orientation,
  rotated BRIEF descriptors, Hamming matching with Lowe ratio and cross-check,
  RANSAC similarity estimation with a least-squares refit.
- `ConfidenceModel` with hard gates before scoring and multiplicative gating on
  inlier ratio and spatial spread.
- `GuidanceEngine` translating estimates into plain instructions.
- `LightingEngine` and `FocusEngine`, both advisory.
- Every threshold in configuration, documented as provisional in
  `docs/cv/THRESHOLDS.md`.

**Clinical tools**
- Calibration by ruler, marker or known distance, with validation that refuses
  a nonsensical scale.
- Length, width, diameter, perimeter and area measurement; pixel-only without
  calibration.
- Eight annotation types, non-destructive, individually hideable and deletable.
- Before/After measurement change with a null percentage on a zero baseline.

**Workflow**
- BEFORE, AFTER and PHOTO capture flows; reference picker with gallery import;
  ghost overlay with opacity, transform, flip and lock; review, library, cases,
  protocols, settings.
- Five comparison modes; the difference view carries its disclaimer as part of
  the view.
- Seven export presets, anonymized export with a documented field list, gallery
  save policy that Privacy Mode cannot be configured around.

**AI**
- `AiService` with a provider abstraction ordered on-device, self-hosted, cloud.
  No provider registered, no vendor SDK imported.

**Documentation and CI**
- Knowledge map, requirements traceability, specification conflicts register,
  architecture, CV thresholds, device test plan, release gates, dependency
  justification, network policy.
- CI running format, analyze, tests, a privacy gate that fails if an `INTERNET`
  permission appears, a secret scan, and Android and iOS builds.

### Fixed

- `package:image` throws `RangeError` on short or malformed buffers rather than
  returning null, so a truncated or corrupt file would have crashed the app.
  All decoding now goes through `ImageCodec`. Found by the immutability test.
- BRIEF descriptors are not scale-invariant, so alignment failed under a change
  in subject size — the exact case "Move closer" exists to address. Added a
  scale pyramid. Found by the scale regression test.
- The measurement change table mutated the widget's own list during build.
- The CV dataset's scale transform composited at a negative offset, which
  `package:image` does not clip correctly, silently producing a translation
  instead of a scale.

### Not verified

iOS and Android builds, real camera behaviour, sensors, gallery permissions,
performance, memory, thermal and battery. This build environment has no Android
SDK, no Xcode and no device. See `docs/testing/DEVICE_TEST_PLAN.md` and
`docs/deployment/RELEASE_GATES.md`.
