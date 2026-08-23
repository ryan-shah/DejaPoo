import 'dart:convert';

import 'package:dejapoo/data/updates/update_models.dart';
import 'package:dejapoo/data/updates/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A GitHub `releases/latest` payload, trimmed to the fields the service reads.
String releaseJson({
  String tag = 'v0.1.19',
  List<String> assetNames = const <String>[
    'dejapoo-v0.1.19.aab',
    'dejapoo-v0.1.19.apk',
  ],
}) {
  return jsonEncode(<String, Object?>{
    'tag_name': tag,
    'html_url': 'https://github.com/ryan-shah/DejaPoo/releases/tag/$tag',
    'published_at': '2026-08-20T12:00:00Z',
    'assets': <Object?>[
      for (final String name in assetNames)
        <String, Object?>{
          'name': name,
          'browser_download_url':
              'https://github.com/ryan-shah/DejaPoo/releases/download/$tag/$name',
        },
    ],
  });
}

UpdateService serviceReturning(
  String body, {
  int statusCode = 200,
  String currentVersion = '0.1.10',
  void Function(http.Request request)? onRequest,
}) {
  return UpdateService(
    currentVersion: currentVersion,
    client: MockClient((http.Request request) async {
      onRequest?.call(request);
      return http.Response(
        body,
        statusCode,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );
}

void main() {
  group('UpdateService.checkForUpdate', () {
    test('reports an update when the release is newer than the build',
        () async {
      final UpdateCheckResult result =
          await serviceReturning(releaseJson()).checkForUpdate();

      expect(result.status, UpdateStatus.updateAvailable);
      expect(result.hasUpdate, isTrue);
      expect(result.currentVersion, '0.1.10');
      expect(result.latest.version, '0.1.19');
      expect(result.latest.tag, 'v0.1.19');
    });

    test('reports up to date when the build matches the release', () async {
      final UpdateCheckResult result =
          await serviceReturning(releaseJson(), currentVersion: '0.1.19')
              .checkForUpdate();

      expect(result.status, UpdateStatus.upToDate);
      expect(result.hasUpdate, isFalse);
    });

    test('a build ahead of the latest release is not an update', () async {
      // Local/CI builds off main run ahead of the last published release.
      final UpdateCheckResult result =
          await serviceReturning(releaseJson(), currentVersion: '0.1.25')
              .checkForUpdate();

      expect(result.status, UpdateStatus.upToDate);
    });

    test('a dev build cannot be compared but still reports the release',
        () async {
      final UpdateCheckResult result =
          await serviceReturning(releaseJson(), currentVersion: 'dev')
              .checkForUpdate();

      expect(result.status, UpdateStatus.unknownCurrentVersion);
      expect(result.hasUpdate, isFalse);
      expect(result.latest.version, '0.1.19');
    });

    test('picks the APK asset as the download target', () async {
      final UpdateCheckResult result =
          await serviceReturning(releaseJson()).checkForUpdate();

      expect(result.latest.apkUrl, endsWith('dejapoo-v0.1.19.apk'));
      expect(result.latest.downloadUrl, result.latest.apkUrl);
    });

    test('falls back to the release page when there is no APK asset',
        () async {
      final UpdateCheckResult result = await serviceReturning(
        releaseJson(assetNames: <String>['dejapoo-v0.1.19.aab']),
      ).checkForUpdate();

      expect(result.latest.apkUrl, isNull);
      expect(
        result.latest.downloadUrl,
        'https://github.com/ryan-shah/DejaPoo/releases/tag/v0.1.19',
      );
    });

    test('parses the publish date', () async {
      final UpdateCheckResult result =
          await serviceReturning(releaseJson()).checkForUpdate();

      expect(
        result.latest.publishedAt?.toUtc(),
        DateTime.utc(2026, 8, 20, 12),
      );
    });

    test('queries the latest-release endpoint, which skips PR prereleases',
        () async {
      http.Request? seen;
      await serviceReturning(
        releaseJson(),
        onRequest: (http.Request request) => seen = request,
      ).checkForUpdate();

      expect(
        seen?.url.toString(),
        'https://api.github.com/repos/ryan-shah/DejaPoo/releases/latest',
      );
      expect(seen?.headers['Accept'], 'application/vnd.github+json');
    });
  });

  group('UpdateService failures', () {
    Future<UpdateCheckException> failureOf(UpdateService service) async {
      try {
        await service.checkForUpdate();
      } on UpdateCheckException catch (e) {
        return e;
      }
      fail('expected an UpdateCheckException');
    }

    test('404 means the repository has no releases yet', () async {
      final UpdateCheckException e =
          await failureOf(serviceReturning('{}', statusCode: 404));
      expect(e.message, contains('No releases'));
    });

    test('403 and 429 report the rate limit', () async {
      expect(
        (await failureOf(serviceReturning('{}', statusCode: 403))).message,
        contains('rate limit'),
      );
      expect(
        (await failureOf(serviceReturning('{}', statusCode: 429))).message,
        contains('rate limit'),
      );
    });

    test('other status codes report the code', () async {
      final UpdateCheckException e =
          await failureOf(serviceReturning('{}', statusCode: 500));
      expect(e.message, contains('500'));
    });

    test('a network failure is reported, not thrown raw', () async {
      final UpdateService service = UpdateService(
        currentVersion: '0.1.10',
        client: MockClient(
          (http.Request request) async =>
              throw http.ClientException('offline'),
        ),
      );

      final UpdateCheckException e = await failureOf(service);
      expect(e.message, contains('Could not reach GitHub'));
      expect(e.cause, isA<http.ClientException>());
    });

    test('a slow response times out', () async {
      final UpdateService service = UpdateService(
        currentVersion: '0.1.10',
        timeout: const Duration(milliseconds: 20),
        client: MockClient((http.Request request) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return http.Response(releaseJson(), 200);
        }),
      );

      expect((await failureOf(service)).message, contains('Timed out'));
    });

    test('a malformed body is reported', () async {
      final UpdateCheckException e =
          await failureOf(serviceReturning('not json'));
      expect(e.message, contains('Could not read'));
    });

    test('a release with no tag is reported', () async {
      final UpdateCheckException e = await failureOf(
        serviceReturning(jsonEncode(<String, Object?>{'html_url': 'x'})),
      );
      expect(e.message, contains('no version tag'));
    });
  });
}
