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

  testWidgets('daily focus goal reflects today tracked session time', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final startedAt = now.subtract(const Duration(minutes: 10));
    final session = ReadingSession(
      id: 'daily-goal-test-session',
      startedAtUtc: startedAt.millisecondsSinceEpoch,
      endedAtUtc: now.millisecondsSinceEpoch,
      durationMs: 10 * 60 * 1000,
      tzOffsetMin: now.timeZoneOffset.inMinutes,
      subjectId: 'Reading',
      note: 'Test chapter',
      source: 'manual',
      createdAt: startedAt.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );
    final repository = InMemorySessionRepository([session]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TogglTimerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily focus goal'), findsOneWidget);
    expect(find.text('10 / 30 min tracked'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
  });
}
