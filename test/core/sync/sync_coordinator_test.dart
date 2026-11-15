import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/account/account_scope.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/web_session_repository.dart';
import 'package:pageclock/core/sync/cloud_session_data_source.dart';
import 'package:pageclock/core/sync/sync_coordinator.dart';
import 'package:pageclock/core/sync/sync_meta.dart';
import 'package:pageclock/core/sync/sync_status.dart';

class MockCloudSessionDataSource implements CloudSessionDataSource {
  final List<CloudSessionRow> remoteRows = [];
  final List<ReadingSession> pushedBatches = [];
  final List<ReadingSession> pushedSingles = [];

  bool failNextBatchWithPoisonPill = false;
  String poisonPillSessionId = '';
  bool failWithUserCap = false;

  @override
  Future<CloudPullResponse> pullSessions({
    required String userId,
    required int afterServerSeq,
    int limit = 500,
  }) async {
    final matching = remoteRows
        .where((r) => r.serverSeq > afterServerSeq)
        .take(limit)
        .toList();

    int maxSeq = afterServerSeq;
    for (final r in matching) {
      if (r.serverSeq > maxSeq) {
        maxSeq = r.serverSeq;
      }
    }

    return CloudPullResponse(rows: matching, maxServerSeq: maxSeq);
  }

  @override
  Future<void> pushBatch({
    required String userId,
    required List<ReadingSession> sessions,
  }) async {
    if (failWithUserCap) {
      throw Exception('reading_sessions_user_cap (P0001)');
    }
    if (failNextBatchWithPoisonPill) {
      failNextBatchWithPoisonPill = false;
      throw Exception('PostgrestException: Check constraint violated');
    }
    pushedBatches.addAll(sessions);
  }

  @override
  Future<void> pushSingle({
    required String userId,
    required ReadingSession session,
  }) async {
    if (session.id == poisonPillSessionId) {
      throw Exception('PostgrestException: Invalid session ID format');
    }
    pushedSingles.add(session);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReadingSession createSession({
    required String id,
    required int updatedAt,
    int? endedAtUtc = 1700001800000,
    int? deletedAt,
    String? note = 'Sync test session',
  }) {
    return ReadingSession(
      id: id,
      startedAtUtc: 1700000000000,
      endedAtUtc: endedAtUtc,
      durationMs: 1800000,
      tzOffsetMin: 0,
      note: note,
      source: 'timer',
      createdAt: 1700000000000,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  group('SyncCoordinator Engine & Lifecycle (M4)', () {
    late SharedPreferences prefs;
    late WebSessionRepository repository;
    late MockCloudSessionDataSource dataSource;
    const userId = 'usr_test_coordinator_123';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = WebSessionRepository(
        prefs,
        storageKey: AccountScope.userSessionsKey(userId),
        isUser: true,
      );
      dataSource = MockCloudSessionDataSource();
    });

    test('happy path: pulls remote changes and pushes local dirty sessions', () async {
      // 1. Add remote row
      final remoteSession = createSession(id: 'sess_remote_1', updatedAt: 2000, note: 'From Cloud');
      dataSource.remoteRows.add(CloudSessionRow(session: remoteSession, serverSeq: 10));

      // 2. Add local dirty session
      final localSession = createSession(id: 'sess_local_1', updatedAt: 1500, note: 'From Local Device');
      await repository.saveSession(localSession);

      final coordinator = SyncCoordinator(
        prefs: prefs,
        repository: repository,
        dataSource: dataSource,
        userId: userId,
      );

      // Wait for initialization sync
      await coordinator.sync();

      // Local repository now contains both sessions
      final allSessions = await repository.getAllSessions();
      expect(allSessions.length, equals(2));
      expect(allSessions.any((s) => s.id == 'sess_remote_1'), isTrue);
      expect(allSessions.any((s) => s.id == 'sess_local_1'), isTrue);

      // Push was acknowledged
      expect(dataSource.pushedBatches.any((s) => s.id == 'sess_local_1'), isTrue);

      // Cursor was updated to highest serverSeq
      expect(coordinator.syncMeta.cursor, equals(10));

      // Status is synced
      expect(coordinator.state.status, equals(SyncStatus.synced));
    });

    test('pulled rows are not echoed back in push batch', () async {
      final remoteSession = createSession(id: 'sess_remote_echo_test', updatedAt: 5000);
      dataSource.remoteRows.add(CloudSessionRow(session: remoteSession, serverSeq: 1));

      final coordinator = SyncCoordinator(
        prefs: prefs,
        repository: repository,
        dataSource: dataSource,
        userId: userId,
      );

      await coordinator.sync();

      // Pushed batches must be empty because the pulled row was not locally dirty!
      expect(dataSource.pushedBatches, isEmpty);
      expect(coordinator.state.status, equals(SyncStatus.synced));
    });

    test('cursor overlap test: device pulls row committed with older timestamp', () async {
      final coordinator = SyncCoordinator(
        prefs: prefs,
        repository: repository,
        dataSource: dataSource,
        userId: userId,
      );

      // Suppose device A already progressed cursor to 250
      coordinator.syncMeta.cursor = 250;
      await coordinator.syncMeta.save(prefs);

      // Device B commits an offline session with server_seq = 210 (within the 200-row overlap)
      final lateRow = createSession(id: 'sess_late_offline', updatedAt: 1000);
      dataSource.remoteRows.add(CloudSessionRow(session: lateRow, serverSeq: 210));

      // Device A syncs with default overlap (200 rows)
      await coordinator.sync(firstPullOverlap: 200);

      // Device A successfully pulled the row
      final all = await repository.getAllSessions();
      expect(all.any((s) => s.id == 'sess_late_offline'), isTrue);
    });

    test('poison-pill handling: isolates invalid row into quarantine, remaining rows sync', () async {
      final validSession = createSession(id: 'sess_valid_1', updatedAt: 1000);
      final poisonSession = createSession(id: 'sess_poison_2', updatedAt: 1000);

      await repository.saveSession(validSession);
      await repository.saveSession(poisonSession);

      dataSource.failNextBatchWithPoisonPill = true;
      dataSource.poisonPillSessionId = 'sess_poison_2';

      final coordinator = SyncCoordinator(
        prefs: prefs,
        repository: repository,
        dataSource: dataSource,
        userId: userId,
      );

      await coordinator.sync();

      // Batch failed, single push succeeded for valid row and failed for poison row
      expect(dataSource.pushedSingles.any((s) => s.id == 'sess_valid_1'), isTrue);
      expect(coordinator.syncMeta.quarantine.containsKey('sess_poison_2'), isTrue);
      expect(coordinator.syncMeta.isDirty(poisonSession), isFalse); // Quarantined rows excluded
      expect(coordinator.state.status, equals(SyncStatus.needsAttention));
      expect(coordinator.state.quarantinedCount, equals(1));
    });

    test('server storage cap (P0001) surfaces account limit status', () async {
      final session = createSession(id: 'sess_limit', updatedAt: 1000);
      await repository.saveSession(session);

      dataSource.failWithUserCap = true;

      final coordinator = SyncCoordinator(
        prefs: prefs,
        repository: repository,
        dataSource: dataSource,
        userId: userId,
      );

      await coordinator.sync();

      expect(coordinator.state.status, equals(SyncStatus.needsAttention));
      expect(coordinator.state.hasStorageCapError, isTrue);
      expect(coordinator.state.message, contains('20,000'));
    });

    test('guest import: merge option imports completed sessions and preserves guest partition', () async {
      // 1. Populate guest partition with 1 completed and 1 running session
      final guestSessions = [
        createSession(id: 'guest_completed_1', updatedAt: 1000, endedAtUtc: 1700001800000),
        createSession(id: 'guest_running_2', updatedAt: 1000, endedAtUtc: null), // Running timer
      ];
      await prefs.setString(
        AccountScope.guestSessionsKey,
        json.encode(guestSessions.map((s) => s.toMap()).toList()),
      );

      final coordinator = SyncCoordinator(
        prefs: prefs,
        repository: repository,
        dataSource: dataSource,
        userId: userId,
      );

      // Verify guest prompt is required
      expect(coordinator.shouldPromptGuestImport(), isTrue);

      // User chooses Merge
      await coordinator.handleGuestImport(GuestImportChoice.merge);

      // Completed session was imported into user partition
      final userSessions = await repository.getAllSessions();
      expect(userSessions.any((s) => s.id == 'guest_completed_1'), isTrue);
      // Running timer must NEVER be imported
      expect(userSessions.any((s) => s.id == 'guest_running_2'), isFalse);

      // Invariant: Guest partition was NOT modified or deleted
      final guestRaw = prefs.getString(AccountScope.guestSessionsKey);
      expect(guestRaw, isNotNull);
      final guestList = json.decode(guestRaw!) as List<dynamic>;
      expect(guestList.length, equals(2));

      // Guest import log records this user
      final logRaw = prefs.getString(AccountScope.guestImportLogKey);
      expect(logRaw, contains(userId));
    });
  });
}
