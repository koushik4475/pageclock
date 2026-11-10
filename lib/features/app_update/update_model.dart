class AppReleaseInfo {
  final String tagName;
  final String versionName;
  final int? buildNumber;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String? sha256DownloadUrl;
  final String? expectedSha256;
  final int apkSize;
  final DateTime publishedAt;

  const AppReleaseInfo({
    required this.tagName,
    required this.versionName,
    this.buildNumber,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    this.sha256DownloadUrl,
    this.expectedSha256,
    required this.apkSize,
    required this.publishedAt,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final body = json['body'] as String? ?? 'No release notes provided.';
    final publishedAt = DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now();

    // Parse version from tag (e.g., "v1.2.0" or "v1.2.0+5")
    String vName = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    int? bNum;
    if (vName.contains('+')) {
      final parts = vName.split('+');
      vName = parts[0];
      bNum = int.tryParse(parts[1]);
    }

    final assets = (json['assets'] as List<dynamic>? ?? []);
    String apkUrl = '';
    int size = 0;
    String? sha256Url;
    String? assetDigest;
    String? apkAssetName;

    // Prefer GitHub's SHA-256 digest for the APK itself. This avoids an
    // unnecessary second HTTP request and cannot accidentally select a hash
    // belonging to a different asset.
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '');
      final lowerName = name.toLowerCase();
      if (lowerName.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String? ?? '';
        size = asset['size'] as int? ?? 0;
        apkAssetName = name;
        final digest = asset['digest'] as String?;
        if (digest != null && digest.toLowerCase().startsWith('sha256:')) {
          assetDigest = digest.substring('sha256:'.length).trim();
        }
      }
    }

    // Fallback for older releases that predate GitHub's asset digest field.
    // Only accept the sidecar checksum whose filename belongs to this APK.
    if (apkAssetName != null) {
      final expectedSidecar = '${apkAssetName.toLowerCase()}.sha256';
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name == expectedSidecar) {
          sha256Url = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    // Older releases may embed a SHA-256 in their release notes.
    String? inlineSha256;
    final sha256Regex = RegExp(r'[A-Fa-f0-9]{64}');
    final match = sha256Regex.firstMatch(body);
    if (match != null) {
      inlineSha256 = match.group(0);
    }

    final expectedSha256 = _normalizeSha256(assetDigest) ??
        _normalizeSha256(inlineSha256);

    return AppReleaseInfo(
      tagName: tagName,
      versionName: vName,
      buildNumber: bNum,
      releaseNotes: body,
      apkDownloadUrl: apkUrl,
      sha256DownloadUrl: sha256Url,
      expectedSha256: expectedSha256,
      apkSize: size,
      publishedAt: publishedAt,
    );
  }
}


String? _normalizeSha256(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toLowerCase();
  if (normalized.length != 64) return null;
  final isHex = normalized.codeUnits.every((unit) =>
      (unit >= 48 && unit <= 57) ||
      (unit >= 97 && unit <= 102));
  return isHex ? normalized : null;
}
