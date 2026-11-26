import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pageclock/core/engine/pomodoro_break_snapshot.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/repository/subject_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';
import 'package:pageclock/features/settings/toggl_settings_screen.dart';

void expectNear45MinuteCountdown(WidgetTester tester) {
  expect(
    find.byWidgetPredicate((widget) {
      if (widget is! Text || widget.data == null) return false;
      final value = widget.data!;
      if (value == '45:00') return true;
      if (!value.startsWith('44:')) return false;
      final seconds = int.tryParse(value.substring(3));
      return seconds != null && seconds >= 0 && seconds < 60;
    }),
    findsOneWidget,
  );
}

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
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
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

    await tester.ensureVisible(find.text('Set custom focus time'));
    await tester.tap(find.text('Set custom focus time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '45');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expectNear45MinuteCountdown(tester);
    expect(find.text('SESSION ACTIVE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('custom focus target survives restoring a running session', (tester) async {
    final mounted = await mountTimer(tester);

    await tester.ensureVisible(find.text('Set custom focus time'));
    await tester.tap(find.text('Set custom focus time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '45');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      mounted.preferences.getInt('pageclock_pomodoro_focus_target_ms_v1'),
      45 * 60000,
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
          sharedPreferencesProvider.overrideWithValue(mounted.preferences),
          sessionRepositoryProvider.overrideWithValue(mounted.repository),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expectNear45MinuteCountdown(tester);
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
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
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

    await tester.ensureVisible(find.text('Skip long break'));
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
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LONG BREAK'), findsOneWidget);
    expect(find.text('Skip long break'), findsOneWidget);
    await tester.ensureVisible(find.text('Skip long break'));
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
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsNotifier(preferences);
    await settings.update((value) => value.copyWith(
          pomodoroSoundEnabled: false,
          pomodoroNotificationsEnabled: false,
        ));
    settings.dispose();
    final repository = InMemorySessionRepository();
    var nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final stopwatch = StopwatchNotifier(
      repository,
      nowUtcMs: () => nowUtcMs,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(repository),
          stopwatchProvider.overrideWith((ref) => stopwatch),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Set custom focus time'));
    await tester.tap(find.text('Set custom focus time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('List view'));
    await tester.pump();

    // Advance the injected wall clock beyond the one-minute focus target.
    // The periodic ticker then emits the elapsed update just as it would
    // after the app resumes from a long background suspension.
    nowUtcMs += 61000;
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SHORT BREAK'), findsOneWidget);
    expect(find.text('Skip short break'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Pomodoro settings validate and persist arbitrary durations',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
        ],
        child: const MaterialApp(home: TogglSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pomodoro intervals'));
    await tester.tap(find.text('Pomodoro intervals'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter valid whole-minute durations within the limits.'),
      findsOneWidget,
    );

    await tester.enterText(fields.at(0), '27');
    await tester.enterText(fields.at(1), '6');
    await tester.enterText(fields.at(2), '22');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final restored = SettingsNotifier(preferences);
    expect(restored.state.pomodoroFocusMinutes, 27);
    expect(restored.state.pomodoroShortBreakMinutes, 6);
    expect(restored.state.pomodoroLongBreakMinutes, 22);
    expect(tester.takeException(), isNull);
    restored.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('custom Pomodoro settings persist after app settings reload', () async {
    final preferences = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(preferences);

    await notifier.update((settings) => settings.copyWith(
          pomodoroFocusMinutes: 27,
          pomodoroShortBreakMinutes: 6,
          pomodoroLongBreakMinutes: 22,
          pomodoroLongBreakInterval: 3,
          pomodoroAutoStart: true,
        ));

    final restored = SettingsNotifier(preferences);
    expect(restored.state.pomodoroFocusMinutes, 27);
    expect(restored.state.pomodoroShortBreakMinutes, 6);
    expect(restored.state.pomodoroLongBreakMinutes, 22);
    expect(restored.state.pomodoroLongBreakInterval, 3);
    expect(restored.state.pomodoroAutoStart, isTrue);

    notifier.dispose();
    restored.dispose();
  });

}
