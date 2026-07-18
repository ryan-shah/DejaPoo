import 'package:dejapoo/data/db/app_database.dart';
import 'package:dejapoo/data/import/import_service.dart';
import 'package:dejapoo/data/repositories/drift_bowel_movement_repository.dart';
import 'package:dejapoo/data/repositories/drift_sync_state_repository.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// The app-wide database, opened once and closed when the container dies.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final AppDatabase db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

/// The app-wide [BowelMovementRepository].
@Riverpod(keepAlive: true)
BowelMovementRepository bowelMovementRepository(Ref ref) {
  return DriftBowelMovementRepository(ref.watch(appDatabaseProvider));
}

/// The app-wide [DriftSyncStateRepository].
@Riverpod(keepAlive: true)
DriftSyncStateRepository syncStateRepository(Ref ref) {
  return DriftSyncStateRepository(ref.watch(appDatabaseProvider));
}

/// The app-wide [ImportService] for historical spreadsheet import.
@Riverpod(keepAlive: true)
ImportService importService(Ref ref) {
  return ImportService(ref.watch(bowelMovementRepositoryProvider));
}
