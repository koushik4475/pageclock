import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/account/account_scope.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/web_session_migration.dart';

void main() {
  group('Web Session Legacy Migration Baseline (M0)', () {
    late String fixtureJson;

    setUp(() {
      final file = File('test/fixtures/web_sessions_v1.json');
      expect(file.existsSync(), isTrue, reason: 'web_sessions_v1.json fixture must exist');
      fixtureJson = file.readAsStringSync();
    });

    test('v1 fixture parses into ReadingSession list matching real toMap/fromMap format', () {
      final decodedList = json.decode(fixtureJson) as List<dynamic>;
      expect(decodedList.length, equals(5));

      final sessions = decodedList
          .map((item) => ReadingSession.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      expect(sessions.length, equals(5));

      // 1. Completed session
      final completed = sessions.firstWhere((s) => s.id == 'sess_completed_001');
      expect(completed.endedAtUtc, equals(1700001800000));
      expect(completed.pausedAtUtc, isNull);
      expect(completed.isRunning, isFalse);
      expect(completed.isPaused, isFalse);
      expect(completed.durationMs, equals(1800000));
      expect(completed.pauseIntervals, isEmpty);
      expect(completed.subjectId, equals('subj_math'));
      expect(completed.note, equals('Calculus chapter 1'));
      expect(completed.deletedAt, isNull);

      // 2. Session with pause intervals
      final pausedWithIntervals = sessions.firstWhere((s) => s.id == 'sess_paused_intervals_002');
      expect(pausedWithIntervals.pauseIntervals.length, equals(2));
      expect(pausedWithIntervals.pauseIntervals[0].startedAtUtc, equals(1700011000000));
      expect(pausedWithIntervals.pauseIntervals[0].endedAtUtc, equals(1700011600000));
      expect(pausedWithIntervals.pauseIntervals[0].durationMs, equals(600000));
      expect(pausedWithIntervals.pauseIntervals[1].startedAtUtc, equals(1700012400000));
      expect(pausedWithIntervals.pauseIntervals[1].endedAtUtc, equals(1700012800000));
      expect(pausedWithIntervals.pauseIntervals[1].durationMs, equals(400000));
      expect(pausedWithIntervals.pausedTotalMs, equals(1000000));
      expect(pausedWithIntervals.durationMs, equals(3000000));
      expect(pausedWithIntervals.activeDurationMs(), equals(3000000));

      // 3. Legacy session with paused_total_ms > 0 and empty intervals
      final legacy = sessions.firstWhere((s) => s.id == 'sess_legacy_no_intervals_003');
      expect(legacy.pausedTotalMs, equals(600000));
      expect(legacy.pauseIntervals, isEmpty);
      expect(legacy.durationMs, equals(1800000));
      final fallbackActive = legacy.activeIntervals();
      expect(fallbackActive.length, equals(1));
      expect(fallbackActive.first.durationMs, equals(1800000));

      // 4. Soft-deleted row
      final deleted = sessions.firstWhere((s) => s.id == 'sess_soft_deleted_004');
      expect(deleted.deletedAt, equals(1700032000000));
      expect(deleted.note, equals('Discarded draft'));

      // 5. Running row
      final running = sessions.firstWhere((s) => s.id == 'sess_running_005');
      expect(running.endedAtUtc, isNull);
      expect(running.pausedAtUtc, isNull);
      expect(running.isRunning, isTrue);
      expect(running.deletedAt, isNull);
    });

    test('all parsed sessions round-trip losslessly through toMap() and fromMap()', () {
      final decodedList = json.decode(fixtureJson) as List<dynamic>;

      for (final rawItem in decodedList) {
        final originalMap = Map<String, dynamic>.from(rawItem as Map);
        final session = ReadingSession.fromMap(originalMap);
        final serializedMap = session.toMap();
        final rehydratedSession = ReadingSession.fromMap(serializedMap);

        expect(session.id, equals(rehydratedSession.id));
        expect(session.startedAtUtc, equals(rehydratedSession.startedAtUtc));
        expect(session.endedAtUtc, equals(rehydratedSession.endedAtUtc));
        expect(session.pausedAtUtc, equals(rehydratedSession.pausedAtUtc));
        expect(session.pausedTotalMs, equals(rehydratedSession.pausedTotalMs));
        expect(session.durationMs, equals(rehydratedSession.durationMs));
        expect(session.tzOffsetMin, equals(rehydratedSession.tzOffsetMin));
        expect(session.subjectId, equals(rehydratedSession.subjectId));
        expect(session.note, equals(rehydratedSession.note));
        expect(session.source, equals(rehydratedSession.source));
        expect(session.deviceId, equals(rehydratedSession.deviceId));
        expect(session.createdAt, equals(rehydratedSession.createdAt));
        expect(session.updatedAt, equals(rehydratedSession.updatedAt));
        expect(session.deletedAt, equals(rehydratedSession.deletedAt));
        expect(session.pauseIntervals.length, equals(rehydratedSession.pauseIntervals.length));
        for (var i = 0; i < session.pauseIntervals.length; i++) {
          expect(session.pauseIntervals[i].startedAtUtc,
              equals(rehydratedSession.pauseIntervals[i].startedAtUtc));
          expect(session.pauseIntervals[i].endedAtUtc,
              equals(rehydratedSession.pauseIntervals[i].endedAtUtc));
        }
      }
    });

    test('migrates legacy v1 fixture into v2 guest partition idempotently', () async {
      SharedPreferences.setMockInitialValues({
        AccountScope.legacyV1Key: fixtureJson,
      });
      final prefs = await SharedPreferences.getInstance();

      final count = await WebSessionMigration.migrateLegacyV1ToV2Guest(prefs);
      expect(count, equals(5));

      // 1. Invariant: v1 must NEVER be deleted or modified
      expect(prefs.containsKey(AccountScope.legacyV1Key), isTrue);
      expect(prefs.getString(AccountScope.legacyV1Key), equals(fixtureJson));

      // 2. v2 guest partition must contain all 5 migrated sessions
      final rawV2 = prefs.getString(AccountScope.guestSessionsKey);
      expect(rawV2, isNotNull);
      final listV2 = json.decode(rawV2!) as List<dynamic>;
      expect(listV2.length, equals(5));

      // 3. Second run must be fully idempotent
      final secondRunCount = await WebSessionMigration.migrateLegacyV1ToV2Guest(prefs);
      expect(secondRunCount, equals(5));
      expect(prefs.getString(AccountScope.legacyV1Key), equals(fixtureJson));
    });

    test('re-merges newer sessions if an older tab writes to v1 later', () async {
      SharedPreferences.setMockInitialValues({
        AccountScope.legacyV1Key: fixtureJson,
      });
      final prefs = await SharedPreferences.getInstance();

      // Initial migration
      await WebSessionMigration.migrateLegacyV1ToV2Guest(prefs);

      // Simulate an older cached PWA tab writing a newer version of sess_completed_001 to v1
      final decodedList = json.decode(fixtureJson) as List<dynamic>;
      final updatedV1List = decodedList.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        if (m['id'] == 'sess_completed_001') {
          m['updated_at'] = 1700009999000;
          m['note'] = 'Edited in legacy tab';
        }
        return m;
      }).toList();
      await prefs.setString(AccountScope.legacyV1Key, json.encode(updatedV1List));

      // Next app boot re-runs migration
      await WebSessionMigration.migrateLegacyV1ToV2Guest(prefs);

      final rawV2 = prefs.getString(AccountScope.guestSessionsKey);
      final listV2 = json.decode(rawV2!) as List<dynamic>;
      final updatedInV2 = listV2.firstWhere((item) => item['id'] == 'sess_completed_001');

      expect(updatedInV2['note'], equals('Edited in legacy tab'));
      expect(updatedInV2['updated_at'], equals(1700009999000));
    });
  });
}
