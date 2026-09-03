import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_screen.dart';
import '../shared/constants/wise_strings.dart';
import 'providers.dart';
import 'routes.dart';
import 'theme/wise_theme.dart';

/// The application root.
///
/// Warms the local user, preferences and seeded protocols before the home
/// screen renders, so the settings precedence chain has real values rather
/// than defaults that flicker into place.
class WiseApp extends ConsumerWidget {
  const WiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Established here so nothing downstream races on first launch.
    ref.watch(currentUserProvider);

    return MaterialApp(
      title: WiseStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: WiseTheme.light(),
      // The camera screen applies its own dark theme locally
      // (UX/UI section 58), so the app theme stays light throughout.
      onGenerateRoute: generateWiseRoute,
      home: const HomeScreen(),
      builder: (context, child) {
        // Respect the platform text scale, but bound it: beyond about 1.4 the
        // camera controls stop fitting, and the capture action must remain
        // obvious (UX/UI sections 54-55, Functional section 42).
        final scaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
