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

  group('WebSessionRepository Isolation & Partitioning (M3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

    test('cross-tab simulation: two repository instances on same key do not clobber each other', () async {
      final prefs = await SharedPreferences.getInstance();
      const sharedKey = 'pageclock_web_sessions_v2_guest';

      // Simulate Tab A and Tab B opening the same storage partition
      final tabA = WebSessionRepository(prefs, storageKey: sharedKey);
      final tabB = WebSessionRepository(prefs, storageKey: sharedKey);

      // Tab A writes session A
      await tabA.saveSession(makeSession(id: 'sess_A', updatedAt: 1000, note: 'From Tab A'));

      // Tab B reloads from storage and writes session B
      await tabB.reloadFromStorage();
      await tabB.saveSession(makeSession(id: 'sess_B', updatedAt: 1000, note: 'From Tab B'));

      // Tab A updates session A with a newer timestamp
      await tabA.saveSession(makeSession(id: 'sess_A', updatedAt: 2000, note: 'Updated from Tab A'));

      // Tab A also writes session B that tab B added when reloading
      await tabA.reloadFromStorage();
      await tabB.reloadFromStorage();

      final tabBAll = await tabB.getAllSessions();
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
      expect(repo.allForSync(), isEmpty);
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
      final syncRows = repo.allForSync();
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
