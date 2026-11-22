import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';

class CompletionSoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(AppSettings settings) async {
    if (!settings.pomodoroSoundEnabled ||
        settings.completionSoundTheme == 'silent') return;
    try {
      if (settings.completionSoundTheme == 'custom' &&
          settings.completionSoundCustomPath.isNotEmpty) {
        await _player.stop();
        await _player.play(DeviceFileSource(settings.completionSoundCustomPath));
      } else if (settings.completionSoundTheme == 'calm') {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      // Timer completion should not be interrupted by an audio failure.
    }
  }

  static Future<void> preview(AppSettings settings) async {
    if (settings.completionSoundTheme == 'silent') return;
    try {
      if (settings.completionSoundTheme == 'custom' &&
          settings.completionSoundCustomPath.isNotEmpty) {
        await _player.stop();
        await _player.play(DeviceFileSource(settings.completionSoundCustomPath));
      } else if (settings.completionSoundTheme == 'calm') {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      rethrow;
    }
  }

  static Future<void> stopPreview() => _player.stop();
}
