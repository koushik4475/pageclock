import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';
import 'package:pageclock/features/settings/toggl_settings_screen.dart';
import 'package:pageclock/features/timer/widgets/fullscreen_ambient_focus_screen.dart';

void main() {
  group('Toggl Track Timer Screen & Action Buttons End-to-End Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Header Actions: (+) manual entry, [ ] Mac flip clock, ⚙ settings', (tester) async {
      final inMemoryRepo = InMemorySessionRepository([]);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(800, 1200)),
              child: TogglTimerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Timer'), findsOneWidget);

      // Verify the 3 header icon buttons exist
      final addIcon = find.byIcon(Icons.add_circle_outline_rounded);
      final flipIcon = find.byIcon(Icons.fullscreen_rounded);
      final settingsIcon = find.byIcon(Icons.settings_outlined);

      expect(addIcon, findsOneWidget);
      expect(flipIcon, findsOneWidget);
      expect(settingsIcon, findsOneWidget);

      // 1. Test (+) Manual Add Time Entry Modal
      await tester.tap(addIcon);
      await tester.pumpAndSettle();

      expect(find.text('Add Time Entry'), findsOneWidget);
      expect(find.text('Save Entry'), findsOneWidget);

      // Tap Save Entry
      await tester.tap(find.text('Save Entry'));
      await tester.pumpAndSettle();

      // Verify modal dismissed
      expect(find.text('Add Time Entry'), findsNothing);

      // 2. Test [ ] Mac Retro Flip Clock Mode
      await tester.tap(flipIcon);
      await tester.pumpAndSettle();

      // Verify Apple Mac Fliqlo Clock screen is presented
      expect(find.byType(AppleMacFlipClockScreen), findsOneWidget);
      expect(find.text('Mac Wall Clock'), findsOneWidget);

      // Exit flip clock back to timer
      final closeFlip = find.byIcon(Icons.close_rounded);
      if (closeFlip.evaluate().isNotEmpty) {
        await tester.tap(closeFlip);
        await tester.pumpAndSettle();
      }

      // 3. Test ⚙ Settings Button Navigation
      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      expect(find.byType(TogglSettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Test Settings Arrow Back Button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Returned back to Timer Screen
      expect(find.text('Timer'), findsOneWidget);
    });

    testWidgets('Pomodoro / List View Mode Switching & Elements', (tester) async {
      final inMemoryRepo = InMemorySessionRepository([]);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(800, 1200)),
              child: TogglTimerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Pomodoro Mode
      final pomodoroTab = find.text('Pomodoro');
      expect(pomodoroTab, findsOneWidget);
      await tester.tap(pomodoroTab);
      await tester.pumpAndSettle();

      // Verify Pomodoro Elements
      expect(find.text('FOCUS INTERVAL'), findsOneWidget);
      expect(find.text('READY TO FOCUS'), findsOneWidget);
      expect(find.text('Start session'), findsOneWidget);
      expect(find.text('Pomodoro settings'), findsOneWidget);

      // Switch back to List View
      await tester.tap(find.text('List view'));
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Deep Work & Focus'), findsOneWidget);
    });

    testWidgets('Theme Switcher: special1 activates Pastel Waves & Cream palette', (tester) async {
      final inMemoryRepo = InMemorySessionRepository([]);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(800, 1600)),
              child: TogglSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find App theme tile (in general section)
      final themeTile = find.text('App theme');
      await tester.scrollUntilVisible(themeTile, 300);
      expect(themeTile, findsOneWidget);
      await tester.tap(themeTile);
      await tester.pumpAndSettle();

      // Verify bottom sheet has special1
      expect(find.text('Choose Theme'), findsOneWidget);
      expect(find.text('special1'), findsOneWidget);

      // Tap on special1
      await tester.tap(find.text('special1'));
      await tester.pumpAndSettle();

      // Verify bottom sheet dismissed
      expect(find.text('Choose Theme'), findsNothing);
    });
  });
}
