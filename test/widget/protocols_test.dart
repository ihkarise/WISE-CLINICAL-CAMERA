import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/app/providers.dart';
import 'package:wise_clinical_camera/app/theme/wise_theme.dart';
import 'package:wise_clinical_camera/features/protocols/protocol_editor_screen.dart';
import 'package:wise_clinical_camera/features/protocols/protocols_screen.dart';

import '../support/test_harness.dart';

/// User-created protocols (Functional PRO-001..005, master prompt §7).
///
/// The repository CRUD is covered in the persistence round-trip suite; these
/// tests cover the management UI added for MVP-2: creating a protocol, and the
/// separation that keeps built-in protocols immutable.
void main() {
  late TestHarness harness;
  late ProviderContainer container;

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: WiseTheme.light(), home: child),
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
    // Establishes the local user and seeds the built-in protocols.
    await container.read(currentUserProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await harness.dispose();
  });

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() => container.read(protocolsProvider.future));
    await tester.pumpWidget(host(const ProtocolsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('built-in protocols are grouped separately', (tester) async {
    await pumpList(tester);

    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('Your protocols'), findsOneWidget);
    // Dermatology Standard is one of the seeded protocols.
    expect(find.text('Dermatology Standard'), findsOneWidget);
  });

  testWidgets('a built-in protocol offers Duplicate but not Edit or Delete', (
    tester,
  ) async {
    await pumpList(tester);

    // The first tile is a built-in protocol; open its menu.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('the editor creates a user protocol from the list', (
    tester,
  ) async {
    await pumpList(tester);

    // Open the editor through the New protocol action, so the save pops back
    // to the list cleanly rather than popping the only route.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New protocol'));
    await tester.pumpAndSettle();
    expect(find.byType(ProtocolEditorScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'My wound series');
    await tester.tap(find.text('Save'));
    // Let the real event loop run the database write, then the list re-read
    // after the editor pops (both are real sqflite I/O).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();

    // Shown back in the list under the user group.
    expect(find.text('My wound series'), findsOneWidget);
  });
}
