import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 7, 1, 12);
    repo = DriftBowelMovementRepository(db, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('create / getById', () {
    test('round-trips an entry with all optional fields set', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8, 30),
        bristolType: BristolType.type4,
        size: StoolSize.medium,
        color: StoolColor.brown,
        urgency: 3,
        strain: 2,
        blood: false,
        note: 'after coffee',
      );

      final BowelMovement? fetched = await repo.getById(created.id);
      expect(fetched, created);
      expect(fetched!.createdAt, now);
      expect(fetched.updatedAt, now);
      expect(fetched.deletedAt, isNull);
      expect(fetched.dateOnly, isFalse);
    });

    test('round-trips an entry with only required fields', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 9),
        bristolType: BristolType.type1,
        dateOnly: true,
      );

      final BowelMovement? fetched = await repo.getById(created.id);
      expect(fetched, created);
      expect(fetched!.size, isNull);
      expect(fetched.note, isNull);
      expect(fetched.dateOnly, isTrue);
    });

    test('assigns unique ids', () async {
      final BowelMovement a = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 9),
        bristolType: BristolType.type3,
      );
      final BowelMovement b = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 10),
        bristolType: BristolType.type3,
      );
      expect(a.id, isNot(b.id));
    });

    test('getById returns null for unknown id', () async {
      expect(await repo.getById('nope'), isNull);
    });
  });

  group('update', () {
    test('persists changes and bumps updatedAt', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );

      now = now.add(const Duration(hours: 2));
      final BowelMovement updated = await repo.update(
        created.copyWith(bristolType: BristolType.type6, note: 'changed'),
      );

      final BowelMovement? fetched = await repo.getById(created.id);
      expect(fetched, updated);
      expect(fetched!.bristolType, BristolType.type6);
      expect(fetched.note, 'changed');
      expect(fetched.createdAt, created.createdAt);
      expect(fetched.updatedAt, created.updatedAt.add(const Duration(hours: 2)));
    });

    test('can clear an optional field', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
        note: 'to be cleared',
      );

      await repo.update(created.copyWith(note: null));

      final BowelMovement? fetched = await repo.getById(created.id);
      expect(fetched!.note, isNull);
    });
  });

  group('softDelete', () {
    test('hides the row from reads but keeps a tombstone', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );

      now = now.add(const Duration(minutes: 5));
      await repo.softDelete(created.id);

      expect(await repo.getById(created.id), isNull);
      expect(
        await repo.getRange(DateTime(2026, 7, 1), DateTime(2026, 7, 2)),
        isEmpty,
      );

      // The tombstone row still exists for sync, with bumped timestamps.
      final BowelMovement raw = await (db.select(db.bowelMovements)
            ..where(($BowelMovementsTable t) => t.id.equals(created.id)))
          .getSingle();
      expect(raw.deletedAt, now);
      expect(raw.updatedAt, now);
    });
  });

  group('getRange / watchRange', () {
    test('returns [from, to) newest first', () async {
      final BowelMovement beforeRange = await repo.create(
        occurredAt: DateTime(2026, 6, 30, 23, 59),
        bristolType: BristolType.type2,
      );
      final BowelMovement atFrom = await repo.create(
        occurredAt: DateTime(2026, 7, 1),
        bristolType: BristolType.type3,
      );
      final BowelMovement inRange = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 12),
        bristolType: BristolType.type4,
      );
      final BowelMovement atTo = await repo.create(
        occurredAt: DateTime(2026, 7, 2),
        bristolType: BristolType.type5,
      );

      final List<BowelMovement> range = await repo.getRange(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
      );

      expect(range, <BowelMovement>[inRange, atFrom]);
      expect(range, isNot(contains(beforeRange)));
      expect(range, isNot(contains(atTo)));
    });

    test('watchRange emits current rows', () async {
      final BowelMovement a = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );
      final BowelMovement b = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 20),
        bristolType: BristolType.type5,
      );

      final List<BowelMovement> emitted = await repo
          .watchRange(DateTime(2026, 7, 1), DateTime(2026, 7, 2))
          .first;
      expect(emitted, <BowelMovement>[b, a]);
    });
  });

  group('insertAll', () {
    test('bulk-inserts fully formed entities', () async {
      final DateTime created = DateTime.utc(2026, 1, 1);
      final List<BowelMovement> movements = <BowelMovement>[
        for (int i = 0; i < 5; i++)
          BowelMovement(
            id: 'fixture-$i',
            occurredAt: DateTime(2026, 7, 1, 6 + i),
            dateOnly: false,
            bristolType: BristolType.fromNumber(i + 1),
            createdAt: created,
            updatedAt: created,
          ),
      ];

      await repo.insertAll(movements);

      final List<BowelMovement> range = await repo.getRange(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
      );
      expect(range.length, 5);
      expect(range.first.id, 'fixture-4');
    });
  });

  group('insertAllIfAbsent', () {
    BowelMovement makeMovement(String id, {DateTime? occurredAt}) {
      final DateTime created = DateTime.utc(2024, 1, 1);
      return BowelMovement(
        id: id,
        occurredAt: occurredAt ?? DateTime(2024, 1, 1, 12),
        dateOnly: true,
        bristolType: BristolType.type4,
        createdAt: created,
        updatedAt: created,
      );
    }

    test('inserts new movements and returns count', () async {
      final List<BowelMovement> movements = <BowelMovement>[
        makeMovement('a'),
        makeMovement('b'),
        makeMovement('c'),
      ];

      final int inserted = await repo.insertAllIfAbsent(movements);

      expect(inserted, 3);
      expect(await repo.getById('a'), isNotNull);
      expect(await repo.getById('b'), isNotNull);
      expect(await repo.getById('c'), isNotNull);
    });

    test('skips duplicates', () async {
      final List<BowelMovement> movements = <BowelMovement>[
        makeMovement('a'),
        makeMovement('b'),
        makeMovement('c'),
      ];
      await repo.insertAllIfAbsent(movements);

      final int inserted = await repo.insertAllIfAbsent(movements);

      expect(inserted, 0);
    });

    test('mixed new and existing only inserts the new ones', () async {
      await repo.insertAllIfAbsent(<BowelMovement>[
        makeMovement('a'),
        makeMovement('b'),
        makeMovement('c'),
      ]);

      final int inserted = await repo.insertAllIfAbsent(<BowelMovement>[
        makeMovement('a'),
        makeMovement('b'),
        makeMovement('c'),
        makeMovement('d'),
        makeMovement('e'),
      ]);

      expect(inserted, 2);
      expect(await repo.getById('d'), isNotNull);
      expect(await repo.getById('e'), isNotNull);
    });

    test('does not resurrect soft-deleted rows', () async {
      await repo.insertAllIfAbsent(<BowelMovement>[makeMovement('a')]);
      await repo.softDelete('a');

      final int inserted = await repo.insertAllIfAbsent(
        <BowelMovement>[makeMovement('a')],
      );

      expect(inserted, 0);
      expect(await repo.getById('a'), isNull);
      final BowelMovement raw = await (db.select(db.bowelMovements)
            ..where(($BowelMovementsTable t) => t.id.equals('a')))
          .getSingle();
      expect(raw.deletedAt, isNotNull);
    });

    test('chunks lookups past the 500-variable limit', () async {
      final List<BowelMovement> movements = <BowelMovement>[
        for (int i = 0; i < 501; i++) makeMovement('bulk-$i'),
      ];

      final int inserted = await repo.insertAllIfAbsent(movements);

      expect(inserted, 501);

      final int reinserted = await repo.insertAllIfAbsent(movements);
      expect(reinserted, 0);
    });

    test('empty list returns 0', () async {
      expect(await repo.insertAllIfAbsent(<BowelMovement>[]), 0);
    });
  });
}
