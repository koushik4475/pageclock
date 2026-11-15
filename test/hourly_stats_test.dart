import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/stats/stats_engine.dart';

void main() {
  group('Hourly Bucketing Tests (PRD §5.3)', () {
    test('Session within single hour buckets all minutes to that hour', () {
      // 14:00 to 14:45 local time
      final tzOffsetMin = DateTime.now().timeZoneOffset.inMinutes;
      final startUtc = DateTime(2026, 11, 7, 14, 0).subtract(Duration(minutes: tzOffsetMin)).millisecondsSinceEpoch;
      final endUtc = DateTime(2026, 11, 7, 14, 45).subtract(Duration(minutes: tzOffsetMin)).millisecondsSinceEpoch;

      final session = ReadingSession(
        id: 'test-1',
        startedAtUtc: startUtc,
        endedAtUtc: endUtc,
        durationMs: 45 * 60 * 1000,
        tzOffsetMin: tzOffsetMin,
        createdAt: startUtc,
        updatedAt: endUtc,
      );

      final hourly = StatsEngine.calculateHourlyDistribution(
        [session],
        DateTime(2026, 11, 7),
      );

      expect(hourly[14], equals(45));
      expect(hourly.values.reduce((a, b) => a + b), equals(45));
    });

    test('Session spanning across hour boundary splits correctly', () {
      // 10:30 to 11:15 local time (30 mins in hour 10, 15 mins in hour 11)
      final tzOffsetMin = DateTime.now().timeZoneOffset.inMinutes;
      final startUtc = DateTime(2026, 11, 7, 10, 30).subtract(Duration(minutes: tzOffsetMin)).millisecondsSinceEpoch;
      final endUtc = DateTime(2026, 11, 7, 11, 15).subtract(Duration(minutes: tzOffsetMin)).millisecondsSinceEpoch;

      final session = ReadingSession(
        id: 'test-2',
        startedAtUtc: startUtc,
        endedAtUtc: endUtc,
        durationMs: 45 * 60 * 1000,
        tzOffsetMin: tzOffsetMin,
        createdAt: startUtc,
        updatedAt: endUtc,
      );

      final hourly = StatsEngine.calculateHourlyDistribution(
        [session],
        DateTime(2026, 11, 7),
      );

      expect(hourly[10], equals(30));
      expect(hourly[11], equals(15));
      expect(hourly.length, equals(24));
    });

    test('Hourly distribution excludes multiple pauses using the stored timezone offset', () {
      const offsetMs = 330 * 60000;
      int utcAt(int hour, int minute) =>
          DateTime.utc(2026, 11, 9, hour, minute).millisecondsSinceEpoch -
          offsetMs;

      final session = ReadingSession(
        id: 'paused-hourly',
        startedAtUtc: utcAt(9, 0),
        endedAtUtc: utcAt(10, 30),
        pausedTotalMs: 30 * 60000,
        durationMs: 60 * 60000,
        tzOffsetMin: 330,
        pauseIntervals: [
          PauseInterval(
            startedAtUtc: utcAt(9, 15),
            endedAtUtc: utcAt(9, 30),
          ),
          PauseInterval(
            startedAtUtc: utcAt(9, 45),
            endedAtUtc: utcAt(10, 0),
          ),
        ],
        createdAt: utcAt(9, 0),
        updatedAt: utcAt(10, 30),
      );

      final hourly = StatsEngine.calculateHourlyDistribution(
        [session],
        DateTime(2026, 11, 9),
      );

      expect(hourly[9], 30);
      expect(hourly[10], 30);
      expect(hourly.values.fold<int>(0, (sum, value) => sum + value), 60);
    });
  });
}
