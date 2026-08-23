import 'dart:async';

import 'package:dejapoo/data/updates/update_models.dart';
import 'package:dejapoo/data/updates/update_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_providers.g.dart';

/// The app-wide [UpdateService].
@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) {
  final UpdateService service = UpdateService();
  ref.onDispose(service.dispose);
  return service;
}

/// The result of the most recent update check, or `null` before one has been
/// run.
///
/// The check is deliberately manual — [check] runs only when the user taps
/// "Check for updates" in Settings, so the app never calls out to GitHub on
/// its own.
@riverpod
class UpdateCheckNotifier extends _$UpdateCheckNotifier {
  @override
  FutureOr<UpdateCheckResult?> build() => null;

  /// Runs a check, moving the provider through loading to data or error.
  Future<void> check() async {
    state = const AsyncValue<UpdateCheckResult?>.loading();
    state = await AsyncValue.guard<UpdateCheckResult?>(
      () => ref.read(updateServiceProvider).checkForUpdate(),
    );
  }
}
