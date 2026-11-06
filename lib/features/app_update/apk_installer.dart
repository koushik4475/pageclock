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
            message: 'Permission to install unknown packages was denied.',
          );
        }
      }

      // Launch standard Android Package Installer via FileProvider
      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      return result;
    } catch (e) {
      return OpenResult(
        type: ResultType.error,
        message: 'Failed to launch installer: $e',
      );
    }
  }
}
