import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ApkInstallResult {
  final bool success;
  final String message;
  const ApkInstallResult({required this.success, required this.message});
}

class ApkInstaller {
  /// Prompts the Android system Package Installer to directly install [apkFile].
  static Future<ApkInstallResult> installApk(File apkFile) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const ApkInstallResult(
        success: false,
        message: 'APK installation is only supported on Android devices.',
      );
    }
    if (!await apkFile.exists()) {
      return const ApkInstallResult(
        success: false,
        message: 'The verified APK is no longer available. Please download it again.',
      );
    }

    try {
      // On Android 8.0+ (API 26+), verify install unknown apps permission
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final requestStatus = await Permission.requestInstallPackages.request();
        if (!requestStatus.isGranted) {
          return const ApkInstallResult(
            success: false,
            message: 'Android requires permission to install updates. Open Settings → Apps → Special app access → Install unknown apps → PageClock, allow it, then tap Install Update.',
          );
        }
      }

      // Launch standard Android Package Installer via FileProvider
      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        return const ApkInstallResult(
          success: true,
          message: 'Android installer opened. Confirm Install in the system prompt to complete the update.',
        );
      }

      return ApkInstallResult(
        success: false,
        message: result.message.isNotEmpty
            ? result.message
            : 'Could not open Android Package Installer. Check Install unknown apps permission and try again.',
      );
    } catch (e) {
      return ApkInstallResult(
        success: false,
        message: 'Failed to launch installer: $e',
      );
    }
  }

  /// Fallback option: Shares the verified APK if the user prefers to save or share it.
  static Future<ApkInstallResult> shareVerifiedApk(File apkFile) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const ApkInstallResult(success: false, message: 'APK updates can only be shared from Android.');
    }
    if (!await apkFile.exists()) {
      return const ApkInstallResult(success: false, message: 'The verified APK is no longer available. Download it again.');
    }
    try {
      await Share.shareXFiles(
        [XFile(apkFile.path, mimeType: 'application/vnd.android.package-archive')],
        subject: 'PageClock Android update',
        text: 'This APK passed PageClock SHA-256 verification. Save it to Downloads or share it.',
      );
      return const ApkInstallResult(
        success: true,
        message: 'Android share sheet opened.',
      );
    } catch (e) {
      return ApkInstallResult(success: false, message: 'Could not share the verified APK: $e');
    }
  }
}
