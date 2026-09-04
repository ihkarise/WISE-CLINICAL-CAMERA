import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/features/capture/capture_metadata_sheet.dart';
import 'package:wise_clinical_camera/features/cases/cases_screen.dart';
import 'package:wise_clinical_camera/models/clinical_case.dart';
import 'package:wise_clinical_camera/models/enums.dart';

/// The pre-capture metadata sheet (Functional MOD-012, MOD-030).
///
/// Until this workflow existed, `setMetadata` had no caller and every
/// photograph was stored with body part, laterality and case null. These tests
/// prove the sheet reports each choice, offers an explicit "not recorded"
/// option so the fields stay optional, and lists the cases it is given.
void main() {
  final now = DateTime.utc(2026, 1, 1);
  final aCase = ClinicalCase(
    id: 'case-1',
    title: 'Left forearm follow-up',
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    BodyPart? bodyPart,
    Laterality? laterality,
    String? caseId,
    ValueChanged<BodyPart?>? onBodyPartChanged,
    ValueChanged<Laterality?>? onLateralityChanged,
    ValueChanged<String?>? onCaseChanged,
    List<ClinicalCase> cases = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [casesProvider.overrideWith((ref) async => cases)],
    );
    addTearDown(container.dispose);
    // Resolve the case list before pumping so the sheet renders its data branch
    // rather than an animating progress indicator (which would hang
    // pumpAndSettle).
    await tester.runAsync(() => container.read(casesProvider.future));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: CaptureMetadataSheet(
              bodyPart: bodyPart,
              laterality: laterality,
              caseId: caseId,
              onBodyPartChanged: onBodyPartChanged ?? (_) {},
              onLateralityChanged: onLateralityChanged ?? (_) {},
              onCaseChanged: onCaseChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reports the chosen body part', (tester) async {
    BodyPart? received;
    var fired = false;
    await pumpSheet(
      tester,
      onBodyPartChanged: (value) {
        received = value;
        fired = true;
      },
    );

    await tester.tap(find.byType(DropdownButton<BodyPart?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hand').last);
    await tester.pumpAndSettle();

    expect(fired, isTrue);
    expect(received, BodyPart.hand);
  });

  testWidgets('offers "not recorded" so the field stays optional', (
    tester,
  ) async {
    await pumpSheet(tester);
    // The body part field starts unset and shows the opt-out label.
    expect(find.text('Not recorded'), findsWidgets);
  });

  testWidgets('lists the cases it is given and reports a selection', (
    tester,
  ) async {
    String? received;
    var fired = false;
    await pumpSheet(
      tester,
      cases: [aCase],
      onCaseChanged: (value) {
        received = value;
        fired = true;
      },
    );

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Left forearm follow-up').last);
    await tester.pumpAndSettle();

    expect(fired, isTrue);
    expect(received, 'case-1');
  });
}
