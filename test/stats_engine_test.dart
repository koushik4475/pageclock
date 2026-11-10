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
  });
}
