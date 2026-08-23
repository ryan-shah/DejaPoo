import 'package:dejapoo/app_version.dart';

/// A release published on the project's GitHub releases page.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.releaseUrl,
    this.apkUrl,
    this.publishedAt,
  });

  /// The version without its `v` prefix, e.g. `0.1.19`.
  final String version;

  /// The git tag the release was cut from, e.g. `v0.1.19`.
  final String tag;

  /// The release's page on GitHub.
  final String releaseUrl;

  /// Direct download link for the release's Android APK, when it has one.
  final String? apkUrl;

  final DateTime? publishedAt;

  /// What the download button should open: the APK itself when the release
  /// carries one, otherwise the release page so the user can pick an asset.
  String get downloadUrl => apkUrl ?? releaseUrl;
}

/// How the running build compares to the latest published release.
enum UpdateStatus {
  /// The running build is the latest release, or newer than it (a local build
  /// made after the last release).
  upToDate,

  /// A newer release is available.
  updateAvailable,

  /// The running build's version is not comparable — a `dev` build, which
  /// carries no version at all. The latest release is still reported so it can
  /// be downloaded.
  unknownCurrentVersion,
}

/// The outcome of one update check.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.latest,
  });

  final UpdateStatus status;

  /// The version the app is running, i.e. [appVersion] at the time of the
  /// check.
  final String currentVersion;

  final AppRelease latest;

  bool get hasUpdate => status == UpdateStatus.updateAvailable;
}

/// Raised when an update check cannot complete: no network, a GitHub error, a
/// rate limit, or a repository with no releases yet.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message, {this.cause});

  /// User-facing, already phrased for display in the settings list.
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'UpdateCheckException: $message${cause == null ? '' : ' ($cause)'}';
}
