import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';

class CompletionSoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(AppSettings settings) async {
    if (!settings.pomodoroSoundEnabled ||
        settings.completionSoundTheme == 'silent') {
      return;
    }
    try {
      if (settings.completionSoundTheme == 'custom' &&
          settings.completionSoundCustomPath.isNotEmpty) {
        await _player.stop();
        await _player.play(DeviceFileSource(settings.completionSoundCustomPath));
      } else if (settings.completionSoundTheme == 'calm') {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      // Keep timer completion resilient when platform audio is unavailable.
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
      // Surface playback failure through the UI's preview feedback.
      rethrow;
    }
  }

  static Future<void> stopPreview() => _player.stop();
}
