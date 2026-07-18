import 'dart:async';

import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/data/sync/drive_snapshot_store.dart';
import 'package:dejapoo/data/sync/merge_engine.dart';
import 'package:dejapoo/data/sync/snapshot_exceptions.dart';
import 'package:dejapoo/data/sync/sync_models.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bowel_movement_repository.dart';

/// High-level sync status.
enum SyncStatus { idle, syncing, success, error }

/// Observable sync state exposed to the UI.
class SyncState {
  const SyncState({
    required this.status,
    this.lastSyncAt,
    this.errorMessage,
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? errorMessage;

  static const SyncState initial = SyncState(status: SyncStatus.idle);
}

/// Orchestrates the pull-merge-push sync cycle against a
/// [DriveSnapshotStore].
///
/// Thread-safe: concurrent [sync] calls are coalesced into a single flight
/// via a [Completer]-based mutex.
class SyncService {
  SyncService({
    required BowelMovementRepository bowelMovementRepository,
    required DriftSyncStateRepository syncStateRepository,
    required DriveSnapshotStore driveSnapshotStore,
  })  : _bmRepo = bowelMovementRepository,
        _syncStateRepo = syncStateRepository,
        _driveStore = driveSnapshotStore;

  final BowelMovementRepository _bmRepo;
  final DriftSyncStateRepository _syncStateRepo;
  final DriveSnapshotStore _driveStore;

  /// Current state, updated throughout the sync cycle.
  SyncState get state => _state;
  SyncState _state = SyncState.initial;

  /// Stream of state changes for UI binding.
  Stream<SyncState> get stateStream => _controller.stream;
  final StreamController<SyncState> _controller =
      StreamController<SyncState>.broadcast();

  /// Single-flight guard: if a sync is already running, callers await the
  /// same completer rather than starting a second cycle.
  Completer<void>? _inflight;

  static const String _lastSyncKey = 'lastSyncAt';

  /// Runs one pull-merge-push cycle.
  ///
  /// If a sync is already in progress, the returned future completes when
  /// the in-progress sync finishes (no double-execution).
  Future<void> sync() async {
    if (_inflight != null) {
      return _inflight!.future;
    }
    final completer = Completer<void>();
    _inflight = completer;
    try {
      await _syncOnce(retryOnConflict: true);
      completer.complete();
    } catch (e) {
      completer.complete(); // complete, not completeError — state carries error
    } finally {
      _inflight = null;
    }
  }

  Future<void> _syncOnce({required bool retryOnConflict}) async {
    _emit(const SyncState(status: SyncStatus.syncing));

    try {
      // 1. Read remote snapshot.
      final (remoteJson, etag) = await _driveStore.readSnapshot();

      // 2-3. Parse remote (if any) and get local records.
      final List<SyncRecord> remoteRecords;
      if (remoteJson != null) {
        final remoteSnapshot = SyncSnapshot.fromJson(remoteJson);
        remoteRecords = remoteSnapshot.records;
      } else {
        remoteRecords = const <SyncRecord>[];
      }

      // 4. Get local records and convert to SyncRecords.
      final List<BowelMovement> localBMs =
          await _bmRepo.getAllIncludingDeleted();
      final localRecords =
          localBMs.map(SyncRecord.fromBowelMovement).toList();

      // 5. Merge.
      final mergeResult = MergeEngine.merge(localRecords, remoteRecords);

      // 6. Apply remote changes to local DB.
      if (mergeResult.hasChanges) {
        final changedBMs = <BowelMovement>[
          for (final r in mergeResult.added) r.toBowelMovement(),
          for (final r in mergeResult.updated) r.toBowelMovement(),
        ];
        await _bmRepo.applyRemote(changedBMs);
      }

      // 7-8. Build merged snapshot and write to remote.
      final mergedSnapshot = SyncSnapshot(
        version: syncSnapshotVersion,
        generatedAt: DateTime.now().toUtc(),
        records: mergeResult.merged,
      );
      await _driveStore.writeSnapshot(mergedSnapshot.toJson(), ifMatch: etag);

      // 10. Record lastSyncAt.
      final now = DateTime.now().toUtc();
      await _syncStateRepo.set(_lastSyncKey, now.toIso8601String());

      _emit(SyncState(status: SyncStatus.success, lastSyncAt: now));
    } on SnapshotConflictException {
      // 9. On conflict, retry once by re-reading.
      if (retryOnConflict) {
        await _syncOnce(retryOnConflict: false);
      } else {
        _emit(const SyncState(
          status: SyncStatus.error,
          errorMessage: 'Sync conflict could not be resolved',
        ));
      }
    } on SnapshotNetworkException catch (e) {
      _emit(SyncState(
        status: SyncStatus.error,
        errorMessage: e.message,
      ));
    } on FormatException catch (e) {
      _emit(SyncState(
        status: SyncStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      _emit(SyncState(
        status: SyncStatus.error,
        errorMessage: 'Unexpected sync error: $e',
      ));
    }
  }

  /// Deletes the remote snapshot from Drive.
  Future<void> clearRemote() async {
    await _driveStore.deleteSnapshot();
    await _syncStateRepo.delete(_lastSyncKey);
  }

  /// Loads the persisted lastSyncAt from the database.
  Future<DateTime?> loadLastSyncAt() async {
    final raw = await _syncStateRepo.get(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  void _emit(SyncState s) {
    _state = s;
    _controller.add(s);
  }

  /// Releases the stream controller. Call when the service is no longer
  /// needed.
  void dispose() {
    _controller.close();
  }
}
