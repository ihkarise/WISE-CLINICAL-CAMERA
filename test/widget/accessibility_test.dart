import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/routes.dart';
import 'package:wise_clinical_camera/app/theme/wise_theme.dart';
import 'package:wise_clinical_camera/app/theme/wise_tokens.dart';
import 'package:wise_clinical_camera/core/cv/alignment_result.dart';
import 'package:wise_clinical_camera/core/sensors/device_level_service.dart';
import 'package:wise_clinical_camera/features/alignment/alignment_panel.dart';
import 'package:wise_clinical_camera/features/home/home_screen.dart';
import 'package:wise_clinical_camera/features/level/level_indicator.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/shared/widgets/wise_status_chip.dart';

/// Accessibility (Phase 2 section 37, Functional section 42, UX/UI section 55,
/// Build Specification section 93).
///
/// The requirement that shapes most of this: **status must never depend on
/// colour alone**. Technical Architecture section 47 gives the example
/// directly — show "Good", not a green dot. A clinician reviewing a wound in a
/// bright room, or with a colour vision deficiency, has to be able to read the
/// state.
void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => ProviderScope(
    child: MaterialApp(
      theme: theme ?? WiseTheme.light(),
      onGenerateRoute: generateWiseRoute,
      home: Scaffold(body: child),
    ),
  );

  group('status is never colour-only', () {
    testWidgets('a status chip carries an icon and a word', (tester) async {
      for (final tone in WiseStatusTone.values) {
        await tester.pumpWidget(
          wrap(WiseStatusChip(label: 'Focus good', tone: tone)),
        );

        expect(find.text('Focus good'), findsOneWidget);
        expect(
          find.byType(Icon),
          findsWidgets,
          reason: '$tone must carry a shape as well as a colour',
        );
      }
    });

    testWidgets('a status chip speaks its tone to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          const WiseStatusChip(
            label: 'Lighting differs',
            tone: WiseStatusTone.warning,
          ),
        ),
      );

      // The tone is spoken, so meaning does not depend on seeing the colour.
      expect(
        find.bySemanticsLabel('Warning: Lighting differs'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('alignment dimensions carry a tick or cross, not just colour', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          const AlignmentPanel(
            result: AlignmentResult(
              status: AlignmentStatus.fair,
              confidence: 0.75,
              engineVersion: 'cv-1.0.0',
              dimensions: AlignmentDimensions(
                position: false,
                scale: true,
                rotation: true,
                framing: true,
                orientation: true,
              ),
            ),
          ),
          theme: WiseTheme.cameraDark(),
        ),
      );

      expect(find.bySemanticsLabel('Position does not match'), findsOneWidget);
      expect(find.bySemanticsLabel('Scale matches'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the level indicator announces its angle', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrap(
          const LevelIndicator(
            reading: LevelReading(
              rollDegrees: 6.4,
              pitchDegrees: 0,
              available: true,
            ),
          ),
          theme: WiseTheme.cameraDark(),
        ),
      );

      expect(find.bySemanticsLabel('Device tilted 6.4°'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an unavailable sensor renders nothing at all', (tester) async {
      // UX/UI section 74: never show a control that silently does nothing.
      await tester.pumpWidget(
        wrap(
          const LevelIndicator(reading: LevelReading.unavailable),
          theme: WiseTheme.cameraDark(),
        ),
      );

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('the capture path is reachable by screen reader', () {
    testWidgets('every mode card is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump();

      for (final label in const [
        'Before. Reference',
        'After. Match it',
        'Photo. Simple',
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: '"$label" must be announced',
        );
      }
      handle.dispose();
    });

    testWidgets('mode cards meet the minimum touch target', (tester) async {
      // UX/UI section 54 and Build Specification section 93.
      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump();

      final handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text on the home screen meets contrast guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('every actionable element has a label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pump();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('large text', () {
    testWidgets('the home screen survives the maximum supported scale', (
      tester,
    ) async {
      // The app clamps to 1.4x; beyond that the camera controls stop fitting.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: WiseTheme.light(),
            onGenerateRoute: generateWiseRoute,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the layout must not overflow at the maximum supported scale',
      );
      expect(find.text('BEFORE'), findsOneWidget);
    });
  });

  group('design tokens support accessibility', () {
    test('the minimum touch target meets platform guidance', () {
      expect(WiseTokens.minTouchTarget, greaterThanOrEqualTo(48));
    });

    test('the capture control is the largest control on the screen', () {
      // UX/UI sections 54, 63, 65: the capture action must be dominant.
      expect(
        WiseTokens.captureButtonSize,
        greaterThan(WiseTokens.minTouchTarget),
      );
    });

    test('body text is large enough to read', () {
      expect(WiseTokens.bodySize, greaterThanOrEqualTo(16));
      expect(WiseTokens.captionSize, greaterThanOrEqualTo(12));
    });
  });
}
