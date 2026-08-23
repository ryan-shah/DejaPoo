import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'install_prompt_preferences.g.dart';

const String _dismissedKey = 'install_prompt_dismissed';

/// Whether the user has dismissed the "install the Android app" prompt shown
/// to Android web visitors.
///
/// Device-local only (backed by `shared_preferences`) — this must NEVER be
/// included in the Google Drive sync snapshot, which only carries
/// [BowelMovement] records. A dismissal on one phone's browser says nothing
/// about any other device.
@Riverpod(keepAlive: true)
class InstallPromptDismissed extends _$InstallPromptDismissed {
  @override
  Future<bool> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  /// Records whether the prompt has been dismissed, updating the UI
  /// immediately and persisting in the background.
  Future<void> setDismissed(bool dismissed) async {
    state = AsyncData<bool>(dismissed);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, dismissed);
  }
}
