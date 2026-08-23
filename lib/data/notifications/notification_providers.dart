import 'package:dejapoo/data/notifications/local_notification_service.dart';
import 'package:dejapoo/data/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_providers.g.dart';

/// The app-wide [NotificationService].
///
/// Returns `null` on web — `flutter_local_notifications` has no web
/// scheduling support, and the settings UI hides the notification section
/// entirely via `kIsWeb` rather than exposing a non-functional toggle.
@Riverpod(keepAlive: true)
NotificationService? notificationService(Ref ref) {
  if (kIsWeb) return null;
  return LocalNotificationService();
}
