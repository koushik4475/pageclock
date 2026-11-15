import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';
import 'package:pageclock/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('daily focus goal reflects today tracked session time', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final todayStart = DateTime.now();
    final localMidnight = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final startedAt = localMidnight.subtract(const Duration(minutes: 10));
    final endedAt = localMidnight.add(const Duration(minutes: 10));
    final session = ReadingSession(
      id: 'daily-goal-test-session',
      startedAtUtc: startedAt.toUtc().millisecondsSinceEpoch,
      endedAtUtc: endedAt.toUtc().millisecondsSinceEpoch,
      durationMs: 20 * 60 * 1000,
      tzOffsetMin: startedAt.timeZoneOffset.inMinutes,
      subjectId: 'Reading',
      note: 'Test chapter',
      source: 'manual',
      createdAt: startedAt.toUtc().millisecondsSinceEpoch,
      updatedAt: endedAt.toUtc().millisecondsSinceEpoch,
    );
    final repository = InMemorySessionRepository([session]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionsStreamProvider.overrideWith((ref) => repository.watchAllSessions()),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Daily focus goal'), findsOneWidget);
    expect(find.text('10 / 30 min tracked'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
  });
}
