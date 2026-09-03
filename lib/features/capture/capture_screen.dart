import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/theme/wise_theme.dart';
import '../../app/theme/wise_tokens.dart';
import '../../core/camera/camera_preview_surface.dart';
import '../../models/effective_settings.dart';
import '../../models/enums.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/wise_error_view.dart';
import '../alignment/alignment_panel.dart';
import '../grid/grid_overlay.dart';
import '../level/level_indicator.dart';
import '../overlay/ghost_overlay.dart';
import '../settings/tools_drawer.dart';
import 'capture_controller.dart';
import 'capture_review_sheet.dart';
import 'capture_state.dart';

/// The camera screen (UX/UI section 10, Build Specification section 10).
///
/// Composition follows the UX priority order (UX/UI section 63): the live
/// preview fills the screen, the capture control dominates, alignment guidance
/// sits above secondary chrome, and inactive tools stay in the Tools drawer
/// rather than on screen (UX/UI sections 10-11, PRD section 34).
///
/// Dark chrome around the preview, per UX/UI section 58.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({required this.arguments, super.key});

  final CaptureArguments arguments;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  @override
  void initState() {
    super.initState();
    // Start after the first frame so the controller can surface a permission
    // dialog against a mounted context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(
            captureControllerProvider((
              mode: widget.arguments.type,
              reference: widget.arguments.referencePhoto,
            )).notifier,
          )
          .start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = captureControllerProvider((
      mode: widget.arguments.type,
      reference: widget.arguments.referencePhoto,
    ));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final settings = ref.watch(effectiveSettingsProvider).valueOrNull;

    return Theme(
      data: WiseTheme.cameraDark(),
      child: Scaffold(
        backgroundColor: WiseTokens.cameraSurface,
        body: SafeArea(
          child: switch (state.phase) {
            CapturePhase.error => WiseErrorView(
              failure: state.failure!,
              onRetry: controller.start,
              onOpenSettings: () =>
                  ref.read(permissionServiceProvider).openSettings(),
            ),
            CapturePhase.reviewing => CaptureReviewSheet(
              state: state,
              onRetake: controller.retake,
              onUse: () => Navigator.of(context).pop(state.capturedPhoto),
            ),
            _ => _CameraView(
              state: state,
              settings: settings,
              controller: controller,
            ),
          },
        ),
      ),
    );
  }
}

class _CameraView extends ConsumerWidget {
  const _CameraView({
    required this.state,
    required this.settings,
    required this.controller,
  });

  final CaptureState state;
  final EffectiveSettings? settings;
  final CaptureController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The photograph is the hero (UX/UI sections 4, 63).
        const _PreviewSurface(),

        // 2. The reference, when Ghost Overlay is on.
        if (settings?.overlayEnabled ?? false)
          if (state.reference != null)
            GhostOverlay(
              imagePath: state.reference!.originalPath,
              opacity: settings!.overlayOpacity,
              transform: state.referenceTransform,
              onTransformChanged: controller.adjustReference,
            ),

        // 3. Guides. Display layers only; never part of the original.
        if (settings?.gridEnabled ?? false)
          GridOverlay(type: settings!.gridType),

        // 4. Chrome.
        _TopBar(state: state, settings: settings, controller: controller),
        _GuidanceLayer(state: state, settings: settings),
        _BottomBar(state: state, settings: settings, controller: controller),

        if (state.isBusy)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// The live preview.
///
/// Delegates to `CameraPreviewSurface`, which owns the platform boundary, so
/// this screen imports no camera plugin (Technical Architecture section 4).
class _PreviewSurface extends ConsumerWidget {
  const _PreviewSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CameraPreviewSurface(engine: ref.watch(cameraEngineProvider));
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.settings,
    required this.controller,
  });

  final CaptureState state;
  final EffectiveSettings? settings;
  final CaptureController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WiseTokens.space8,
          vertical: WiseTokens.space4,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: WiseTokens.cameraOnSurface,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
            Text(
              _modeLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: WiseTokens.cameraOnSurface,
              ),
            ),
            const Spacer(),
            if (settings?.levelEnabled ?? false)
              LevelIndicator(reading: state.level),
            const SizedBox(width: WiseTokens.space8),
            TextButton.icon(
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Tools'),
              style: TextButton.styleFrom(
                foregroundColor: WiseTokens.cameraOnSurface,
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ToolsDrawer(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _modeLabel => switch (state.mode) {
    PhotoType.before => WiseStrings.beforeTitle,
    PhotoType.after => WiseStrings.afterTitle,
    PhotoType.photo => WiseStrings.photoTitle,
  };
}

/// Alignment status, guidance and warnings.
class _GuidanceLayer extends StatelessWidget {
  const _GuidanceLayer({required this.state, required this.settings});

  final CaptureState state;
  final EffectiveSettings? settings;

  @override
  Widget build(BuildContext context) {
    final warning = state.readiness?.primaryWarning;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One instruction at a time (CV section 33, UX/UI section 20).
          if (state.guidance != null)
            _GuidanceBubble(message: state.guidance!.message),

          if (state.guidance == null && (state.readiness?.isReady ?? false))
            const _GuidanceBubble(
              message: WiseStrings.readyToCapture,
              positive: true,
            ),

          if (warning != null && state.guidance == null)
            Padding(
              padding: const EdgeInsets.only(top: WiseTokens.space8),
              child: _GuidanceBubble(message: warning.message, warning: true),
            ),

          if (settings?.alignmentEnabled ?? false)
            Padding(
              padding: const EdgeInsets.only(top: WiseTokens.space8),
              child: AlignmentPanel(
                result: state.alignment,
                showScore: settings?.showAlignmentScore ?? false,
              ),
            ),
        ],
      ),
    );
  }
}

class _GuidanceBubble extends StatelessWidget {
  const _GuidanceBubble({
    required this.message,
    this.positive = false,
    this.warning = false,
  });

  final String message;
  final bool positive;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colour = positive
        ? WiseTokens.successGreen
        : warning
        ? WiseTokens.warningRed
        : WiseTokens.cameraOnSurface;

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: WiseTokens.space32),
        padding: const EdgeInsets.symmetric(
          horizontal: WiseTokens.space16,
          vertical: WiseTokens.space8,
        ),
        decoration: BoxDecoration(
          color: WiseTokens.cameraChrome,
          borderRadius: BorderRadius.circular(WiseTokens.pillRadius),
          border: Border.all(color: colour.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              positive
                  ? Icons.check_circle_outline
                  : warning
                  ? Icons.error_outline
                  : Icons.navigation_outlined,
              size: 16,
              color: colour,
            ),
            const SizedBox(width: WiseTokens.space8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colour),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.state,
    required this.settings,
    required this.controller,
  });

  final CaptureState state;
  final EffectiveSettings? settings;
  final CaptureController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Opacity is the control the clinician reaches for most while
          // matching, so it sits directly above the shutter (UX/UI 18).
          if ((settings?.overlayEnabled ?? false) && state.hasReference)
            _OpacityControl(
              value: settings!.overlayOpacity,
              locked: state.referenceTransform.locked,
              onChanged: (value) => ref
                  .read(sessionOverridesProvider.notifier)
                  .update((current) => current.withOverlayOpacity(value)),
              onToggleLock: () => controller.setReferenceLock(
                locked: !state.referenceTransform.locked,
              ),
              onReset: controller.resetReference,
            ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: WiseTokens.space24),
            child: _CaptureButton(
              label: state.readiness?.captureLabel ?? WiseStrings.capture,
              enabled: state.canCapture,
              onPressed: () async {
                final result = await controller.capture();
                if (result.isFailure && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.failureOrNull!.userMessage)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The shutter. The dominant action on the screen (UX/UI sections 54, 63, 65).
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: enabled ? onPressed : null,
            child: Container(
              width: WiseTokens.captureButtonSize,
              height: WiseTokens.captureButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? WiseTokens.white
                    : WiseTokens.white.withValues(alpha: 0.35),
                border: Border.all(
                  color: WiseTokens.white.withValues(alpha: 0.6),
                  width: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: WiseTokens.space8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: WiseTokens.cameraOnSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay opacity, lock and reset (UX/UI sections 18-19).
class _OpacityControl extends StatelessWidget {
  const _OpacityControl({
    required this.value,
    required this.locked,
    required this.onChanged,
    required this.onToggleLock,
    required this.onReset,
  });

  final double value;
  final bool locked;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleLock;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: WiseTokens.space16),
      padding: const EdgeInsets.symmetric(
        horizontal: WiseTokens.space16,
        vertical: WiseTokens.space8,
      ),
      decoration: BoxDecoration(
        color: WiseTokens.cameraChrome,
        borderRadius: BorderRadius.circular(WiseTokens.cardRadius),
      ),
      child: Row(
        children: [
          Text(
            'Reference ${(value * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: WiseTokens.cameraOnSurface,
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(
                EffectiveSettings.minOverlayOpacity,
                EffectiveSettings.maxOverlayOpacity,
              ),
              min: EffectiveSettings.minOverlayOpacity,
              max: EffectiveSettings.maxOverlayOpacity,
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: Icon(locked ? Icons.lock : Icons.lock_open),
            color: locked ? WiseTokens.wiseRed : WiseTokens.cameraOnSurface,
            tooltip: locked
                ? WiseStrings.referenceUnlocked
                : WiseStrings.referenceLocked,
            onPressed: onToggleLock,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: WiseTokens.cameraOnSurface,
            tooltip: 'Reset reference',
            onPressed: locked ? null : onReset,
          ),
        ],
      ),
    );
  }
}
