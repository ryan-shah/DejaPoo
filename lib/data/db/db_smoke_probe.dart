import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:flutter/foundation.dart';

/// Runtime database smoke probe — the **local web gate** for the data layer.
///
/// `flutter test --platform chrome` is unusable here: it wedges
/// nondeterministically on this machine (dp-0ot) and its browser harness
/// cannot serve assets (rootBundle loads time out on CI). This probe instead
/// exercises the real production path — `driftDatabase()` with the compiled
/// drift worker, WASM sqlite, and whichever storage drift selects — inside
/// the actual app on Chrome:
///
///   flutter run -d chrome --dart-define=DB_SMOKE=true
///
/// then look for a `DB_SMOKE OK` / `DB_SMOKE FAIL` line on the console.
/// Uses a throwaway database name so the real app database is untouched.
Future<void> runDbSmokeProbe() async {
  final AppDatabase db = AppDatabase.open(name: 'dejapoo_smoke_probe');
  try {
    final DriftBowelMovementRepository repo =
        DriftBowelMovementRepository(db);
    final DateTime now = DateTime.now();

    final BowelMovement created = await repo.create(
      occurredAt: now,
      bristolType: BristolType.type4,
      note: 'db smoke probe',
    );
    final BowelMovement? fetched = await repo.getById(created.id);
    final List<DailyTypeCount> counts = await repo.dailyTypeCounts(now, now);
    await repo.softDelete(created.id);
    final BowelMovement? afterDelete = await repo.getById(created.id);

    final bool ok = fetched == created &&
        counts.any(
          (DailyTypeCount c) => c.type == BristolType.type4 && c.count > 0,
        ) &&
        afterDelete == null;
    debugPrint(
      ok
          ? 'DB_SMOKE OK: insert/read/aggregate/soft-delete round-tripped'
          : 'DB_SMOKE FAIL: fetched=$fetched counts=$counts '
              'afterDelete=$afterDelete',
    );
  } catch (error, stackTrace) {
    debugPrint('DB_SMOKE FAIL: $error\n$stackTrace');
  } finally {
    await db.close();
  }
}
