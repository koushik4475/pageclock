import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'update_model.dart';
import 'apk_downloader.dart';
import 'version_comparator.dart';

class UpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final AppReleaseInfo? releaseInfo;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseInfo,
    this.errorMessage,
  });
}

class AppUpdateService {
  final http.Client _client;
  final String repoOwner;
  final String repoName;

  static const Duration cacheDuration = Duration(hours: 6);
  static DateTime? _lastCheckTime;
  static UpdateCheckResult? _cachedResult;

  AppUpdateService({
    http.Client? client,
    this.repoOwner = 'koushik4475',
    this.repoName = 'pageclock',
  }) : _client = client ?? http.Client();

  /// Checks for available updates from GitHub Releases.
  Future<UpdateCheckResult> checkForUpdate({bool force = false}) async {
    // Check in-memory 6-hour cache if not forced
    if (!force && _cachedResult != null && _lastCheckTime != null) {
      if (DateTime.now().difference(_lastCheckTime!) < cacheDuration) {
        return _cachedResult!;
      }
    }

    String currentVersion = '1.0.0';
    int currentBuild = 1;

    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      currentBuild = int.tryParse(info.buildNumber) ?? 1;
    } catch (e) {
      debugPrint('[AppUpdateService] Could not read PackageInfo, using fallback: $e');
    }

    final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'PageClock-Productivity-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          errorMessage: 'No releases found yet.',
        );
        _cache(res);
        return res;
      }

      if (response.statusCode == 403) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          errorMessage: 'GitHub API rate limit exceeded. Please try again later.',
        );
      }

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          errorMessage: 'Failed to check updates (HTTP ${response.statusCode})',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['draft'] == true || data['prerelease'] == true) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          latestVersion: currentVersion,
        );
        _cache(res);
        return res;
      }

      final release = AppReleaseInfo.fromJson(data);

      // Fetch an older-release checksum sidecar only from trusted GitHub
      // asset hosts, validating every redirect before following it.
      String? sha256 = release.expectedSha256;
      if (sha256 == null && release.sha256DownloadUrl != null) {
        try {
          sha256 = await _fetchTrustedSha256(release.sha256DownloadUrl!);
        } catch (_) {}
      }

      if (!_isValidSha256(sha256)) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion + '+' + currentBuild.toString(),
          latestVersion: release.tagName,
          errorMessage: 'Update blocked: a valid SHA-256 checksum is unavailable.',
        );
      }
      final enrichedRelease = AppReleaseInfo(
        tagName: release.tagName,
        versionName: release.versionName,
        buildNumber: release.buildNumber,
        releaseNotes: release.releaseNotes,
        apkDownloadUrl: release.apkDownloadUrl,
        sha256DownloadUrl: release.sha256DownloadUrl,
        expectedSha256: sha256,
        apkSize: release.apkSize,
        publishedAt: release.publishedAt,
      );

      final isNewer = VersionComparator.isNewer(
        enrichedRelease.versionName,
        currentVersion,
        remoteBuild: enrichedRelease.buildNumber,
        currentBuild: currentBuild,
      );

      final result = UpdateCheckResult(
        hasUpdate: isNewer && enrichedRelease.apkDownloadUrl.isNotEmpty,
        currentVersion: '$currentVersion+$currentBuild',
        latestVersion: enrichedRelease.tagName,
        releaseInfo: enrichedRelease,
      );

      _cache(result);
      return result;
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        errorMessage: 'Network error while checking updates: $e',
      );
    }
  }

  Future<String?> _fetchTrustedSha256(String url) async {
    final parsedUri = Uri.tryParse(url);
    if (parsedUri == null ||
        !ApkDownloader.isTrustedDownloadUri(parsedUri)) {
      return null;
    }
    var currentUri = parsedUri;

    var redirects = 0;
    while (true) {
      final request = http.Request('GET', currentUri)..followRedirects = false;
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        final redirectedUri = currentUri.resolve(location);
        await response.stream.drain<void>();
        if (!ApkDownloader.isTrustedDownloadUri(redirectedUri)) {
          return null;
        }
        currentUri = redirectedUri;
        redirects++;
        if (redirects > 8) return null;
        continue;
      }

      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        return null;
      }

      final declaredLength =
          int.tryParse(response.headers['content-length'] ?? '');
      if (declaredLength != null && declaredLength > 4096) {
        await response.stream.drain<void>();
        return null;
      }

      final body = StringBuffer();
      var receivedBytes = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 5),
      )) {
        receivedBytes += chunk.length;
        if (receivedBytes > 4096) return null;
        body.write(utf8.decode(chunk, allowMalformed: true));
      }
      return RegExp(r'[A-Fa-f0-9]{64}')
          .firstMatch(body.toString())
          ?.group(0);
    }
  }

  static void _cache(UpdateCheckResult result) {
    _cachedResult = result;
    _lastCheckTime = DateTime.now();
  }

  static void clearCache() {
    _cachedResult = null;
    _lastCheckTime = null;
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
