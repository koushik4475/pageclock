import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';
class CompletionSoundService {
 static final AudioPlayer _player=AudioPlayer();
 static const _assets={'calm':'assets/audio/calm.wav','rain':'assets/audio/rain.wav','forest':'assets/audio/forest.wav','ocean':'assets/audio/ocean.wav','bell':'assets/audio/bell.wav','classic':'assets/audio/classic.wav'};
 static Future<void> _playCustom(AppSettings s) async {final d=s.completionSoundCustomData;if(d.isNotEmpty){await _player.stop();await _player.play(BytesSource(Uint8List.fromList(base64Decode(d))));return;}final p=s.completionSoundCustomPath;if(p.isNotEmpty){await _player.stop();await _player.play(DeviceFileSource(p));return;}throw StateError('No custom audio selected');}
 static Future<void> play(AppSettings s) async {if(!s.pomodoroSoundEnabled||s.completionSoundTheme=='silent')return;try{await preview(s);}catch(_){}}
 static Future<void> preview(AppSettings s) async {final theme=s.completionSoundTheme;if(theme=='silent')return;await _player.stop();if(theme=='custom'){await _playCustom(s);return;}final asset=_assets[theme];if(asset==null)throw StateError('Unknown audio theme');await _player.play(AssetSource(asset));}
 static Future<void> stopPreview()=>_player.stop();
}
