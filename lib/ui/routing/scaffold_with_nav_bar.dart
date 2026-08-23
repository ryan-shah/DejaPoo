import 'package:dejapoo/data/auth/google_auth_provider.dart';
import 'package:dejapoo/data/sync/sync_providers.dart';
import 'package:dejapoo/data/sync/sync_reminder.dart';
import 'package:dejapoo/data/sync/sync_reminder_preferences.dart';
import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Width (in logical pixels) at or above which the shell switches from a
/// bottom [NavigationBar] to a side [NavigationRail].
const double kWideLayoutBreakpoint = 840;

/// Max width for the primary content column at wide layouts, so text-heavy
/// screens stay readable. Individual screens (e.g. charts) may opt out.
const double kContentMaxWidth = 840;

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activates the auto-sync-on-open / sign-out-teardown trigger. This is the
    // only watcher in the app: until the shell watched it, syncTrigger never
    // ran at all.
    ref.watch(syncTriggerProvider);

    final bool showBanner = ref.watch(syncReminderProvider).shouldShow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kWideLayoutBreakpoint;

        /// Puts the staleness banner above [child] inside the *shell's*
        /// Scaffold body, so it sits above the per-screen Scaffolds and their
        /// AppBars (a ScaffoldMessenger banner would belong to whichever
        /// screen Scaffold is on top, and disappear when branches switch).
        ///
        /// The banner takes over the status-bar inset while it is visible, so
        /// the inner AppBars must not reserve it a second time.
        Widget withBanner(Widget child) {
          if (!showBanner) return child;
          return Column(
            children: [
              const SafeArea(bottom: false, child: SyncStalenessBanner()),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                ),
              ),
            ],
          );
        }

        if (!isWide) {
          return Scaffold(
            body: withBanner(navigationShell),
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: withBanner(
            Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('Reports'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: kContentMaxWidth,
                      ),
                      child: navigationShell,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Prompts the user when their Drive data has not synced in
/// [kSyncStalenessThreshold]. Renders nothing when the data is fresh, when the
/// user has never synced, or while the prompt is snoozed.
///
/// Sits above the per-screen scaffolds (see [ScaffoldWithNavBar]) so it is
/// visible on Home, Reports and Settings alike.
class SyncStalenessBanner extends ConsumerWidget {
  const SyncStalenessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncReminderStatus status = ref.watch(syncReminderProvider);
    if (!status.shouldShow) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final int days = status.daysSinceLastSync ?? kSyncStalenessThreshold.inDays;
    final bool authorized =
        ref.watch(googleAuthProvider) == AuthStatus.driveAuthorized;

    return MaterialBanner(
      backgroundColor: theme.colorScheme.secondaryContainer,
      contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      leading: Icon(
        Icons.cloud_off_outlined,
        color: theme.colorScheme.onSecondaryContainer,
      ),
      content: Text("Your data hasn't synced in $days days"),
      actions: [
        TextButton(
          onPressed: () {
            if (authorized) {
              ref.read(syncServiceProvider.notifier).syncNow();
            } else {
              // Not authorized — send the user to Settings to sign in.
              context.go(AppRoutes.settings);
            }
          },
          child: const Text('Sync now'),
        ),
        TextButton(
          onPressed: () {
            ref.read(syncReminderPreferencesProvider.notifier).snooze();
          },
          child: const Text('Later'),
        ),
      ],
    );
  }
}
