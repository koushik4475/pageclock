import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:crypto/crypto.dart';
import 'package:pageclock/features/app_update/apk_downloader.dart';

class _StreamedBodyClient extends http.BaseClient {
  final Stream<List<int>> body;
  _StreamedBodyClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body, 200);
}

class _OversizedContentLengthClient extends http.BaseClient {
  final int contentLength;
  _OversizedContentLengthClient(this.contentLength);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        const Stream<List<int>>.empty(),
        200,
        contentLength: contentLength,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Directory? testTempDirectory;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return testTempDirectory?.path ?? Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  setUp(() async {
    testTempDirectory =
        await Directory.systemTemp.createTemp('pageclock-updater-test-');
  });

  tearDown(() async {
    final directory = testTempDirectory;
    testTempDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  const releaseApk =
      'https://github.com/koushik4475/pageclock/releases/download/v1.0.0+119/PageClock.apk';

  test('accepts only PageClock release assets and the approved GitHub CDN redirects', () {
    final accepted = [
      releaseApk,
      'https://github.com:443/koushik4475/pageclock/releases/download/v1.0.0/PageClock.apk',
    ];
    for (final value in accepted) {
      expect(
        ApkDownloader.isTrustedDownloadUri(Uri.parse(value)),
        isTrue,
        reason: value,
      );
    }

    for (final value in [
      'https://objects.githubusercontent.com/release/app.apk',
      'https://release-assets.githubusercontent.com/release/app.apk',
      'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/PageClock.apk.sha256',
    ]) {
      expect(
        ApkDownloader.isTrustedRedirectUri(Uri.parse(value)),
        isTrue,
        reason: value,
      );
    }

    final rejected = [
      'http://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
      'https://github.com:444/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
      'https://user@github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
      'https://github.com.attacker.example/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
      'https://attacker.github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
      'https://attacker.example/app.apk',
      'https://github.com/attacker/pageclock/releases/download/v1.0.0/app.apk',
      'https://github.com/koushik4475/other/releases/download/v1.0.0/app.apk',
      'https://github.com/koushik4475/pageclock/blob/main/app.apk',
      'https://github.com/koushik4475/pageclock/releases/download/v1.0.0',
      'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk#fragment',
    ];
    for (final value in rejected) {
      final uri = Uri.parse(value);
      expect(ApkDownloader.isTrustedDownloadUri(uri), isFalse, reason: value);
      expect(ApkDownloader.isTrustedRedirectUri(uri), isFalse, reason: value);
    }
  });

  test('downloads through a trusted GitHub CDN and verifies checksum plus APK ZIP header', () async {
    final apkBytes = <int>[
      0x50, 0x4B, 0x03, 0x04,
      ...utf8.encode('test apk payload'),
    ];
    final expectedSha = sha256.convert(apkBytes).toString();
    final client = MockClient((request) async {
      if (request.url.toString() == releaseApk) {
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://release-assets.githubusercontent.com/signed/app.apk?token=fixture',
          },
        );
      }
      if (request.url.host == 'release-assets.githubusercontent.com') {
        return http.Response.bytes(
          apkBytes,
          200,
          headers: {'content-length': apkBytes.length.toString()},
        );
      }
      return http.Response('Not Found', 404);
    });

    final file = await ApkDownloader(client: client).downloadAndVerifyApk(
      url: releaseApk,
      expectedSha256: expectedSha,
    );
    expect(await file.exists(), isTrue);
    expect(await file.length(), apkBytes.length);
    await file.delete();
  });

  test('rejects an untrusted initial APK URL before network access', () async {
    var requestStarted = false;
    final client = MockClient((request) async {
      requestStarted = true;
      return http.Response('unexpected', 200);
    });

    await expectLater(
      ApkDownloader(client: client).downloadAndVerifyApk(
        url: 'https://attacker.example/app.apk',
        expectedSha256: '0' * 64,
      ),
      throwsA(isA<HttpException>()),
    );
    expect(requestStarted, isFalse);
  });

  test('rejects redirects to untrusted hosts and other GitHub repositories', () async {
    for (final redirect in [
      'https://attacker.example/payload.apk',
      'https://github.com/attacker/repo/releases/download/v1.0.0/app.apk',
    ]) {
      var requestedAttacker = false;
      final client = MockClient((request) async {
        if (request.url.toString() == releaseApk) {
          return http.Response('', 302, headers: {'location': redirect});
        }
        requestedAttacker = true;
        return http.Response('unexpected', 200);
      });

      await expectLater(
        ApkDownloader(client: client).downloadAndVerifyApk(
          url: releaseApk,
          expectedSha256: '0' * 64,
        ),
        throwsA(isA<HttpException>()),
      );
      expect(requestedAttacker, isFalse, reason: redirect);
    }
  });

  test('rejects a non-APK payload even when its checksum matches and removes it', () async {
    final invalidBytes = utf8.encode('<html>not an apk</html>');
    final expectedSha = sha256.convert(invalidBytes).toString();
    final client = MockClient((request) async =>
        http.Response.bytes(invalidBytes, 200));

    await expectLater(
      ApkDownloader(client: client).downloadAndVerifyApk(
        url: releaseApk,
        expectedSha256: expectedSha,
      ),
      throwsA(isA<InvalidApkPayloadException>()),
    );

    final remaining = await testTempDirectory!
        .list()
        .where((entity) => entity.path.split(Platform.pathSeparator).last
            .startsWith('pageclock_update_'))
        .toList();
    expect(remaining, isEmpty);
  });

  test('rejects checksum mismatches and deletes the downloaded file', () async {
    final apkBytes = <int>[0x50, 0x4B, 0x03, 0x04, ...List<int>.filled(128, 7)];
    final client = MockClient((request) async =>
        http.Response.bytes(apkBytes, 200));

    await expectLater(
      ApkDownloader(client: client).downloadAndVerifyApk(
        url: releaseApk,
        expectedSha256: '0' * 64,
      ),
      throwsA(isA<ChecksumMismatchException>()),
    );

    expect(await testTempDirectory!.list().isEmpty, isTrue);
  });

  test('rejects missing checksums before starting a network request', () async {
    var requestStarted = false;
    final client = MockClient((request) async {
      requestStarted = true;
      return http.Response('unexpected', 200);
    });

    await expectLater(
      ApkDownloader(client: client).downloadAndVerifyApk(
        url: releaseApk,
        expectedSha256: null,
      ),
      throwsA(isA<StateError>()),
    );
    expect(requestStarted, isFalse);
  });

  test('rejects streamed APK overflow without Content-Length and removes partial file', () async {
    final client = _StreamedBodyClient(
      Stream<List<int>>.fromIterable([
        utf8.encode('12345678'),
        utf8.encode('9'),
      ]),
    );
    final downloader = ApkDownloader.forTesting(
      client: client,
      maxApkBytes: 8,
    );

    await expectLater(
      downloader.downloadAndVerifyApk(
        url: releaseApk,
        expectedSha256: '0' * 64,
      ),
      throwsA(isA<HttpException>()),
    );
    expect(await testTempDirectory!.list().isEmpty, isTrue);
  });

  test('rejects declared APK sizes above the configured maximum', () async {
    final client = _OversizedContentLengthClient(9);
    final downloader = ApkDownloader.forTesting(
      client: client,
      maxApkBytes: 8,
    );

    await expectLater(
      downloader.downloadAndVerifyApk(
        url: releaseApk,
        expectedSha256: '0' * 64,
      ),
      throwsA(isA<HttpException>()),
    );
    expect(await testTempDirectory!.list().isEmpty, isTrue);
  });

  test('rejects too many redirects', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
        '',
        302,
        headers: {
          'location':
              'https://release-assets.githubusercontent.com/signed/$requests',
        },
      );
    });

    await expectLater(
      ApkDownloader(client: client).downloadAndVerifyApk(
        url: releaseApk,
        expectedSha256: '0' * 64,
      ),
      throwsA(isA<HttpException>()),
    );
    expect(requests, 9);
  });
}
