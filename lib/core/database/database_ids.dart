import 'package:uuid/uuid.dart';

/// Identifier generation (Data Model section 4).
///
/// Every persistent entity gets a UUID rather than an auto-increment integer,
/// which is what makes future synchronization, backup/restore and multi-device
/// use possible without renumbering anything.
///
/// Injectable so tests can produce deterministic identifiers.
class DatabaseIds {
  const DatabaseIds([this._generate = _defaultGenerate]);

  /// Deterministic sequence for tests: `prefix-1`, `prefix-2`, ...
  factory DatabaseIds.sequential(String prefix) {
    var counter = 0;
    return DatabaseIds(() {
      counter++;
      return '$prefix-$counter';
    });
  }

  static const Uuid _uuid = Uuid();
  static String _defaultGenerate() => _uuid.v4();

  final String Function() _generate;

  String newId() => _generate();
}
