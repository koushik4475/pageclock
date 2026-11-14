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

    test('keeps the original ten IDs and adds six classic face IDs', () {
      const originalIds = <String>[
        'mac_flip', 'nixie', 'dot_matrix', 'lcd', 'neon',
        'terminal', 'gradient', 'analog', 'editorial', 'binary',
      ];
      expect(ClockFaceView.styleIds, hasLength(16));
      expect(ClockFaceView.styleIds.take(10), originalIds);
      expect(ClockFaceView.styleIds.toSet(), hasLength(16));
      expect(ClockFaceView.classicStyleIds, hasLength(6));
      expect(ClockFaceView.categoryIds['Classic'], containsAll(ClockFaceView.classicStyleIds));
      expect(ClockFaceView.categoryFor('classic_braun'), 'Classic');
      expect(ClockFaceView.categoryFor('mac_flip'), 'Digital');
      expect(ClockFaceView.labelFor('classic_braun'), 'Braun Minimal');
      expect(ClockFaceView.labelFor('classic_railway'), 'Railway Classic');
      expect(ClockFaceView.labelFor('classic_roman'), 'Roman Heritage');
      expect(ClockFaceView.labelFor('classic_regulator'), 'Regulator');
      expect(ClockFaceView.labelFor('classic_classroom'), 'Classroom Clear');
      expect(ClockFaceView.labelFor('classic_night_lume'), 'Night Lume');
      expect(ClockFaceView.labelFor('unknown'), 'macOS Flip');
    });
  });

  testWidgets('all sixteen clock faces render without layout exceptions', (tester) async {
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
      expect(tester.takeException(), isNull, reason: 'Clock face ' + style + ' should render');
    }
  });

  testWidgets('classic faces fit compact iPhones, landscape phones and iPads', (tester) async {
    const viewports = <Size>[
      Size(320, 568),   // compact iPhone portrait
      Size(390, 844),   // standard iPhone portrait
      Size(430, 932),   // large iPhone portrait
      Size(667, 375),   // small phone landscape
      Size(844, 390),   // modern phone landscape
      Size(820, 1180),  // iPad portrait
      Size(1180, 820),  // iPad landscape
    ];

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in viewports) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      for (final style in ClockFaceView.classicStyleIds) {
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            );
          },
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: viewport.width - 40,
                child: ClockFaceView(
                  styleId: style,
                  leftText: '25',
                  rightText: '43',
                  secondsText: '08',
                  badge: 'FOCUS',
                  accentColor: ClockFaceView.colorFromHex('#F5A623'),
                  showSeconds: false,
                  showDate: false,
                  date: DateTime(2026, 11, 14, 9, 41, 8),
                  isDark: true,
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: style + ' should fit viewport ' + viewport.width.toString() + 'x' + viewport.height.toString() + ' with enlarged text',
        );
      }
    }
  });
}
