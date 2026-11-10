import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';

class _DelayedRestoreRepository extends InMemorySessionRepository {
  final Completer<void> restoreGate;

  _DelayedRestoreRepository(
    List<ReadingSession> initial,
    this.restoreGate,
  ) : super(initial);

  @override
  Future<ReadingSession?> getActiveSession() async {
    await restoreGate.future;
    return super.getActiveSession();
  }
}

void main() {
  group('Stopwatch active-session restoration', () {
    test('start waits for persisted active session before creating a new row', () async {
      final startedAt = DateTime.now().toUtc().millisecondsSinceEpoch - 60000;
      final persistedSession = ReadingSession(
        id: 'persisted-active',
        startedAtUtc: startedAt,
        endedAtUtc: null,
        durationMs: 0,
        tzOffsetMin: 0,
        subjectId: 'Reading',
        note: 'Existing session',
        source: 'timer',
        deviceId: 'local',
        createdAt: startedAt,
        updatedAt: startedAt,
      );
      final restoreGate = Completer<void>();
      final repository = _DelayedRestoreRepository([persistedSession], restoreGate);
      final notifier = StopwatchNotifier(repository);

      // Simulate a user tapping Start immediately after cold launch, before
      // the asynchronous database read has returned the active session.
      final start = notifier.start(subjectId: 'Coding', note: 'New session');
      await Future<void>.delayed(Duration.zero);

      expect(
        (await repository.getAllSessions()).where((s) => s.endedAtUtc == null),
        hasLength(1),
      );

      restoreGate.complete();
      await start;

      final activeSessions = (await repository.getAllSessions())
          .where((s) => s.endedAtUtc == null)
          .toList();
      expect(activeSessions, hasLength(1));
      expect(activeSessions.single.id, 'persisted-active');
      expect(notifier.state.currentSession?.id, 'persisted-active');
      notifier.dispose();
    });

    test('concurrent start taps create only one active session', () async {
      final repository = InMemorySessionRepository([]);
      final notifier = StopwatchNotifier(repository);

      await Future.wait([
        notifier.start(subjectId: 'Reading'),
        notifier.start(subjectId: 'Coding'),
      ]);

      final activeSessions = (await repository.getAllSessions())
          .where((s) => s.endedAtUtc == null)
          .toList();
      expect(activeSessions, hasLength(1));
      expect(notifier.state.currentSession?.id, activeSessions.single.id);
      notifier.dispose();
    });

    test('start, pause, resume and stop persist one completed session', () async {
      final repository = InMemorySessionRepository([]);
      final notifier = StopwatchNotifier(repository);

      await notifier.start(subjectId: 'Reading', note: 'Chapter 4');
      expect(notifier.state.status, StopwatchStatus.running);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.pause();
      expect(notifier.state.status, StopwatchStatus.paused);
      final pausedAt = notifier.state.currentSession?.pausedAtUtc;
      expect(pausedAt, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 25));

      await notifier.resume();
      expect(notifier.state.status, StopwatchStatus.running);
      expect(notifier.state.currentSession?.pausedAtUtc, isNull);
      expect(notifier.state.currentSession!.pausedTotalMs, greaterThan(0));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final finished = await notifier.stop(minSessionDurationMs: 0);

      expect(finished, isNotNull);
      expect(finished!.endedAtUtc, isNotNull);
      expect(finished.durationMs, greaterThan(0));
      expect(notifier.state.status, StopwatchStatus.idle);

      final saved = await repository.getAllSessions();
      expect(saved, hasLength(1));
      expect(saved.single.id, finished.id);
      expect(saved.single.durationMs, finished.durationMs);
      expect(saved.single.pausedTotalMs, finished.pausedTotalMs);
      notifier.dispose();
    });
  });
}
