import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/stats/stats_engine.dart';

void main() {
  group('StatsEngine Unit & Edge Case Tests', () {
    test('Midnight Split: session spanning local midnight is split across two days', () {
      // 11:30 PM to 12:30 AM local time (60 mins total)
      final localStart = DateTime(2026, 11, 6, 23, 30);
      final localEnd = DateTime(2026, 11, 7, 0, 30);

      final session = ReadingSession(
        id: 'midnight-1',
        startedAtUtc: localStart.millisecondsSinceEpoch,
        endedAtUtc: localEnd.millisecondsSinceEpoch,
        durationMs: 60 * 60 * 1000,
        tzOffsetMin: 0,
        createdAt: localStart.millisecondsSinceEpoch,
        updatedAt: localEnd.millisecondsSinceEpoch,
      );

      final splits = StatsEngine.splitSessionByLocalDay(session);
      expect(splits.length, equals(2));

      final day1 = DateTime(2026, 11, 6);
      final day2 = DateTime(2026, 11, 7);

      expect(splits[day1], equals(30));
      expect(splits[day2], equals(30));
    });

    test('Consistency calculation & streaks', () {
      final today = DateTime(2026, 11, 10);
      final dailyTotals = {
        DateTime(2026, 11, 10): 25, // today >= 10
        DateTime(2026, 11, 9): 45,  // yesterday >= 10
        DateTime(2026, 11, 8): 15,  // 2 days ago >= 10
        DateTime(2026, 11, 7): 5,   // below threshold
        DateTime(2026, 11, 6): 60,
      };

      final consistency = StatsEngine.calculateConsistency(
        dailyTotals: dailyTotals,
        today: today,
        windowDays: 5,
        thresholdMinutes: 10,
      );

      // 4 out of 5 days had >= 10 mins (10, 9, 8, 6)
      expect(consistency.activeDays, equals(4));
      expect(consistency.percentage, equals(80.0));

      final streaks = StatsEngine.calculateStreaks(
        dailyTotals: dailyTotals,
        today: today,
        thresholdMinutes: 10,
      );

      // Current streak: 10, 9, 8 -> 3 consecutive days
      expect(streaks.currentStreak, equals(3));
    });

    test('4-Week Linear Regression Trend Detection', () {
      final today = DateTime(2026, 11, 23); // Monday
      // Construct increasing reading totals over 4 weeks
      // Week -3: 2 hours, Week -2: 4 hours, Week -1: 6 hours, Week 0: 8 hours
      final dailyTotals = <DateTime, int>{};

      void addHoursToWeek(int offsetWeeks, int hours) {
        final date = today.subtract(Duration(days: 7 * offsetWeeks));
        dailyTotals[date] = hours * 60;
      }

      addHoursToWeek(3, 2);
      addHoursToWeek(2, 4);
      addHoursToWeek(1, 6);
      addHoursToWeek(0, 8);

      final trend = StatsEngine.calculateWeeklyTrend(
        dailyTotals: dailyTotals,
        today: today,
      );

      expect(trend.direction, equals(TrendDirection.increasing));
      expect(trend.slope, greaterThan(0.0));
      expect(trend.currentWeekHours, equals(8.0));
      expect(trend.lastWeekHours, equals(6.0));
    });

    test('Empty and negative windows return safe zero values', () {
      final today = DateTime(2026, 11, 12);
      final dailyTotals = <DateTime, int>{today: 42};

      for (final windowDays in [0, -1, -30]) {
        final consistency = StatsEngine.calculateConsistency(
          dailyTotals: dailyTotals,
          today: today,
          windowDays: windowDays,
        );
        expect(consistency.totalDaysInWindow, equals(0));
        expect(consistency.activeDays, equals(0));
        expect(consistency.percentage, equals(0.0));

        expect(
          StatsEngine.calculateVariability(
            dailyTotals: dailyTotals,
            today: today,
            windowDays: windowDays,
          ),
          equals(0.0),
        );
      }
    });

    test('Completed pauses are excluded and split exactly across local midnight', () {
      final start = DateTime.utc(2026, 11, 6, 23, 30).millisecondsSinceEpoch;
      final pauseStart = DateTime.utc(2026, 11, 6, 23, 45).millisecondsSinceEpoch;
      final pauseEnd = DateTime.utc(2026, 11, 7, 0, 15).millisecondsSinceEpoch;
      final end = DateTime.utc(2026, 11, 7, 0, 30).millisecondsSinceEpoch;
      final session = ReadingSession(
        id: 'pause-midnight',
        startedAtUtc: start,
        endedAtUtc: end,
        pausedTotalMs: 30 * 60000,
        durationMs: 30 * 60000,
        tzOffsetMin: 0,
        pauseIntervals: [
          PauseInterval(startedAtUtc: pauseStart, endedAtUtc: pauseEnd),
        ],
        createdAt: start,
        updatedAt: end,
      );

      final daily = StatsEngine.splitSessionByLocalDay(session);
      expect(daily[DateTime(2026, 11, 6)], 15);
      expect(daily[DateTime(2026, 11, 7)], 15);
      expect(daily.values.fold<int>(0, (sum, value) => sum + value), 30);
    });

    test('Multiple pauses are excluded from period totals and project duration', () {
      final start = DateTime.utc(2026, 11, 9, 9).millisecondsSinceEpoch;
      final end = DateTime.utc(2026, 11, 9, 10, 30).millisecondsSinceEpoch;
      final session = ReadingSession(
        id: 'multiple-pauses',
        startedAtUtc: start,
        endedAtUtc: end,
        pausedTotalMs: 30 * 60000,
        durationMs: 60 * 60000,
        tzOffsetMin: 0,
        pauseIntervals: [
          PauseInterval(
            startedAtUtc: DateTime.utc(2026, 11, 9, 9, 15).millisecondsSinceEpoch,
            endedAtUtc: DateTime.utc(2026, 11, 9, 9, 30).millisecondsSinceEpoch,
          ),
          PauseInterval(
            startedAtUtc: DateTime.utc(2026, 11, 9, 9, 45).millisecondsSinceEpoch,
            endedAtUtc: DateTime.utc(2026, 11, 9, 10).millisecondsSinceEpoch,
          ),
        ],
        createdAt: start,
        updatedAt: end,
      );

      expect(StatsEngine.activeDurationMs(session), 60 * 60000);
      expect(
        StatsEngine.activeDurationInLocalRange(
          session,
          DateTime(2026, 11, 9, 9, 30),
          DateTime(2026, 11, 9, 10, 15),
        ),
        30 * 60000,
      );
      expect(
        StatsEngine.calculateDailyTotals([session])[DateTime(2026, 11, 9)],
        60,
      );
    });

    test('Currently paused sessions stop accumulating at the pause timestamp', () {
      final start = DateTime.utc(2026, 11, 6, 23, 30).millisecondsSinceEpoch;
      final pausedAt = DateTime.utc(2026, 11, 7, 0, 15).millisecondsSinceEpoch;
      final session = ReadingSession(
        id: 'currently-paused',
        startedAtUtc: start,
        pausedAtUtc: pausedAt,
        durationMs: 0,
        tzOffsetMin: 0,
        createdAt: start,
        updatedAt: pausedAt,
      );

      final daily = StatsEngine.splitSessionByLocalDay(
        session,
        nowUtcMs: pausedAt + 60 * 60000,
      );
      expect(daily[DateTime(2026, 11, 6)], 30);
      expect(daily[DateTime(2026, 11, 7)], 15);
      expect(session.activeDurationMs(nowUtcMs: pausedAt + 60 * 60000), 45 * 60000);
    });

    test('Legacy sessions keep net totals with documented start-anchored allocation', () {
      final start = DateTime.utc(2026, 11, 6, 23, 30).millisecondsSinceEpoch;
      final end = DateTime.utc(2026, 11, 7, 0, 30).millisecondsSinceEpoch;
      final legacy = ReadingSession(
        id: 'legacy-paused',
        startedAtUtc: start,
        endedAtUtc: end,
        pausedTotalMs: 30 * 60000,
        durationMs: 30 * 60000,
        tzOffsetMin: 0,
        createdAt: start,
        updatedAt: end,
      );

      final daily = StatsEngine.splitSessionByLocalDay(legacy);
      expect(daily[DateTime(2026, 11, 6)], 30);
      expect(daily.containsKey(DateTime(2026, 11, 7)), isFalse);
      expect(StatsEngine.activeDurationMs(legacy), 30 * 60000);
    });
  });
}
