import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/timer/widgets/clock_face.dart';

void main() {
  group('Clock Studio settings', () {
    test('defaults to the macOS-inspired flip clock', () {
      const settings = AppSettings();
      expect(settings.clockStyleId, 'mac_flip');
      expect(settings.clockAccentColor, '#F5A623');
      expect(settings.clockShowSeconds, isFalse);
      expect(settings.clockShowDate, isTrue);
    });

    test('persists all clock customization options through JSON', () {
      final settings = const AppSettings().copyWith(
        clockStyleId: 'nixie',
        clockAccentColor: '#FF5C8A',
        clockShowSeconds: true,
        clockShowDate: false,
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.clockStyleId, 'nixie');
      expect(restored.clockAccentColor, '#FF5C8A');
      expect(restored.clockShowSeconds, isTrue);
      expect(restored.clockShowDate, isFalse);
    });

    test('offers ten distinct stable clock face IDs', () {
      expect(ClockFaceView.styleIds, hasLength(10));
      expect(ClockFaceView.styleIds.toSet(), hasLength(10));
      expect(ClockFaceView.labelFor('mac_flip'), 'macOS Flip');
      expect(ClockFaceView.labelFor('unknown'), 'macOS Flip');
    });
  });
}
