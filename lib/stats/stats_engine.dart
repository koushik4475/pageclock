import 'dart:math';
import '../core/models/reading_session.dart';

class DailyAggregate {
  final DateTime date; // Local date (midnight)
  final int totalMinutes;
  final int sessionCount;

  const DailyAggregate({
    required this.date,
    required this.totalMinutes,
    required this.sessionCount,
  });
}

class ConsistencyResult {
  final int totalDaysInWindow;
  final int activeDays;
  final double percentage; // 0 to 100
  final int thresholdMinutes;

  const ConsistencyResult({
    required this.totalDaysInWindow,
    required this.activeDays,
    required this.percentage,
    required this.thresholdMinutes,
  });
}

enum TrendDirection { increasing, decreasing, steady }

class WeeklyTrendResult {
  final TrendDirection direction;
  final double slope; // slope of last 4 weeks (hours / week)
  final double currentWeekHours;
  final double lastWeekHours;
  final double deltaHours;
  final double percentageChange;

  const WeeklyTrendResult({
    required this.direction,
    required this.slope,
    required this.currentWeekHours,
    required this.lastWeekHours,
    required this.deltaHours,
    required this.percentageChange,
  });
}

class DailyTrendResult {
  final int todayMinutes;
  final int yesterdayMinutes;
  final int deltaMinutes;
  final double percentageChange;

  const DailyTrendResult({
    required this.todayMinutes,
    required this.yesterdayMinutes,
    required this.deltaMinutes,
    required this.percentageChange,
  });
}

class StatsEngine {
  /// Converts one session into local-day focused minutes, excluding pauses.
  /// Day keys remain local DateTime values; interval arithmetic uses a UTC
  /// pseudo-local timeline so stored offsets are independent of device timezone.
  static Map<DateTime, int> splitSessionByLocalDay(
    ReadingSession session, {
    int? nowUtcMs,
  }) {
    if (session.deletedAt != null) return {};

    final offsetMs = session.tzOffsetMin * 60000;
    final millisecondsByDay = <DateTime, int>{};
    for (final interval in session.activeIntervals(nowUtcMs: nowUtcMs)) {
      var current = DateTime.fromMillisecondsSinceEpoch(
        interval.startUtc + offsetMs,
        isUtc: true,
      );
      final localEnd = DateTime.fromMillisecondsSinceEpoch(
        interval.endUtc + offsetMs,
        isUtc: true,
      );

      while (current.isBefore(localEnd)) {
        final dayKey = DateTime(current.year, current.month, current.day);
        final nextDay = DateTime.utc(current.year, current.month, current.day)
            .add(const Duration(days: 1));
        final windowEnd = localEnd.isBefore(nextDay) ? localEnd : nextDay;
        final milliseconds = windowEnd.difference(current).inMilliseconds;
        millisecondsByDay[dayKey] =
            (millisecondsByDay[dayKey] ?? 0) + milliseconds;
        current = windowEnd;
      }
    }

    return {
      for (final entry in millisecondsByDay.entries)
        if (entry.value > 0) entry.key: (entry.value / 60000).round(),
    };
  }

  /// Returns focused milliseconds whose stored-offset local timestamps overlap
  /// the requested local date/time range. Used by period reports and grouping.
  static int activeDurationInLocalRange(
    ReadingSession session,
    DateTime localStart,
    DateTime localEnd, {
    int? nowUtcMs,
  }) {
    if (session.deletedAt != null || !localEnd.isAfter(localStart)) return 0;

    final rangeStart = DateTime.utc(
      localStart.year,
      localStart.month,
      localStart.day,
      localStart.hour,
      localStart.minute,
      localStart.second,
      localStart.millisecond,
      localStart.microsecond,
    );
    final rangeEnd = DateTime.utc(
      localEnd.year,
      localEnd.month,
      localEnd.day,
      localEnd.hour,
      localEnd.minute,
      localEnd.second,
      localEnd.millisecond,
      localEnd.microsecond,
    );
    final offsetMs = session.tzOffsetMin * 60000;
    var total = 0;

    for (final interval in session.activeIntervals(nowUtcMs: nowUtcMs)) {
      final start = DateTime.fromMillisecondsSinceEpoch(
        interval.startUtc + offsetMs,
        isUtc: true,
      );
      final end = DateTime.fromMillisecondsSinceEpoch(
        interval.endUtc + offsetMs,
        isUtc: true,
      );
      final overlapStart = start.isAfter(rangeStart) ? start : rangeStart;
      final overlapEnd = end.isBefore(rangeEnd) ? end : rangeEnd;
      if (overlapEnd.isAfter(overlapStart)) {
        total += overlapEnd.difference(overlapStart).inMilliseconds;
      }
    }
    return total;
  }

  /// Calculates the net focused duration for a session, with legacy fallback.
  static int activeDurationMs(ReadingSession session, {int? nowUtcMs}) {
    if (session.deletedAt != null) return 0;
    return session.activeDurationMs(nowUtcMs: nowUtcMs);
  }

  /// Calculates daily totals for a range of sessions
  static Map<DateTime, int> calculateDailyTotals(List<ReadingSession> sessions) {
    final dailyTotals = <DateTime, int>{};

    for (final session in sessions) {
      if (session.deletedAt != null) continue;
      final splits = splitSessionByLocalDay(session);
      splits.forEach((date, minutes) {
        dailyTotals[date] = (dailyTotals[date] ?? 0) + minutes;
      });
    }

    return dailyTotals;
  }

  /// Calculates consistency percentage for a given window (e.g. 7, 30, 90 days)
  static ConsistencyResult calculateConsistency({
    required Map<DateTime, int> dailyTotals,
    required DateTime today,
    int windowDays = 30,
    int thresholdMinutes = 10,
  }) {
    // A non-positive window has no days to measure. Avoid returning a
    // negative percentage for negative windows.
    if (windowDays <= 0) {
      return ConsistencyResult(
        totalDaysInWindow: 0,
        activeDays: 0,
        percentage: 0.0,
        thresholdMinutes: thresholdMinutes,
      );
    }

    final normalizedToday = DateTime(today.year, today.month, today.day);
    int activeDays = 0;

    for (int i = 0; i < windowDays; i++) {
      final date = normalizedToday.subtract(Duration(days: i));
      final minutes = dailyTotals[date] ?? 0;
      if (minutes >= thresholdMinutes) {
        activeDays++;
      }
    }

    final percentage = windowDays > 0 ? (activeDays / windowDays) * 100.0 : 0.0;

    return ConsistencyResult(
      totalDaysInWindow: windowDays,
      activeDays: activeDays,
      percentage: percentage,
      thresholdMinutes: thresholdMinutes,
    );
  }

  /// Calculates current and best streaks based on the consistency threshold
  static ({int currentStreak, int bestStreak}) calculateStreaks({
    required Map<DateTime, int> dailyTotals,
    required DateTime today,
    int thresholdMinutes = 10,
  }) {
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Current streak: consecutive days up to today (or yesterday if today < threshold)
    int current = 0;
    var checkDate = normalizedToday;

    if ((dailyTotals[checkDate] ?? 0) < thresholdMinutes) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while ((dailyTotals[checkDate] ?? 0) >= thresholdMinutes) {
      current++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Best streak: longest consecutive run all-time
    int best = 0;
    if (dailyTotals.isNotEmpty) {
      final sortedDates = dailyTotals.keys.toList()..sort();
      int tempStreak = 0;
      DateTime? prevDate;

      for (final date in sortedDates) {
        if ((dailyTotals[date] ?? 0) >= thresholdMinutes) {
          if (prevDate != null && date.difference(prevDate).inDays == 1) {
            tempStreak++;
          } else {
            tempStreak = 1;
          }
          if (tempStreak > best) best = tempStreak;
          prevDate = date;
        } else {
          tempStreak = 0;
        }
      }
    }

    return (currentStreak: current, bestStreak: max(current, best));
  }

  /// Today vs yesterday daily trend
  static DailyTrendResult calculateDailyTrend({
    required Map<DateTime, int> dailyTotals,
    required DateTime today,
  }) {
    final t = DateTime(today.year, today.month, today.day);
    final y = t.subtract(const Duration(days: 1));

    final todayMin = dailyTotals[t] ?? 0;
    final yestMin = dailyTotals[y] ?? 0;
    final delta = todayMin - yestMin;

    final pct = yestMin > 0
        ? ((delta / yestMin) * 100.0)
        : (todayMin > 0 ? 100.0 : 0.0);

    return DailyTrendResult(
      todayMinutes: todayMin,
      yesterdayMinutes: yestMin,
      deltaMinutes: delta,
      percentageChange: pct,
    );
  }

  /// Weekly trend and 4-week linear regression slope per PRD §5.2
  static WeeklyTrendResult calculateWeeklyTrend({
    required Map<DateTime, int> dailyTotals,
    required DateTime today,
    int weekStartDay = DateTime.monday,
  }) {
    // Current week sum
    final currentWeekMinutes = _sumWeek(dailyTotals, today, weekStartDay, 0);
    final lastWeekMinutes = _sumWeek(dailyTotals, today, weekStartDay, 1);

    final currentWeekHours = currentWeekMinutes / 60.0;
    final lastWeekHours = lastWeekMinutes / 60.0;
    final deltaHours = currentWeekHours - lastWeekHours;

    final pctChange = lastWeekHours > 0
        ? ((deltaHours / lastWeekHours) * 100.0)
        : (currentWeekHours > 0 ? 100.0 : 0.0);

    // 4-week linear regression: weeks [-3, -2, -1, 0] (x = 0, 1, 2, 3)
    final y = List<double>.generate(4, (i) {
      final offsetWeeks = 3 - i;
      return _sumWeek(dailyTotals, today, weekStartDay, offsetWeeks) / 60.0;
    });

    final x = [0.0, 1.0, 2.0, 3.0];
    final n = 4.0;
    final sumX = 6.0;
    final sumY = y.reduce((a, b) => a + b);
    final meanY = sumY / n;

    double sumXY = 0.0;
    double sumX2 = 0.0;
    for (int i = 0; i < 4; i++) {
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    // Steady if |slope| < 5% of mean
    TrendDirection direction;
    final threshold = meanY * 0.05;
    if (slope.abs() <= threshold || meanY == 0.0) {
      direction = TrendDirection.steady;
    } else if (slope > 0) {
      direction = TrendDirection.increasing;
    } else {
      direction = TrendDirection.decreasing;
    }

    return WeeklyTrendResult(
      direction: direction,
      slope: slope,
      currentWeekHours: currentWeekHours,
      lastWeekHours: lastWeekHours,
      deltaHours: deltaHours,
      percentageChange: pctChange,
    );
  }

  /// Variability: Standard deviation of daily minutes over 30 days
  static double calculateVariability({
    required Map<DateTime, int> dailyTotals,
    required DateTime today,
    int windowDays = 30,
  }) {
    // There is no meaningful population variance for an empty window.
    // Returning zero also avoids reducing an empty list and dividing by zero.
    if (windowDays <= 0) return 0.0;

    final t = DateTime(today.year, today.month, today.day);
    final values = <int>[];

    for (int i = 0; i < windowDays; i++) {
      final d = t.subtract(Duration(days: i));
      values.add(dailyTotals[d] ?? 0);
    }

    final mean = values.reduce((a, b) => a + b) / windowDays;
    double varianceSum = 0;
    for (final val in values) {
      varianceSum += pow(val - mean, 2);
    }

    return sqrt(varianceSum / windowDays);
  }

  /// Calculates focused minutes by local hour, excluding every pause interval.
  static Map<int, int> calculateHourlyDistribution(
    List<ReadingSession> sessions,
    DateTime targetDay,
  ) {
    final millisecondsByHour = <int, int>{for (int h = 0; h < 24; h++) h: 0};
    final dayStart = DateTime.utc(targetDay.year, targetDay.month, targetDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final session in sessions) {
      if (session.deletedAt != null) continue;
      final offsetMs = session.tzOffsetMin * 60000;

      for (final interval in session.activeIntervals()) {
        final localStart = DateTime.fromMillisecondsSinceEpoch(
          interval.startUtc + offsetMs,
          isUtc: true,
        );
        final localEnd = DateTime.fromMillisecondsSinceEpoch(
          interval.endUtc + offsetMs,
          isUtc: true,
        );
        if (!localEnd.isAfter(dayStart) || !localStart.isBefore(dayEnd)) {
          continue;
        }

        var current = localStart.isBefore(dayStart) ? dayStart : localStart;
        final boundedEnd = localEnd.isAfter(dayEnd) ? dayEnd : localEnd;
        while (current.isBefore(boundedEnd)) {
          final nextHour = DateTime.utc(
            current.year,
            current.month,
            current.day,
            current.hour,
          ).add(const Duration(hours: 1));
          final sliceEnd =
              boundedEnd.isBefore(nextHour) ? boundedEnd : nextHour;
          millisecondsByHour[current.hour] =
              (millisecondsByHour[current.hour] ?? 0) +
                  sliceEnd.difference(current).inMilliseconds;
          current = sliceEnd;
        }
      }
    }

    return {
      for (final entry in millisecondsByHour.entries)
        entry.key: (entry.value / 60000).round(),
    };
  }

  static int _sumWeek(
    Map<DateTime, int> dailyTotals,
    DateTime today,
    int weekStartDay,
    int weeksAgo,
  ) {
    final normalized = DateTime(today.year, today.month, today.day);
    final daysFromStart = (normalized.weekday - weekStartDay + 7) % 7;
    final thisWeekStart = normalized.subtract(Duration(days: daysFromStart));
    final targetWeekStart = thisWeekStart.subtract(Duration(days: 7 * weeksAgo));

    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final day = targetWeekStart.add(Duration(days: i));
      sum += dailyTotals[day] ?? 0;
    }
    return sum;
  }
}
