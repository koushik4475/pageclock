import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/engine/pomodoro_clock.dart';

void main() {
  group('PomodoroClock', () {
    test('deadline is based on remaining time, not callback count', () {
      expect(
        PomodoroClock.deadlineAfter(nowUtcMs: 10000, remainingMs: 30000),
        40000,
      );
    });

    test('accounts for delayed callbacks after background suspension', () {
      expect(
        PomodoroClock.remaining(
          deadlineUtcMs: 40000,
          nowUtcMs: 27500,
          maximumMs: 30000,
        ),
        12500,
      );
    });

    test('clamps expired deadlines to zero', () {
      expect(
        PomodoroClock.remaining(
          deadlineUtcMs: 40000,
          nowUtcMs: 45000,
          maximumMs: 30000,
        ),
        0,
      );
    });

    test('never returns more than the configured break duration', () {
      expect(
        PomodoroClock.remaining(
          deadlineUtcMs: 90000,
          nowUtcMs: 10000,
          maximumMs: 30000,
        ),
        30000,
      );
    });
  });
}
