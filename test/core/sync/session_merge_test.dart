import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/sync/session_merge.dart';

void main() {
  ReadingSession createSession({
    required String id,
    required int updatedAt,
    int? deletedAt,
    String? note = 'Initial note',
    int durationMs = 1800000,
  }) {
    return ReadingSession(
      id: id,
      startedAtUtc: 1700000000000,
      endedAtUtc: 1700001800000,
      durationMs: durationMs,
      tzOffsetMin: 0,
      source: 'timer',
      note: note,
      createdAt: 1700000000000,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  group('SessionMerge Pure LWW & Tie-Breaking Rules (§8.4)', () {
    test('local wins when strictly newer than remote', () {
      final local = createSession(id: 's1', updatedAt: 2000, note: 'Local Newer');
      final remote = createSession(id: 's1', updatedAt: 1000, note: 'Remote Older');

      final result = SessionMerge.merge(local: local, remote: remote);

      expect(result.winner, equals(MergeWinner.local));
      expect(result.session.note, equals('Local Newer'));
      expect(result.session.updatedAt, equals(2000));
    });

    test('remote wins when strictly newer than local', () {
      final local = createSession(id: 's1', updatedAt: 1000, note: 'Local Older');
      final remote = createSession(id: 's1', updatedAt: 3000, note: 'Remote Newer');

      final result = SessionMerge.merge(local: local, remote: remote);

      expect(result.winner, equals(MergeWinner.remote));
      expect(result.session.note, equals('Remote Newer'));
      expect(result.session.updatedAt, equals(3000));
    });

    test('equal timestamps: tombstone beats live row (local tombstone)', () {
      final local = createSession(id: 's1', updatedAt: 5000, deletedAt: 5000, note: 'Should be cleared');
      final remote = createSession(id: 's1', updatedAt: 5000, deletedAt: null, note: 'Live Remote');

      final result = SessionMerge.merge(local: local, remote: remote);

      expect(result.winner, equals(MergeWinner.local));
      expect(result.session.deletedAt, equals(5000));
      // Note must be sanitized to null on tombstone
      expect(result.session.note, isNull);
      expect(result.hadConflict, isTrue);
    });

    test('equal timestamps: tombstone beats live row (remote tombstone)', () {
      final local = createSession(id: 's1', updatedAt: 5000, deletedAt: null, note: 'Live Local');
      final remote = createSession(id: 's1', updatedAt: 5000, deletedAt: 5000, note: 'Remote Tombstone');

      final result = SessionMerge.merge(local: local, remote: remote);

      expect(result.winner, equals(MergeWinner.remote));
      expect(result.session.deletedAt, equals(5000));
      expect(result.session.note, isNull);
      expect(result.hadConflict, isTrue);
    });

    test('equal timestamps: server (remote) row wins when both are live', () {
      final local = createSession(id: 's1', updatedAt: 5000, note: 'Local Content');
      final remote = createSession(id: 's1', updatedAt: 5000, note: 'Server Content');

      final result = SessionMerge.merge(local: local, remote: remote);

      // Server row wins on identical timestamp
      expect(result.winner, equals(MergeWinner.remote));
      expect(result.session.note, equals('Server Content'));
      expect(result.hadConflict, isTrue);
    });

    test('equal timestamps: server (remote) row wins when both are tombstones', () {
      final local = createSession(id: 's1', updatedAt: 5000, deletedAt: 5000);
      final remote = createSession(id: 's1', updatedAt: 5000, deletedAt: 5000);

      final result = SessionMerge.merge(local: local, remote: remote);

      expect(result.winner, equals(MergeWinner.remote));
      expect(result.session.deletedAt, equals(5000));
    });

    test('tombstone vs older live: newer tombstone wins', () {
      final liveOlder = createSession(id: 's1', updatedAt: 1000, deletedAt: null);
      final tombstoneNewer = createSession(id: 's1', updatedAt: 2000, deletedAt: 2000);

      final result = SessionMerge.merge(local: tombstoneNewer, remote: liveOlder);

      expect(result.winner, equals(MergeWinner.local));
      expect(result.session.deletedAt, equals(2000));
    });

    test('restore-after-delete: newer restored live session beats older tombstone', () {
      final tombstone = createSession(id: 's1', updatedAt: 2000, deletedAt: 2000);
      // User tapped Undo: restored session has fresh updatedAt = 3000 > 2000, and clearDeletedAt = true
      final restored = createSession(id: 's1', updatedAt: 3000, deletedAt: null, note: 'Restored session');

      final result = SessionMerge.merge(local: restored, remote: tombstone);

      expect(result.winner, equals(MergeWinner.local));
      expect(result.session.deletedAt, isNull);
      expect(result.session.note, equals('Restored session'));
      expect(result.session.updatedAt, equals(3000));
    });

    test('single non-null participant returns sanitized version', () {
      final remote = createSession(id: 's2', updatedAt: 1000, deletedAt: 1000, note: 'Old note');
      final result = SessionMerge.merge(local: null, remote: remote);

      expect(result.winner, equals(MergeWinner.remote));
      expect(result.session.id, equals('s2'));
      expect(result.session.note, isNull); // Sanitized tombstone
    });
  });
}
