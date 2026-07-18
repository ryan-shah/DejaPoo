import 'package:drift/drift.dart';

/// Key-value store for sync metadata (lastSyncAt, lastSnapshotHash, etc.).
class SyncStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
