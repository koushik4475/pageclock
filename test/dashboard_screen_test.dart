import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/core/theme/theme_provider.dart';
import 'package:pageclock/features/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Responsive PageClock dashboard', () {
    const viewports = <Size>[
      Size(360, 800),
      Size(390, 844),
      Size(600, 960),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ];

    testWidgets('empty state fits phone, tablet and desktop layouts', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final viewport in viewports) {
        tester.view.physicalSize = viewport;
        await tester.pumpWidget(
          MaterialApp(
            theme: appThemeDataFor(AppThemeId.pageClockClassic),
            home: DashboardScreen(
              sessions: const [],
              settings: const AppSettings(themeId: 'pageclock_classic'),
              stopwatchState: const StopwatchState(status: StopwatchStatus.idle),
              onNavigate: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recent sessions'), findsOneWidget);
        expect(find.text('Your reading journey starts here'), findsOneWidget);
        expect(find.text('Start your first session'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Light dashboard should fit ${viewport.width}x${viewport.height}');
      }
    });

    testWidgets('shows actual recent session data in light and dark modes', (tester) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final session = ReadingSession(
        id: 'dashboard-session',
        startedAtUtc: now - const Duration(minutes: 25).inMilliseconds,
        endedAtUtc: now,
        durationMs: const Duration(minutes: 25).inMilliseconds,
        tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        note: 'Deep reading',
        subjectId: 'Reading',
        createdAt: now,
        updatedAt: now,
      );

      for (final themeId in [AppThemeId.pageClockClassic, AppThemeId.defaultDark]) {
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpWidget(
          MaterialApp(
            theme: appThemeDataFor(themeId),
            home: DashboardScreen(
              sessions: [session],
              settings: const AppSettings(),
              stopwatchState: const StopwatchState(status: StopwatchStatus.idle),
              onNavigate: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Deep reading'), findsOneWidget);
        expect(find.text('Recent sessions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('quick actions navigate to real PageClock sections', (tester) async {
      var selectedIndex = -1;
      await tester.view.setPhysicalSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: appThemeDataFor(AppThemeId.pageClockClassic),
          home: DashboardScreen(
            sessions: const [],
            settings: const AppSettings(),
            stopwatchState: const StopwatchState(status: StopwatchStatus.idle),
            onNavigate: (index) => selectedIndex = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Focus timer'));
      expect(selectedIndex, 1);
      await tester.tap(find.text('Calendar'));
      expect(selectedIndex, 2);
      await tester.tap(find.text('Reports'));
      expect(selectedIndex, 3);
    });
  });
}
