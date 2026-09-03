import 'dart:developer' as developer;

import '../config/app_environment.dart';

/// Severity levels. `LogLevel.debug` is dropped entirely in production.
enum LogLevel { debug, info, warning, error }

/// Privacy-safe logging (Privacy sections 20-22, Technical Architecture 45).
///
/// Production logs must never contain image pixels, patient names, clinical
/// notes, identifiers or secrets. This logger cannot be handed an image: it
/// takes a message plus a map of scalar fields, and it redacts any field whose
/// key looks sensitive or whose value looks like a filesystem path or a long
/// opaque blob.
///
/// Redaction here is a backstop, not a licence: call sites must still not pass
/// sensitive data.
class AppLogger {
  const AppLogger(this.component, {AppEnvironment? environment})
    : _environmentOverride = environment;

  /// Short name of the subsystem, e.g. `camera`, `storage`, `cv`.
  final String component;
  final AppEnvironment? _environmentOverride;

  AppEnvironment get _environment =>
      _environmentOverride ?? AppEnvironment.current;

  /// Field names that are never printed, whatever their value.
  static const Set<String> _blockedKeys = {
    'image',
    'pixels',
    'bytes',
    'thumbnail',
    'photo',
    'name',
    'patient',
    'patientname',
    'note',
    'notes',
    'diagnosis',
    'apikey',
    'api_key',
    'token',
    'password',
    'secret',
    'key',
    'authorization',
    'credential',
    'gps',
    'latitude',
    'longitude',
    'location',
    'title',
    'label',
    'text',
    'localreference',
  };

  void debug(String message, [Map<String, Object?>? fields]) =>
      _log(LogLevel.debug, message, fields);

  void info(String message, [Map<String, Object?>? fields]) =>
      _log(LogLevel.info, message, fields);

  void warning(String message, [Map<String, Object?>? fields]) =>
      _log(LogLevel.warning, message, fields);

  void error(String message, [Map<String, Object?>? fields]) =>
      _log(LogLevel.error, message, fields);

  void _log(LogLevel level, String message, Map<String, Object?>? fields) {
    if (level == LogLevel.debug && !_environment.allowsVerboseLogging) return;

    final buffer = StringBuffer(message);
    if (fields != null && fields.isNotEmpty) {
      buffer.write(' {');
      var first = true;
      for (final entry in fields.entries) {
        if (!first) buffer.write(', ');
        first = false;
        buffer.write('${entry.key}=${redact(entry.key, entry.value)}');
      }
      buffer.write('}');
    }

    developer.log(
      buffer.toString(),
      name: 'wise.$component',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
    );
  }

  /// Exposed for `test/privacy/logging_test.dart`.
  static String redact(String key, Object? value) {
    if (_blockedKeys.contains(key.toLowerCase())) return '<redacted>';
    if (value == null) return 'null';
    if (value is num || value is bool) return '$value';
    if (value is List || value is Map || value is Set) {
      return '<${value.runtimeType}>';
    }

    final text = '$value';
    // A filesystem path can carry a user or case name in a parent directory.
    // Only the basename is ever useful for debugging, and WISE basenames are
    // opaque UUIDs by construction (Privacy section 12).
    if (text.contains('/') || text.contains(r'\')) {
      final segments = text.split(RegExp(r'[/\\]'));
      return '.../${segments.last}';
    }
    if (text.length > 96) return '<${text.length} chars>';
    return text;
  }
}
