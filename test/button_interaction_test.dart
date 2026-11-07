import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';
import 'package:pageclock/features/settings/toggl_settings_screen.dart';
import 'package:pageclock/features/timer/widgets/fullscreen_ambient_focus_screen.dart';

void main() {
  group('Toggl Track Timer Screen & Action Buttons End-to-End Test', () {
    testWidgets('Header Actions: (+) manual entry, [ ] Mac flip clock, ⚙ settings', (tester) async {
      final inMemoryRepo = InMemorySessionRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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

      // Exit flip clock
      final backOrExit = find.byIcon(Icons.fullscreen_exit_rounded);
      if (backOrExit.evaluate().isNotEmpty) {
        await tester.tap(backOrExit);
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

    testWidgets('Pomodoro / List View Mode Switching & Timer Play/Pause', (tester) async {
      final inMemoryRepo = InMemorySessionRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
      expect(find.text('READY TO FOCUS'), findsOneWidget);
      expect(find.text('Start session'), findsOneWidget);

      // Tap Start Session
      await tester.tap(find.text('Start session'));
      await tester.pump();

      expect(find.text('Pause session'), findsOneWidget);

      // Switch back to List View
      await tester.tap(find.text('List view'));
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Deep Work & Focus'), findsOneWidget);
    });
  });
}
