import 'package:dejapoo/features/home/install_prompt_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('defaults to not dismissed', () async {
    expect(
      await container.read(installPromptDismissedProvider.future),
      isFalse,
    );
  });

  test('dismissing updates state and persists', () async {
    await container.read(installPromptDismissedProvider.future);
    await container
        .read(installPromptDismissedProvider.notifier)
        .setDismissed(true);

    expect(container.read(installPromptDismissedProvider).value, isTrue);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('install_prompt_dismissed'), isTrue);
  });

  test('a persisted dismissal is loaded on build', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'install_prompt_dismissed': true,
    });
    final ProviderContainer fresh = ProviderContainer();
    addTearDown(fresh.dispose);

    expect(await fresh.read(installPromptDismissedProvider.future), isTrue);
  });

  test('un-dismissing clears the persisted flag', () async {
    await container.read(installPromptDismissedProvider.future);
    final InstallPromptDismissed notifier =
        container.read(installPromptDismissedProvider.notifier);
    await notifier.setDismissed(true);
    await notifier.setDismissed(false);

    expect(container.read(installPromptDismissedProvider).value, isFalse);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('install_prompt_dismissed'), isFalse);
  });
}
