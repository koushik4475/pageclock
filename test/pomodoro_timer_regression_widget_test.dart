import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pageclock/core/engine/pomodoro_break_snapshot.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<({SharedPreferences preferences, InMemorySessionRepository repository})>
      mountTimer(WidgetTester tester) async {
    final preferences = await SharedPreferences.getInstance();
    final repository = InMemorySessionRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();
    return (preferences: preferences, repository: repository);
  }

  testWidgets('custom focus duration drives the visible countdown', (tester) async {
    await mountTimer(tester);

    await tester.tap(find.text('Set custom focus time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '45');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('45:00'), findsOneWidget);
    expect(find.text('SESSION ACTIVE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skipping a restored long break starts the next focus session',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    const snapshot = PomodoroBreakSnapshot(
      isLongBreak: true,
      durationMs: 900000,
      remainingMs: 600000,
      isRunning: false,
      deadlineUtcMs: null,
    );
    await preferences.setString(
      'pageclock_pomodoro_break_state_v1',
      snapshot.toJson(),
    );
    final repository = InMemorySessionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();

    expect(find.text('LONG BREAK'), findsOneWidget);
    expect(find.text('Skip long break'), findsOneWidget);

    await tester.tap(find.text('Skip long break'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LONG BREAK'), findsNothing);
    expect(find.text('SESSION ACTIVE'), findsOneWidget);
    expect(await repository.getActiveSession(), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('long-break skip remains available in List view', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    const snapshot = PomodoroBreakSnapshot(
      isLongBreak: true,
      durationMs: 900000,
      remainingMs: 600000,
      isRunning: false,
      deadlineUtcMs: null,
    );
    await preferences.setString(
      'pageclock_pomodoro_break_state_v1',
      snapshot.toJson(),
    );
    final repository = InMemorySessionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LONG BREAK'), findsOneWidget);
    expect(find.text('Skip long break'), findsOneWidget);
    await tester.tap(find.text('Skip long break'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LONG BREAK'), findsNothing);
    expect(await repository.getActiveSession(), isNotNull);
    expect(
      preferences.getInt('pageclock_pomodoro_focus_target_ms_v1'),
      25 * 60000,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Pomodoro completion continues after switching to List view',
      (tester) async {
    await mountTimer(tester);

    await tester.tap(find.text('Set custom focus time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('List view'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('SHORT BREAK'), findsOneWidget);
    expect(find.text('Skip short break'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

}
