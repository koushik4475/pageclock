import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
  });
}

class InvalidApkPayloadException implements Exception {
  const InvalidApkPayloadException();

  @override
  String toString() => 'InvalidApkPayloadException: downloaded file is not an APK archive';
}

class ChecksumMismatchException implements Exception {
  final String expected;
  final String actual;

  ChecksumMismatchException({required this.expected, required this.actual});

  @override
  String toString() => 'ChecksumMismatchException: expected $expected but got $actual';
}

class ApkDownloader {
  static const int maxApkBytes = 200 * 1024 * 1024;
  static const Set<String> _trustedHosts = {
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  final http.Client _client;
  final int _maxApkBytes;

  ApkDownloader({http.Client? client})
      : _client = client ?? http.Client(),
        _maxApkBytes = maxApkBytes;

  /// Allows focused boundary tests without streaming a full 200 MiB fixture.
  ApkDownloader.forTesting({
    http.Client? client,
    required int maxApkBytes,
  })  : _client = client ?? http.Client(),
        _maxApkBytes = maxApkBytes;

  static bool isTrustedDownloadUri(Uri uri) {
    return uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        uri.port == 443 &&
        _trustedHosts.contains(uri.host.toLowerCase());
  }

  /// Downloads an APK from [url] and requires [expectedSha256] to verify it.
  /// and emits progress on [onProgress]. Supports HTTP redirects (e.g. 302/301).
  Future<File> downloadAndVerifyApk({
    required String url,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    if (!_isValidSha256(expectedSha256)) {
      throw StateError('A valid SHA-256 checksum is required before installing an APK.');
    }

    final parsedUri = Uri.tryParse(url);
    if (parsedUri == null || !isTrustedDownloadUri(parsedUri)) {
      throw HttpException('APK downloads must use HTTPS from an approved GitHub release host.');
    }
    Uri currentUri = parsedUri;
    http.StreamedResponse response;
    int redirects = 0;

    while (true) {
      final request = http.Request('GET', currentUri);
      request.followRedirects = false; // Manually handle redirect loop safely
      response = await _client.send(request);

      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        await response.stream.drain<void>();
        final redirectedUri = currentUri.resolve(location);
        if (!isTrustedDownloadUri(redirectedUri)) {
          throw HttpException('APK download redirect points to an untrusted host or scheme.');
        }
        currentUri = redirectedUri;
        redirects++;
        if (redirects > 8) {
          throw HttpException('Too many HTTP redirects when downloading APK.');
        }
        continue;
      }
      break;
    }

    if (response.statusCode != 200) {
      throw HttpException('Failed to download APK. HTTP status: ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? -1;
    if (totalBytes > _maxApkBytes) {
      throw HttpException('APK exceeds the maximum allowed download size.');
    }
    final tempDir = await getTemporaryDirectory();
    final fileName = 'pageclock_update_${DateTime.now().millisecondsSinceEpoch}.apk';
    final targetFile = File(p.join(tempDir.path, fileName));
    final sink = targetFile.openWrite();

    int receivedBytes = 0;

    try {
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
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

      await sink.flush();
      await sink.close();

      // Compute SHA-256 using streaming file read
      final digest = await sha256.bind(targetFile.openRead()).first;
      final actualSha256 = digest.toString().toLowerCase();

      // The checksum was required and validated before the download.
      final expected = expectedSha256!.trim().toLowerCase();
      if (actualSha256 != expected) {
        throw ChecksumMismatchException(expected: expected, actual: actualSha256);
      }

      // APKs are ZIP archives. Reject HTML error pages or arbitrary payloads
      // even when a matching sidecar is present.
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
    } catch (e) {
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
