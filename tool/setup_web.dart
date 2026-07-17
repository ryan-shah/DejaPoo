/// Downloads sqlite3.wasm and compiles drift_worker.js for web support.
///
/// Run after `flutter pub get` (and after bumping drift/sqlite3 versions):
///   dart run tool/setup_web.dart
///
/// The sqlite3.wasm version is read from pubspec.lock so it always matches
/// the resolved `sqlite3` package version; drift_worker.js is compiled from
/// web/drift_worker.dart against the project's own drift version, so the
/// worker can never be version-skewed. Pattern borrowed from BinderManager.
library;

import 'dart:io';

Future<void> main() async {
  final Directory projectRoot = _findProjectRoot();

  final String version = _readSqlite3Version(projectRoot);
  stdout.writeln('Resolved sqlite3 version: $version');

  await _downloadSqlite3Wasm(projectRoot, version);
  await _compileDriftWorker(projectRoot);

  stdout.writeln('\nWeb setup complete.');
}

/// Walk up from the script's location to find the project root
/// (the directory containing pubspec.yaml).
Directory _findProjectRoot() {
  Directory dir = File(Platform.script.toFilePath()).parent;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln('Could not find project root (no pubspec.yaml found).');
      exit(1);
    }
    dir = parent;
  }
  return dir;
}

/// Parse the resolved sqlite3 version from pubspec.lock.
String _readSqlite3Version(Directory root) {
  final File lockFile = File('${root.path}/pubspec.lock');
  if (!lockFile.existsSync()) {
    stderr.writeln('pubspec.lock not found. Run `flutter pub get` first.');
    exit(1);
  }

  final List<String> lines = lockFile.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].trim() == 'sqlite3:') {
      for (int j = i + 1; j < lines.length && j < i + 10; j++) {
        final RegExpMatch? match =
            RegExp(r'^\s+version:\s+"(.+)"').firstMatch(lines[j]);
        if (match != null) {
          return match.group(1)!;
        }
      }
    }
  }

  stderr.writeln('Could not find sqlite3 version in pubspec.lock.');
  exit(1);
}

/// Download sqlite3.wasm from the simolus3/sqlite3.dart GitHub release
/// matching the resolved package version.
Future<void> _downloadSqlite3Wasm(Directory root, String version) async {
  final File dest = File('${root.path}/web/sqlite3.wasm');
  final String url = 'https://github.com/simolus3/sqlite3.dart/releases'
      '/download/sqlite3-$version/sqlite3.wasm';

  stdout.writeln('Downloading sqlite3.wasm from sqlite3-$version release...');
  stdout.writeln('  $url');

  final ProcessResult result = await Process.run('curl', <String>[
    '-fSL',
    '--retry',
    '3',
    '-o',
    dest.path,
    url,
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Download failed (exit ${result.exitCode}):');
    stderr.writeln(result.stderr);
    exit(1);
  }

  final int size = dest.lengthSync();
  stdout.writeln(
    '  Saved ${(size / 1024).toStringAsFixed(0)} KB -> web/sqlite3.wasm',
  );
}

/// Compile web/drift_worker.dart to web/drift_worker.js.
Future<void> _compileDriftWorker(Directory root) async {
  final File source = File('${root.path}/web/drift_worker.dart');
  if (!source.existsSync()) {
    stderr.writeln('web/drift_worker.dart not found.');
    exit(1);
  }

  stdout.writeln('Compiling drift_worker.dart -> drift_worker.js...');

  final String out = '${root.path}/web/drift_worker.js';
  final ProcessResult result = await Process.run('dart', <String>[
    'compile',
    'js',
    source.path,
    '-o',
    out,
    '-O2',
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Compilation failed (exit ${result.exitCode}):');
    stderr.writeln(result.stderr);
    exit(1);
  }

  // dart compile js side outputs; not needed at runtime.
  for (final String suffix in <String>['.deps', '.map']) {
    final File extra = File('$out$suffix');
    if (extra.existsSync()) {
      extra.deleteSync();
    }
  }

  stdout.writeln('  Done -> web/drift_worker.js');
}
