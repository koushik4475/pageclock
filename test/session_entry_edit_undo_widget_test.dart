import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('edits one completed entry and restores it with Undo', (tester) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    const durationMs = 30 * 60 * 1000;
    const pauseDurationMs = 5 * 60 * 1000;
    final pause = PauseInterval(
      startedAtUtc: now - 20 * 60 * 1000,
      endedAtUtc: now - 15 * 60 * 1000,
    );
    final session = ReadingSession(
      id: 'editable-entry',
      startedAtUtc: now - durationMs - pauseDurationMs,
      endedAtUtc: now,
      pausedTotalMs: pauseDurationMs,
      pauseIntervals: [pause],
      durationMs: durationMs,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      subjectId: 'Reading',
      note: 'Original chapter',
      source: 'manual',
      createdAt: now - durationMs - pauseDurationMs,
      updatedAt: now,
    );
    final repository = InMemorySessionRepository([session]);
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(repository),
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

    expect(find.text('Original chapter'), findsOneWidget);
    expect(find.byTooltip('Entry actions'), findsOneWidget);

    await tester.tap(find.byTooltip('Entry actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit entry'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Time Entry'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Updated chapter');
    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    var saved = await repository.getAllSessions();
    expect(saved, hasLength(1));
    expect(saved.single.note, 'Updated chapter');
    expect(saved.single.durationMs, 45 * 60 * 1000);
    expect(saved.single.endedAtUtc, session.endedAtUtc);
    expect(
      saved.single.startedAtUtc,
      session.endedAtUtc! - 45 * 60 * 1000 - pauseDurationMs,
    );
    expect(saved.single.pauseIntervals, [pause]);
    expect(saved.single.activeDurationMs(), 45 * 60 * 1000);
    expect(saved.single.id, session.id);
    expect(saved.single.createdAt, session.createdAt);

    await tester.tap(find.byTooltip('Entry actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();

    expect(await repository.getAllSessions(), isEmpty);
    expect(find.text('Time entry deleted.'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    saved = await repository.getAllSessions();
    expect(saved, hasLength(1));
    expect(saved.single.id, session.id);
    expect(saved.single.note, 'Updated chapter');
    expect(saved.single.deletedAt, isNull);
  });
}
