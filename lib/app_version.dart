/// The running build's version, injected by every CI build workflow as
/// `--dart-define=APP_VERSION=<version>`; `dev` for local builds.
///
/// See `tool/ci_version.sh` for how the value is derived: it is
/// `<MAJOR.MINOR from pubspec.yaml>.<git commit count>`, e.g. `0.1.19`, and
/// matches the `v0.1.19` GitHub release tag for the same commit. The update
/// checker relies on that correspondence.
///
/// Lives at the root of `lib/` rather than in a feature so both the UI and the
/// data layer can read it without the data layer importing a feature.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

/// Whether [version] is a plain dot-separated numeric version that can be
/// ordered by [compareVersions] — false for the local `dev` build.
bool isVersionString(String version) {
  final String trimmed = _stripPrefix(version);
  if (trimmed.isEmpty) return false;
  return trimmed
      .split('.')
      .every((String part) => part.isNotEmpty && int.tryParse(part) != null);
}

/// Compares two dot-separated numeric versions (`0.1.19`), ignoring a leading
/// `v`.
///
/// Returns a negative number if [a] is older than [b], zero if they are equal
/// and a positive number if [a] is newer. Missing components count as zero, so
/// `0.1` and `0.1.0` compare equal. Non-numeric components also count as zero,
/// so filter operands with [isVersionString] first when that matters.
int compareVersions(String a, String b) {
  final List<String> partsA = _stripPrefix(a).split('.');
  final List<String> partsB = _stripPrefix(b).split('.');
  final int length = partsA.length > partsB.length ? partsA.length : partsB.length;
  for (int i = 0; i < length; i++) {
    final int valueA = i < partsA.length ? (int.tryParse(partsA[i]) ?? 0) : 0;
    final int valueB = i < partsB.length ? (int.tryParse(partsB[i]) ?? 0) : 0;
    if (valueA != valueB) return valueA - valueB;
  }
  return 0;
}

String _stripPrefix(String version) {
  final String trimmed = version.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}
