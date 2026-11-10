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
  });
}
