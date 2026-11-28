import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
  });
}

class InvalidApkPayloadException implements Exception {
  const InvalidApkPayloadException();

  @override
  String toString() =>
      'InvalidApkPayloadException: downloaded file is not an APK archive';
}

class ChecksumMismatchException implements Exception {
  final String expected;
  final String actual;

  ChecksumMismatchException({required this.expected, required this.actual});

  @override
  String toString() =>
      'ChecksumMismatchException: expected $expected but got $actual';
}

class ApkDownloader {
  static const int maxApkBytes = 200 * 1024 * 1024;
  static const Set<String> _trustedRedirectHosts = {
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  final http.Client _client;
  final int _maxApkBytes;

  ApkDownloader({http.Client? client})
      : _client = client ?? http.Client(),
        _maxApkBytes = maxApkBytes;

  /// Allows boundary tests without streaming a full production-sized fixture.
  ApkDownloader.forTesting({
    http.Client? client,
    required int maxApkBytes,
  })  : _client = client ?? http.Client(),
        _maxApkBytes = maxApkBytes;

  static bool _hasSafeHttpsOrigin(Uri uri) =>
      uri.scheme.toLowerCase() == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      !uri.hasFragment;

  static bool _isTrustedReleaseAssetUri(Uri uri) {
    if (!_hasSafeHttpsOrigin(uri) ||
        uri.host.toLowerCase() != 'github.com') {
      return false;
    }
    final segments = uri.pathSegments;
    return segments.length == 6 &&
        segments[0] == 'koushik4475' &&
        segments[1] == 'pageclock' &&
        segments[2] == 'releases' &&
        segments[3] == 'download' &&
        segments[4].toLowerCase().startsWith('v') &&
        segments[5].isNotEmpty;
  }

  /// Only the exact PageClock repository's HTTPS release APK assets are valid
  /// initial download URLs. Generic GitHub pages and other repositories fail.
  static bool isTrustedDownloadUri(Uri uri) =>
      _isTrustedReleaseAssetUri(uri) &&
      uri.pathSegments.last.toLowerCase().endsWith('.apk');

  /// Legacy checksum sidecars must come from the same release-asset route.
  static bool isTrustedChecksumUri(Uri uri) =>
      _isTrustedReleaseAssetUri(uri) &&
      uri.pathSegments.last.toLowerCase().endsWith('.apk.sha256');

  /// GitHub may redirect release assets to its signed asset CDN. No other
  /// host, scheme, port, user-info, or GitHub repository is trusted.
  static bool isTrustedRedirectUri(Uri uri) {
    if (!_hasSafeHttpsOrigin(uri)) return false;
    final host = uri.host.toLowerCase();
    return isTrustedDownloadUri(uri) ||
        isTrustedChecksumUri(uri) ||
        _trustedRedirectHosts.contains(host);
  }

  /// Keeps redirects on the same release tag as the original asset request.
  /// GitHub's signed CDN URLs do not expose the tag in their path, so those
  /// remain allowed only after an exact PageClock release URL was validated.
  static bool isTrustedRedirectUriForTag(Uri uri, String expectedTag) {
    if (!isTrustedRedirectUri(uri)) return false;
    if (uri.host.toLowerCase() != 'github.com') return true;
    final segments = uri.pathSegments;
    return segments.length == 6 && segments[4] == expectedTag;
  }

  /// Downloads a trusted PageClock release APK and requires a SHA-256 digest.
  /// Redirects are followed manually so every destination can be validated.
  Future<File> downloadAndVerifyApk({
    required String url,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    if (!_isValidSha256(expectedSha256)) {
      throw StateError(
        'A valid SHA-256 checksum is required before installing an APK.',
      );
    }

    final parsedUri = Uri.tryParse(url);
    if (parsedUri == null || !isTrustedDownloadUri(parsedUri)) {
      throw HttpException(
        'APK downloads must use HTTPS from an approved PageClock GitHub release.',
      );
    }
    var currentUri = parsedUri;
    final expectedTag = parsedUri.pathSegments[4];
    late http.StreamedResponse response;
    var redirects = 0;

    while (true) {
      final request = http.Request('GET', currentUri)
        ..followRedirects = false;
      response = await _client.send(request);

      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        await response.stream.drain<void>();
        final redirectedUri = currentUri.resolve(location);
        if (!isTrustedRedirectUriForTag(redirectedUri, expectedTag)) {
          throw HttpException(
            'APK download redirect points to an untrusted host or scheme.',
          );
        }
        redirects++;
        if (redirects > 8) {
          throw HttpException('Too many HTTP redirects when downloading APK.');
        }
        currentUri = redirectedUri;
        continue;
      }
      break;
    }

    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw HttpException(
        'Failed to download APK. HTTP status: ${response.statusCode}',
      );
    }

    final totalBytes = response.contentLength ?? -1;
    if (totalBytes > _maxApkBytes) {
      await response.stream.drain<void>();
      throw HttpException('APK exceeds the maximum allowed download size.');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'pageclock_update_${DateTime.now().millisecondsSinceEpoch}.apk';
    final targetFile = File(p.join(tempDir.path, fileName));
    final sink = targetFile.openWrite();
    var receivedBytes = 0;

    try {
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          throw Exception('Download cancelled by user.');
        }

        receivedBytes += chunk.length;
        if (receivedBytes > _maxApkBytes) {
          throw HttpException('APK exceeds the maximum allowed download size.');
        }
        sink.add(chunk);

        if (onProgress != null && totalBytes > 0) {
          onProgress(DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: receivedBytes / totalBytes,
          ));
        }
      }

      if (totalBytes >= 0 && receivedBytes != totalBytes) {
        throw HttpException('APK download ended before all bytes were received.');
      }

      await sink.flush();
      await sink.close();

      final digest = await sha256.bind(targetFile.openRead()).first;
      final actualSha256 = digest.toString().toLowerCase();
      final expected = expectedSha256!.trim().toLowerCase();
      if (actualSha256 != expected) {
        throw ChecksumMismatchException(
          expected: expected,
          actual: actualSha256,
        );
      }

      // APKs are ZIP archives. Reject HTML or arbitrary files even if a
      // matching checksum was supplied for the wrong payload.
      final header = <int>[];
      await for (final chunk in targetFile.openRead(0, 4)) {
        header.addAll(chunk);
      }
      if (header.length < 4 ||
          header[0] != 0x50 ||
          header[1] != 0x4B ||
          header[2] != 0x03 ||
          header[3] != 0x04) {
        throw const InvalidApkPayloadException();
      }

      return targetFile;
    } catch (error) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }
}

bool _isValidSha256(String? value) {
  if (value == null) return false;
  final normalized = value.trim();
  if (normalized.length != 64) return false;
  return normalized.codeUnits.every((unit) =>
      (unit >= 48 && unit <= 57) ||
      (unit >= 65 && unit <= 70) ||
      (unit >= 97 && unit <= 102));
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
