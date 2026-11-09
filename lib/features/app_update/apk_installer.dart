import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class ApkInstaller {
  /// Prompts the Android system Package Installer to install [apkFile].
  static Future<OpenResult> installApk(File apkFile) async {
    if (kIsWeb || !Platform.isAndroid) {
      return OpenResult(
        type: ResultType.error,
        message: 'APK installation is only supported on Android devices.',
      );
    }

    try {
      // On Android 8.0+ (API 26+), verify install unknown apps permission
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final requestStatus = await Permission.requestInstallPackages.request();
        if (!requestStatus.isGranted) {
          return OpenResult(
            type: ResultType.permissionDenied,
            message: 'Android blocked APK installation. Open Settings → Apps → Special app access → Install unknown apps → PageClock, allow it, then retry.',
          );
        }
      }

      // Launch standard Android Package Installer via FileProvider
      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        return OpenResult(
          type: ResultType.done,
          message: 'Android installer opened. Confirm Install in the system prompt; reopen PageClock afterwards to verify the installed version.',
        );
      }
      return OpenResult(
        type: result.type,
        message: result.message.isNotEmpty
            ? result.message
            : 'Could not open Android Package Installer. Check Install unknown apps permission and try again.',
      );
    } catch (e) {
      return OpenResult(
        type: ResultType.error,
        message: 'Failed to launch installer: $e',
      );
    }
  }
}
