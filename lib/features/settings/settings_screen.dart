import 'dart:typed_data';

import 'package:dejapoo/data/auth/google_auth_provider.dart';
import 'package:dejapoo/data/fixtures/fixture_generator.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

const bool _demoMode = bool.fromEnvironment('DEMO_MODE');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const <Widget>[
          _AccountSection(),
          _ImportSection(),
          if (_demoMode) _DemoDataSection(),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthStatus authStatus = ref.watch(googleAuthProvider);
    final GoogleAuth authNotifier = ref.read(googleAuthProvider.notifier);

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
            'Account',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        if (authStatus == AuthStatus.signedOut)
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Sign in with Google'),
            subtitle: const Text('Enable Google Drive sync'),
            onTap: () => _handleSignIn(context, authNotifier),
          ),
        if (authStatus == AuthStatus.signedIn) ...<Widget>[
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(authNotifier.currentUserEmail ?? 'Signed in'),
            subtitle: const Text('Drive sync not yet authorized'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Authorize Drive sync'),
            subtitle: const Text('Allow app to sync via Google Drive'),
            onTap: () => _handleAuthorizeDrive(context, authNotifier),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: authNotifier.signOut,
          ),
        ],
        if (authStatus == AuthStatus.driveAuthorized) ...<Widget>[
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(authNotifier.currentUserEmail ?? 'Signed in'),
            subtitle: const Text('Drive sync authorized'),
            trailing: Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: authNotifier.signOut,
          ),
        ],
        const Divider(),
      ],
    );
  }

  Future<void> _handleSignIn(
    BuildContext context,
    GoogleAuth authNotifier,
  ) async {
    try {
      await authNotifier.signIn();
    } on GoogleSignInException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  Future<void> _handleAuthorizeDrive(
    BuildContext context,
    GoogleAuth authNotifier,
  ) async {
    try {
      await authNotifier.authorizeDriveScope();
    } on GoogleSignInException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authorization failed: ${e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authorization failed: $e')),
        );
      }
    }
  }
}

class _ImportSection extends ConsumerStatefulWidget {
  const _ImportSection();

  @override
  ConsumerState<_ImportSection> createState() => _ImportSectionState();
}

class _ImportSectionState extends ConsumerState<_ImportSection> {
  bool _loading = false;

  Future<void> _pickAndImport() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      return;
    }

    setState(() => _loading = true);
    ImportSummary summary;
    try {
      summary = await ref
          .read(importServiceProvider)
          .importBytes(bytes, file.name);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (!mounted) {
      return;
    }
    final bool failed = summary.insertedCount == 0 && summary.hasErrors;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(failed ? 'Import Failed' : 'Import Complete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Inserted ${summary.insertedCount} events '
                '(${summary.skippedCount} already existed)',
              ),
              if (summary.issues.isNotEmpty) ...<Widget>[
                const SizedBox(height: Spacing.sm),
                ...summary.issues.map((ImportIssue issue) => Text('• $issue')),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFormatHelp() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Expected file format'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'XLSX (recommended)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: Spacing.xs),
              Text(
                'One sheet per year, named with the year (e.g. "2024").\n'
                'Row 1: title (ignored)\n'
                'Row 2: headers (ignored)\n'
                'Row 3+: data rows',
              ),
              SizedBox(height: Spacing.sm),
              Text('Column layout:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: Spacing.xs),
              Text(
                '  A — Month name (ignored)\n'
                '  B — Date\n'
                '  C — Type 1 count\n'
                '  D — Type 2 count\n'
                '  E — Type 3 count\n'
                '  F — Type 4 count\n'
                '  G — Type 5 count\n'
                '  H — Type 6 count\n'
                '  I — Type 7 count\n'
                '  J — Total (optional)',
              ),
              SizedBox(height: Spacing.sm),
              Text(
                'Blank count cells are treated as 0. Rows without a '
                'valid date in column B are skipped.',
              ),
              SizedBox(height: Spacing.md),
              Text('CSV', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: Spacing.xs),
              Text(
                'Same column layout as above. One file per year. '
                'Dates can be ISO (2024-01-15), US (1/15/2024), '
                'or Excel serial numbers.',
              ),
              SizedBox(height: Spacing.md),
              Text(
                'Re-importing the same file is safe — duplicate '
                'entries are automatically skipped.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://ryan-shah.github.io/DejaPoo/sample_import.csv',
              ),
            ),
            child: const Text('Download sample CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
            'Import',
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
              : const Icon(Icons.upload_file),
          title: const Text('Import spreadsheet'),
          subtitle: const Text('Import from XLSX or CSV file'),
          enabled: !_loading,
          onTap: _pickAndImport,
          trailing: IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Expected file format',
            onPressed: _showFormatHelp,
          ),
        ),
        const Divider(),
      ],
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
