import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme/wise_tokens.dart';
import '../../models/enums.dart';
import '../../shared/constants/wise_strings.dart';
import '../../shared/widgets/wise_logo.dart';
import '../../shared/widgets/wise_mode_card.dart';
import '../library/recent_photos_strip.dart';

/// The entry screen (UX/UI section 8, Build Specification section 9).
///
/// Deliberately thin. PRD section 2 and Build Specification section 8 both say
/// this must not become a medical dashboard: three mode buttons, recent
/// photographs, and a way into the secondary screens.
///
/// The layout follows the specification's sketch:
///
/// ```text
/// WISE Clinical Camera
/// What would you like to capture?
/// [ BEFORE ] [ AFTER ] [ PHOTO ]
/// Recent photos
/// ```
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(WiseStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Library',
            onPressed: () =>
                Navigator.of(context).pushNamed(WiseRoutes.library),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(WiseRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: WiseTokens.gutter,
            vertical: WiseTokens.space16,
          ),
          children: [
            // Brand identity: the WISE mark, the WiseAiTechs byline and the
            // product tagline (master prompt §8, UX/UI section 6).
            Row(
              children: [
                const WiseLogo(size: 48),
                const SizedBox(width: WiseTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WiseStrings.brandByline,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: WiseTokens.wiseBlue,
                        ),
                      ),
                      const SizedBox(height: WiseTokens.space4),
                      Text(
                        WiseStrings.tagline,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: WiseTokens.space24),

            Text(WiseStrings.modePrompt, style: theme.textTheme.titleLarge),
            const SizedBox(height: WiseTokens.space16),

            // The three primary actions. On a narrow phone they stay in one
            // row; the UX priority order puts these above everything else.
            Row(
              children: [
                Expanded(
                  child: WiseModeCard(
                    title: WiseStrings.beforeTitle,
                    subtitle: WiseStrings.beforeSubtitle,
                    icon: Icons.filter_1_outlined,
                    onTap: () => _openCapture(context, PhotoType.before),
                  ),
                ),
                const SizedBox(width: WiseTokens.space8),
                Expanded(
                  child: WiseModeCard(
                    title: WiseStrings.afterTitle,
                    subtitle: WiseStrings.afterSubtitle,
                    icon: Icons.compare_arrows_outlined,
                    // AFTER always goes through reference selection first: it
                    // cannot start without one (Functional MOD-020).
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(WiseRoutes.referencePicker),
                  ),
                ),
                const SizedBox(width: WiseTokens.space8),
                Expanded(
                  child: WiseModeCard(
                    title: WiseStrings.photoTitle,
                    subtitle: WiseStrings.photoSubtitle,
                    icon: Icons.photo_camera_outlined,
                    onTap: () => _openCapture(context, PhotoType.photo),
                  ),
                ),
              ],
            ),

            const SizedBox(height: WiseTokens.space32),
            Text('Recent', style: theme.textTheme.titleLarge),
            const SizedBox(height: WiseTokens.space8),
            const SizedBox(height: 132, child: RecentPhotosStrip()),

            const SizedBox(height: WiseTokens.space24),
            _SecondaryNavigation(),
          ],
        ),
      ),
    );
  }

  void _openCapture(BuildContext context, PhotoType type) {
    Navigator.of(
      context,
    ).pushNamed(WiseRoutes.capture, arguments: CaptureArguments(type: type));
  }
}

/// Library, cases, protocols and settings (Build Specification section 8).
class _SecondaryNavigation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _NavigationTile(
            icon: Icons.photo_library_outlined,
            label: 'Library',
            route: WiseRoutes.library,
          ),
          const Divider(height: 1),
          _NavigationTile(
            icon: Icons.folder_special_outlined,
            label: 'Cases',
            route: WiseRoutes.cases,
          ),
          const Divider(height: 1),
          _NavigationTile(
            icon: Icons.checklist_outlined,
            label: 'Protocols',
            route: WiseRoutes.protocols,
          ),
          const Divider(height: 1),
          _NavigationTile(
            icon: Icons.tune_outlined,
            label: 'Settings',
            route: WiseRoutes.settings,
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: WiseTokens.wiseBlue),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      trailing: const Icon(Icons.chevron_right, color: WiseTokens.slateGray),
      onTap: () => Navigator.of(context).pushNamed(route),
    );
  }
}
