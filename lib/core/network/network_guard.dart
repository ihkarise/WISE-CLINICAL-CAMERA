import '../config/feature_flags.dart';
import '../errors/failures.dart';
import '../errors/result.dart';

/// One recorded network attempt.
class NetworkAttempt {
  const NetworkAttempt({
    required this.host,
    required this.purpose,
    required this.allowed,
    required this.at,
    this.carriedImage = false,
    this.blockReason,
  });

  final String host;
  final String purpose;
  final bool allowed;
  final DateTime at;

  /// True when the request would have carried clinical image data.
  final bool carriedImage;
  final String? blockReason;
}

/// The single gate every outbound request must pass (Privacy section 31,
/// Build Specification sections 72-73).
///
/// Two jobs:
///
/// 1. **Enforcement.** Clinical images may leave the device only when the user
///    has explicitly enabled a feature that requires it. Privacy Mode and a
///    disabled cloud-AI flag both refuse unconditionally (Privacy PRI-003).
/// 2. **Audit.** Every attempt is recorded, so a test can assert that the whole
///    BEFORE-to-export workflow produced no outbound request at all. That is
///    the privacy testing hook Build Specification section 73 asks for, and it
///    is what `test/privacy/network_policy_test.dart` checks.
///
/// The core camera, storage, CV, measurement, annotation, comparison and export
/// paths contain no call site for this class. That absence is the actual
/// guarantee; the guard exists so that any future call site is visible.
class NetworkGuard {
  NetworkGuard({
    required FeatureFlags flags,
    bool privacyMode = true,
    int auditLimit = 256,
  }) : _flags = flags,
       _privacyMode = privacyMode,
       _auditLimit = auditLimit;

  FeatureFlags _flags;
  bool _privacyMode;
  final int _auditLimit;
  final List<NetworkAttempt> _audit = <NetworkAttempt>[];

  /// Attempts recorded so far, oldest first.
  List<NetworkAttempt> get audit => List.unmodifiable(_audit);

  /// Attempts that were permitted. A core-workflow test asserts this is empty.
  List<NetworkAttempt> get allowedAttempts =>
      _audit.where((a) => a.allowed).toList(growable: false);

  /// Permitted attempts that would have carried image data.
  List<NetworkAttempt> get imageUploads =>
      _audit.where((a) => a.allowed && a.carriedImage).toList(growable: false);

  void updateFlags(FeatureFlags flags) => _flags = flags;

  void updatePrivacyMode({required bool enabled}) => _privacyMode = enabled;

  void clearAudit() => _audit.clear();

  /// Asks permission for one outbound request.
  ///
  /// [carriesImage] must be true whenever any clinical pixel data would be
  /// transmitted. Callers that lie defeat the guarantee, which is why the core
  /// simply never calls this.
  Result<void> authorize({
    required String host,
    required String purpose,
    bool carriesImage = false,
  }) {
    String? blockReason;

    if (carriesImage && _privacyMode) {
      blockReason = 'Privacy Mode forbids sending images off the device.';
    } else if (carriesImage && !_flags.cloudAi) {
      blockReason = 'Cloud AI is disabled, so no image may be transmitted.';
    } else if (!carriesImage && _privacyMode) {
      blockReason = 'Privacy Mode forbids network access.';
    }

    _record(
      NetworkAttempt(
        host: host,
        purpose: purpose,
        allowed: blockReason == null,
        at: DateTime.now(),
        carriedImage: carriesImage,
        blockReason: blockReason,
      ),
    );

    if (blockReason != null) {
      return Result.failed(NetworkBlockedByPolicy(blockReason));
    }
    return const Result.ok(null);
  }

  void _record(NetworkAttempt attempt) {
    _audit.add(attempt);
    if (_audit.length > _auditLimit) _audit.removeAt(0);
  }
}
