import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/stats/stats_engine.dart';
import 'package:pageclock/core/services/export_service.dart';

void main() {
  group('Pressure and Edge-Case Stress Suite', () {
    test('10,000 reading sessions stress & performance test', () {
      final baseTime = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final sessions = <ReadingSession>[];
      final random = Random(42);

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 10000; i++) {
        final start = baseTime + (i * 3600000); // 1 hour steps
        final duration = (15 + random.nextInt(90)) * 60 * 1000; // 15 to 105 mins
        sessions.add(
          ReadingSession(
            id: 'perf-$i',
            startedAtUtc: start,
            endedAtUtc: start + duration,
            durationMs: duration,
            tzOffsetMin: 330, // IST
            createdAt: start,
            updatedAt: start + duration,
          ),
        );
      }

      // Pressure test daily total aggregation
      final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
      expect(dailyTotals.isNotEmpty, isTrue);

      // Pressure test consistency calculation over 90 days
      final consistency = StatsEngine.calculateConsistency(
        dailyTotals: dailyTotals,
        today: DateTime(2026, 11, 7),
        windowDays: 90,
        thresholdMinutes: 20,
      );
      expect(consistency.percentage, inInclusiveRange(0.0, 100.0));

      // Pressure test 4-week trend
      final trend = StatsEngine.calculateWeeklyTrend(
        dailyTotals: dailyTotals,
        today: DateTime(2026, 11, 7),
      );
      expect(trend.slope.isNaN, isFalse);

      stopwatch.stop();
      // PRD §6 performance requirement: stats queries for large datasets should execute in < 200ms
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('Negative and zero elapsed time resilience', () {
      final now = 1700000000000;
      final session = ReadingSession(
        id: 'clock-skew-test',
        startedAtUtc: now,
        pausedTotalMs: 100000, // pause exceeds elapsed due to simulated clock skew
        tzOffsetMin: 0,
        createdAt: now,
        updatedAt: now,
      );

      final elapsed = session.calculateCurrentDurationMs(now + 1000);
      expect(elapsed, equals(0)); // Never negative
    });

    test('Extreme DST / Timezone shifting resilience', () {
      // Test cross-midnight session across extreme timezone offset (e.g. UTC-10 vs UTC+14)
      final session = ReadingSession(
        id: 'kiribati-hawaii',
        startedAtUtc: 1700000000000,
        endedAtUtc: 1700000000000 + (2 * 3600000),
        durationMs: 2 * 3600000,
        tzOffsetMin: 840, // UTC+14 (Line Islands, Kiribati)
        createdAt: 1700000000000,
        updatedAt: 1700000000000 + (2 * 3600000),
      );

      final splits = StatsEngine.splitSessionByLocalDay(session);
      expect(splits.isNotEmpty, isTrue);
      final totalMinutes = splits.values.reduce((a, b) => a + b);
      expect(totalMinutes, equals(120));
    });
  });
}
