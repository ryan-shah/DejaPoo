import 'package:dejapoo/data/db/bowel_movements_table.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The app's Drift database.
///
/// Use [AppDatabase.open] in the app; tests inject an in-memory
/// [QueryExecutor] via the default constructor.
@DriftDatabase(tables: [BowelMovements])
class AppDatabase extends _$AppDatabase {
  /// Creates a database on an explicit executor — used by tests.
  AppDatabase(super.e);

  /// Opens the persistent database for the current platform (native SQLite on
  /// Android/iOS, WASM SQLite on web via `web/sqlite3.wasm` +
  /// `web/drift_worker.js`).
  AppDatabase.open()
      : super(
          driftDatabase(
            name: 'dejapoo',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
      );
}
