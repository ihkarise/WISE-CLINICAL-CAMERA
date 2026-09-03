import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/camera/camera_engine.dart';
import '../core/camera/plugin_camera_engine.dart';
import '../core/config/app_environment.dart';
import '../core/config/feature_flags.dart';
import '../core/cv/alignment_config.dart';
import '../core/cv/alignment_engine.dart';
import '../core/cv/focus_engine.dart';
import '../core/cv/guidance_engine.dart';
import '../core/cv/lighting_engine.dart';
import '../core/cv/local_alignment_engine.dart';
import '../core/cv/quality_config.dart';
import '../core/database/database_service.dart';
import '../core/errors/failures.dart';
import '../core/imaging/layer_renderer.dart';
import '../core/imaging/thumbnail_generator.dart';
import '../core/network/network_guard.dart';
import '../core/permissions/permission_service.dart';
import '../core/sensors/device_level_service.dart';
import '../core/storage/image_storage_service.dart';
import '../core/storage/storage_paths.dart';
import '../models/effective_settings.dart';
import '../models/tool_capabilities.dart';
import '../models/tool_overrides.dart';
import '../models/user_preferences.dart';
import '../models/wise_user.dart';
import '../repositories/case_repository.dart';
import '../repositories/clinical_repository.dart';
import '../repositories/photo_repository.dart';
import '../repositories/preference_repository.dart';
import '../repositories/protocol_repository.dart';
import '../services/ai/ai_service.dart';

/// Dependency wiring.
///
/// Keeps the layering the specifications require: UI reads providers,
/// providers expose repositories and services, and nothing in a widget touches
/// SQLite or a camera plugin directly (Data Model section 65, Build
/// Specification section 102).

// --- Configuration -----------------------------------------------------------

final environmentProvider = Provider<AppEnvironment>(
  (ref) => AppEnvironment.current,
);

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags.forEnvironment(ref.watch(environmentProvider)),
);

final alignmentConfigProvider = Provider<AlignmentConfig>(
  (ref) => const AlignmentConfig(),
);

final qualityConfigProvider = Provider<QualityConfig>(
  (ref) => const QualityConfig(),
);

// --- Infrastructure ----------------------------------------------------------

/// Resolved once at startup; everything below depends on it.
final storagePathsProvider = FutureProvider<StoragePaths>((ref) async {
  final paths = await StoragePaths.resolve();
  await paths.ensureCreated();
  return paths;
});

final databaseProvider = FutureProvider<DatabaseService>((ref) async {
  final paths = await ref.watch(storagePathsProvider.future);
  final service = DatabaseService();
  final opened = await service.open(path: paths.databasePath);
  if (opened.isFailure) {
    throw StateError('database unavailable: ${opened.failureOrNull}');
  }
  ref.onDispose(service.close);
  return service;
});

final imageStorageProvider = FutureProvider<ImageStorageService>((ref) async {
  final paths = await ref.watch(storagePathsProvider.future);
  return ImageStorageService(paths);
});

final networkGuardProvider = Provider<NetworkGuard>((ref) {
  final guard = NetworkGuard(flags: ref.watch(featureFlagsProvider));
  // Privacy Mode is mirrored onto the guard whenever preferences change, so
  // the enforcement point always reflects the user's current setting.
  ref.listen(preferencesProvider, (previous, next) {
    final preferences = next.valueOrNull;
    if (preferences != null) {
      guard.updatePrivacyMode(enabled: preferences.privacyMode);
    }
  });
  return guard;
});

// --- Repositories ------------------------------------------------------------

final photoRepositoryProvider = FutureProvider<PhotoRepository>((ref) async {
  return PhotoRepository(
    database: await ref.watch(databaseProvider.future),
    storage: await ref.watch(imageStorageProvider.future),
  );
});

final clinicalRepositoryProvider = FutureProvider<ClinicalRepository>((
  ref,
) async {
  return ClinicalRepository(database: await ref.watch(databaseProvider.future));
});

final caseRepositoryProvider = FutureProvider<CaseRepository>((ref) async {
  return CaseRepository(database: await ref.watch(databaseProvider.future));
});

final protocolRepositoryProvider = FutureProvider<ProtocolRepository>((
  ref,
) async {
  return ProtocolRepository(database: await ref.watch(databaseProvider.future));
});

final preferenceRepositoryProvider = FutureProvider<PreferenceRepository>((
  ref,
) async {
  return PreferenceRepository(
    database: await ref.watch(databaseProvider.future),
  );
});

// --- Engines -----------------------------------------------------------------

final alignmentEngineProvider = Provider<AlignmentEngine>(
  (ref) => LocalAlignmentEngine(config: ref.watch(alignmentConfigProvider)),
);

final guidanceEngineProvider = Provider<GuidanceEngine>(
  (ref) => GuidanceEngine(ref.watch(alignmentConfigProvider)),
);

final lightingEngineProvider = Provider<LightingEngine>(
  (ref) => LightingEngine(ref.watch(qualityConfigProvider)),
);

final focusEngineProvider = Provider<FocusEngine>(
  (ref) => FocusEngine(ref.watch(qualityConfigProvider)),
);

final layerRendererProvider = Provider<LayerRenderer>(
  (ref) => const LayerRenderer(),
);

final thumbnailGeneratorProvider = Provider<ThumbnailGenerator>(
  (ref) => const ThumbnailGenerator(),
);

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

final levelServiceProvider = Provider<DeviceLevelService>((ref) {
  final service = DeviceLevelService();
  ref.onDispose(service.dispose);
  return service;
});

/// Overridden with a `FakeCameraEngine` in tests.
final cameraEngineProvider = Provider<CameraEngine>((ref) {
  final engine = PluginCameraEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final aiServiceProvider = Provider<AiService>(
  (ref) => AiService(
    flags: ref.watch(featureFlagsProvider),
    networkGuard: ref.watch(networkGuardProvider),
    // V1 registers no provider: the core must work with AI off
    // (AI sections 3 and 65).
  ),
);

// --- Session state -----------------------------------------------------------

/// The local user, created on first launch.
final currentUserProvider = FutureProvider<WiseUser>((ref) async {
  final repository = await ref.watch(preferenceRepositoryProvider.future);
  final user = await repository.ensureLocalUser();

  final protocols = await ref.watch(protocolRepositoryProvider.future);
  await protocols.seedSystemProtocols(userId: user.id);

  return user;
});

/// Persistent tool defaults.
final preferencesProvider = FutureProvider<UserPreferences>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  final repository = await ref.watch(preferenceRepositoryProvider.future);
  return repository.load(user.id);
});

/// Detected device capabilities. The top of the settings precedence chain.
final toolCapabilitiesProvider = StateProvider<ToolCapabilities>(
  (ref) => ToolCapabilities.full,
);

/// One-capture overrides. Runtime only: never written to the database, which
/// is what makes an override temporary (Build Specification section 2.7).
final sessionOverridesProvider = StateProvider<ToolOverrides>(
  (ref) => ToolOverrides.none,
);

/// The active protocol's tool block, if a protocol is selected.
final activeProtocolOverridesProvider = StateProvider<ToolOverrides?>(
  (ref) => null,
);

/// The resolved configuration for the current capture.
final effectiveSettingsProvider = Provider<AsyncValue<EffectiveSettings>>((
  ref,
) {
  final preferences = ref.watch(preferencesProvider);
  return preferences.whenData(
    (defaults) => EffectiveSettings.resolve(
      defaults: defaults,
      capabilities: ref.watch(toolCapabilitiesProvider),
      protocol: ref.watch(activeProtocolOverridesProvider),
      session: ref.watch(sessionOverridesProvider),
    ),
  );
});

/// Saves a preference change as the new default (Functional SET-004).
final savePreferencesProvider =
    Provider<Future<Failure?> Function(UserPreferences)>((ref) {
      return (preferences) async {
        final repository = await ref.read(preferenceRepositoryProvider.future);
        final result = await repository.save(preferences);
        if (result.isOk) ref.invalidate(preferencesProvider);
        return result.failureOrNull;
      };
    });
