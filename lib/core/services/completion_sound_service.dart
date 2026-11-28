import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../settings/app_settings.dart';
import 'browser_completion_audio_stub.dart'
    if (dart.library.js_interop) 'browser_completion_audio.dart' as browser;

class CompletionSoundService {
  static final AudioPlayer _player = AudioPlayer();
  static Future<void> prepareFromUserGesture() async {
    if (!kIsWeb) return;
    try {
      await browser.prepare();
    } catch (error) {
      debugPrint('[CompletionSoundService] Browser audio preparation failed: $error');
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

  static Future<bool> play(AppSettings settings) async {
    if (!settings.pomodoroSoundEnabled ||
        settings.completionSoundTheme == 'silent') {
      return true;
    }
    try {
      await preview(settings);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[CompletionSoundService] Playback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> preview(AppSettings settings) async {
    final theme = settings.completionSoundTheme;
    if (theme == 'silent') return;
    if (kIsWeb) {
      if (theme == 'custom') {
        final data = settings.completionSoundCustomData;
        if (data.isEmpty) throw StateError('Custom audio data is missing.');
        return browser.play('data:application/octet-stream;base64,$data');
      }
      final asset = _assets[theme];
      if (asset == null) throw StateError('Unknown completion sound theme: $theme');
      return browser.play('assets/assets/$asset');
    }
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

  static Future<void> stopPreview() async {
    if (kIsWeb) {
      browser.stop();
    } else {
      await _player.stop();
    }
  }
}
