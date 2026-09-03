import 'package:camera/camera.dart' as plugin;
import 'package:flutter/material.dart';

import '../../app/theme/wise_tokens.dart';
import 'camera_engine.dart';
import 'plugin_camera_engine.dart';

/// Renders the live preview for whichever [CameraEngine] is in use.
///
/// Exists so that no feature screen imports a camera plugin. Technical
/// Architecture section 4 puts the native boundary here, and Build
/// Specification section 11 says platform-specific camera logic must not sit in
/// feature screens.
///
/// It also means a test or a development build running against
/// `FakeCameraEngine` gets a placeholder rather than a platform-channel error.
class CameraPreviewSurface extends StatelessWidget {
  const CameraPreviewSurface({required this.engine, super.key});

  final CameraEngine engine;

  @override
  Widget build(BuildContext context) {
    final current = engine;

    if (current is PluginCameraEngine) {
      final controller = current.controller;
      if (controller != null && controller.value.isInitialized) {
        return plugin.CameraPreview(controller);
      }
    }

    // No initialised preview: an engine that is still starting, unavailable, or
    // a fake in a test. A neutral surface, not an error — the failure path is
    // handled by the capture controller, which has the typed failure.
    return const ColoredBox(
      color: WiseTokens.cameraSurface,
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: 48,
          color: WiseTokens.slateGray,
        ),
      ),
    );
  }
}
