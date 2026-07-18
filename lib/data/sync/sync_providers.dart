import 'dart:async';

import 'package:dejapoo/data/auth/google_auth_provider.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/sync/drive_snapshot_store.dart';
import 'package:dejapoo/data/sync/drive_snapshot_store_impl.dart';
import 'package:dejapoo/data/sync/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_providers.g.dart';

/// The app-wide [SyncService], wired to the real Drive snapshot store
/// when the user is authorized.
///
/// Returns `null` when the user is not driveAuthorized (no auth client
/// available).
@Riverpod(keepAlive: true)
class SyncServiceNotifier extends _$SyncServiceNotifier {
  SyncService? _service;
  StreamSubscription<SyncState>? _sub;
  Timer? _debounce;

  @override
  SyncState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _service?.dispose();
      _debounce?.cancel();
    });
    return SyncState.initial;
  }

  /// Lazily creates the [SyncService] and returns it, or `null` if no
  /// auth client is available.
  Future<SyncService?> _ensureService() async {
    if (_service != null) return _service;

    final authNotifier = ref.read(googleAuthProvider.notifier);
    final authClient = await authNotifier.getAuthClient();
    if (authClient == null) return null;

    final DriveSnapshotStore store = DriveSnapshotStoreImpl(authClient);
    _service = SyncService(
      bowelMovementRepository: ref.read(bowelMovementRepositoryProvider),
      syncStateRepository: ref.read(syncStateRepositoryProvider),
      driveSnapshotStore: store,
    );

    // Forward state changes to the Riverpod state.
    _sub = _service!.stateStream.listen((s) {
      state = s;
    });

    // Load persisted lastSyncAt so the UI shows it immediately.
    final lastSync = await _service!.loadLastSyncAt();
    if (lastSync != null) {
      state = SyncState(status: SyncStatus.idle, lastSyncAt: lastSync);
    }

    return _service;
  }

  /// Triggers a sync cycle now. No-op if not authorized.
  Future<void> syncNow() async {
    final service = await _ensureService();
    if (service == null) return;
    await service.sync();
  }

  /// Schedules a debounced sync (e.g. after a local write). Resets the
  /// timer on each call so rapid edits coalesce into a single sync.
  void scheduleDebouncedSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), syncNow);
  }

  /// Deletes the remote snapshot from Drive. Does not affect local data.
  Future<void> clearSyncedData() async {
    final service = await _ensureService();
    if (service == null) return;
    await service.clearRemote();
    state = const SyncState(status: SyncStatus.idle);
  }

  /// Tears down the service (e.g. on sign-out) so a new auth client can
  /// be created on next sync.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _service?.dispose();
    _service = null;
    _debounce?.cancel();
    _debounce = null;
    state = SyncState.initial;
  }
}

/// Triggers an initial sync on app open when the user is driveAuthorized.
///
/// Watch this provider from a top-level widget to activate it.
@Riverpod(keepAlive: true)
void syncTrigger(Ref ref) {
  final authStatus = ref.watch(googleAuthProvider);
  if (authStatus == AuthStatus.driveAuthorized) {
    // Use Future.microtask to avoid modifying providers during build.
    Future.microtask(() {
      ref.read(syncServiceProvider.notifier).syncNow();
    });
  } else {
    // User signed out — tear down any existing service.
    ref.read(syncServiceProvider.notifier).reset();
  }
}
