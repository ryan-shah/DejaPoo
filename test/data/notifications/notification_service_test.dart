import 'package:dejapoo/data/notifications/fake_notification_service.dart';
import 'package:dejapoo/data/notifications/notification_preferences.dart';
import 'package:dejapoo/data/notifications/notification_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeNotificationService fake;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fake = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(fake),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<NotificationPreferencesNotifier> notifier() async {
    // Ensure the async build() completes before interacting.
    await container.read(notificationPreferencesProvider.future);
    return container.read(notificationPreferencesProvider.notifier);
  }

  test('defaults to disabled at 9:00', () async {
    final NotificationPreferences prefs =
        await container.read(notificationPreferencesProvider.future);
    expect(prefs.enabled, isFalse);
    expect(prefs.hour, 9);
    expect(prefs.minute, 0);
  });

  test('enabling schedules a notification', () async {
    final NotificationPreferencesNotifier n = await notifier();

    final bool success = await n.setEnabled(true);

    expect(success, isTrue);
    expect(fake.scheduleCallCount, 1);
    expect(fake.scheduledHour, 9);
    expect(fake.scheduledMinute, 0);
    final NotificationPreferences prefs =
        container.read(notificationPreferencesProvider).value!;
    expect(prefs.enabled, isTrue);
  });

  test('disabling cancels the scheduled notification', () async {
    final NotificationPreferencesNotifier n = await notifier();
    await n.setEnabled(true);
    expect(fake.scheduleCallCount, 1);

    final bool success = await n.setEnabled(false);

    expect(success, isTrue);
    expect(fake.cancelCallCount, 1);
    expect(fake.scheduledHour, isNull);
    final NotificationPreferences prefs =
        container.read(notificationPreferencesProvider).value!;
    expect(prefs.enabled, isFalse);
  });

  test('changing time reschedules when enabled', () async {
    final NotificationPreferencesNotifier n = await notifier();
    await n.setEnabled(true);

    await n.setTime(20, 30);

    expect(fake.scheduleCallCount, 2);
    expect(fake.scheduledHour, 20);
    expect(fake.scheduledMinute, 30);
    final NotificationPreferences prefs =
        container.read(notificationPreferencesProvider).value!;
    expect(prefs.hour, 20);
    expect(prefs.minute, 30);
  });

  test('changing time while disabled does not schedule', () async {
    final NotificationPreferencesNotifier n = await notifier();

    await n.setTime(20, 30);

    expect(fake.scheduleCallCount, 0);
    final NotificationPreferences prefs =
        container.read(notificationPreferencesProvider).value!;
    expect(prefs.hour, 20);
    expect(prefs.minute, 30);
    expect(prefs.enabled, isFalse);
  });

  test('permission denial reverts the toggle', () async {
    fake.permissionGranted = false;
    final NotificationPreferencesNotifier n = await notifier();

    final bool success = await n.setEnabled(true);

    expect(success, isFalse);
    expect(fake.scheduleCallCount, 0);
    final NotificationPreferences prefs =
        container.read(notificationPreferencesProvider).value!;
    expect(prefs.enabled, isFalse);
  });

  test('preferences persist across a fresh notifier read (shared_preferences)',
      () async {
    final NotificationPreferencesNotifier n = await notifier();
    await n.setEnabled(true);
    await n.setTime(7, 15);

    // Simulate app restart: fresh container, same shared_preferences store.
    final ProviderContainer restarted = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      ],
    );
    addTearDown(restarted.dispose);

    final NotificationPreferences prefs = await restarted
        .read(notificationPreferencesProvider.future);
    expect(prefs.enabled, isTrue);
    expect(prefs.hour, 7);
    expect(prefs.minute, 15);
  });

  test('returns false when no NotificationService is available (web)',
      () async {
    final ProviderContainer webContainer = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(null),
      ],
    );
    addTearDown(webContainer.dispose);

    await webContainer.read(notificationPreferencesProvider.future);
    final NotificationPreferencesNotifier n = webContainer.read(
      notificationPreferencesProvider.notifier,
    );

    final bool success = await n.setEnabled(true);
    expect(success, isFalse);
  });
}
