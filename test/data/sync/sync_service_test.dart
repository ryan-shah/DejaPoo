import 'package:dejapoo/data/db/app_database.dart' hide SyncState;
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/data/sync/in_memory_drive_snapshot_store.dart';
import 'package:dejapoo/data/sync/sync_models.dart';
import 'package:dejapoo/data/sync/sync_service.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late DriftSyncStateRepository syncStateRepo;
  late InMemoryDriveSnapshotStore driveStore;
  late SyncService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBowelMovementRepository(db);
    syncStateRepo = DriftSyncStateRepository(db);
    driveStore = InMemoryDriveSnapshotStore();
    service = SyncService(
      bowelMovementRepository: repo,
      syncStateRepository: syncStateRepo,
      driveSnapshotStore: driveStore,
    );
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  /// Helper: create a BowelMovement with minimal fields.
  Future<BowelMovement> createLocal({
    String? id,
    DateTime? occurredAt,
    BristolType bristolType = BristolType.type4,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final bm = BowelMovement(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      occurredAt: occurredAt ?? DateTime(2026, 7, 17, 10, 0),
      dateOnly: false,
      bristolType: bristolType,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      deletedAt: deletedAt,
      note: note,
    );
    await repo.insertAll([bm]);
    return bm;
  }

  /// Helper: build a SyncSnapshot JSON map from a list of SyncRecords.
  Map<String, dynamic> snapshotJson(List<SyncRecord> records) {
    return SyncSnapshot(
      version: syncSnapshotVersion,
      generatedAt: DateTime.now().toUtc(),
      records: records,
    ).toJson();
  }

  /// Helper: build a SyncRecord with minimal fields.
  SyncRecord makeRecord({
    required String id,
    DateTime? updatedAt,
    DateTime? createdAt,
    DateTime? deletedAt,
    BristolType bristolType = BristolType.type4,
    String? note,
  }) {
    final now = DateTime.now().toUtc();
    return SyncRecord(
      id: id,
      occurredAt: DateTime(2026, 7, 17, 10, 0),
      dateOnly: false,
      bristolType: bristolType.number,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      deletedAt: deletedAt,
      note: note,
    );
  }

  group('SyncService', () {
    test('basic sync: local records sync to empty remote', () async {
      // Create a local record.
      await createLocal(id: 'local-1');

      await service.sync();

      expect(service.state.status, SyncStatus.success);
      expect(service.state.lastSyncAt, isNotNull);
      expect(driveStore.writeCount, 1);

      // Verify snapshot was written to remote.
      final (json, _) = await driveStore.readSnapshot();
      expect(json, isNotNull);
      final snapshot = SyncSnapshot.fromJson(json!);
      expect(snapshot.records, hasLength(1));
      expect(snapshot.records.first.id, 'local-1');
    });

    test('pull from remote: remote has records not in local', () async {
      // Seed the remote with a record.
      final remoteRecord = makeRecord(id: 'remote-1');
      await driveStore.writeSnapshot(snapshotJson([remoteRecord]));

      await service.sync();

      expect(service.state.status, SyncStatus.success);

      // Verify the record was pulled into local DB.
      final allLocal = await repo.getAllIncludingDeleted();
      expect(allLocal.any((bm) => bm.id == 'remote-1'), isTrue);
    });

    test('LWW merge: newer updatedAt wins', () async {
      final oldTime = DateTime.utc(2026, 7, 17, 10, 0);
      final newTime = DateTime.utc(2026, 7, 17, 12, 0);

      // Local has an old version.
      await createLocal(
        id: 'shared-1',
        updatedAt: oldTime,
        createdAt: oldTime,
        note: 'local version',
      );

      // Remote has a newer version.
      final remoteRecord = makeRecord(
        id: 'shared-1',
        updatedAt: newTime,
        createdAt: oldTime,
        note: 'remote version',
      );
      await driveStore.writeSnapshot(snapshotJson([remoteRecord]));

      await service.sync();

      expect(service.state.status, SyncStatus.success);

      // The remote (newer) version should win.
      final allLocal = await repo.getAllIncludingDeleted();
      final merged = allLocal.firstWhere((bm) => bm.id == 'shared-1');
      expect(merged.note, 'remote version');
    });

    test('conflict retry: first write throws conflict, second succeeds',
        () async {
      await createLocal(id: 'retry-1');

      // Force a conflict on the first write attempt.
      driveStore.forceConflictOnNextWrite = true;

      await service.sync();

      // Should still succeed after retry.
      expect(service.state.status, SyncStatus.success);
      // Two writes: first conflicted, second succeeded.
      expect(driveStore.writeCount, 1);
    });

    test('two-device convergence', () async {
      // Simulate two devices with separate DBs and stores, sharing the
      // same remote (InMemoryDriveSnapshotStore).

      // Device A's local DB.
      final dbA = AppDatabase(NativeDatabase.memory());
      final repoA = DriftBowelMovementRepository(dbA);
      final syncStateA = DriftSyncStateRepository(dbA);

      // Device B's local DB.
      final dbB = AppDatabase(NativeDatabase.memory());
      final repoB = DriftBowelMovementRepository(dbB);
      final syncStateB = DriftSyncStateRepository(dbB);

      // Shared remote.
      final sharedRemote = InMemoryDriveSnapshotStore();

      final serviceA = SyncService(
        bowelMovementRepository: repoA,
        syncStateRepository: syncStateA,
        driveSnapshotStore: sharedRemote,
      );
      final serviceB = SyncService(
        bowelMovementRepository: repoB,
        syncStateRepository: syncStateB,
        driveSnapshotStore: sharedRemote,
      );

      final t1 = DateTime.utc(2026, 7, 17, 10, 0);
      final t2 = DateTime.utc(2026, 7, 17, 11, 0);
      final t3 = DateTime.utc(2026, 7, 17, 12, 0);

      // Device A creates record-A.
      await repoA.insertAll([
        BowelMovement(
          id: 'record-A',
          occurredAt: DateTime(2026, 7, 17, 10, 0),
          dateOnly: false,
          bristolType: BristolType.type3,
          createdAt: t1,
          updatedAt: t1,
        ),
      ]);

      // Device B creates record-B.
      await repoB.insertAll([
        BowelMovement(
          id: 'record-B',
          occurredAt: DateTime(2026, 7, 17, 11, 0),
          dateOnly: false,
          bristolType: BristolType.type5,
          createdAt: t2,
          updatedAt: t2,
        ),
      ]);

      // Both devices also have a shared record-C, but device B edited it
      // more recently.
      await repoA.insertAll([
        BowelMovement(
          id: 'record-C',
          occurredAt: DateTime(2026, 7, 17, 9, 0),
          dateOnly: false,
          bristolType: BristolType.type4,
          note: 'device A version',
          createdAt: t1,
          updatedAt: t1,
        ),
      ]);
      await repoB.insertAll([
        BowelMovement(
          id: 'record-C',
          occurredAt: DateTime(2026, 7, 17, 9, 0),
          dateOnly: false,
          bristolType: BristolType.type4,
          note: 'device B version',
          createdAt: t1,
          updatedAt: t3, // newer
        ),
      ]);

      // Device A also has a soft-deleted record.
      await repoA.insertAll([
        BowelMovement(
          id: 'record-D',
          occurredAt: DateTime(2026, 7, 17, 8, 0),
          dateOnly: false,
          bristolType: BristolType.type2,
          createdAt: t1,
          updatedAt: t2,
          deletedAt: t2,
        ),
      ]);

      // Device A syncs first.
      await serviceA.sync();
      expect(serviceA.state.status, SyncStatus.success);

      // Device B syncs second.
      await serviceB.sync();
      expect(serviceB.state.status, SyncStatus.success);

      // Device A syncs again to pick up B's changes.
      await serviceA.sync();
      expect(serviceA.state.status, SyncStatus.success);

      // Both devices should now have identical records.
      final allA = await repoA.getAllIncludingDeleted();
      final allB = await repoB.getAllIncludingDeleted();

      final idsA = allA.map((bm) => bm.id).toSet();
      final idsB = allB.map((bm) => bm.id).toSet();
      expect(idsA, idsB, reason: 'Both devices should have the same record IDs');
      expect(
        idsA,
        containsAll(['record-A', 'record-B', 'record-C', 'record-D']),
      );

      // record-C should have device B's version (newer updatedAt).
      final cFromA = allA.firstWhere((bm) => bm.id == 'record-C');
      final cFromB = allB.firstWhere((bm) => bm.id == 'record-C');
      expect(cFromA.note, 'device B version');
      expect(cFromB.note, 'device B version');

      // record-D should be soft-deleted on both devices.
      final dFromA = allA.firstWhere((bm) => bm.id == 'record-D');
      final dFromB = allB.firstWhere((bm) => bm.id == 'record-D');
      expect(dFromA.deletedAt, isNotNull);
      expect(dFromB.deletedAt, isNotNull);

      serviceA.dispose();
      serviceB.dispose();
      await dbA.close();
      await dbB.close();
    });

    test('network error sets error state, does not crash', () async {
      driveStore.forceNetworkFailureOnNextOperation = true;

      await service.sync();

      expect(service.state.status, SyncStatus.error);
      expect(service.state.errorMessage, contains('network'));
    });

    test('version mismatch: remote version > 1 sets error state', () async {
      // Write a snapshot with a future version.
      await driveStore.writeSnapshot({
        'version': 999,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'records': <dynamic>[],
      });

      await service.sync();

      expect(service.state.status, SyncStatus.error);
      expect(
        service.state.errorMessage,
        contains('update the app'),
      );
    });

    test('single-flight: concurrent sync calls do not double-execute',
        () async {
      await createLocal(id: 'single-flight-1');

      // Launch two syncs concurrently.
      final f1 = service.sync();
      final f2 = service.sync();

      await Future.wait([f1, f2]);

      // Only one write should have occurred.
      expect(driveStore.writeCount, 1);
      expect(service.state.status, SyncStatus.success);
    });

    test('state stream emits sync lifecycle', () async {
      await createLocal(id: 'stream-1');

      final states = <SyncState>[];
      final sub = service.stateStream.listen(states.add);

      await service.sync();
      // Allow microtasks to deliver remaining stream events.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // Should have at least syncing -> success.
      expect(states.any((s) => s.status == SyncStatus.syncing), isTrue);
      expect(states.any((s) => s.status == SyncStatus.success), isTrue);
    });

    test('lastSyncAt is persisted and loadable', () async {
      await createLocal(id: 'persist-1');
      await service.sync();

      final loaded = await service.loadLastSyncAt();
      expect(loaded, isNotNull);
      expect(service.state.lastSyncAt, isNotNull);
    });
  });
}
