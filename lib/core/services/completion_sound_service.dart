import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';
class CompletionSoundService {
  static final AudioPlayer _player = AudioPlayer();
  static Future<void> _playCustom(AppSettings settings) async {
    final encoded = settings.completionSoundCustomData;
    if (encoded.isNotEmpty) { await _player.stop(); await _player.play(BytesSource(Uint8List.fromList(base64Decode(encoded)))); return; }
    final path = settings.completionSoundCustomPath;
    if (path.isNotEmpty) { await _player.stop(); await _player.play(DeviceFileSource(path)); return; }
    throw StateError('No custom audio data or file path is available');
  }
  static Future<void> play(AppSettings settings) async {
    if (!settings.pomodoroSoundEnabled || settings.completionSoundTheme == 'silent') return;
    try { if (settings.completionSoundTheme == 'custom') { await _playCustom(settings); } else if (settings.completionSoundTheme == 'calm') { await SystemSound.play(SystemSoundType.alert); } } catch (_) { }
  }
  static Future<void> preview(AppSettings settings) async {
    if (settings.completionSoundTheme == 'silent') return;
    try { if (settings.completionSoundTheme == 'custom') { await _playCustom(settings); } else if (settings.completionSoundTheme == 'calm') { await SystemSound.play(SystemSoundType.alert); } } catch (_) { rethrow; }
  }
  static Future<void> stopPreview() => _player.stop();
}
