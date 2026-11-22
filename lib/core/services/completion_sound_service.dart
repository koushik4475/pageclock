import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';
class CompletionSoundService {
 static final AudioPlayer _player=AudioPlayer();
 static Future<void> play(AppSettings s) async { if(!s.pomodoroSoundEnabled||s.completionSoundTheme=='silent')return; try { if(s.completionSoundTheme=='custom'&&s.completionSoundCustomPath.isNotEmpty){await _player.stop();await _player.play(DeviceFileSource(s.completionSoundCustomPath));}else{await SystemSound.play(SystemSoundType.alert);} }catch(_){try{await SystemSound.play(SystemSoundType.alert);}catch(_){}} }
 static Future<void> preview(AppSettings s) async {if(s.completionSoundTheme=='silent')return;if(s.completionSoundTheme=='custom'&&s.completionSoundCustomPath.isNotEmpty){await _player.stop();await _player.play(DeviceFileSource(s.completionSoundCustomPath));}else{await SystemSound.play(SystemSoundType.alert);}}
 static Future<void> stopPreview()=>_player.stop();
}