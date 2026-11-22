import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/settings/app_settings.dart';
void main() { test('custom audio bytes persist through settings JSON', () { final bytes=<int>[0,1,2,3,255]; final settings=const AppSettings().copyWith(completionSoundTheme:'custom',completionSoundCustomData:base64Encode(bytes),completionSoundCustomPath:''); final restored=AppSettings.fromJson(settings.toJson()); expect(restored.completionSoundTheme,'custom'); expect(base64Decode(restored.completionSoundCustomData),bytes); expect(restored.completionSoundCustomPath,isEmpty); }); }
