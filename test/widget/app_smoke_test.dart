import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/app.dart';
import 'package:wise_clinical_camera/shared/constants/wise_strings.dart';

/// The application root builds and reaches its first screen.
///
/// Nothing else covers `WiseApp` itself: the other widget tests mount
/// individual screens. This is the test that fails if provider wiring, theme
/// construction or route generation breaks at the top level.
///
/// It runs with the real provider graph. The database and storage providers are
/// futures that never resolve under a test binding (there is no platform
/// channel for `path_provider`), which is exactly the first-launch condition
/// worth covering: the app must render rather than hang or throw while its
/// asynchronous dependencies are still pending.
void main() {
  testWidgets('builds and shows the three capture modes', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WiseApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text(WiseStrings.modePrompt), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('AFTER'), findsOneWidget);
    expect(find.text('PHOTO'), findsOneWidget);
  });

  testWidgets('renders while storage and database are still resolving', (
    tester,
  ) async {
    // A first launch on a slow device must not show a blank screen or throw.
    await tester.pumpWidget(const ProviderScope(child: WiseApp()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(WiseStrings.appName), findsWidgets);
  });

  testWidgets('clamps text scale so the capture action stays reachable', (
    tester,
  ) async {
    // UX/UI sections 54-55: the capture action must remain obvious. An
    // unbounded platform text scale pushes the camera controls off screen.
    tester.platformDispatcher.textScaleFactorTestValue = 4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ProviderScope(child: WiseApp()));
    await tester.pump();

    final context = tester.element(find.text(WiseStrings.modePrompt));
    final scaled = MediaQuery.textScalerOf(context).scale(10);

    expect(
      scaled,
      lessThanOrEqualTo(14.001),
      reason: 'text scale must be clamped to 1.4x',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies the light application theme at the root', (
    tester,
  ) async {
    // The camera screen applies its own dark theme locally (UX/UI section 58);
    // the app theme stays light everywhere else.
    await tester.pumpWidget(const ProviderScope(child: WiseApp()));
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.brightness, Brightness.light);
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
