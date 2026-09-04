/// An optional grouping of photographs (Data Model section 7, Functional
/// CAS-001).
///
/// A photograph may exist without a case, and deleting a case never deletes its
/// photographs (Data Model section 35).
///
/// Deliberately carries no patient-identifying fields. Data Model section 52
/// and Privacy PRI-001 forbid storing a patient name, government ID or contact
/// details unless a future requirement explicitly defines them. `localReference`
/// is a user-chosen label; the user may put anything in it, so it is treated as
/// sensitive by the logger and by anonymized export.
class ClinicalCase {
  const ClinicalCase({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.localReference,
    this.title,
    this.notes,
    this.deletedAt,
    this.version = 1,
  });

  final String id;
  final String? userId;
  final String? localReference;
  final String? title;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;

  bool get isDeleted => deletedAt != null;

  String get displayTitle {
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) return trimmedTitle;
    final trimmedReference = localReference?.trim();
    if (trimmedReference != null && trimmedReference.isNotEmpty) {
      return trimmedReference;
    }
    return 'Untitled case';
  }

  ClinicalCase copyWith({
    String? localReference,
    String? title,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? version,
    bool clearDeletedAt = false,
  }) => ClinicalCase(
    id: id,
    userId: userId,
    localReference: localReference ?? this.localReference,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    version: version ?? this.version,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'local_reference': localReference,
    'title': title,
    'notes': notes,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'version': version,
  };

  static ClinicalCase fromRow(Map<String, Object?> row) => ClinicalCase(
    id: row['id']! as String,
    userId: row['user_id'] as String?,
    localReference: row['local_reference'] as String?,
    title: row['title'] as String?,
    notes: row['notes'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at']! as num).toInt(),
    ),
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (row['deleted_at']! as num).toInt(),
          ),
    version: (row['version'] as num?)?.toInt() ?? 1,
  );
}
