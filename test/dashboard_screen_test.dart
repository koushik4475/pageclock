import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/core/theme/theme_provider.dart';
import 'package:pageclock/features/dashboard/dashboard_screen.dart';
import 'package:pageclock/features/dashboard/reading_desk_artwork.dart';

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
              onToggleTheme: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recent sessions'), findsOneWidget);
        expect(find.text('Your weekly rhythm starts here'), findsOneWidget);
        expect(
          find.byType(ReadingDeskArtwork),
          viewport.width >= 600 ? findsOneWidget : findsNothing,
          reason: 'Reading artwork should appear only when the hero has room',
        );
        expect(find.text('Your reading journey starts here'), findsOneWidget);
        expect(find.text('Start your first session'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Light dashboard should fit ${viewport.width}x${viewport.height}');
      }
    });

    testWidgets('reading desk scene paints in both themes at hero size', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1;

      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appThemeDataFor(
              isDark ? AppThemeId.defaultDark : AppThemeId.pageClockClassic,
            ),
            home: Scaffold(
              body: Center(
                child: ReadingDeskArtwork(
                  width: 248,
                  height: 186,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReadingDeskArtwork), findsOneWidget);
        expect(tester.takeException(), isNull);
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
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: appThemeDataFor(themeId),
            home: DashboardScreen(
              sessions: [session],
              settings: const AppSettings(),
              stopwatchState: const StopwatchState(status: StopwatchStatus.idle),
              onNavigate: (_) {},
              onToggleTheme: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Deep reading'), findsOneWidget);
        expect(find.text('Recent sessions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('quick actions and profile navigate to real PageClock sections', (tester) async {
      var selectedIndex = -1;
      var profileOpened = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: appThemeDataFor(AppThemeId.pageClockClassic),
          home: DashboardScreen(
            sessions: const [],
            settings: const AppSettings(),
            stopwatchState: const StopwatchState(status: StopwatchStatus.idle),
            onNavigate: (index) => selectedIndex = index,
            onToggleTheme: () {},
            onOpenProfile: () => profileOpened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final focusAction = find.text('Focus timer');
      await tester.ensureVisible(focusAction);
      await tester.tap(focusAction);
      expect(selectedIndex, 1);

      final calendarAction = find.text('Calendar');
      await tester.ensureVisible(calendarAction);
      await tester.tap(calendarAction);
      expect(selectedIndex, 2);

      final reportsAction = find.text('Reports');
      await tester.ensureVisible(reportsAction);
      await tester.tap(reportsAction);
      expect(selectedIndex, 3);

      final settingsButton = find.byTooltip('Open account menu');
      await tester.ensureVisible(settingsButton);
      await tester.pumpAndSettle();
      await tester.tap(settingsButton);
      expect(profileOpened, isTrue);
      expect(selectedIndex, 3, reason: 'Opening the profile must not navigate to Settings');
    });
    testWidgets('theme switch exposes the paired PageClock appearance', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      for (final themeId in [
        AppThemeId.defaultDark,
        AppThemeId.pageClockClassic,
      ]) {
        var toggled = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: appThemeDataFor(themeId),
            home: DashboardScreen(
              sessions: const [],
              settings: const AppSettings(),
              stopwatchState: const StopwatchState(status: StopwatchStatus.idle),
              onNavigate: (_) {},
              onToggleTheme: () => toggled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tooltip = themeId == AppThemeId.defaultDark
            ? 'Switch to PageClock Classic light mode'
            : 'Switch to Night Focus dark mode';
        final themeButton = find.byTooltip(tooltip);
        expect(themeButton, findsOneWidget);
        await tester.tap(themeButton);
        expect(toggled, isTrue);
      }
    });

  });
}
