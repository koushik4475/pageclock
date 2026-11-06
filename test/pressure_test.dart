import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/stats/stats_engine.dart';
import 'package:pageclock/core/services/pdf_service.dart';

void main() {
  group('Comprehensive Pressure, Stability & PDF Test Suite', () {
    test('10,000 sessions aggregation & 90-day consistency stress test', () {
      final base = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final sessions = <ReadingSession>[];
      final random = Random(1234);

      final sw = Stopwatch()..start();

      for (int i = 0; i < 10000; i++) {
        final start = base + (i * 3600000);
        final dur = (20 + random.nextInt(80)) * 60000;
        sessions.add(
          ReadingSession(
            id: 'perf-$i',
            startedAtUtc: start,
            endedAtUtc: start + dur,
            durationMs: dur,
            tzOffsetMin: 330,
            createdAt: start,
            updatedAt: start + dur,
          ),
        );
      }

      final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
      expect(dailyTotals.isNotEmpty, isTrue);

      final consistency = StatsEngine.calculateConsistency(
        dailyTotals: dailyTotals,
        today: DateTime(2026, 11, 7),
        windowDays: 90,
        thresholdMinutes: 20,
      );
      expect(consistency.percentage, inInclusiveRange(0.0, 100.0));

      final trend = StatsEngine.calculateWeeklyTrend(
        dailyTotals: dailyTotals,
        today: DateTime(2026, 11, 7),
      );
      expect(trend.slope.isNaN, isFalse);

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(800));
    });

    test('PDF Generation with Embedded Vector Graph', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sampleSessions = List.generate(14, (i) {
        final start = now - (i * 86400000);
        return ReadingSession(
          id: 'pdf-sample-$i',
          startedAtUtc: start,
          endedAtUtc: start + (45 * 60000),
          durationMs: 45 * 60000,
          tzOffsetMin: 330,
          source: 'timer',
          note: 'Chapter ${i + 1} review',
          createdAt: start,
          updatedAt: start + (45 * 60000),
        );
      });

      final bytes = await SessionPdfService.generatePdf(sampleSessions);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000)); // Non-empty valid PDF byte stream
    });

    test('Edge case: Clock skew and zero-duration safety', () {
      final now = 1700000000000;
      final session = ReadingSession(
        id: 'safety-test',
        startedAtUtc: now,
        pausedTotalMs: 500000, // pause exceeds elapsed
        tzOffsetMin: 0,
        createdAt: now,
        updatedAt: now,
      );

      final elapsed = session.calculateCurrentDurationMs(now + 10000);
      expect(elapsed, equals(0)); // Never negative
    });
  });
}
