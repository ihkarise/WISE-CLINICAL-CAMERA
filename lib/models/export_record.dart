import 'dart:convert';

import 'enums.dart';

/// Which layers an export includes (Data Model section 31, Functional EXP-002).
class ExportConfiguration {
  const ExportConfiguration({
    this.includeAnnotations = true,
    this.includeMeasurements = true,
    this.includeGrid = false,
    this.includeFooter = true,
    this.includeMetadata = false,
    this.includeDate = true,
    this.footerText,
    this.maxDimension,
  });

  factory ExportConfiguration.fromMap(Map<String, Object?> map) =>
      ExportConfiguration(
        includeAnnotations: map['include_annotations'] as bool? ?? true,
        includeMeasurements: map['include_measurements'] as bool? ?? true,
        includeGrid: map['include_grid'] as bool? ?? false,
        includeFooter: map['include_footer'] as bool? ?? true,
        includeMetadata: map['include_metadata'] as bool? ?? false,
        includeDate: map['include_date'] as bool? ?? true,
        footerText: map['footer_text'] as String?,
        maxDimension: (map['max_dimension'] as num?)?.toInt(),
      );

  /// The configuration each preset implies (Functional EXP-001, EXP-004).
  ///
  /// `ORIGINAL` deliberately includes nothing: "Original export must preserve
  /// original image content and should not include optional overlays unless
  /// explicitly requested."
  factory ExportConfiguration.forPreset(ExportPreset preset) =>
      switch (preset) {
        ExportPreset.original => const ExportConfiguration(
          includeAnnotations: false,
          includeMeasurements: false,
          includeFooter: false,
          includeMetadata: true,
          includeDate: false,
        ),
        ExportPreset.annotated => const ExportConfiguration(
          includeMeasurements: false,
        ),
        ExportPreset.measured => const ExportConfiguration(
          includeAnnotations: false,
        ),
        ExportPreset.beforeAfter => const ExportConfiguration(
          includeAnnotations: false,
          includeMeasurements: false,
        ),
        ExportPreset.beforeAfterMeasurements => const ExportConfiguration(),
        ExportPreset.anonymized => const ExportConfiguration(
          includeMetadata: false,
          includeDate: false,
          includeFooter: false,
        ),
        ExportPreset.reportReady => const ExportConfiguration(),
      };

  final bool includeAnnotations;
  final bool includeMeasurements;
  final bool includeGrid;
  final bool includeFooter;

  /// Whether EXIF-style metadata is carried into the exported file.
  final bool includeMetadata;

  final bool includeDate;
  final String? footerText;

  /// Longest edge of the exported image. Null keeps the original resolution
  /// (Technical Architecture section 44).
  final int? maxDimension;

  ExportConfiguration copyWith({
    bool? includeAnnotations,
    bool? includeMeasurements,
    bool? includeGrid,
    bool? includeFooter,
    bool? includeMetadata,
    bool? includeDate,
    String? footerText,
    int? maxDimension,
  }) => ExportConfiguration(
    includeAnnotations: includeAnnotations ?? this.includeAnnotations,
    includeMeasurements: includeMeasurements ?? this.includeMeasurements,
    includeGrid: includeGrid ?? this.includeGrid,
    includeFooter: includeFooter ?? this.includeFooter,
    includeMetadata: includeMetadata ?? this.includeMetadata,
    includeDate: includeDate ?? this.includeDate,
    footerText: footerText ?? this.footerText,
    maxDimension: maxDimension ?? this.maxDimension,
  );

  Map<String, Object?> toMap() => {
    'include_annotations': includeAnnotations,
    'include_measurements': includeMeasurements,
    'include_grid': includeGrid,
    'include_footer': includeFooter,
    'include_metadata': includeMetadata,
    'include_date': includeDate,
    if (footerText != null) 'footer_text': footerText,
    if (maxDimension != null) 'max_dimension': maxDimension,
  };
}

/// A completed or attempted export (Data Model section 30).
class ExportRecord {
  const ExportRecord({
    required this.id,
    required this.preset,
    required this.outputPath,
    required this.createdAt,
    required this.status,
    this.photoId,
    this.comparisonId,
    this.configuration = const ExportConfiguration(),
    this.anonymized = false,
  });

  final String id;
  final String? photoId;
  final String? comparisonId;
  final ExportPreset preset;
  final String outputPath;
  final ExportConfiguration configuration;
  final bool anonymized;
  final DateTime createdAt;
  final String status;

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'comparison_id': comparisonId,
    'preset': preset.wireName,
    'output_path': outputPath,
    'configuration_json': jsonEncode(configuration.toMap()),
    'anonymized': anonymized ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'status': status,
  };

  static ExportRecord fromRow(Map<String, Object?> row) => ExportRecord(
    id: row['id']! as String,
    photoId: row['photo_id'] as String?,
    comparisonId: row['comparison_id'] as String?,
    preset: ExportPreset.fromWire(row['preset']! as String),
    outputPath: row['output_path']! as String,
    configuration: row['configuration_json'] == null
        ? const ExportConfiguration()
        : ExportConfiguration.fromMap(
            jsonDecode(row['configuration_json']! as String)
                as Map<String, Object?>,
          ),
    anonymized: (row['anonymized'] as num?)?.toInt() == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    status: row['status'] as String? ?? 'COMPLETE',
  );
}

/// A record that a copy was placed in the device Gallery (Data Model 32).
///
/// The Gallery copy is an independent file. Deleting the WISE photograph must
/// not silently delete it (Data Model section 37.7, Functional section 34), and
/// the database must not assume the asset still exists.
class GalleryExport {
  const GalleryExport({
    required this.id,
    required this.photoId,
    required this.createdAt,
    required this.status,
    this.derivedAssetId,
    this.platformAssetIdentifier,
    this.albumName,
  });

  final String id;
  final String photoId;
  final String? derivedAssetId;
  final String? platformAssetIdentifier;
  final String? albumName;
  final DateTime createdAt;
  final String status;

  Map<String, Object?> toRow() => {
    'id': id,
    'photo_id': photoId,
    'derived_asset_id': derivedAssetId,
    'platform_asset_identifier': platformAssetIdentifier,
    'album_name': albumName,
    'created_at': createdAt.millisecondsSinceEpoch,
    'status': status,
  };

  static GalleryExport fromRow(Map<String, Object?> row) => GalleryExport(
    id: row['id']! as String,
    photoId: row['photo_id']! as String,
    derivedAssetId: row['derived_asset_id'] as String?,
    platformAssetIdentifier: row['platform_asset_identifier'] as String?,
    albumName: row['album_name'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at']! as num).toInt(),
    ),
    status: row['status'] as String? ?? 'SAVED',
  );
}
