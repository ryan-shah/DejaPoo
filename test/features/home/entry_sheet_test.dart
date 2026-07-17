import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/features/home/widgets/entry_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late DateTime clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 7, 17, 12);
    repo = DriftBowelMovementRepository(db, clock: () => clock);
  });

  tearDown(() async {
    await db.close();
  });

  /// Mounts the [EntrySheet] directly inside a [Scaffold] body so the full
  /// form is accessible for scrolling/tapping in the 600px test viewport.
  Future<void> pumpEntrySheet(
    WidgetTester tester, {
    BowelMovement? existing,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bowelMovementRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EntrySheet(existing: existing),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Create mode', () {
    testWidgets('renders with Save disabled when no Bristol type selected',
        (WidgetTester tester) async {
      await pumpEntrySheet(tester);

      // Title shows "New Entry".
      expect(find.text('New Entry'), findsOneWidget);

      // Save button is present but disabled.
      final Finder saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(saveButton, findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('selecting a Bristol type enables Save',
        (WidgetTester tester) async {
      await pumpEntrySheet(tester);

      // Save starts disabled.
      FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(button.onPressed, isNull);

      // Tap Type 4 label.
      await tester.tap(find.text('Type 4'));
      await tester.pumpAndSettle();

      // Save is now enabled.
      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Save in create mode calls repository.create()',
        (WidgetTester tester) async {
      await pumpEntrySheet(tester);

      // Select Bristol type 4.
      await tester.tap(find.text('Type 4'));
      await tester.pumpAndSettle();

      // Scroll Save button into view and tap it.
      final Finder saveButton = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify the entry was created in the repository.
      final DateTime today = DateTime.now();
      final List<BowelMovement> entries = await repo.getRange(
        DateTime(today.year, today.month, today.day),
        DateTime(today.year, today.month, today.day + 1),
      );
      expect(entries, hasLength(1));
      expect(entries.first.bristolType, BristolType.type4);
    });
  });

  group('Edit mode', () {
    testWidgets('prefills all fields from existing entry',
        (WidgetTester tester) async {
      final BowelMovement existing = await repo.create(
        occurredAt: DateTime(2026, 7, 15, 9, 30),
        bristolType: BristolType.type3,
        size: StoolSize.large,
        urgency: 4,
        strain: 2,
        blood: true,
        note: 'test note',
      );

      await pumpEntrySheet(tester, existing: existing);

      // Title shows "Edit Entry".
      expect(find.text('Edit Entry'), findsOneWidget);

      // Update button is present and enabled (type is prefilled).
      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update'),
      );
      expect(button.onPressed, isNotNull);

      // Note is prefilled — scroll to the TextField first.
      final Finder textField = find.byType(TextField);
      await tester.ensureVisible(textField);
      await tester.pumpAndSettle();
      final TextField noteField = tester.widget<TextField>(textField);
      expect(noteField.controller!.text, 'test note');

      // Blood switch is on — scroll to it.
      final Finder switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      final Switch bloodSwitch = tester.widget<Switch>(switchFinder);
      expect(bloodSwitch.value, isTrue);
    });

    testWidgets('Save in edit mode calls repository.update()',
        (WidgetTester tester) async {
      final BowelMovement existing = await repo.create(
        occurredAt: DateTime(2026, 7, 15, 9, 30),
        bristolType: BristolType.type3,
      );

      await pumpEntrySheet(tester, existing: existing);

      // Change Bristol type to type 5.
      await tester.tap(find.text('Type 5'));
      await tester.pumpAndSettle();

      // Advance the clock so updatedAt changes.
      clock = clock.add(const Duration(hours: 1));

      // Scroll Update button into view and tap it.
      final Finder updateButton =
          find.widgetWithText(FilledButton, 'Update');
      await tester.ensureVisible(updateButton);
      await tester.pumpAndSettle();
      await tester.tap(updateButton);
      await tester.pumpAndSettle();

      // Verify the entry was updated.
      final BowelMovement? updated = await repo.getById(existing.id);
      expect(updated, isNotNull);
      expect(updated!.bristolType, BristolType.type5);
      // occurredAt should remain the same (we didn't change it).
      expect(updated.occurredAt.hour, 9);
      expect(updated.occurredAt.minute, 30);
    });
  });
}
