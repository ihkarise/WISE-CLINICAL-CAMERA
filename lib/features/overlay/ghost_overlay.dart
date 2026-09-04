import 'package:flutter/material.dart';

import '../../models/reference_transform.dart';
import '../../shared/widgets/clinical_image.dart';

/// The reference image drawn over the live camera preview.
///
/// The core differentiating feature (PRD section 5). Rendered locally, with no
/// server involvement (Functional OVR-006), and it never modifies the reference
/// file: this is a `Transform` around an `Image`, nothing more.
///
/// Gestures are refused while the transform is locked, which is enforced in
/// [ReferenceTransform.adjusted] rather than here, so the lock holds regardless
/// of which control was touched (Functional OVR-005, PRD section 24).
class GhostOverlay extends StatelessWidget {
  const GhostOverlay({
    required this.imagePath,
    required this.opacity,
    required this.transform,
    this.onTransformChanged,
    super.key,
  });

  final String imagePath;

  /// 0.1-1.0 (Functional OVR-002).
  final double opacity;

  final ReferenceTransform transform;

  /// Null makes the overlay non-interactive, as in the review screen.
  final ValueChanged<ReferenceTransform>? onTransformChanged;

  @override
  Widget build(BuildContext context) {
    final image = Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(
            transform.translationX * MediaQuery.sizeOf(context).width,
            transform.translationY * MediaQuery.sizeOf(context).height,
            0,
            1,
          )
          ..rotateZ(transform.rotationRadians)
          ..scaleByDouble(
            transform.scale * (transform.flipX ? -1 : 1),
            transform.scale * (transform.flipY ? -1 : 1),
            1,
            1,
          ),
        // Bounded decode: this sits on top of a live camera preview that is
        // already holding buffers, so a full-resolution reference is the worst
        // possible place to spend memory.
        child: ClinicalImage.file(imagePath),
      ),
    );

    if (onTransformChanged == null || transform.locked) {
      return IgnorePointer(child: image);
    }

    return _InteractiveOverlay(
      transform: transform,
      onTransformChanged: onTransformChanged!,
      child: image,
    );
  }
}

/// Pan, pinch and rotate for the reference (Functional OVR-003).
class _InteractiveOverlay extends StatefulWidget {
  const _InteractiveOverlay({
    required this.transform,
    required this.onTransformChanged,
    required this.child,
  });

  final ReferenceTransform transform;
  final ValueChanged<ReferenceTransform> onTransformChanged;
  final Widget child;

  @override
  State<_InteractiveOverlay> createState() => _InteractiveOverlayState();
}

class _InteractiveOverlayState extends State<_InteractiveOverlay> {
  late ReferenceTransform _start;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onScaleStart: (_) => _start = widget.transform,
      onScaleUpdate: (details) {
        widget.onTransformChanged(
          _start.adjusted(
            // Focal-point delta is in logical pixels; the transform stores a
            // fraction of the preview so it is resolution-independent.
            translationX:
                _start.translationX + details.focalPointDelta.dx / size.width,
            translationY:
                _start.translationY + details.focalPointDelta.dy / size.height,
            scale: _start.scale * details.scale,
            rotationDegrees:
                _start.rotationDegrees + details.rotation * 180 / 3.1415926535,
          ),
        );
      },
      child: widget.child,
    );
  }
}
