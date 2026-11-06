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

    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final downloadUrl = asset['browser_download_url'] as String? ?? '';
      if (name.endsWith('.apk')) {
        apkUrl = downloadUrl;
        size = asset['size'] as int? ?? 0;
      } else if (name.endsWith('.sha256') || name.contains('sha256')) {
        sha256Url = downloadUrl;
      }
    }

    // Try extracting SHA-256 embedded in release body if not found as asset
    String? inlineSha256;
    final sha256Regex = RegExp(r'[A-Fa-f0-9]{64}');
    final match = sha256Regex.firstMatch(body);
    if (match != null) {
      inlineSha256 = match.group(0);
    }

    return AppReleaseInfo(
      tagName: tagName,
      versionName: vName,
      buildNumber: bNum,
      releaseNotes: body,
      apkDownloadUrl: apkUrl,
      sha256DownloadUrl: sha256Url,
      expectedSha256: inlineSha256,
      apkSize: size,
      publishedAt: publishedAt,
    );
  }
}
