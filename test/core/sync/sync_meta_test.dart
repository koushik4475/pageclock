import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/sync/sync_meta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReadingSession createSession({
    required String id,
    required int updatedAt,
    int? endedAtUtc = 1700001800000,
    int? deletedAt,
  }) {
    return ReadingSession(
      id: id,
      startedAtUtc: 1700000000000,
      endedAtUtc: endedAtUtc,
      durationMs: 1800000,
      tzOffsetMin: 0,
      source: 'timer',
      createdAt: 1700000000000,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  group('SyncMeta Dirty Derivation & State Tracking (§8.2)', () {
    late SyncMeta meta;

    setUp(() {
      meta = SyncMeta(userId: 'test_user_123');
    });

    test('completed session with no syncedVersion is dirty', () {
      final session = createSession(id: 's1', updatedAt: 1000);
      expect(meta.isDirty(session), isTrue);
    });

    test('running session (endedAtUtc == null) is NEVER dirty', () {
      final runningSession = createSession(
        id: 's_running',
        updatedAt: 1000,
        endedAtUtc: null,
      );
      expect(meta.isDirty(runningSession), isFalse);
    });

    test('cancel() tombstone of a running row (endedAtUtc == null) is NEVER dirty', () {
      final cancelTombstone = createSession(
        id: 's_cancelled_running',
        updatedAt: 1000,
        endedAtUtc: null,
        deletedAt: 1000,
      );
      expect(meta.isDirty(cancelTombstone), isFalse);
    });

    test('completed session acknowledged by server is NOT dirty', () {
      final session = createSession(id: 's1', updatedAt: 2000);
      meta.markSynced('s1', 2000);
      expect(meta.isDirty(session), isFalse);
    });

    test('edit-while-in-flight stays dirty after older push acknowledges', () {
      final sessionOld = createSession(id: 's1', updatedAt: 2000);
      // User edits session locally while push of version 2000 is mid-flight
      final sessionEdited = createSession(id: 's1', updatedAt: 2500);

      // Server acknowledges the version that was pushed (2000)
      meta.markSynced('s1', sessionOld.updatedAt);

      // The edited session must remain dirty for the next sync cycle!
      expect(meta.isDirty(sessionEdited), isTrue);
    });

    test('quarantined rows are excluded from dirty batch', () {
      final session = createSession(id: 's_bad', updatedAt: 1000);
      expect(meta.isDirty(session), isTrue);

      meta.markQuarantined('s_bad', 'P0001: Check constraint violation');
      expect(meta.isDirty(session), isFalse);
      expect(meta.quarantine.containsKey('s_bad'), isTrue);

      meta.clearQuarantine('s_bad');
      expect(meta.isDirty(session), isTrue);
    });

    test('cursor advances monotonically and resets for full resync', () {
      expect(meta.cursor, equals(0));
      meta.updateCursor(50);
      expect(meta.cursor, equals(50));

      // Does not regress if smaller number provided
      meta.updateCursor(30);
      expect(meta.cursor, equals(50));

      meta.updateCursor(120);
      expect(meta.cursor, equals(120));

      meta.resetCursor();
      expect(meta.cursor, equals(0));
    });

    test('serialization round-trip through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      meta.cursor = 450;
      meta.markSynced('sess_1', 1700000000000);
      meta.markSynced('sess_2', 1700000050000);
      meta.markQuarantined('sess_bad', 'Note exceeded length');
      meta.importChoice = GuestImportChoice.merge;

      final saved = await meta.save(prefs);
      expect(saved, isTrue);

      final loaded = SyncMeta.load(prefs, 'test_user_123');
      expect(loaded.userId, equals('test_user_123'));
      expect(loaded.cursor, equals(450));
      expect(loaded.syncedVersions['sess_1'], equals(1700000000000));
      expect(loaded.syncedVersions['sess_2'], equals(1700000050000));
      expect(loaded.quarantine['sess_bad'], equals('Note exceeded length'));
      expect(loaded.importChoice, equals(GuestImportChoice.merge));
    });
  });
}
