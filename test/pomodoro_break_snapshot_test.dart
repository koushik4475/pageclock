import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/engine/pomodoro_break_snapshot.dart';

void main() {
  group('PomodoroBreakSnapshot', () {
    test('round-trips a running break and its absolute deadline', () {
      const snapshot = PomodoroBreakSnapshot(
        isLongBreak: true,
        durationMs: 900000,
        remainingMs: 600000,
        isRunning: true,
        deadlineUtcMs: 1700000600000,
      );

      final restored = PomodoroBreakSnapshot.tryParse(snapshot.toJson());

      expect(restored, isNotNull);
      expect(restored!.isLongBreak, isTrue);
      expect(restored.durationMs, 900000);
      expect(restored.isRunning, isTrue);
      expect(restored.deadlineUtcMs, 1700000600000);
    });

    test('recomputes remaining time after the app was suspended or closed', () {
      const snapshot = PomodoroBreakSnapshot(
        isLongBreak: false,
        durationMs: 300000,
        remainingMs: 300000,
        isRunning: true,
        deadlineUtcMs: 1700000300000,
      );

      expect(snapshot.remainingAt(1700000125000), 175000);
      expect(snapshot.remainingAt(1700000400000), 0);
    });

    test('preserves a paused break without inventing a deadline', () {
      const snapshot = PomodoroBreakSnapshot(
        isLongBreak: false,
        durationMs: 300000,
        remainingMs: 125000,
        isRunning: false,
        deadlineUtcMs: null,
      );

      final restored = PomodoroBreakSnapshot.tryParse(snapshot.toJson());

      expect(restored, isNotNull);
      expect(restored!.isRunning, isFalse);
      expect(restored.deadlineUtcMs, isNull);
      expect(restored.remainingAt(1700009999999), 125000);
    });

    test('rejects unsupported, malformed, and inconsistent snapshots', () {
      expect(PomodoroBreakSnapshot.tryParse('{bad json'), isNull);
      expect(PomodoroBreakSnapshot.tryParse('{"schema":99}'), isNull);
      expect(
        PomodoroBreakSnapshot.tryParse(
          '{"schema":1,"isLongBreak":false,"durationMs":300000,'
          '"remainingMs":100000,"isRunning":true,"deadlineUtcMs":null}',
        ),
        isNull,
      );
    });
  });
}
