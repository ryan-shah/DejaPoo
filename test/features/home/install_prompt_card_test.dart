import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/features/home/home_screen.dart';
import 'package:dejapoo/ui/widgets/install_prompt/android_web_detect.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHomeScreen(
    WidgetTester tester, {
    required bool isAndroidWeb,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bowelMovementRepositoryProvider.overrideWithValue(repo),
          isAndroidWebBrowserProvider.overrideWithValue(isAndroidWeb),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> teardownDriftStreams(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows the install prompt on an Android browser',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester, isAndroidWeb: true);

    expect(find.text('Install DejaPoo for Android'), findsOneWidget);
    expect(find.text('How to install'), findsOneWidget);

    await teardownDriftStreams(tester);
  });

  testWidgets('hides the install prompt off an Android browser',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester, isAndroidWeb: false);

    expect(find.text('Install DejaPoo for Android'), findsNothing);
    expect(find.text('How to install'), findsNothing);

    await teardownDriftStreams(tester);
  });

  testWidgets('dismissing hides the prompt and persists the choice',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester, isAndroidWeb: true);
    expect(find.text('Install DejaPoo for Android'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Install DejaPoo for Android'), findsNothing);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('install_prompt_dismissed'), isTrue);

    await teardownDriftStreams(tester);
  });

  testWidgets('stays hidden when a previous dismissal is persisted',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'install_prompt_dismissed': true,
    });

    await pumpHomeScreen(tester, isAndroidWeb: true);

    expect(find.text('Install DejaPoo for Android'), findsNothing);

    await teardownDriftStreams(tester);
  });
}
