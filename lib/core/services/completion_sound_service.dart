import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../settings/app_settings.dart';

class CompletionSoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _webPlaybackPrepared = false;
  static Future<void>? _webPreparation;

  /// Starts a muted preview during a real user gesture so web browsers can
  /// authorize later timer-completion playback outside the gesture callback.
  /// Concurrent start paths share one preparation attempt because they use
  /// the same AudioPlayer instance.
  static Future<void> prepareFromUserGesture() {
    if (!kIsWeb || _webPlaybackPrepared) return Future<void>.value();
    return _webPreparation ??= _prepareWebPlayback().whenComplete(() {
      _webPreparation = null;
    });
  }

  static Future<void> _prepareWebPlayback() async {
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
