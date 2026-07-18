import 'package:dejapoo/data/sync/in_memory_drive_snapshot_store.dart';
import 'package:dejapoo/data/sync/snapshot_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryDriveSnapshotStore store;

  setUp(() {
    store = InMemoryDriveSnapshotStore();
  });

  group('DriveSnapshotStore (in-memory)', () {
    test('read returns null when no snapshot exists', () async {
      final (json, etag) = await store.readSnapshot();
      expect(json, isNull);
      expect(etag, isNull);
    });

    test('write creates snapshot, read returns it with etag', () async {
      final snapshot = {'version': 1, 'data': 'test'};
      final etag = await store.writeSnapshot(snapshot);

      expect(etag, isNotEmpty);

      final (readJson, readEtag) = await store.readSnapshot();
      expect(readJson, equals(snapshot));
      expect(readEtag, equals(etag));
    });

    test('write with correct ifMatch succeeds and updates etag', () async {
      final etag1 = await store.writeSnapshot({'v': 1});
      final etag2 = await store.writeSnapshot({'v': 2}, ifMatch: etag1);

      expect(etag2, isNotEmpty);
      expect(etag2, isNot(equals(etag1)));

      final (json, etag) = await store.readSnapshot();
      expect(json, equals({'v': 2}));
      expect(etag, equals(etag2));
    });

    test('write with wrong ifMatch throws SnapshotConflictException', () async {
      await store.writeSnapshot({'v': 1});

      expect(
        () => store.writeSnapshot({'v': 2}, ifMatch: 'wrong-etag'),
        throwsA(isA<SnapshotConflictException>()),
      );
    });

    test('write without ifMatch always succeeds (create-or-overwrite)',
        () async {
      final etag1 = await store.writeSnapshot({'v': 1});
      // Write without ifMatch -- should succeed even though etag changed.
      final etag2 = await store.writeSnapshot({'v': 2});

      expect(etag2, isNot(equals(etag1)));

      final (json, _) = await store.readSnapshot();
      expect(json, equals({'v': 2}));
    });

    test('injected conflict mode works', () async {
      await store.writeSnapshot({'v': 1});
      store.forceConflictOnNextWrite = true;

      expect(
        () => store.writeSnapshot({'v': 2}, ifMatch: 'any'),
        throwsA(isA<SnapshotConflictException>()),
      );

      // Conflict flag resets after firing.
      expect(store.forceConflictOnNextWrite, isFalse);

      // Subsequent write without ifMatch succeeds.
      final etag = await store.writeSnapshot({'v': 3});
      expect(etag, isNotEmpty);
    });

    test('injected network failure mode works on read', () async {
      await store.writeSnapshot({'v': 1});
      store.forceNetworkFailureOnNextOperation = true;

      expect(
        () => store.readSnapshot(),
        throwsA(isA<SnapshotNetworkException>()),
      );

      // Flag resets after firing -- next read works.
      final (json, _) = await store.readSnapshot();
      expect(json, equals({'v': 1}));
    });

    test('injected network failure mode works on write', () async {
      store.forceNetworkFailureOnNextOperation = true;

      expect(
        () => store.writeSnapshot({'v': 1}),
        throwsA(isA<SnapshotNetworkException>()),
      );

      // Flag resets -- next write works.
      final etag = await store.writeSnapshot({'v': 1});
      expect(etag, isNotEmpty);
    });

    test('multiple sequential writes increment etag', () async {
      final etags = <String>[];
      for (var i = 0; i < 5; i++) {
        final etag = await store.writeSnapshot({'v': i});
        etags.add(etag);
      }

      // All etags are unique.
      expect(etags.toSet().length, equals(5));
      // Write count tracks all successful writes.
      expect(store.writeCount, equals(5));
    });

    test('read returns deep copy (mutations do not affect store)', () async {
      await store.writeSnapshot({'nested': {'key': 'value'}});
      final (json, _) = await store.readSnapshot();
      json!['nested'] = 'mutated';

      // Store should still have the original.
      final (json2, _) = await store.readSnapshot();
      expect(json2!['nested'], equals({'key': 'value'}));
    });

    test('write stores deep copy (mutations do not affect store)', () async {
      final data = <String, dynamic>{'nested': {'key': 'value'}};
      await store.writeSnapshot(data);
      data['nested'] = 'mutated';

      // Store should still have the original.
      final (json, _) = await store.readSnapshot();
      expect(json!['nested'], equals({'key': 'value'}));
    });

    test('reset clears all state', () async {
      await store.writeSnapshot({'v': 1});
      store.forceConflictOnNextWrite = true;
      store.forceNetworkFailureOnNextOperation = true;
      store.reset();

      expect(store.storedSnapshot, isNull);
      expect(store.currentEtag, isNull);
      expect(store.writeCount, equals(0));
      expect(store.forceConflictOnNextWrite, isFalse);
      expect(store.forceNetworkFailureOnNextOperation, isFalse);

      final (json, etag) = await store.readSnapshot();
      expect(json, isNull);
      expect(etag, isNull);
    });

    test('conflict mode does not fire when ifMatch is null', () async {
      await store.writeSnapshot({'v': 1});
      store.forceConflictOnNextWrite = true;

      // Write without ifMatch -- conflict mode should NOT fire.
      final etag = await store.writeSnapshot({'v': 2});
      expect(etag, isNotEmpty);

      // Flag should still be set since it didn't fire.
      expect(store.forceConflictOnNextWrite, isTrue);
    });
  });
}
