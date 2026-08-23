import 'package:dejapoo/data/auth/google_auth_provider.dart';
import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
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
/// database and a non-plugin auth notifier.
///
/// Return type is `dynamic` for the same reason as in `sync_wiring_test.dart`:
/// `Override` isn't exported from `flutter_riverpod.dart` in riverpod 3.x.
dynamic shellOverrides(
  AppDatabase db, {
  AuthStatus authStatus = AuthStatus.signedOut,
}) =>
    [
      appDatabaseProvider.overrideWithValue(db),
      syncStateRepositoryProvider
          .overrideWithValue(DriftSyncStateRepository(db)),
      googleAuthProvider.overrideWith(() => FakeGoogleAuth(authStatus)),
    ];
