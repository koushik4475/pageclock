import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageclock/features/app_update/version_comparator.dart';
import 'package:pageclock/features/app_update/update_model.dart';
import 'package:pageclock/features/app_update/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionComparator Tests', () {
    test('Standard semver greater', () {
      expect(VersionComparator.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(VersionComparator.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(VersionComparator.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(VersionComparator.isNewer('v1.2.0', '1.1.5'), isTrue);
    });

    test('Standard semver not greater', () {
      expect(VersionComparator.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(VersionComparator.isNewer('1.0.0', '1.0.1'), isFalse);
      expect(VersionComparator.isNewer('1.0.0', '2.0.0'), isFalse);
    });

    test('Build number comparison when version names match', () {
      expect(VersionComparator.isNewer('1.0.0+2', '1.0.0+1'), isTrue);
      expect(VersionComparator.isNewer('1.0.0', '1.0.0', remoteBuild: 5, currentBuild: 4), isTrue);
      expect(VersionComparator.isNewer('1.0.0', '1.0.0', remoteBuild: 4, currentBuild: 5), isFalse);
    });
  });

  group('AppReleaseInfo JSON Parsing', () {
    test('Correctly extracts release tag, APK asset, and SHA-256', () {
      final json = {
        'tag_name': 'v1.2.0',
        'body': 'Bug fixes and performance improvements.\nSHA256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        'published_at': '2026-11-07T00:00:00Z',
        'assets': [
          {
            'name': 'pageclock-v1.2.0.apk',
            'browser_download_url': 'https://github.com/koushik4475/pageclock/releases/download/v1.2.0/pageclock-v1.2.0.apk',
            'size': 15728640,
          },
          {
            'name': 'pageclock-v1.2.0.apk.sha256',
            'browser_download_url': 'https://github.com/koushik4475/pageclock/releases/download/v1.2.0/pageclock-v1.2.0.apk.sha256',
            'size': 64,
          }
        ]
      };

      final info = AppReleaseInfo.fromJson(json);

      expect(info.tagName, equals('v1.2.0'));
      expect(info.versionName, equals('1.2.0'));
      expect(info.apkDownloadUrl, contains('pageclock-v1.2.0.apk'));
      expect(info.sha256DownloadUrl, contains('pageclock-v1.2.0.apk.sha256'));
      expect(info.expectedSha256, equals('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'));
      expect(info.apkSize, equals(15728640));
    });
  });

  group('AppUpdateService Tests', () {
    test('Detects update when remote version is higher', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/releases/latest')) {
          return http.Response(
            json.encode({
              'tag_name': 'v2.0.0',
              'body': 'Major upgrade',
              'draft': false,
              'prerelease': false,
              'published_at': '2026-11-07T01:00:00Z',
              'assets': [
                {
                  'name': 'pageclock.apk',
                  'browser_download_url': 'https://example.com/pageclock.apk',
                  'size': 12345,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(client: mockClient);
      AppUpdateService.clearCache();

      final result = await service.checkForUpdate(force: true);

      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, equals('v2.0.0'));
      expect(result.releaseInfo?.apkDownloadUrl, equals('https://example.com/pageclock.apk'));
    });

    test('Handles 404 cleanly when no releases exist', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"message": "Not Found"}', 404);
      });

      final service = AppUpdateService(client: mockClient);
      AppUpdateService.clearCache();

      final result = await service.checkForUpdate(force: true);

      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, contains('No releases found yet'));
    });

    test('Handles 403 API rate limit cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"message": "API rate limit exceeded"}', 403);
      });

      final service = AppUpdateService(client: mockClient);
      AppUpdateService.clearCache();

      final result = await service.checkForUpdate(force: true);

      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, contains('rate limit exceeded'));
    });
  });
}
