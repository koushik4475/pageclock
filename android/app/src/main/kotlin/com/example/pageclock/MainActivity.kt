package com.example.pageclock

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val installerChannel = "com.example.pageclock/apk_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installerChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_APK_PATH", "APK path is missing.", null)
                    return@setMethodCallHandler
                }

                val apk = File(path)
                if (!apk.isFile || !apk.canRead()) {
                    result.error("APK_NOT_READABLE", "The verified APK cannot be read.", null)
                    return@setMethodCallHandler
                }

                try {
                    val apkUri: Uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        apk
                    )
                    val installIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(apkUri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    // Launch directly instead of preflighting resolveActivity().
                    // Android 11+ package-visibility filtering can make resolver
                    // queries return null even when startActivity can resolve it.
                    startActivity(installIntent)
                    result.success(true)
                } catch (error: ActivityNotFoundException) {
                    result.error("NO_PACKAGE_INSTALLER", "Android Package Installer is unavailable.", error.message)
                } catch (error: Exception) {
                    result.error("INSTALLER_LAUNCH_FAILED", error.message ?: "Could not launch Android Package Installer.", null)
                }
            }
    }
}
