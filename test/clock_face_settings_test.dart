import 'package:flutter/material.dart';
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

    test('old settings payloads retain safe clock defaults', () {
      final restored = AppSettings.fromJson(<String, dynamic>{'themeId': 'default_dark'});
      expect(restored.clockStyleId, 'mac_flip');
      expect(restored.clockShowDate, isTrue);
    });

    test('parses accent colours and falls back safely for invalid values', () {
      expect(ClockFaceView.colorFromHex('#FF5C8A').value, 0xFFFF5C8A);
      expect(ClockFaceView.colorFromHex('invalid').value, 0xFFF5A623);
    });

    test('offers ten distinct stable clock face IDs', () {
      expect(ClockFaceView.styleIds, hasLength(10));
      expect(ClockFaceView.styleIds.toSet(), hasLength(10));
      expect(ClockFaceView.labelFor('mac_flip'), 'macOS Flip');
      expect(ClockFaceView.labelFor('unknown'), 'macOS Flip');
    });
  });

  testWidgets('all ten clock faces render without layout exceptions', (tester) async {
    for (final style in ClockFaceView.styleIds) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: ClockFaceView(
                styleId: style,
                leftText: '09',
                rightText: '41',
                secondsText: '26',
                badge: 'FOCUS',
                accentColor: ClockFaceView.colorFromHex('#F5A623'),
                showSeconds: true,
                showDate: true,
                date: DateTime(2026, 11, 13, 9, 41, 26),
                isDark: true,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Clock face $style should render');
    }
  });
}
