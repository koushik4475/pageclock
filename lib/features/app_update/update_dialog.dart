import 'dart:io';
import 'package:flutter/material.dart';
import 'apk_downloader.dart';
import 'apk_installer.dart';
import 'update_model.dart';

class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo releaseInfo;

  const UpdateDialog({super.key, required this.releaseInfo});

  static Future<void> show(BuildContext context, AppReleaseInfo releaseInfo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(releaseInfo: releaseInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;
  String? _infoMessage;
  File? _verifiedApkFile;
  CancellationToken? _cancelToken;

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Starting download...';
      _errorMessage = null;
      _infoMessage = null;
      _verifiedApkFile = null;
      _cancelToken = CancellationToken();
    });

    final downloader = ApkDownloader();

    try {
      final file = await downloader.downloadAndVerifyApk(
        url: widget.releaseInfo.apkDownloadUrl,
        expectedSha256: widget.releaseInfo.expectedSha256,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progress = p.progress;
              final recMb = (p.receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              final totMb = (p.totalBytes / (1024 * 1024)).toStringAsFixed(1);
              _statusText = 'Downloading: $recMb MB / $totMb MB (${(p.progress * 100).toInt()}%)';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _verifiedApkFile = file;
        _statusText = 'SHA-256 verification successful.';
      });
      await _shareVerifiedApk();
    } on ChecksumMismatchException {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Security Warning: SHA-256 Checksum Mismatch!\nThe downloaded APK was deleted and will not be shared or installed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Update could not be installed: $e';
        });
      }
    }
  }

  Future<void> _shareVerifiedApk() async {
    final file = _verifiedApkFile;
    if (file == null) return;
    setState(() {
      _errorMessage = null;
      _infoMessage = 'Opening Android share sheet...';
    });
    final result = await ApkInstaller.shareVerifiedApk(file);
    if (!mounted) return;
    setState(() {
      _infoMessage = result.opened ? result.message : null;
      _errorMessage = result.opened ? null : result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = (widget.releaseInfo.apkSize / (1024 * 1024)).toStringAsFixed(1);

    return Dialog(
      backgroundColor: const Color(0xFF111417),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF34D399),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.releaseInfo.tagName} • ${sizeMb != "0.0" ? "$sizeMb MB" : "Android APK"}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              "What's New:",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.releaseInfo.releaseNotes.trim(),
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (widget.releaseInfo.expectedSha256 != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF34D399)),
                  const SizedBox(width: 6),
                  Text(
                    'SHA-256 Checksum Verified Release',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 10),
              Text(
                _statusText,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
            if (_infoMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFF34D399), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _infoMessage!,
                        style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading) ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _verifiedApkFile == null ? _startDownload : _shareVerifiedApk,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _verifiedApkFile == null ? 'Download Update' : 'Share Verified APK',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      _cancelToken?.cancel();
                      setState(() {
                        _isDownloading = false;
                        _statusText = 'Cancelled';
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Cancel Download'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
