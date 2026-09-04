/// Build configurations required by Build Specification section 95.
///
/// Development may enable CV debug overlays, verbose logging and mock
/// providers. Production must disable all of them (Build Specification
/// sections 87-88).
enum AppEnvironment {
  development,
  staging,
  production;

  /// Resolved from `--dart-define=WISE_ENV=...`, defaulting to production.
  ///
  /// Defaulting to production means a build that forgets the flag is the *safe*
  /// build: debug overlays and verbose logging stay off.
  static final AppEnvironment current = _parse(
    const String.fromEnvironment('WISE_ENV', defaultValue: 'production'),
  );

  static AppEnvironment _parse(String value) => switch (value.toLowerCase()) {
    'development' || 'dev' => AppEnvironment.development,
    'staging' => AppEnvironment.staging,
    _ => AppEnvironment.production,
  };

  bool get isDevelopment => this == AppEnvironment.development;
  bool get isProduction => this == AppEnvironment.production;

  /// CV debug overlays (keypoints, match lines, inliers) must never appear in a
  /// production build (Build Specification section 88).
  bool get allowsCvDebugOverlay => isDevelopment;

  /// Verbose technical logging. Never includes image pixels in any environment
  /// (Privacy sections 20-21).
  bool get allowsVerboseLogging => !isProduction;
}
