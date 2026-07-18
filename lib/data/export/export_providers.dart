import 'package:dejapoo/data/export/export_service.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_providers.g.dart';

@Riverpod(keepAlive: true)
ExportService exportService(Ref ref) {
  return ExportService(ref.watch(bowelMovementRepositoryProvider));
}
