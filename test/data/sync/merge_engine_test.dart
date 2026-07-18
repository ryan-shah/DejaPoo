import 'package:dejapoo/data/sync/merge_engine.dart';
import 'package:dejapoo/data/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

SyncRecord _record(
  String id, {
  DateTime? updatedAt,
  DateTime? deletedAt,
  String? note,
  int bristolType = 4,
}) {
  return SyncRecord(
    id: id,
    occurredAt: DateTime(2026, 7, 17, 8, 30),
    dateOnly: false,
    bristolType: bristolType,
    note: note,
    createdAt: DateTime.utc(2026, 7, 17, 8, 0),
    updatedAt: updatedAt ?? DateTime.utc(2026, 7, 17, 9, 0),
    deletedAt: deletedAt,
  );
}

/// Asserts that merging [a] with [b] and [b] with [a] produce the same set
/// of records (order-independent), which is the key convergence property.
void _expectCommutative(List<SyncRecord> a, List<SyncRecord> b) {
  final ab = MergeEngine.merge(a, b).merged;
  final ba = MergeEngine.merge(b, a).merged;
  expect(
    Set<SyncRecord>.from(ab),
    Set<SyncRecord>.from(ba),
    reason: 'merge(a,b) and merge(b,a) must converge to the same set',
  );
}

void main() {
  group('MergeEngine.merge basics', () {
    test('empty lists merge to empty', () {
      final result = MergeEngine.merge([], []);
      expect(result.merged, isEmpty);
      expect(result.added, isEmpty);
      expect(result.updated, isEmpty);
      expect(result.hasChanges, isFalse);
    });

    test('non-overlapping records union', () {
      final local = [_record('a')];
      final remote = [_record('b')];

      final result = MergeEngine.merge(local, remote);

      expect(result.merged.map((r) => r.id).toSet(), {'a', 'b'});
      expect(result.added.map((r) => r.id).toList(), ['b']);
      expect(result.updated, isEmpty);
      expect(result.hasChanges, isTrue);
    });
  });

  group('MergeEngine.merge last-write-wins', () {
    test('same id, remote newer: remote wins', () {
      final local = [
        _record('a', updatedAt: DateTime.utc(2026, 7, 17, 9), note: 'local'),
      ];
      final remote = [
        _record('a', updatedAt: DateTime.utc(2026, 7, 17, 10), note: 'remote'),
      ];

      final result = MergeEngine.merge(local, remote);

      expect(result.merged.single.note, 'remote');
      expect(result.updated.single.note, 'remote');
      expect(result.added, isEmpty);
      expect(result.hasChanges, isTrue);
    });

    test('same id, local newer: local wins', () {
      final local = [
        _record('a', updatedAt: DateTime.utc(2026, 7, 17, 10), note: 'local'),
      ];
      final remote = [
        _record('a', updatedAt: DateTime.utc(2026, 7, 17, 9), note: 'remote'),
      ];

      final result = MergeEngine.merge(local, remote);

      expect(result.merged.single.note, 'local');
      expect(result.updated, isEmpty);
      expect(result.added, isEmpty);
      expect(result.hasChanges, isFalse);
    });

    test('same id, exact tie, remote is tombstone: tombstone wins', () {
      final tie = DateTime.utc(2026, 7, 17, 9);
      final local = [_record('a', updatedAt: tie, note: 'alive')];
      final remote = [
        _record('a', updatedAt: tie, deletedAt: DateTime.utc(2026, 7, 17, 9, 1)),
      ];

      final result = MergeEngine.merge(local, remote);

      expect(result.merged.single.deletedAt, isNotNull);
    });

    test('same id, exact tie, local is tombstone: tombstone wins', () {
      final tie = DateTime.utc(2026, 7, 17, 9);
      final local = [
        _record('a', updatedAt: tie, deletedAt: DateTime.utc(2026, 7, 17, 9, 1)),
      ];
      final remote = [_record('a', updatedAt: tie, note: 'alive')];

      final result = MergeEngine.merge(local, remote);

      expect(result.merged.single.deletedAt, isNotNull);
    });

    test('same id, exact tie, both alive: resolves deterministically both '
        'ways', () {
      final tie = DateTime.utc(2026, 7, 17, 9);
      final a = _record('x', updatedAt: tie, note: 'aaa');
      final b = _record('x', updatedAt: tie, note: 'bbb');

      final resultAB = MergeEngine.merge([a], [b]);
      final resultBA = MergeEngine.merge([b], [a]);

      // Same winner regardless of which side is "local".
      expect(resultAB.merged.single.note, resultBA.merged.single.note);
    });

    test('same id, exact tie, both tombstones: resolves deterministically '
        'both ways', () {
      final tie = DateTime.utc(2026, 7, 17, 9);
      final delA = DateTime.utc(2026, 7, 17, 9, 5);
      final delB = DateTime.utc(2026, 7, 17, 9, 6);
      final a = _record('x', updatedAt: tie, deletedAt: delA, note: 'aaa');
      final b = _record('x', updatedAt: tie, deletedAt: delB, note: 'bbb');

      final resultAB = MergeEngine.merge([a], [b]);
      final resultBA = MergeEngine.merge([b], [a]);

      expect(resultAB.merged.single.deletedAt, resultBA.merged.single.deletedAt);
      expect(resultAB.merged.single.note, resultBA.merged.single.note);
    });
  });

  group('MergeEngine.merge convergence property', () {
    test('commutative for non-overlapping sets', () {
      final a = [_record('a'), _record('b')];
      final b = [_record('c'), _record('d')];
      _expectCommutative(a, b);
    });

    test('commutative when one side has a strictly newer conflicting record',
        () {
      final a = [
        _record('shared', updatedAt: DateTime.utc(2026, 7, 17, 9), note: 'a'),
        _record('onlyA'),
      ];
      final b = [
        _record('shared', updatedAt: DateTime.utc(2026, 7, 17, 10), note: 'b'),
        _record('onlyB'),
      ];
      _expectCommutative(a, b);
    });

    test('commutative on exact-tie conflicts', () {
      final tie = DateTime.utc(2026, 7, 17, 9);
      final a = [
        _record('shared', updatedAt: tie, note: 'a'),
        _record('tombA', updatedAt: tie, deletedAt: tie),
      ];
      final b = [
        _record('shared', updatedAt: tie, note: 'b'),
        _record('tombA', updatedAt: tie, note: 'alive-on-b'),
      ];
      _expectCommutative(a, b);
    });

    test('DST-edge boundary: same instant expressed as UTC vs local resolves '
        'correctly', () {
      // A single instant, once expressed in UTC and once as the equivalent
      // local DateTime — both denote the same moment, so this must resolve
      // as an exact tie (not "one is newer"), consistent with the
      // requirement that all comparisons happen in UTC.
      final instantUtc = DateTime.utc(2026, 7, 17, 9, 0, 0);
      final instantAsLocal = instantUtc.toLocal();

      final local = [_record('a', updatedAt: instantUtc, note: 'utc-copy')];
      final remote = [
        _record('a', updatedAt: instantAsLocal, note: 'local-copy'),
      ];

      final result = MergeEngine.merge(local, remote);

      // Exact tie (same instant), both alive -> deterministic winner,
      // convergent both ways.
      final resultOther = MergeEngine.merge(remote, local);
      expect(result.merged.single.note, resultOther.merged.single.note);
    });

    test('large merge with many conflicts: no crash and convergent', () {
      final a = <SyncRecord>[];
      final b = <SyncRecord>[];

      for (var i = 0; i < 150; i++) {
        final id = 'id-$i';
        if (i % 3 == 0) {
          // Conflict: both sides have it, different updatedAt.
          a.add(_record(id, updatedAt: DateTime.utc(2026, 7, 17, 9, i)));
          b.add(_record(id, updatedAt: DateTime.utc(2026, 7, 17, 10, i)));
        } else if (i % 3 == 1) {
          // Conflict: exact tie.
          final tie = DateTime.utc(2026, 7, 17, 8, i);
          a.add(_record(id, updatedAt: tie, note: 'a-$i'));
          b.add(_record(id, updatedAt: tie, note: 'b-$i'));
        } else {
          // Only on one side.
          if (i % 2 == 0) {
            a.add(_record(id));
          } else {
            b.add(_record(id));
          }
        }
      }

      final result = MergeEngine.merge(a, b);
      final ids = result.merged.map((r) => r.id).toSet();
      expect(ids.length, result.merged.length); // no duplicate ids
      expect(ids.length, greaterThanOrEqualTo(100));

      _expectCommutative(a, b);
    });
  });
}
