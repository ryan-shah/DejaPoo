import 'package:dejapoo/data/auth/google_auth_provider.dart';
import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/notifications/fake_notification_service.dart';
import 'package:dejapoo/data/notifications/notification_providers.dart';
import 'package:dejapoo/data/notifications/notification_service.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';

/// A [GoogleAuth] stub that reports a fixed [AuthStatus] without touching the
/// google_sign_in plugin (which has no implementation under `flutter_test`).
///
/// Needed by any test that mounts `ScaffoldWithNavBar`: the shell watches
/// `syncTriggerProvider`, which watches `googleAuthProvider`.
class FakeGoogleAuth extends GoogleAuth {
  FakeGoogleAuth([this.status = AuthStatus.signedOut]);

  final AuthStatus status;

  @override
  AuthStatus build() => status;
}

/// Overrides that let the app shell be pumped in a widget test: an in-memory
/// database, a non-plugin auth notifier, and a fake notification service.
///
/// Pass [extraOverrides] to append screen-specific overrides; appending here
/// rather than spreading at the call site keeps the list's element type intact,
/// which `ProviderScope` checks at runtime.
///
/// Return type is `dynamic` for the same reason as in `sync_wiring_test.dart`:
/// `Override` isn't exported from `flutter_riverpod.dart` in riverpod 3.x — so
/// [extraOverrides] cannot be given its real type either.
dynamic shellOverrides(
  AppDatabase db, {
  AuthStatus authStatus = AuthStatus.signedOut,
  NotificationService? notificationService,
  dynamic extraOverrides,
}) {
  final overrides = [
    appDatabaseProvider.overrideWithValue(db),
    syncStateRepositoryProvider.overrideWithValue(DriftSyncStateRepository(db)),
    googleAuthProvider.overrideWith(() => FakeGoogleAuth(authStatus)),
    // The shell reads notificationPreferences to re-arm the daily reminder,
    // so keep the real plugin-backed service out of widget tests.
    notificationServiceProvider.overrideWithValue(
      notificationService ?? FakeNotificationService(),
    ),
  ];
  if (extraOverrides != null) {
    overrides.addAll(extraOverrides);
  }
  return overrides;
}
