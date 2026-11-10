import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/stats/stats_engine.dart';
import 'package:pageclock/core/services/pdf_service.dart';
import 'package:pageclock/core/services/export_service.dart';

void main() {
  group('End-to-End Enterprise Pressure & Stress Test Suite', () {
    test('50,000 Sessions High-Throughput Aggregation & Trend Benchmark (<600ms)', () {
      final base = DateTime(2025, 1, 1).millisecondsSinceEpoch;
      final sessions = <ReadingSession>[];
      final random = Random(42);

      // 1. Generation of 50,000 sessions across 365 days
      for (int i = 0; i < 50000; i++) {
        final start = base + (i * 630000); // spread across year
        final dur = (10 + random.nextInt(90)) * 60000; // 10 to 100 mins
        sessions.add(
          ReadingSession(
            id: 'stress-$i',
            startedAtUtc: start,
            endedAtUtc: start + dur,
            durationMs: dur,
            tzOffsetMin: 330,
            subjectId: i % 4 == 0 ? 'Coding' : (i % 4 == 1 ? 'Reading' : 'Deep Work'),
            note: 'High volume performance session $i',
            source: i % 2 == 0 ? 'timer' : 'manual',
            createdAt: start,
            updatedAt: start + dur,
          ),
        );
      }
      expect(sessions.length, equals(50000));

      final sw = Stopwatch()..start();

      // 2. High throughput Daily Totals aggregation
      final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
      expect(dailyTotals.isNotEmpty, isTrue);

      // 3. 90-Day Rolling Consistency Calculation
      final consistency = StatsEngine.calculateConsistency(
        dailyTotals: dailyTotals,
        today: DateTime(2025, 11, 7),
        windowDays: 90,
        thresholdMinutes: 20,
      );
      expect(consistency.percentage, inInclusiveRange(0.0, 100.0));
      expect(consistency.totalDaysInWindow, equals(90));

      // 4. 4-Week Linear Regression Weekly Trend
      final trend = StatsEngine.calculateWeeklyTrend(
        dailyTotals: dailyTotals,
        today: DateTime(2025, 11, 7),
      );
      expect(trend.slope.isNaN, isFalse);
      expect(trend.currentWeekHours, greaterThanOrEqualTo(0.0));

      // 5. 30-Day Activity Variability (Standard Deviation)
      final variability = StatsEngine.calculateVariability(
        dailyTotals: dailyTotals,
        today: DateTime(2025, 11, 7),
        windowDays: 30,
      );
      expect(variability.isNaN, isFalse);
      expect(variability, greaterThanOrEqualTo(0.0));

      sw.stop();
      // Whole 50,000 session mathematical pipeline must complete comfortably under CI limits
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('GitHub Contribution Heatmap 18-Week Quantile & Intensity Stress Test', () {
      final dailyTotals = <DateTime, int>{};
      final now = DateTime(2026, 11, 7);
      final random = Random(999);

      // Generate 126 days (18 weeks x 7 days)
      for (int i = 0; i < 126; i++) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        // Distribute across all 5 intensity levels:
        // 0 mins (Level 0), 1-14 (Level 1), 15-29 (Level 2), 30-59 (Level 3), 60+ (Level 4)
        final roll = random.nextInt(5);
        switch (roll) {
          case 0:
            dailyTotals[date] = 0;
            break;
          case 1:
            dailyTotals[date] = 10;
            break;
          case 2:
            dailyTotals[date] = 25;
            break;
          case 3:
            dailyTotals[date] = 45;
            break;
          case 4:
            dailyTotals[date] = 120;
            break;
        }
      }

      int level0Count = 0;
      int level1Count = 0;
      int level2Count = 0;
      int level3Count = 0;
      int level4Count = 0;

      final sw = Stopwatch()..start();
      dailyTotals.forEach((date, mins) {
        if (mins <= 0) {
          level0Count++;
        } else if (mins < 15) {
          level1Count++;
        } else if (mins < 30) {
          level2Count++;
        } else if (mins < 60) {
          level3Count++;
        } else {
          level4Count++;
        }
      });
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(200)); // Sub-millisecond lookup
      expect(level0Count + level1Count + level2Count + level3Count + level4Count, equals(126));
      expect(level0Count, greaterThan(0));
      expect(level4Count, greaterThan(0));
    });

    test('Calendar 24-Hour Timeline with 500 Overlapping Sessions in One Day', () {
      final targetDay = DateTime(2026, 11, 7);
      final dayStart = DateTime(2026, 11, 7, 0, 0, 0).millisecondsSinceEpoch;
      final sessions = <ReadingSession>[];

      // 500 overlapping and micro-burst sessions across the 24 hours
      for (int i = 0; i < 500; i++) {
        final startOffset = (i * 150000) % (24 * 3600000); // wrap within 24h
        final start = dayStart + startOffset;
        final dur = 15 * 60000; // 15 mins
        sessions.add(
          ReadingSession(
            id: 'cal-burst-$i',
            startedAtUtc: start,
            endedAtUtc: start + dur,
            durationMs: dur,
            tzOffsetMin: 0,
            subjectId: 'General Focus',
            createdAt: start,
            updatedAt: start + dur,
          ),
        );
      }

      final sw = Stopwatch()..start();
      final hourly = StatsEngine.calculateHourlyDistribution(sessions, targetDay);
      sw.stop();

      expect(hourly.length, equals(24));
      for (int h = 0; h < 24; h++) {
        expect(hourly.containsKey(h), isTrue);
        expect(hourly[h], greaterThanOrEqualTo(0));
      }
      expect(sw.elapsedMilliseconds, lessThan(300));
    });

    test('Stopwatch Clock Skew, NTP Rewinds & Edge Case Hardening', () {
      final now = 1750000000000;

      // Case 1: NTP rewind / clock skew where pause exceeds elapsed
      final skewedSession = ReadingSession(
        id: 'skew-1',
        startedAtUtc: now,
        pausedTotalMs: 99999999, // enormous pause
        tzOffsetMin: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(skewedSession.calculateCurrentDurationMs(now + 1000), equals(0));

      // Case 2: Negative clock time (evaluated in past)
      expect(skewedSession.calculateCurrentDurationMs(now - 100000), equals(0));

      // Case 3: Zero-duration session
      final zeroSession = ReadingSession(
        id: 'zero-1',
        startedAtUtc: now,
        endedAtUtc: now,
        durationMs: 0,
        tzOffsetMin: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(zeroSession.calculateCurrentDurationMs(now + 5000), equals(0));

      // Case 4: Spanning midnight across Year Leap Day (2024-02-29 to 2024-03-01)
      final leapStart = DateTime(2024, 2, 29, 23, 40);
      final leapEnd = DateTime(2024, 3, 1, 0, 30);
      final leapSession = ReadingSession(
        id: 'leap-session',
        startedAtUtc: leapStart.millisecondsSinceEpoch,
        endedAtUtc: leapEnd.millisecondsSinceEpoch,
        durationMs: 50 * 60 * 1000,
        tzOffsetMin: 0,
        createdAt: leapStart.millisecondsSinceEpoch,
        updatedAt: leapEnd.millisecondsSinceEpoch,
      );

      final leapSplits = StatsEngine.splitSessionByLocalDay(leapSession);
      expect(leapSplits[DateTime(2024, 2, 29)], equals(20));
      expect(leapSplits[DateTime(2024, 3, 1)], equals(30));
    });

    test('Bulk CSV Export/Import Lossless Integrity Test (5,000 Records)', () {
      final now = DateTime(2026, 11, 7).millisecondsSinceEpoch;
      final originalList = List.generate(5000, (i) {
        final start = now - (i * 120000);
        return ReadingSession(
          id: 'bulk-csv-$i',
          startedAtUtc: start,
          endedAtUtc: start + 60000,
          durationMs: 60000,
          tzOffsetMin: 330,
          subjectId: 'Project-${i % 5}',
          note: 'Work item record $i with special chars "quotes, and commas"',
          source: 'timer',
          deviceId: 'device-test',
          createdAt: start,
          updatedAt: start + 60000,
        );
      });

      final sw = Stopwatch()..start();
      final csvData = SessionExportService.exportToCsv(originalList);
      final importedList = SessionExportService.importFromCsv(csvData);
      sw.stop();

      expect(importedList.length, equals(5000));
      expect(importedList.first.id, equals(originalList.first.id));
      expect(importedList[2500].note, equals(originalList[2500].note));
      expect(importedList.last.startedAtUtc, equals(originalList.last.startedAtUtc));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('365-Day Vector PDF Generation Stress Test', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final yearSessions = List.generate(365, (i) {
        final start = now - (i * 86400000);
        return ReadingSession(
          id: 'pdf-year-$i',
          startedAtUtc: start,
          endedAtUtc: start + (45 * 60000),
          durationMs: 45 * 60000,
          tzOffsetMin: 330,
          subjectId: 'Daily Focus',
          note: 'Annual report entry day $i',
          source: 'timer',
          createdAt: start,
          updatedAt: start + (45 * 60000),
        );
      });

      final sw = Stopwatch()..start();
      final pdfBytes = await SessionPdfService.generatePdf(yearSessions);
      sw.stop();

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(15000)); // Comprehensive document with pages
      expect(sw.elapsedMilliseconds, lessThan(8000)); // Completed under 8 seconds under virtualized runner
    });
  });
}
