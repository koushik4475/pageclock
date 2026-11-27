import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/calendar/calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('paused session calendar total excludes pause and short blocks do not overflow',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startLocal = today.add(Duration(hours: now.hour));
    final pauseStartLocal = startLocal.add(const Duration(minutes: 15));
    final pauseEndLocal = startLocal.add(const Duration(minutes: 45));
    final endLocal = startLocal.add(const Duration(hours: 1));
    final start = startLocal.toUtc().millisecondsSinceEpoch;
    final pauseStart = pauseStartLocal.toUtc().millisecondsSinceEpoch;
    final pauseEnd = pauseEndLocal.toUtc().millisecondsSinceEpoch;
    final end = endLocal.toUtc().millisecondsSinceEpoch;
    final session = ReadingSession(
      id: 'calendar-pause-short-blocks',
      startedAtUtc: start,
      endedAtUtc: end,
      pausedTotalMs: 30 * 60000,
      durationMs: 30 * 60000,
      tzOffsetMin: startLocal.timeZoneOffset.inMinutes,
      subjectId: 'Study',
      note: 'A note hidden from compact blocks',
      pauseIntervals: [
        PauseInterval(startedAtUtc: pauseStart, endedAtUtc: pauseEnd),
      ],
      createdAt: start,
      updatedAt: end,
    );

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: CalendarScreen(sessions: [session]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('Study'), findsWidgets);
    expect(find.text('A note hidden from compact blocks'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
