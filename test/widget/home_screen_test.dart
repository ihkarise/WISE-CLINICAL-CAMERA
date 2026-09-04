import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/routes.dart';
import 'package:wise_clinical_camera/app/theme/wise_theme.dart';
import 'package:wise_clinical_camera/features/home/home_screen.dart';
import 'package:wise_clinical_camera/shared/constants/wise_strings.dart';

/// The home screen presents exactly three primary actions.
///
/// PRD section 2 and Build Specification section 8 both insist this stays
/// simple: "Do not turn the home screen into a complex medical dashboard."
/// This test is the guard against that drifting.
void main() {
  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(
      theme: WiseTheme.light(),
      onGenerateRoute: generateWiseRoute,
      home: child,
    ),
  );

  testWidgets('shows BEFORE, AFTER and PHOTO as the primary actions', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pump();

    expect(find.text(WiseStrings.modePrompt), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('AFTER'), findsOneWidget);
    expect(find.text('PHOTO'), findsOneWidget);
  });

  testWidgets('the three modes carry their specified subtitles', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pump();

    // UX/UI section 8.
    expect(find.text(WiseStrings.beforeSubtitle), findsOneWidget);
    expect(find.text(WiseStrings.afterSubtitle), findsOneWidget);
    expect(find.text(WiseStrings.photoSubtitle), findsOneWidget);
  });

  testWidgets('secondary navigation is present but subordinate', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pump();

    expect(find.text('Library'), findsWidgets);
    expect(find.text('Cases'), findsOneWidget);
    expect(find.text('Protocols'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('the mode cards are exposed to screen readers', (tester) async {
    // Functional section 42 and UX/UI section 55: accessible labels, and the
    // capture path must be reachable with VoiceOver or TalkBack.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pump();

    expect(
      find.bySemanticsLabel(
        '${WiseStrings.beforeTitle}. ${WiseStrings.beforeSubtitle}',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('AFTER routes to reference selection, not straight to camera', (
    tester,
  ) async {
    // Functional MOD-020: an After capture cannot start without a reference.
    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pump();

    await tester.tap(find.text('AFTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(WiseStrings.chooseBefore), findsWidgets);
  });
}
