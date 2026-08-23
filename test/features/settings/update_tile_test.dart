import 'dart:convert';

import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/notifications/fake_notification_service.dart';
import 'package:dejapoo/data/notifications/notification_providers.dart';
import 'package:dejapoo/data/updates/update_providers.dart';
import 'package:dejapoo/data/updates/update_service.dart';
import 'package:dejapoo/features/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/shell_overrides.dart';

const String _tag = 'v0.1.19';

String _releaseJson() => jsonEncode(<String, Object?>{
      'tag_name': _tag,
      'html_url': 'https://github.com/ryan-shah/DejaPoo/releases/tag/$_tag',
      'assets': <Object?>[
        <String, Object?>{
          'name': 'dejapoo-$_tag.apk',
          'browser_download_url':
              'https://github.com/ryan-shah/DejaPoo/releases/download/$_tag/dejapoo-$_tag.apk',
        },
      ],
    });

/// An [UpdateService] wired to a canned GitHub response, with the running
/// build's version injected so the test does not depend on `APP_VERSION`.
UpdateService _service({
  required String currentVersion,
  String? body,
  int statusCode = 200,
}) {
  return UpdateService(
    currentVersion: currentVersion,
    client: MockClient(
      (http.Request request) async =>
          http.Response(body ?? _releaseJson(), statusCode),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpSettings(WidgetTester tester, UpdateService service) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: shellOverrides(
          db,
          extraOverrides: [
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
            updateServiceProvider.overrideWithValue(service),
          ],
        ),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The About section is at the bottom of a lazy ListView.
    await tester.scrollUntilVisible(find.text('Check for updates'), 200);
    await tester.pumpAndSettle();
  }

  /// Drift closes its `watch()` streams with zero-duration timers at
  /// ProviderScope disposal; without this the tester can wedge after a
  /// failure. See the test-run rules in CLAUDE.md.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('offers a check and does not call GitHub until tapped',
      (WidgetTester tester) async {
    bool called = false;
    final UpdateService service = UpdateService(
      currentVersion: '0.1.10',
      client: MockClient((http.Request request) async {
        called = true;
        return http.Response(_releaseJson(), 200);
      }),
    );

    await pumpSettings(tester, service);

    expect(find.text('Check for updates'), findsOneWidget);
    expect(
      find.text('See whether a newer release is available'),
      findsOneWidget,
    );
    expect(called, isFalse);

    await teardownTree(tester);
  });

  testWidgets('an available update shows the version and a download button',
      (WidgetTester tester) async {
    await pumpSettings(tester, _service(currentVersion: '0.1.10'));

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.19 is available'), findsOneWidget);
    expect(find.text('Download v0.1.19 APK'), findsOneWidget);
    expect(find.text('Release notes'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('an up-to-date build offers no download',
      (WidgetTester tester) async {
    await pumpSettings(tester, _service(currentVersion: '0.1.19'));

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(
      find.text('Up to date — 0.1.19 is the latest release'),
      findsOneWidget,
    );
    expect(find.text('Download v0.1.19 APK'), findsNothing);

    await teardownTree(tester);
  });

  testWidgets('a dev build still gets the latest release to download',
      (WidgetTester tester) async {
    await pumpSettings(tester, _service(currentVersion: 'dev'));

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Latest release is 0.1.19'), findsOneWidget);
    expect(find.text('Download v0.1.19 APK'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('a failed check shows the reason and can be retried',
      (WidgetTester tester) async {
    int calls = 0;
    final UpdateService service = UpdateService(
      currentVersion: '0.1.10',
      client: MockClient((http.Request request) async {
        calls++;
        return calls == 1
            ? http.Response('{}', 403)
            : http.Response(_releaseJson(), 200);
      }),
    );

    await pumpSettings(tester, service);

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(
      find.text('GitHub rate limit reached. Try again later.'),
      findsOneWidget,
    );
    expect(find.text('Download v0.1.19 APK'), findsNothing);

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Version 0.1.19 is available'), findsOneWidget);

    await teardownTree(tester);
  });
}
