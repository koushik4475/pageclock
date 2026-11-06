class VersionComparator {
  /// Returns true if [remoteVersion] is strictly newer than [currentVersion].
  ///
  /// Examples:
  /// - `isNewer('1.0.1', '1.0.0')` -> `true`
  /// - `isNewer('1.0.0+2', '1.0.0+1')` -> `true`
  /// - `isNewer('1.0.0', '1.0.0')` -> `false`
  /// - `isNewer('1.0.0', '1.0.1')` -> `false`
  static bool isNewer(
    String remoteVersion,
    String currentVersion, {
    int? remoteBuild,
    int? currentBuild,
  }) {
    final cleanRemote = _clean(remoteVersion);
    final cleanCurrent = _clean(currentVersion);

    final remoteParts = cleanRemote.versionName.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.versionName.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;
    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }

    // Version names are identical, check build numbers
    final rBuild = remoteBuild ?? cleanRemote.buildNumber ?? 0;
    final cBuild = currentBuild ?? cleanCurrent.buildNumber ?? 0;

    return rBuild > cBuild;
  }

  static ({String versionName, int? buildNumber}) _clean(String version) {
    var v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    int? build;
    if (v.contains('+')) {
      final parts = v.split('+');
      v = parts[0];
      build = int.tryParse(parts[1]);
    }
    return (versionName: v, buildNumber: build);
  }
}
