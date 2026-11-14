import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ApkInstallResult {
  final bool success;
  final String message;
  const ApkInstallResult({required this.success, required this.message});
}

class ApkInstaller {
  static const MethodChannel _installerChannel =
      MethodChannel('com.example.pageclock/apk_installer');

  /// Launches Android's Package Installer directly using a FileProvider URI.
  /// Sharing remains a separate, explicitly selected user action.
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

      await _installerChannel.invokeMethod<bool>(
        'installApk',
        <String, Object>{'path': apkFile.absolute.path},
      );
      return const ApkInstallResult(
        success: true,
        message: 'Android Package Installer opened. Confirm Install in the system prompt to complete the update.',
      );
    } on PlatformException catch (error) {
      return ApkInstallResult(
        success: false,
        message: error.message ?? 'Could not open Android Package Installer.',
      );
    } catch (error) {
      return ApkInstallResult(
        success: false,
        message: 'Failed to launch installer: $error',
      );
    }
  }

  /// Fallback option only when the user explicitly taps Share APK.
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
      return const ApkInstallResult(success: true, message: 'Android share sheet opened.');
    } catch (error) {
      return ApkInstallResult(success: false, message: 'Could not share the verified APK: $error');
    }
  }
}
