import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/stats/stats_engine.dart';

ReadingSession _session({
  required String id,
  required DateTime startedAtLocal,
  DateTime? endedAtLocal,
  DateTime? pausedAtLocal,
  required int durationMs,
  int pausedTotalMs = 0,
  List<PauseInterval> pauseIntervals = const [],
}) {
  final startUtc = startedAtLocal.toUtc().millisecondsSinceEpoch;
  final endUtc = endedAtLocal?.toUtc().millisecondsSinceEpoch;
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return ReadingSession(
    id: id,
    startedAtUtc: startUtc,
    endedAtUtc: endUtc,
    pausedAtUtc: pausedAtLocal?.toUtc().millisecondsSinceEpoch,
    pausedTotalMs: pausedTotalMs,
    pauseIntervals: pauseIntervals,
    durationMs: durationMs,
    tzOffsetMin: startedAtLocal.timeZoneOffset.inMinutes,
    subjectId: 'Reading',
    source: 'timer',
    createdAt: startUtc,
    updatedAt: endUtc ?? now,
  );
}

void main() {
  group('Timer daily-goal local-day allocation', () {
    final dayStart = DateTime(2026, 11, 14);
    final dayEnd = dayStart.add(const Duration(days: 1));

    DailyFocusSummary summarize({
      List<ReadingSession> sessions = const [],
      ReadingSession? currentSession,
      required DateTime now,
    }) {
      return StatsEngine.calculateDailyFocusSummary(
        sessions: sessions,
        localStart: dayStart,
        localEnd: dayEnd,
        currentSession: currentSession,
        nowUtcMs: now.toUtc().millisecondsSinceEpoch,
      );
    }

    test('includes a completed session that started yesterday', () {
      final session = _session(
        id: 'yesterday-into-today',
        startedAtLocal: dayStart.subtract(const Duration(minutes: 10)),
        endedAtLocal: dayStart.add(const Duration(minutes: 10)),
        durationMs: 20 * 60000,
      );

      final summary = summarize(
        sessions: [session],
        now: dayStart.add(const Duration(minutes: 20)),
      );

      expect(summary.completedSessions, [session]);
      expect(summary.completedMilliseconds, 10 * 60000);
      expect(summary.totalMilliseconds, 10 * 60000);
    });

    test('counts only today portion of a session continuing into tomorrow', () {
      final session = _session(
        id: 'today-into-tomorrow',
        startedAtLocal: dayEnd.subtract(const Duration(minutes: 10)),
        endedAtLocal: dayEnd.add(const Duration(minutes: 10)),
        durationMs: 20 * 60000,
      );

      final summary = summarize(
        sessions: [session],
        now: dayEnd.add(const Duration(minutes: 20)),
      );

      expect(summary.completedSessions, [session]);
      expect(summary.completedMilliseconds, 10 * 60000);
    });

    test('excludes a pause interval that crosses midnight', () {
      final pauseStart = dayStart.subtract(const Duration(minutes: 10));
      final pauseEnd = dayStart.add(const Duration(minutes: 10));
      final session = _session(
        id: 'pause-crosses-midnight',
        startedAtLocal: dayStart.subtract(const Duration(minutes: 30)),
        endedAtLocal: dayStart.add(const Duration(minutes: 30)),
        durationMs: 40 * 60000,
        pausedTotalMs: 20 * 60000,
        pauseIntervals: [
          PauseInterval(
            startedAtUtc: pauseStart.toUtc().millisecondsSinceEpoch,
            endedAtUtc: pauseEnd.toUtc().millisecondsSinceEpoch,
          ),
        ],
      );

      final summary = summarize(
        sessions: [session],
        now: dayStart.add(const Duration(hours: 1)),
      );

      expect(summary.completedMilliseconds, 20 * 60000);
    });

    test('counts a running session started yesterday from midnight onward', () {
      final now = dayStart.add(const Duration(minutes: 10));
      final session = _session(
        id: 'running-from-yesterday',
        startedAtLocal: dayStart.subtract(const Duration(minutes: 15)),
        durationMs: 0,
      );

      final summary = summarize(currentSession: session, now: now);

      expect(summary.completedSessions, isEmpty);
      expect(summary.currentSessionMilliseconds, 10 * 60000);
      expect(summary.totalMilliseconds, 10 * 60000);
    });

    test('counts a paused session only until its pause timestamp', () {
      final pauseAt = dayStart.add(const Duration(minutes: 5));
      final session = _session(
        id: 'paused-after-midnight',
        startedAtLocal: dayStart.subtract(const Duration(minutes: 15)),
        pausedAtLocal: pauseAt,
        durationMs: 0,
      );

      final summary = summarize(
        currentSession: session,
        now: dayStart.add(const Duration(minutes: 30)),
      );

      expect(summary.currentSessionMilliseconds, 5 * 60000);
    });

    test('keeps deterministic legacy allocation without exact pause positions', () {
      final session = _session(
        id: 'legacy-pause',
        startedAtLocal: dayStart.subtract(const Duration(minutes: 30)),
        endedAtLocal: dayStart.add(const Duration(minutes: 30)),
        durationMs: 40 * 60000,
        pausedTotalMs: 20 * 60000,
      );

      final summary = summarize(
        sessions: [session],
        now: dayStart.add(const Duration(hours: 1)),
      );

      expect(summary.completedMilliseconds, 10 * 60000);
    });
  });
}
