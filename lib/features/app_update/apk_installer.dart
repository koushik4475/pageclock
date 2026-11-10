import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ApkShareResult {
  final bool opened;
  final String message;
  const ApkShareResult({required this.opened, required this.message});
}

class ApkInstaller {
  /// Shares the verified APK instead of asking PageClock to install unknown apps.
  static Future<ApkShareResult> shareVerifiedApk(File apkFile) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const ApkShareResult(opened: false, message: 'APK updates can only be shared from Android.');
    }
    if (!await apkFile.exists()) {
      return const ApkShareResult(opened: false, message: 'The verified APK is no longer available. Download it again.');
    }
    try {
      await Share.shareXFiles(
        [XFile(apkFile.path, mimeType: 'application/vnd.android.package-archive')],
        subject: 'PageClock Android update',
        text: 'This APK passed PageClock SHA-256 verification. Save it to Downloads using a trusted file manager, then open it from Downloads to install. Android will ask you to confirm the installation.',
      );
      return const ApkShareResult(
        opened: true,
        message: 'The Android share sheet was opened. Choose a trusted file manager or save-to-files option, save the verified APK in Downloads, then open it from Downloads to install. Android will show its own confirmation. PageClock does not need permission to install unknown apps.',
      );
    } catch (e) {
      return ApkShareResult(opened: false, message: 'Could not share the verified APK: $e');
    }
  }
}
