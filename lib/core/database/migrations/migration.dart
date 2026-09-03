import 'package:sqflite/sqflite.dart';

/// One numbered schema step (Data Model section 45).
///
/// The application must never assume it is starting from a clean database, so
/// upgrades run only the migrations above the stored version, in order.
abstract class Migration {
  const Migration();

  /// 1-based. Matches `PRAGMA user_version`.
  int get version;

  /// Short description, used by the migration test's failure messages.
  String get description;

  Future<void> apply(Transaction txn);
}
