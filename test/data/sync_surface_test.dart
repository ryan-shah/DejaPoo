import 'dart:io';

import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late AppDatabase db;
  late DriftBowelMovementRepository repo;
  late DriftSyncStateRepository syncStateRepo;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 7, 1, 12);
    repo = DriftBowelMovementRepository(db, clock: () => now);
    syncStateRepo = DriftSyncStateRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  BowelMovement makeMovement(
    String id, {
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    BristolType bristolType = BristolType.type4,
  }) {
    final DateTime ts = createdAt ?? DateTime.utc(2024, 1, 1);
    return BowelMovement(
      id: id,
      occurredAt: occurredAt ?? DateTime(2024, 1, 1, 12),
      dateOnly: true,
      bristolType: bristolType,
      createdAt: ts,
      updatedAt: updatedAt ?? ts,
      deletedAt: deletedAt,
    );
  }

  group('getAllIncludingDeleted', () {
    test('returns both alive and soft-deleted rows', () async {
      final BowelMovement alive = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type3,
      );
      final BowelMovement toDelete = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 9),
        bristolType: BristolType.type5,
      );
      await repo.softDelete(toDelete.id);

      final List<BowelMovement> all = await repo.getAllIncludingDeleted();

      expect(all.map((BowelMovement m) => m.id), containsAll(<String>[alive.id, toDelete.id]));
      final BowelMovement deletedRow =
          all.firstWhere((BowelMovement m) => m.id == toDelete.id);
      expect(deletedRow.deletedAt, isNotNull);
    });
  });

  group('applyRemote', () {
    test('inserts new records', () async {
      final BowelMovement remote = makeMovement('remote-1');

      await repo.applyRemote(<BowelMovement>[remote]);

      final List<BowelMovement> all = await repo.getAllIncludingDeleted();
      expect(all.length, 1);
      expect(all.single, remote);
    });

    test('overwrites existing records verbatim, without bumping updatedAt', () async {
      final DateTime originalUpdatedAt = DateTime.utc(2024, 1, 1);
      await repo.applyRemote(<BowelMovement>[
        makeMovement('a', updatedAt: originalUpdatedAt),
      ]);

      final DateTime remoteUpdatedAt = DateTime.utc(2025, 5, 5);
      final BowelMovement incoming = makeMovement(
        'a',
        bristolType: BristolType.type7,
        updatedAt: remoteUpdatedAt,
      );
      await repo.applyRemote(<BowelMovement>[incoming]);

      final List<BowelMovement> all = await repo.getAllIncludingDeleted();
      expect(all.length, 1);
      expect(all.single, incoming);
      expect(all.single.bristolType, BristolType.type7);
      expect(all.single.updatedAt, remoteUpdatedAt);
    });

    test('can resurrect soft-deleted rows', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );
      await repo.softDelete(created.id);
      expect(await repo.getById(created.id), isNull);

      final BowelMovement resurrected = created.copyWith(
        deletedAt: null,
        updatedAt: now.add(const Duration(minutes: 10)),
      );
      await repo.applyRemote(<BowelMovement>[resurrected]);

      final BowelMovement? fetched = await repo.getById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.deletedAt, isNull);
    });

    test('can tombstone alive rows', () async {
      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 1, 8),
        bristolType: BristolType.type4,
      );
      expect(await repo.getById(created.id), isNotNull);

      final DateTime tombstoneAt = now.add(const Duration(minutes: 10));
      final BowelMovement tombstoned = created.copyWith(deletedAt: tombstoneAt);
      await repo.applyRemote(<BowelMovement>[tombstoned]);

      expect(await repo.getById(created.id), isNull);
      final List<BowelMovement> all = await repo.getAllIncludingDeleted();
      expect(all.single.deletedAt, tombstoneAt);
    });

    test('empty list is a no-op', () async {
      await repo.applyRemote(<BowelMovement>[]);
      expect(await repo.getAllIncludingDeleted(), isEmpty);
    });
  });

  group('DriftSyncStateRepository', () {
    test('get returns null for unknown key', () async {
      expect(await syncStateRepo.get('lastSyncAt'), isNull);
    });

    test('set then get round-trips a value', () async {
      await syncStateRepo.set('lastSyncAt', '2026-07-01T12:00:00Z');
      expect(await syncStateRepo.get('lastSyncAt'), '2026-07-01T12:00:00Z');
    });

    test('set overwrites an existing value', () async {
      await syncStateRepo.set('lastSyncAt', 'first');
      await syncStateRepo.set('lastSyncAt', 'second');
      expect(await syncStateRepo.get('lastSyncAt'), 'second');
    });

    test('delete removes a value', () async {
      await syncStateRepo.set('lastSyncAt', 'first');
      await syncStateRepo.delete('lastSyncAt');
      expect(await syncStateRepo.get('lastSyncAt'), isNull);
    });

    test('multiple keys are independent', () async {
      await syncStateRepo.set('lastSyncAt', 'a');
      await syncStateRepo.set('lastSnapshotHash', 'b');
      expect(await syncStateRepo.get('lastSyncAt'), 'a');
      expect(await syncStateRepo.get('lastSnapshotHash'), 'b');
    });
  });

  group('migration', () {
    test('upgrades a v1 database (bowel_movements only) to v2, adding sync_states', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp('dejapoo_migration_test');
      final File dbFile = File(p.join(tempDir.path, 'v1.sqlite'));

      addTearDown(() async {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      // Build a v1 schema by hand: just the bowel_movements table, with
      // schema_version left at 1 (drift tracks this in a meta table it
      // manages itself on open, so we only need the user table present
      // before AppDatabase opens the file for the first time via drift's
      // own onCreate path with a pre-seeded version).
      final sqlite3.Database raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('''
        CREATE TABLE bowel_movements (
          id TEXT NOT NULL PRIMARY KEY,
          occurred_at TEXT NOT NULL,
          date_only INTEGER NOT NULL DEFAULT 0,
          bristol_type INTEGER NOT NULL,
          size INTEGER NULL,
          color INTEGER NULL,
          urgency INTEGER NULL,
          strain INTEGER NULL,
          blood INTEGER NULL,
          note TEXT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT NULL
        );
      ''');
      raw.execute(
        'CREATE INDEX idx_bowel_movements_occurred_at ON bowel_movements (occurred_at);',
      );
      raw.execute(
        'CREATE INDEX idx_bowel_movements_deleted_at ON bowel_movements (deleted_at);',
      );
      // drift stores its schema version in a table it manages
      // (`__schema_version` via user_version pragma) so set that directly.
      raw.execute('PRAGMA user_version = 1;');
      raw.close();

      // Two AppDatabase instances are intentionally alive at once in this
      // test (the outer setUp's in-memory `db` plus this file-based one);
      // they never share an executor, so drift's race-condition warning is
      // a false positive here.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase migratedDb = AppDatabase(NativeDatabase(dbFile));
      // Trigger DB open, which runs the migration strategy.
      await migratedDb.customSelect('SELECT 1').get();

      expect(await migratedDb.customSelect('PRAGMA user_version').getSingle(), isNotNull);
      final int version = (await migratedDb
              .customSelect('PRAGMA user_version')
              .getSingle())
          .data['user_version'] as int;
      expect(version, 2);

      // sync_states table now exists and is usable.
      final DriftSyncStateRepository migratedSyncRepo = DriftSyncStateRepository(migratedDb);
      await migratedSyncRepo.set('lastSyncAt', 'ok');
      expect(await migratedSyncRepo.get('lastSyncAt'), 'ok');

      await migratedDb.close();
    });
  });
}
