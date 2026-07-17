import 'package:dejapoo/data/fixtures/fixture_generator.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const bool _demoMode = bool.fromEnvironment('DEMO_MODE');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const <Widget>[
          if (_demoMode) _DemoDataSection(),
        ],
      ),
    );
  }
}

class _DemoDataSection extends ConsumerStatefulWidget {
  const _DemoDataSection();

  @override
  ConsumerState<_DemoDataSection> createState() => _DemoDataSectionState();
}

class _DemoDataSectionState extends ConsumerState<_DemoDataSection> {
  bool _loading = false;

  Future<void> _loadSampleData() async {
    setState(() => _loading = true);
    try {
      final BowelMovementRepository repo =
          ref.read(bowelMovementRepositoryProvider);
      final DateTime now = DateTime.now();
      final DateTime threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
      final List<BowelMovement> fixtures = FixtureGenerator().generate(
        firstDay: threeMonthsAgo,
        lastDay: now,
      );
      await repo.insertAll(fixtures);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${fixtures.length} sample entries')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _removeSampleData() async {
    setState(() => _loading = true);
    try {
      final BowelMovementRepository repo =
          ref.read(bowelMovementRepositoryProvider);
      await repo.deleteAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All entries removed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.md,
            Spacing.xs,
          ),
          child: Text(
            'Demo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ListTile(
          leading: _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          title: const Text('Load sample data'),
          subtitle: const Text('Add ~3 months of synthetic entries'),
          enabled: !_loading,
          onTap: _loadSampleData,
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Remove all data'),
          subtitle: const Text('Delete every entry from the database'),
          enabled: !_loading,
          onTap: () async {
            final bool? confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Remove all data?'),
                content: const Text(
                  'This will permanently delete every entry. '
                  'This cannot be undone.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await _removeSampleData();
            }
          },
        ),
        const Divider(),
      ],
    );
  }
}
