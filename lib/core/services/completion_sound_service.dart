import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../settings/app_settings.dart';

class CompletionSoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _webPlaybackPrepared = false;

  /// Starts a muted preview during a real user gesture so web browsers can
  /// authorize later timer-completion playback outside the gesture callback.
  static Future<void> prepareFromUserGesture() async {
    if (!kIsWeb || _webPlaybackPrepared) return;
    try {
      await _player.play(
        AssetSource('audio/completion_preview.wav'),
        volume: 0,
      );
      await _player.stop();
      _webPlaybackPrepared = true;
    } catch (error, stackTrace) {
      debugPrint('[CompletionSoundService] Web audio preparation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static const _assets = {
    'calm': 'audio/calm.wav',
    'rain': 'audio/rain.wav',
    'forest': 'audio/forest.wav',
    'ocean': 'audio/ocean.wav',
    'bell': 'audio/bell.wav',
    'classic': 'audio/classic.wav',
  };

  static Future<void> _playCustom(AppSettings settings) async {
    final data = settings.completionSoundCustomData;
    if (data.isNotEmpty) {
      await _player.play(BytesSource(Uint8List.fromList(base64Decode(data))));
      return;
    }
    final path = settings.completionSoundCustomPath;
    if (path.isNotEmpty) {
      await _player.play(DeviceFileSource(path));
      return;
    }
    throw StateError('Custom completion sound has no saved audio data or file path.');
  }

  static Future<void> play(AppSettings settings) async {
    if (!settings.pomodoroSoundEnabled ||
        settings.completionSoundTheme == 'silent') return;
    try {
      await preview(settings);
    } catch (error, stackTrace) {
      debugPrint('[CompletionSoundService] Playback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> preview(AppSettings settings) async {
    final theme = settings.completionSoundTheme;
    if (theme == 'silent') return;
    await _player.stop();
    await _player.setVolume(1.0);
    if (theme == 'custom') {
      await _playCustom(settings);
      return;
    }
    final asset = _assets[theme];
    if (asset == null) throw StateError('Unknown completion sound theme: $theme');
    await _player.play(AssetSource(asset));
  }

  static Future<void> stopPreview() => _player.stop();
}
