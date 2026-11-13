/// Time calculations for Pomodoro countdowns.
///
/// Deadlines are stored as UTC epoch milliseconds so wall-clock timezone
/// changes do not alter the remaining duration.
class PomodoroClock {
  const PomodoroClock._();

  static int deadlineAfter({
    required int nowUtcMs,
    required int remainingMs,
  }) => nowUtcMs + (remainingMs < 0 ? 0 : remainingMs);

  static int remaining({
    required int deadlineUtcMs,
    required int nowUtcMs,
    required int maximumMs,
  }) {
    final value = deadlineUtcMs - nowUtcMs;
    if (value <= 0) return 0;
    return value > maximumMs ? maximumMs : value;
  }
}
