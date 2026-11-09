import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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

class ChecksumMismatchException implements Exception {
  final String expected;
  final String actual;

  ChecksumMismatchException({required this.expected, required this.actual});

  @override
  String toString() => 'ChecksumMismatchException: expected $expected but got $actual';
}

class ApkDownloader {
  final http.Client _client;

  ApkDownloader({http.Client? client}) : _client = client ?? http.Client();

  /// Downloads an APK from [url], verifies [expectedSha256] if provided,
  /// and emits progress on [onProgress]. Supports HTTP redirects (e.g. 302/301).
  Future<File> downloadAndVerifyApk({
    required String url,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    if (expectedSha256 == null ||
        !RegExp(r'^[A-Fa-f0-9]{64}    int redirects = 0;

    while (true) {
      final request = http.Request('GET', currentUri);
      request.followRedirects = false; // Manually handle redirect loop safely
      response = await _client.send(request);

      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        currentUri = currentUri.resolve(location);
        if (currentUri.scheme != 'https') {
          throw HttpException('APK download redirects must remain on HTTPS.');
        }
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

        sink.add(chunk);
        receivedBytes += chunk.length;

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

      // The expected checksum is mandatory and validated before download.
      final expected = expectedSha256!.trim().toLowerCase();
      if (actualSha256 != expected) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        throw ChecksumMismatchException(expected: expected, actual: actualSha256);
      }

      return targetFile;
    } catch (e) {
      try {
        await sink.close();
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
).hasMatch(expectedSha256.trim())) {
      throw StateError('A valid SHA-256 checksum is required before installing an APK.');
    }

    Uri currentUri = Uri.parse(url);
    if (currentUri.scheme != 'https') {
      throw HttpException('APK downloads must use HTTPS.');
    }
    http.StreamedResponse response;
    int redirects = 0;

    while (true) {
      final request = http.Request('GET', currentUri);
      request.followRedirects = false; // Manually handle redirect loop safely
      response = await _client.send(request);

      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        currentUri = Uri.parse(location);
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

        sink.add(chunk);
        receivedBytes += chunk.length;

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

      // Verify SHA-256 if expected hash is provided
      if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
        final expected = expectedSha256.trim().toLowerCase();
        if (actualSha256 != expected) {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          throw ChecksumMismatchException(expected: expected, actual: actualSha256);
        }
      }

      return targetFile;
    } catch (e) {
      try {
        await sink.close();
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
