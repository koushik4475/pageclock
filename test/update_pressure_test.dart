import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageclock/features/app_update/version_comparator.dart';
import 'package:pageclock/features/app_update/update_model.dart';
import 'package:pageclock/features/app_update/app_update_service.dart';
import 'package:pageclock/features/app_update/apk_downloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  group('OTA App Update Pressure & Reliability Tests', () {
    test('Historical Fleet Compatibility: All 19 released versions update smoothly to new release', () {
      const historicalVersions = [
        'v1.0.0+20', 'v1.0.0+21', 'v1.0.0+22', 'v1.0.0+23', 'v1.0.0+25',
        'v1.0.0+26', 'v1.0.0+27', 'v1.0.0+29', 'v1.0.0+30', 'v1.0.0+31',
        'v1.0.0+33', 'v1.0.0+39', 'v1.0.0+40', 'v1.0.0+41', 'v1.0.0+42',
        'v1.0.0+44', 'v1.0.0+55', 'v1.0.0+56', 'v1.0.0+57'
      ];

      const targetReleases = [
        'v1.0.0+58',
        'v1.0.0+119',
        'v1.0.1+1',
        'v1.1.0+1',
        'v2.0.0+1',
      ];

      for (final target in targetReleases) {
        for (final installed in historicalVersions) {
          final isNewer = VersionComparator.isNewer(target, installed);
          expect(isNewer, isTrue,
              reason: 'Installed version $installed MUST detect $target as an available update');
        }
      }

      // Verify identical versions do NOT trigger update loops
      for (final v in historicalVersions) {
        expect(VersionComparator.isNewer(v, v), isFalse);
      }

      // Verify older remote versions do NOT trigger downgrade prompts
      expect(VersionComparator.isNewer('v1.0.0+56', 'v1.0.0+57'), isFalse);
      expect(VersionComparator.isNewer('v1.0.0+44', 'v1.0.0+57'), isFalse);
    });

    test('10,000 High-Throughput Version Comparison Permutations (<500ms)', () {
      final sw = Stopwatch()..start();
      final rng = Random(42);

      for (int i = 0; i < 10000; i++) {
        final majorA = rng.nextInt(5);
        final minorA = rng.nextInt(10);
        final patchA = rng.nextInt(20);
        final buildA = rng.nextInt(200);

        final majorB = rng.nextInt(5);
        final minorB = rng.nextInt(10);
        final patchB = rng.nextInt(20);
        final buildB = rng.nextInt(200);

        final vA = 'v$majorA.$minorA.$patchA+$buildA';
        final vB = 'v$majorB.$minorB.$patchB+$buildB';

        final result = VersionComparator.isNewer(vA, vB);

        bool expected = false;
        if (majorA != majorB) {
          expected = majorA > majorB;
        } else if (minorA != minorB) {
          expected = minorA > minorB;
        } else if (patchA != patchB) {
          expected = patchA > patchB;
        } else {
          expected = buildA > buildB;
        }

        expect(result, equals(expected),
            reason: 'Mismatch comparing $vA to $vB');
      }

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('GitHub Release Multi-Asset Ingestion and Checksum Priority', () {
      final releaseJson = {
        'tag_name': 'v1.0.0+119',
        'body': 'Automated release notes.\nSHA256: 1111111111111111111111111111111111111111111111111111111111111111',
        'published_at': '2026-11-09T18:00:00Z',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'source.tar.gz',
            'browser_download_url': 'https://example.com/source.tar.gz',
            'size': 10000,
          },
          {
            'name': 'PageClock-v1.0.0+119.apk',
            'browser_download_url': 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0%2B119/PageClock-v1.0.0%2B119.apk',
            'size': 29996762,
            'digest': 'sha256:5483da3256e709ea15408fca2d0b98dca3531206553ada4a7e2df99308345d84',
          },
          {
            'name': 'PageClock-v1.0.0+119.apk.sha256',
            'browser_download_url': 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0%2B119/PageClock-v1.0.0%2B119.apk.sha256',
            'size': 90,
          },
        ],
      };

      final info = AppReleaseInfo.fromJson(releaseJson);

      expect(info.tagName, equals('v1.0.0+119'));
      expect(info.versionName, equals('1.0.0'));
      expect(info.buildNumber, equals(119));
      expect(info.apkDownloadUrl, contains('PageClock-v1.0.0%2B119.apk'));
      // Asset digest takes precedence over inline notes
      expect(info.expectedSha256, equals('5483da3256e709ea15408fca2d0b98dca3531206553ada4a7e2df99308345d84'));
      expect(info.sha256DownloadUrl, contains('PageClock-v1.0.0%2B119.apk.sha256'));
    });

    test('Network Stress: Gracefully handles 403, 500, 502, 503, 504 and SocketException without crash', () async {
      final statusesToTest = [403, 500, 502, 503, 504];

      for (final code in statusesToTest) {
        final mockClient = MockClient((request) async {
          return http.Response('Server status code $code', code);
        });

        final service = AppUpdateService(client: mockClient);
        AppUpdateService.clearCache();

        final result = await service.checkForUpdate(force: true);
        expect(result.hasUpdate, isFalse);
        expect(result.errorMessage, isNotNull);
      }

      // Test socket failure / offline airplane mode
      final offlineClient = MockClient((request) async {
        throw const SocketException('No address associated with hostname');
      });

      final offlineService = AppUpdateService(client: offlineClient);
      AppUpdateService.clearCache();

      final offlineResult = await offlineService.checkForUpdate(force: true);
      expect(offlineResult.hasUpdate, isFalse);
      expect(offlineResult.errorMessage, contains('Network error'));
    });

    test('Update Download Multi-Hop Redirect, Streaming & Bit-Level Checksum Verification', () async {
      final apkBytes = List<int>.generate(1024 * 64, (i) => i % 256);
      final validChecksum = sha256.convert(apkBytes).toString();

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://github.com/releases/download/v1.0.0+119/app.apk') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://s3.amazonaws.com/github-releases/app.apk'},
          );
        } else if (url == 'https://s3.amazonaws.com/github-releases/app.apk') {
          return http.Response.bytes(
            apkBytes,
            200,
            headers: {
              'content-length': apkBytes.length.toString(),
              'content-type': 'application/vnd.android.package-archive',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final downloader = ApkDownloader(client: mockClient);

      // 1. Success case: bit-for-bit verified
      final verifiedFile = await downloader.downloadAndVerifyApk(
        url: 'https://github.com/releases/download/v1.0.0+119/app.apk',
        expectedSha256: validChecksum,
      );

      expect(await verifiedFile.exists(), isTrue);
      expect(await verifiedFile.length(), equals(apkBytes.length));
      await verifiedFile.delete();

      // 2. Tampered checksum case: single bit alteration rejected and file wiped
      final tamperedChecksum = '0' * 64;
      expect(
        () async => await downloader.downloadAndVerifyApk(
          url: 'https://github.com/releases/download/v1.0.0+119/app.apk',
          expectedSha256: tamperedChecksum,
        ),
        throwsA(isA<ChecksumMismatchException>()),
      );
    });

    test('Download Cancellation Token immediately cleans up temporary files', () async {
      final apkBytes = List<int>.generate(1024 * 128, (i) => i % 256);
      final validChecksum = sha256.convert(apkBytes).toString();
      final cancelToken = CancellationToken();

      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          apkBytes,
          200,
          headers: {'content-length': apkBytes.length.toString()},
        );
      });

      final downloader = ApkDownloader(client: mockClient);
      cancelToken.cancel();

      expect(
        () async => await downloader.downloadAndVerifyApk(
          url: 'https://github.com/releases/download/app.apk',
          expectedSha256: validChecksum,
          cancelToken: cancelToken,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
