import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:crypto/crypto.dart';
import 'package:pageclock/features/app_update/apk_downloader.dart';

class _OversizedContentLengthClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      200,
      contentLength: ApkDownloader.maxApkBytes + 1,
    );
  }
}

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

  group('Update Download & Integrity Pressure Tests', () {
    test('ApkDownloader follows multi-hop HTTP 302/301 redirects and computes bit-for-bit SHA-256', () async {
      final dummyApkBytes = utf8.encode('DUMMY_ANDROID_APK_BINARY_STREAM_FOR_TESTING_PURPOSES');
      final expectedSha = sha256.convert(dummyApkBytes).toString();

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://github.com/releases/download/v1.0.0/app.apk') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://release-assets.githubusercontent.com/cdn/app.apk'},
          );
        } else if (request.url.toString() == 'https://release-assets.githubusercontent.com/cdn/app.apk') {
          return http.Response.bytes(
            dummyApkBytes,
            200,
            headers: {
              'content-length': dummyApkBytes.length.toString(),
              'content-type': 'application/vnd.android.package-archive',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final downloader = ApkDownloader(client: mockClient);
      final downloadedFile = await downloader.downloadAndVerifyApk(
        url: 'https://github.com/releases/download/v1.0.0/app.apk',
        expectedSha256: expectedSha,
      );

      expect(await downloadedFile.exists(), isTrue);
      expect(await downloadedFile.length(), equals(dummyApkBytes.length));

      // Clean up
      await downloadedFile.delete();
    });

    test('ApkDownloader strictly rejects corrupted APK payload on SHA-256 mismatch', () async {
      final dummyApkBytes = utf8.encode('CORRUPTED_OR_TAMPERED_APK_BYTES');

      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          dummyApkBytes,
          200,
          headers: {'content-length': dummyApkBytes.length.toString()},
        );
      });

      final downloader = ApkDownloader(client: mockClient);

      expect(
        () async => await downloader.downloadAndVerifyApk(
          url: 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
          expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsA(isA<ChecksumMismatchException>()),
      );
    }); 
    test('ApkDownloader rejects missing checksums before starting a network request', () async {
      var requestStarted = false;
      final mockClient = MockClient((request) async {
        requestStarted = true;
        return http.Response('unexpected', 200);
      });
      final downloader = ApkDownloader(client: mockClient);

      expect(
        () async => downloader.downloadAndVerifyApk(
          url: 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
          expectedSha256: null,
        ),
        throwsA(isA<StateError>()),
      );
      expect(requestStarted, isFalse);
    });

    test('ApkDownloader rejects HTTPS-to-HTTP redirects', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '',
          302,
          headers: {'location': 'http://insecure.example.com/app.apk'},
        );
      });
      final downloader = ApkDownloader(client: mockClient);

      expect(
        () async => downloader.downloadAndVerifyApk(
          url: 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
          expectedSha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        throwsA(isA<HttpException>()),
      );
    });


    test('rejects an APK URL on an untrusted HTTPS host before network access', () async {
      var requestStarted = false;
      final client = MockClient((request) async {
        requestStarted = true;
        return http.Response('unexpected', 200);
      });

      expect(
        () => ApkDownloader(client: client).downloadAndVerifyApk(
          url: 'https://attacker.example/app.apk',
          expectedSha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        throwsA(isA<HttpException>()),
      );
      expect(requestStarted, isFalse);
    });

    test('rejects redirects to untrusted HTTPS hosts', () async {
      final client = MockClient((request) async => http.Response(
        '',
        302,
        headers: {'location': 'https://attacker.example/payload.apk'},
      ));

      expect(
        () => ApkDownloader(client: client).downloadAndVerifyApk(
          url: 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
          expectedSha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('rejects an APK whose declared content length exceeds the safety limit', () async {
      final client = _OversizedContentLengthClient();

      expect(
        () => ApkDownloader(client: client).downloadAndVerifyApk(
          url: 'https://github.com/koushik4475/pageclock/releases/download/v1.0.0/app.apk',
          expectedSha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
