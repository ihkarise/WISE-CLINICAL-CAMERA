import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/calibration.dart';
import '../../models/enums.dart';
import '../../models/measurement.dart';
import '../../models/photo.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/clinical_image.dart';
import '../export/export_sheet.dart';

/// Everything known about one photograph.
final photoDetailProvider =
    FutureProvider.family<
      ({
        Calibration? calibration,
        List<Measurement> measurements,
        List<Photo> afters,
      }),
      Photo
    >((ref, photo) async {
      final clinical = await ref.watch(clinicalRepositoryProvider.future);
      final photos = await ref.watch(photoRepositoryProvider.future);

      return (
        calibration: await clinical.getCalibrationFor(photo.id),
        measurements: await clinical.getMeasurements(photo.id),
        afters: photo.type == PhotoType.before
            ? await photos.getAfterPhotosFor(photo.id)
            : const <Photo>[],
      );
    });

/// A single photograph with its clinical data and the actions available on it.
class PhotoDetailScreen extends ConsumerWidget {
  const PhotoDetailScreen({required this.photo, super.key});

  final Photo photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(photoDetailProvider(photo));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(photo.type.wireName),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Export',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ExportSheet(photo: photo),
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('This photograph could not be loaded.')),
        data: (data) => ListView(
          children: [
            AspectRatio(
              aspectRatio: photo.aspectRatio,
              child: ClinicalImage.file(
                photo.originalPath,
                semanticLabel:
                    '${photo.type.wireName} photograph, '
                    '${photo.widthPx} by ${photo.heightPx} pixels',
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(WiseTokens.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetadataRows(photo: photo),
                  const SizedBox(height: WiseTokens.space16),

                  // Measurements, or the reason there are none.
                  Text('Measurements', style: theme.textTheme.titleMedium),
                  const SizedBox(height: WiseTokens.space4),
                  if (data.calibration == null)
                    Text(
                      WiseStrings.calibrationRequired,
                      style: theme.textTheme.bodyMedium,
                    )
                  else if (data.measurements.isEmpty)
                    Text(
                      'No measurements yet.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    for (final measurement in data.measurements)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(measurement.type.label),
                        trailing: Text(measurement.displayValue),
                      ),

                  if (data.measurements.isNotEmpty) ...[
                    const SizedBox(height: WiseTokens.space4),
                    Text(
                      WiseStrings.measurementDisclaimer,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],

                  const SizedBox(height: WiseTokens.space16),
                  Wrap(
                    spacing: WiseTokens.space8,
                    runSpacing: WiseTokens.space8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.straighten_outlined, size: 18),
                        label: Text(
                          data.calibration == null
                              ? 'Set scale'
                              : 'Recalibrate',
                        ),
                        onPressed: () async {
                          await Navigator.of(
                            context,
                          ).pushNamed(WiseRoutes.calibration, arguments: photo);
                          ref.invalidate(photoDetailProvider(photo));
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Measure and mark'),
                        onPressed: () async {
                          await Navigator.of(
                            context,
                          ).pushNamed(WiseRoutes.markup, arguments: photo);
                          ref.invalidate(photoDetailProvider(photo));
                        },
                      ),
                      if (photo.type == PhotoType.before &&
                          data.afters.isNotEmpty)
                        FilledButton.icon(
                          icon: const Icon(Icons.compare_outlined, size: 18),
                          label: const Text('Compare'),
                          onPressed: () => Navigator.of(context).pushNamed(
                            WiseRoutes.comparison,
                            arguments: ComparisonArguments(
                              before: photo,
                              after: data.afters.last,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (data.afters.isNotEmpty) ...[
                    const SizedBox(height: WiseTokens.space16),
                    Text(
                      'After photographs (${data.afters.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataRows extends StatelessWidget {
  const _MetadataRows({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Captured', photo.capturedAt.toLocal().toString().split('.').first),
      ('Dimensions', '${photo.widthPx} x ${photo.heightPx}'),
      if (photo.bodyPart != null) ('Body part', photo.bodyPart!.label),
      if (photo.laterality != null) ('Side', photo.laterality!.label),
      ('Source', photo.source.wireName),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
