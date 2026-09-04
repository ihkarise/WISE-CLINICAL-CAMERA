import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/providers.dart';
import 'package:wise_clinical_camera/app/routes.dart';
import 'package:wise_clinical_camera/app/theme/wise_theme.dart';
import 'package:wise_clinical_camera/features/library/photo_thumbnail.dart';
import 'package:wise_clinical_camera/features/reference/reference_picker_screen.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/photo.dart';

import '../support/test_harness.dart';

/// The AFTER reference picker (Functional MOD-002).
///
/// MOD-002 lists five reference sources. Before this phase only the WISE
/// library and the device Gallery existed; these tests cover the two that were
/// added — importing from the file system, and choosing a Before from within a
/// case.
void main() {
  late TestHarness harness;
  late ProviderContainer container;
  late String userId;

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: WiseTheme.light(),
      onGenerateRoute: generateWiseRoute,
      home: child,
    ),
  );

  setUp(() async {
    harness = await TestHarness.create();
    container = ProviderContainer(
      overrides: [
        storagePathsProvider.overrideWith((ref) async => harness.paths),
        databaseProvider.overrideWith((ref) async => harness.database),
        imageStorageProvider.overrideWith((ref) async => harness.storage),
      ],
    );
    userId = (await container.read(currentUserProvider.future)).id;
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  Future<Photo> addBefore({String? caseId}) async {
    final repository = await container.read(photoRepositoryProvider.future);
    return (await repository.createPhoto(
      bytes: sampleJpeg(),
      type: PhotoType.before,
      source: PhotoSource.camera,
      userId: userId,
      caseId: caseId,
    )).valueOrNull!;
  }

  Future<String> addCase(String title) async {
    final cases = await container.read(caseRepositoryProvider.future);
    return (await cases.createCase(userId: userId, title: title)).valueOrNull!.id;
  }

  Future<void> show(
    WidgetTester tester, {
    required Future<void> Function() prepare,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(prepare);
    await tester.pumpWidget(host(const ReferencePickerScreen()));
    await tester.pump();
  }

  testWidgets('offers both a Gallery and a File import (MOD-002)', (
    tester,
  ) async {
    await show(
      tester,
      prepare: () => container.read(referenceCandidatesProvider.future),
    );

    expect(find.text('Import from Gallery'), findsOneWidget);
    expect(find.text('Import from File'), findsOneWidget);
  });

  testWidgets('a case filter appears only once a case exists', (tester) async {
    await show(
      tester,
      prepare: () async {
        await addBefore();
        await container.read(referenceCandidatesProvider.future);
      },
    );
    expect(find.text('All cases'), findsNothing);

    await show(
      tester,
      prepare: () async {
        await addCase('Wrist series');
        // casesProvider resolved to empty during the first pump; re-read it.
        container.invalidate(casesProvider);
        await container.read(casesProvider.future);
        await container.read(referenceCandidatesProvider.future);
      },
    );
    expect(find.text('All cases'), findsWidgets);
  });

  testWidgets('choosing a case restricts the references to it (MOD-002)', (
    tester,
  ) async {
    await show(
      tester,
      prepare: () async {
        final caseId = await addCase('Wrist series');
        await addBefore(caseId: caseId);
        await addBefore(); // uncategorised, must be filtered out
        container.read(referenceCaseFilterProvider.notifier).state = caseId;
        await container.read(referenceCandidatesProvider.future);
      },
    );

    // Only the Before inside the case is a candidate.
    expect(find.byType(PhotoThumbnail), findsOneWidget);
  });
}
