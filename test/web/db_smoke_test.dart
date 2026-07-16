@TestOn('browser')
library;

import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/wasm.dart';

/// Smoke test for the web exit criterion: drift runs against WASM sqlite in
/// a real browser. Run with: flutter test --platform chrome test/web
///
/// The wasm binary is loaded from the asset bundle — the test server does not
/// serve files from web/, and fetching an unserved URL hangs the suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'drift on WASM sqlite inserts and reads back',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final ByteData wasm = await rootBundle.load('web/sqlite3.wasm');
      final WasmSqlite3 sqlite3 =
          await WasmSqlite3.load(wasm.buffer.asUint8List());
      sqlite3.registerVirtualFileSystem(
        InMemoryFileSystem(),
        makeDefault: true,
      );

      final AppDatabase db = AppDatabase(WasmDatabase.inMemory(sqlite3));
      addTearDown(db.close);
      final DriftBowelMovementRepository repo =
          DriftBowelMovementRepository(db);

      final BowelMovement created = await repo.create(
        occurredAt: DateTime(2026, 7, 16, 8, 30),
        bristolType: BristolType.type4,
        note: 'wasm smoke',
      );

      expect(await repo.getById(created.id), created);
      expect(
        await repo.dailyTypeCounts(
          DateTime(2026, 7, 16),
          DateTime(2026, 7, 16),
        ),
        <DailyTypeCount>[
          DailyTypeCount(
            day: DateTime(2026, 7, 16),
            type: BristolType.type4,
            count: 1,
          ),
        ],
      );
    },
  );
}
