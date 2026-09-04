import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../models/photo.dart';
import '../../shared/widgets/clinical_image.dart';

/// A photograph in a list or grid.
///
/// Loads the thumbnail, never the full-resolution original: browsing must not
/// decode clinical photographs at full size (Data Model sections 40 and 70,
/// Build Specification sections 60 and 107).
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    required this.photo,
    this.onTap,
    this.size = 104,
    this.showBadge = true,
    super.key,
  });

  final Photo photo;
  final VoidCallback? onTap;
  final double size;

  /// The BEFORE/AFTER/PHOTO badge (UX/UI section 45).
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final path = photo.thumbnailPath ?? photo.originalPath;

    return Semantics(
      button: onTap != null,
      label: _semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WiseTokens.controlRadius),
                child: Stack(
                  children: [
                    SizedBox(
                      width: size,
                      height: size,
                      // The library falls back to the original when a
                      // thumbnail is missing, so the decode must still be
                      // bounded (Data Model section 70).
                      child: ClinicalImage.file(path, fit: BoxFit.cover),
                    ),
                    if (showBadge)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: _TypeBadge(type: photo.type),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: WiseTokens.space4),
              Text(
                _formatDate(photo.capturedAt),
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _semanticLabel {
    final parts = <String>[
      photo.type.wireName,
      _formatDate(photo.capturedAt),
      if (photo.bodyPart != null) photo.bodyPart!.label,
      if (photo.laterality != null) photo.laterality!.label,
    ];
    return parts.join(', ');
  }

  static String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final PhotoType type;

  @override
  Widget build(BuildContext context) {
    final colour = switch (type) {
      PhotoType.before => WiseTokens.wiseBlue,
      PhotoType.after => WiseTokens.wiseRed,
      PhotoType.photo => WiseTokens.slateGray,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(WiseTokens.pillRadius),
      ),
      child: Text(
        type.wireName,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: WiseTokens.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
