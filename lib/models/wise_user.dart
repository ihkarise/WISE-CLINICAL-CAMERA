/// The local application user (Data Model section 6).
///
/// No online account, no credentials, no authentication. The row exists so that
/// preferences and protocols have a stable owner and so future multi-device
/// synchronization has a key to hang on (Data Model section 55). See
/// SPECIFICATION_CONFLICTS C-012.
class WiseUser {
  const WiseUser({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
    this.version = 1,
  });

  final String id;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  Map<String, Object?> toRow() => {
    'id': id,
    'display_name': displayName,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'version': version,
  };

  static WiseUser fromRow(Map<String, Object?> row) => WiseUser(
    id: row['id']! as String,
    displayName: row['display_name'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
    version: (row['version'] as num?)?.toInt() ?? 1,
  );
}
