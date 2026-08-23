import 'dart:async';
import 'dart:convert';

import 'package:dejapoo/app_version.dart';
import 'package:dejapoo/data/updates/update_models.dart';
import 'package:http/http.dart' as http;

/// Checks GitHub for a newer published release of the app.
///
/// Reads the repository's `releases/latest` endpoint, which deliberately skips
/// drafts and prereleases — the PR test builds in `android.yml` are published
/// as prereleases tagged `pr-<N>`, so they never surface as an update.
///
/// The endpoint is public, so the request is unauthenticated (60 requests per
/// hour per IP) and CORS-enabled, which is what lets the web build call it
/// directly from the browser.
class UpdateService {
  UpdateService({
    http.Client? client,
    this.currentVersion = appVersion,
    this.repository = defaultRepository,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// `owner/name` of the GitHub repository releases are published to.
  static const String defaultRepository = 'ryan-shah/DejaPoo';

  final http.Client _client;
  final bool _ownsClient;

  /// The version the running build reports; injectable so tests do not depend
  /// on the ambient `APP_VERSION` define.
  final String currentVersion;
  final String repository;
  final Duration timeout;

  Uri get _latestReleaseUri =>
      Uri.parse('https://api.github.com/repos/$repository/releases/latest');

  /// Fetches the latest release and compares it to [currentVersion].
  ///
  /// Throws [UpdateCheckException] with a user-facing message on any failure.
  Future<UpdateCheckResult> checkForUpdate() async {
    final AppRelease latest = await fetchLatestRelease();
    return UpdateCheckResult(
      status: _statusFor(latest.version),
      currentVersion: currentVersion,
      latest: latest,
    );
  }

  UpdateStatus _statusFor(String latestVersion) {
    if (!isVersionString(currentVersion) || !isVersionString(latestVersion)) {
      return UpdateStatus.unknownCurrentVersion;
    }
    return compareVersions(latestVersion, currentVersion) > 0
        ? UpdateStatus.updateAvailable
        : UpdateStatus.upToDate;
  }

  /// Fetches the latest non-prerelease release from GitHub.
  Future<AppRelease> fetchLatestRelease() async {
    final http.Response response;
    try {
      response = await _client
          .get(
            _latestReleaseUri,
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw UpdateCheckException(
        'Timed out reaching GitHub. Try again.',
        cause: e,
      );
    } on Exception catch (e) {
      throw UpdateCheckException(
        'Could not reach GitHub. Check your connection.',
        cause: e,
      );
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 404:
        throw const UpdateCheckException(
          'No releases have been published yet.',
        );
      case 403:
      case 429:
        throw const UpdateCheckException(
          'GitHub rate limit reached. Try again later.',
        );
      default:
        throw UpdateCheckException(
          'GitHub returned an error (${response.statusCode}).',
        );
    }

    return _parseRelease(response.body);
  }

  AppRelease _parseRelease(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw UpdateCheckException(
        'Could not read the release information from GitHub.',
        cause: e,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateCheckException(
        'Could not read the release information from GitHub.',
      );
    }

    final Object? tag = decoded['tag_name'];
    if (tag is! String || tag.trim().isEmpty) {
      throw const UpdateCheckException(
        'The latest GitHub release has no version tag.',
      );
    }

    final Object? htmlUrl = decoded['html_url'];
    final String releaseUrl = htmlUrl is String && htmlUrl.isNotEmpty
        ? htmlUrl
        : 'https://github.com/$repository/releases/tag/$tag';

    final Object? publishedAt = decoded['published_at'];

    return AppRelease(
      version: _versionFromTag(tag),
      tag: tag.trim(),
      releaseUrl: releaseUrl,
      apkUrl: _apkAssetUrl(decoded['assets']),
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)?.toLocal()
          : null,
    );
  }

  /// `v0.1.19` -> `0.1.19`.
  String _versionFromTag(String tag) {
    final String trimmed = tag.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  /// The download URL of the release's APK asset, if it has one.
  ///
  /// Release assets are named `dejapoo-v<version>.apk` / `.aab` by
  /// `android.yml`, so matching the extension is enough and stays correct if
  /// the name ever changes.
  String? _apkAssetUrl(Object? assets) {
    if (assets is! List) return null;
    for (final Object? asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final Object? name = asset['name'];
      final Object? url = asset['browser_download_url'];
      if (name is String &&
          name.toLowerCase().endsWith('.apk') &&
          url is String &&
          url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  /// Closes the internally-created HTTP client. A client passed in by the
  /// caller is left alone — whoever created it owns it.
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
