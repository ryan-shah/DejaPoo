import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android manifest wiring that `flutter_local_notifications`
/// needs but does not declare itself (its plugin manifest carries only the
/// VIBRATE / POST_NOTIFICATIONS permissions).
///
/// Regression test for dp-5br: without `ScheduledNotificationReceiver` the
/// AlarmManager broadcast has no target component, so every scheduled daily
/// reminder fired into nothing and no notification was ever posted.
void main() {
  late String manifest;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test('declares the scheduled-notification receiver', () {
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
      ),
    );
  });

  test('declares the boot receiver so reminders survive reboot/update', () {
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications'
        '.ScheduledNotificationBootReceiver',
      ),
    );
    for (final String action in <String>[
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
      'android.intent.action.QUICKBOOT_POWERON',
    ]) {
      expect(manifest, contains(action), reason: 'missing action $action');
    }
  });

  test('holds the permissions the reminder needs', () {
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
  });
}
