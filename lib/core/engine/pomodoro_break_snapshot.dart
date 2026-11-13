import 'dart:convert';

import 'pomodoro_clock.dart';

/// A small, versioned snapshot of an in-progress Pomodoro break.
///
/// It is stored in local preferences so a break survives process termination
/// without relying on a background Dart timer.
class PomodoroBreakSnapshot {
  static const int schemaVersion = 1;

  final bool isLongBreak;
  final int durationMs;
  final int remainingMs;
  final bool isRunning;
  final int? deadlineUtcMs;

  const PomodoroBreakSnapshot({
    required this.isLongBreak,
    required this.durationMs,
    required this.remainingMs,
    required this.isRunning,
    required this.deadlineUtcMs,
  });

  int remainingAt(int nowUtcMs) {
    if (!isRunning) {
      if (remainingMs <= 0) return 0;
      return remainingMs > durationMs ? durationMs : remainingMs;
    }

    final deadline = deadlineUtcMs;
    if (deadline == null) return 0;
    return PomodoroClock.remaining(
      deadlineUtcMs: deadline,
      nowUtcMs: nowUtcMs,
      maximumMs: durationMs,
    );
  }

  String toJson() => jsonEncode({
        'schema': schemaVersion,
        'isLongBreak': isLongBreak,
        'durationMs': durationMs,
        'remainingMs': remainingMs,
        'isRunning': isRunning,
        'deadlineUtcMs': deadlineUtcMs,
      });

  static PomodoroBreakSnapshot? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['schema'] != schemaVersion) return null;

      final duration = (map['durationMs'] as num?)?.toInt();
      final remaining = (map['remainingMs'] as num?)?.toInt();
      final isLongBreak = map['isLongBreak'];
      final isRunning = map['isRunning'];
      final rawDeadline = map['deadlineUtcMs'];
      final deadline = rawDeadline is num ? rawDeadline.toInt() : null;

      if (duration == null ||
          remaining == null ||
          duration <= 0 ||
          remaining < 0 ||
          remaining > duration ||
          isLongBreak is! bool ||
          isRunning is! bool ||
          (rawDeadline != null && deadline == null)) {
        return null;
      }
      if (isRunning && deadline == null) return null;
      if (!isRunning && deadline != null) return null;

      return PomodoroBreakSnapshot(
        isLongBreak: isLongBreak,
        durationMs: duration,
        remainingMs: remaining,
        isRunning: isRunning,
        deadlineUtcMs: deadline,
      );
    } catch (_) {
      return null;
    }
  }
}
