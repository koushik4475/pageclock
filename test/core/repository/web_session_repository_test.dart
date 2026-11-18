import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/web_session_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReadingSession makeSession({
    required String id,
    required int updatedAt,
    int? deletedAt,
    String? note = 'Sample Note',
  }) {
    return ReadingSession(
      id: id,
      startedAtUtc: 1700000000000,
      endedAtUtc: 1700001800000,
      durationMs: 1800000,
      tzOffsetMin: 0,
      note: note,
      source: 'timer',
      createdAt: 1700000000000,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  ReadingSession makeOpenSession({
    required String id,
    required int startedAtUtc,
    int? pausedAtUtc,
    int pausedTotalMs = 0,
    int durationMs = 0,
    List<PauseInterval> pauseIntervals = const [],
  }) {
    return ReadingSession(
      id: id,
      startedAtUtc: startedAtUtc,
      pausedAtUtc: pausedAtUtc,
      pausedTotalMs: pausedTotalMs,
      durationMs: durationMs,
      pauseIntervals: pauseIntervals,
      tzOffsetMin: 0,
      createdAt: startedAtUtc,
      updatedAt: startedAtUtc,
    );
  }

  group('WebSessionRepository Isolation & Partitioning (M3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getActiveSession persists recovery of an orphaned paused session', () async {
      const key = 'pageclock_web_sessions_v2_guest';
      const now = 1795000000000;
      final startedAt = now - 60 * 60000;
      final pausedAt = now - 20 * 60000;
      final oldPauseStart = startedAt + 10 * 60000;
      final oldPauseEnd = startedAt + 15 * 60000;
      final orphaned = makeOpenSession(
        id: 'orphaned-paused',
        startedAtUtc: startedAt,
        pausedAtUtc: pausedAt,
        pausedTotalMs: 10 * 60000,
        // An open row may carry a stale denormalized duration from an older
        // timer state; recovery must recompute it from elapsed/pause history.
        durationMs: 55 * 60000,
        pauseIntervals: [
          PauseInterval(
            startedAtUtc: oldPauseStart,
            endedAtUtc: oldPauseEnd,
          ),
        ],
      );
      final newest = makeOpenSession(
        id: 'newest-active',
        startedAtUtc: now - 5 * 60000,
      );
      SharedPreferences.setMockInitialValues({
        key: jsonEncode([orphaned.toMap(), newest.toMap()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = WebSessionRepository(
        prefs,
        storageKey: key,
        nowUtcMs: () => now,
      );

      final active = await repo.getActiveSession();
      expect(active?.id, 'newest-active');

      final persisted = (jsonDecode(prefs.getString(key)!) as List)
          .map((row) => ReadingSession.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
      final repaired = persisted.singleWhere((session) => session.id == orphaned.id);
      expect(repaired.endedAtUtc, now);
      expect(repaired.pausedAtUtc, isNull);
      expect(repaired.pausedTotalMs, 30 * 60000);
      expect(repaired.durationMs, 30 * 60000);
      expect(repaired.pauseIntervals, hasLength(2));
      expect(repaired.pauseIntervals.last.startedAtUtc, pausedAt);
      expect(repaired.pauseIntervals.last.endedAtUtc, now);

      // A new repository instance must observe the persisted repair, and a
      // second recovery pass must not move the original end timestamp.
      final reopened = WebSessionRepository(
        prefs,
        storageKey: key,
        nowUtcMs: () => now + 60 * 60000,
      );
      final reopenedActive = await reopened.getActiveSession();
      expect(reopenedActive?.id, 'newest-active');
      final reopenedOrphan = (await reopened.getAllSessions())
          .singleWhere((session) => session.id == orphaned.id);
      expect(reopenedOrphan.endedAtUtc, now);
      expect(reopenedOrphan.durationMs, 30 * 60000);
    });

    test('watchActiveSession persists recovery of an orphaned running session', () async {
      const key = 'pageclock_web_sessions_v2_guest';
      const now = 1795000000000;
      final older = makeOpenSession(
        id: 'older-running',
        startedAtUtc: now - 25 * 60000,
      );
      final newest = makeOpenSession(
        id: 'newest-running',
        startedAtUtc: now - 5 * 60000,
      );
      SharedPreferences.setMockInitialValues({
        key: jsonEncode([older.toMap(), newest.toMap()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = WebSessionRepository(
        prefs,
        storageKey: key,
        nowUtcMs: () => now,
      );

      final active = await repo.watchActiveSession().first;
      expect(active?.id, 'newest-running');

      final persisted = (jsonDecode(prefs.getString(key)!) as List)
          .map((row) => ReadingSession.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
      final repaired = persisted.singleWhere((session) => session.id == older.id);
      expect(repaired.endedAtUtc, now);
      expect(repaired.durationMs, 25 * 60000);
      expect(repaired.pausedAtUtc, isNull);
    });

    test('separate partitions remain completely isolated', () async {
      final prefs = await SharedPreferences.getInstance();

      final guestRepo = WebSessionRepository(
        prefs,
        storageKey: 'pageclock_web_sessions_v2_guest',
      );
      final userRepo = WebSessionRepository(
        prefs,
        storageKey: 'pageclock_web_sessions_v2_user_user_abc',
      );

      await guestRepo.saveSession(makeSession(id: 'sess_guest_1', updatedAt: 1000));
      await userRepo.saveSession(makeSession(id: 'sess_user_1', updatedAt: 1000));

      final guestAll = await guestRepo.getAllSessions();
      final userAll = await userRepo.getAllSessions();

      expect(guestAll.map((s) => s.id), contains('sess_guest_1'));
      expect(guestAll.map((s) => s.id), isNot(contains('sess_user_1')));

      expect(userAll.map((s) => s.id), contains('sess_user_1'));
      expect(userAll.map((s) => s.id), isNot(contains('sess_guest_1')));
    });

    test('cross-tab simulation: reloadFromStorage pulls writes from another repository instance', () async {
      final prefs = await SharedPreferences.getInstance();
      const sharedKey = 'pageclock_web_sessions_v2_guest';

      // Simulate Tab A and Tab B opening the same storage partition
      final tabA = WebSessionRepository(prefs, storageKey: sharedKey);
      final tabB = WebSessionRepository(prefs, storageKey: sharedKey);

      // Tab A writes session A
      await tabA.saveSession(makeSession(id: 'sess_A', updatedAt: 1000, note: 'From Tab A'));

      // Tab B reloads from storage and sees session A
      await tabB.reloadFromStorage();
      var tabBAll = await tabB.getAllSessions();
      expect(tabBAll.length, equals(1));
      expect(tabBAll.single.id, equals('sess_A'));

      // Tab B writes session B
      await tabB.saveSession(makeSession(id: 'sess_B', updatedAt: 1000, note: 'From Tab B'));

      // Tab A reloads from storage and updates session A
      await tabA.reloadFromStorage();
      await tabA.saveSession(makeSession(id: 'sess_A', updatedAt: 2000, note: 'Updated from Tab A'));

      // Tab B reloads from storage and sees both sessions with latest values
      await tabB.reloadFromStorage();

      tabBAll = await tabB.getAllSessions();
      expect(tabBAll.length, equals(2));
      final sessionA = tabBAll.firstWhere((s) => s.id == 'sess_A');
      final sessionB = tabBAll.firstWhere((s) => s.id == 'sess_B');

      expect(sessionA.note, equals('Updated from Tab A'));
      expect(sessionB.note, equals('From Tab B'));
    });

    test('hardDeleteAll in guest scope purges storage key completely', () async {
      final prefs = await SharedPreferences.getInstance();
      const guestKey = 'pageclock_web_sessions_v2_guest';
      final repo = WebSessionRepository(prefs, storageKey: guestKey, isUser: false);

      await repo.saveSession(makeSession(id: 's1', updatedAt: 1000));
      expect(prefs.containsKey(guestKey), isTrue);

      await repo.hardDeleteAll();

      expect(prefs.containsKey(guestKey), isFalse);
      expect((await repo.getAllSessions()), isEmpty);
      expect(await repo.allForSync(), isEmpty);
    });

    test('hardDeleteAll in user scope tombstones all rows to prevent cloud resurrection (§8.5)', () async {
      final prefs = await SharedPreferences.getInstance();
      const userKey = 'pageclock_web_sessions_v2_user_uuid_456';
      final repo = WebSessionRepository(prefs, storageKey: userKey, isUser: true);

      await repo.saveSession(makeSession(id: 's1', updatedAt: 1000, note: 'Important notes'));
      await repo.saveSession(makeSession(id: 's2', updatedAt: 1000, note: 'Chapter 2'));

      await repo.hardDeleteAll();

      // In user scope, key must NOT be deleted from disk
      expect(prefs.containsKey(userKey), isTrue);

      // Visible sessions are empty because they are deleted
      final visibleSessions = await repo.getAllSessions();
      expect(visibleSessions, isEmpty);

      // Sync methods must retain tombstones with cleared notes so deletions sync to server
      final syncRows = await repo.allForSync();
      expect(syncRows.length, equals(2));
      for (final s in syncRows) {
        expect(s.deletedAt, isNotNull);
        expect(s.note, isNull);
        expect(s.updatedAt, greaterThanOrEqualTo(1000));
      }
    });

    test('applyRemote merges incoming rows without losing local unsynced edits', () async {
      final prefs = await SharedPreferences.getInstance();
      const key = 'pageclock_web_sessions_v2_user_test';
      final repo = WebSessionRepository(prefs, storageKey: key, isUser: true);

      // Local session was edited at t=3000
      await repo.saveSession(makeSession(id: 's1', updatedAt: 3000, note: 'Local Edit'));

      // Remote row arrives from another device that was edited at t=2000 (older)
      final olderRemote = makeSession(id: 's1', updatedAt: 2000, note: 'Older Remote');
      // And a new session created on the other device
      final newRemote = makeSession(id: 's2', updatedAt: 2500, note: 'New Remote');

      await repo.applyRemote([olderRemote, newRemote]);

      final all = await repo.getAllSessions();
      expect(all.length, equals(2));

      // Local newer edit must be preserved
      final s1 = all.firstWhere((s) => s.id == 's1');
      expect(s1.note, equals('Local Edit'));
      expect(s1.updatedAt, equals(3000));

      final s2 = all.firstWhere((s) => s.id == 's2');
      expect(s2.note, equals('New Remote'));
    });
  });
}
