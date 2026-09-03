import '../../core/config/feature_flags.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import '../../core/network/network_guard.dart';

/// Where an AI request would be processed (Functional PRI-003, Privacy 25-28).
///
/// Surfaced to the user, because "the AI processing must identify whether
/// processing is local, self-hosted or cloud-based".
enum AiProcessingLocation {
  onDevice('On this device'),
  selfHosted('On your own server'),
  cloud('A cloud service');

  const AiProcessingLocation(this.label);
  final String label;

  /// True when using this location would send data off the device.
  bool get leavesDevice => this != AiProcessingLocation.onDevice;
}

/// The AI capabilities the architecture anticipates (Technical Architecture
/// section 39, AI section 66).
enum AiCapability {
  bodyRegionDetection,
  landmarkDetection,
  photoQualityAssessment,
  imageDescription,
  documentTextExtraction,
  reportAssistance,
}

/// A request to an AI provider.
class AiRequest {
  const AiRequest({
    required this.capability,
    this.imageBytes,
    this.text,
    this.context = const <String, Object?>{},
  });

  final AiCapability capability;

  /// Present only for capabilities that genuinely need pixels. A provider that
  /// would transmit this must clear [NetworkGuard] first.
  final List<int>? imageBytes;

  final String? text;
  final Map<String, Object?> context;

  bool get carriesImage => imageBytes != null && imageBytes!.isNotEmpty;
}

/// An AI result.
///
/// Always carries [location] and [isExperimental] so the UI can label it as
/// AI-generated assistance and never as clinical fact (Build Specification
/// sections 113, AI section 57, Functional section 44).
class AiResult {
  const AiResult({
    required this.capability,
    required this.location,
    required this.data,
    this.confidence,
    this.isExperimental = true,
    this.modelVersion,
  });

  final AiCapability capability;
  final AiProcessingLocation location;
  final Map<String, Object?> data;
  final double? confidence;
  final bool isExperimental;
  final String? modelVersion;

  /// The label shown beside any AI output.
  static const String assistanceLabel = 'AI-generated assistance';

  /// Shown when experimental AI output is displayed.
  static const String experimentalNotice =
      'Experimental. This is not a clinical finding and has not been '
      'validated.';
}

/// One AI backend (AI section 44, Build Specification section 64).
abstract class AiProvider {
  String get name;

  AiProcessingLocation get location;

  Future<bool> isAvailable();

  Future<Result<AiResult>> analyze(AiRequest request);

  /// Capabilities this provider actually implements.
  Set<AiCapability> get capabilities;
}

/// The entry point every feature uses (AI section 44, Technical Architecture
/// section 39).
///
/// Two properties matter more than anything this class does:
///
/// 1. **The core works with AI off.** With no provider registered, every call
///    returns [AiUnavailable] and nothing in the capture, storage, CV,
///    measurement, annotation, comparison or export path notices. That is the
///    state V1 ships in (AI sections 3, 65; Build Specification section 2.4).
/// 2. **No vendor SDK is imported anywhere.** Providers are registered by the
///    application, so no feature depends on a specific vendor
///    (AI section 47, Build Specification section 64).
///
/// A provider that would send an image off the device must clear
/// [NetworkGuard] first, and the guard refuses under Privacy Mode or with
/// cloud AI disabled (Privacy PRI-003, AI section 8).
class AiService {
  AiService({
    required FeatureFlags flags,
    NetworkGuard? networkGuard,
    List<AiProvider> providers = const <AiProvider>[],
  }) : _flags = flags,
       _networkGuard = networkGuard,
       _providers = List.of(providers);

  FeatureFlags _flags;
  final NetworkGuard? _networkGuard;
  final List<AiProvider> _providers;

  /// True when no AI will run at all. The V1 default.
  bool get isDisabled => _flags.aiFullyDisabled || _providers.isEmpty;

  List<AiProvider> get providers => List.unmodifiable(_providers);

  void updateFlags(FeatureFlags flags) => _flags = flags;

  void registerProvider(AiProvider provider) => _providers.add(provider);

  /// Runs a request through the cheapest capable provider.
  ///
  /// Routing follows the escalation order the specifications insist on:
  /// on-device, then self-hosted, then cloud. A higher-cost layer is only
  /// reached when no lower one can serve the request (AI sections 5, 66;
  /// Build Specification section 66; master prompt Phase 35).
  Future<Result<AiResult>> analyze(AiRequest request) async {
    if (isDisabled) {
      return const Result.failed(
        AiUnavailable(technicalDetail: 'AI is disabled'),
      );
    }

    for (final provider in _orderedProviders()) {
      if (!provider.capabilities.contains(request.capability)) continue;
      if (!await provider.isAvailable()) continue;

      if (provider.location.leavesDevice) {
        final gate = _authorize(provider, request);
        if (gate.isFailure) continue;
      }

      final result = await provider.analyze(request);
      if (result.isOk) return result;
    }

    return const Result.failed(AiUnavailable());
  }

  /// Cheapest and most private first.
  List<AiProvider> _orderedProviders() {
    final ordered = List.of(_providers);
    ordered.sort((a, b) => a.location.index.compareTo(b.location.index));
    return ordered;
  }

  Result<void> _authorize(AiProvider provider, AiRequest request) {
    if (provider.location == AiProcessingLocation.cloud && !_flags.cloudAi) {
      return const Result.failed(
        NetworkBlockedByPolicy('Cloud AI is turned off.'),
      );
    }

    final guard = _networkGuard;
    if (guard == null) {
      // No guard means no audited route off the device, so refuse rather than
      // transmit unaudited. Failing closed is the required direction
      // (Privacy PRI-003).
      return const Result.failed(
        NetworkBlockedByPolicy('No audited network route is configured.'),
      );
    }

    return guard.authorize(
      host: provider.name,
      purpose: 'ai:${request.capability.name}',
      carriesImage: request.carriesImage,
    );
  }
}

/// The V1 provider: none.
///
/// Registered so the abstraction is exercised and so a future provider slots in
/// without changing a caller. It never runs a model and never touches the
/// network, which is exactly what "mandatory per-photo AI API cost = $0"
/// requires (AI section 64).
class DisabledAiProvider implements AiProvider {
  const DisabledAiProvider();

  @override
  String get name => 'disabled';

  @override
  AiProcessingLocation get location => AiProcessingLocation.onDevice;

  @override
  Set<AiCapability> get capabilities => const <AiCapability>{};

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Result<AiResult>> analyze(AiRequest request) async =>
      const Result.failed(AiUnavailable());
}
