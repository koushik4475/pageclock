import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../account/account_scope.dart';
import '../models/reading_session.dart';
import '../repository/session_repository.dart';
import '../repository/web_session_repository.dart';
import '../settings/app_settings.dart';
import 'cloud_session_data_source.dart';
import 'sync_meta.dart';
import 'sync_status.dart';
import 'sync_web_lock_stub.dart'
    if (dart.library.html) 'sync_web_lock_web.dart';

/// Central coordinator for PageClock cloud synchronization.
///
/// Implements:
/// - Single-flight sync executions.
/// - Cross-tab leader election using Web Locks.
/// - Safe cursor-based pagination with transaction overlap.
/// - Batched push with poison-pill quarantine isolation.
/// - LWW conflict convergence matching server database triggers.
/// - Guest history import flows on first sign-in.
class SyncCoordinator extends StateNotifier<SyncState> {
  final SharedPreferences _prefs;
  final WebSessionRepository _repository;
  final CloudSessionDataSource _dataSource;
  final String _userId;
  final SyncMeta _syncMeta;

  bool _isDisposed = false;
  bool _syncInProgress = false;
  bool _queuedSync = false;
  Timer? _debounceTimer;
  int consecutiveFailures = 0;

  SyncCoordinator({
    required SharedPreferences prefs,
    required WebSessionRepository repository,
    required CloudSessionDataSource dataSource,
    required String userId,
    SyncMeta? syncMeta,
    bool autoSync = true,
  })  : _prefs = prefs,
        _repository = repository,
        _dataSource = dataSource,
        _userId = userId,
        _syncMeta = syncMeta ?? SyncMeta.load(prefs, userId),
        super(const SyncState.localOnly()) {
    if (autoSync) {
      _init();
    }
  }

  SyncMeta get syncMeta => _syncMeta;
  String get userId => _userId;

  void _init() {
    // Initial sync on startup with overlap 1000
    sync(firstPullOverlap: 1000);
  }

  /// Debounced trigger for local session modifications.
  void notifyLocalChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!_isDisposed) {
        sync();
      }
    });
  }

  /// Forces a full resync from sequence 0.
  Future<void> fullResync() async {
    _syncMeta.resetCursor();
    await _syncMeta.save(_prefs);
    await sync(firstPullOverlap: 0);
  }

  /// Main sync execution (Pull -> Merge -> Push -> Acknowledge).
  Future<void> sync({int? firstPullOverlap}) async {
    if (_syncInProgress) {
      _queuedSync = true;
      return;
    }

    _syncInProgress = true;
    state = const SyncState.syncing();

    final lockName = 'pageclock-sync-$_userId';
    try {
      await SyncWebLock.runWithLock(lockName, () async {
        await _performSyncCycle(firstPullOverlap: firstPullOverlap);
      });
      consecutiveFailures = 0;
    } catch (e, st) {
      consecutiveFailures++;
      debugPrint('[SyncCoordinator] Sync failed: $e\n$st');
      final errorMsg = e.toString();
      if (errorMsg.contains('reading_sessions_user_cap') ||
          errorMsg.contains('P0001')) {
        state = SyncState.needsAttention(
          message: 'Account storage limit reached (20,000 sessions).',
          quarantinedCount: _syncMeta.quarantine.length,
          hasStorageCapError: true,
        );
      } else if (errorMsg.contains('network') ||
          errorMsg.contains('SocketException') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('ClientException') ||
          errorMsg.contains('offline')) {
        state = const SyncState.offline();
      } else {
        state = SyncState.needsAttention(
          message: 'Sync error. Changes are saved locally.',
          quarantinedCount: _syncMeta.quarantine.length,
        );
      }
    } finally {
      _syncInProgress = false;
      if (_queuedSync && !_isDisposed) {
        _queuedSync = false;
        sync();
      }
    }
  }

  Future<void> _performSyncCycle({int? firstPullOverlap}) async {
    // -----------------------------------------------------------
    // Step 1: PULL (with overlap to handle out-of-order commits)
    // -----------------------------------------------------------
    final int overlap = firstPullOverlap ?? 200;
    int afterSeq = _syncMeta.cursor > overlap ? _syncMeta.cursor - overlap : 0;
    int highestSeqSeen = _syncMeta.cursor;
    bool hasMore = true;

    while (hasMore && !_isDisposed) {
      final response = await _dataSource.pullSessions(
        userId: _userId,
        afterServerSeq: afterSeq,
        limit: 500,
      );

      if (response.rows.isNotEmpty) {
        final incomingSessions = <ReadingSession>[];
        for (final row in response.rows) {
          if (row.serverSeq > highestSeqSeen) {
            highestSeqSeen = row.serverSeq;
          }
          // Mark in syncedVersions map so incoming rows are never echoed back
          _syncMeta.markSynced(row.session.id, row.session.updatedAt);
          incomingSessions.add(row.session);
        }

        // Apply to local repository using LWW merge
        await _repository.applyRemote(incomingSessions);
        afterSeq = response.maxServerSeq;
      }

      hasMore = response.rows.length >= 500;
    }

    _syncMeta.updateCursor(highestSeqSeen);
    await _syncMeta.save(_prefs);

    // -----------------------------------------------------------
    // Step 2: PUSH (Dirty completed sessions only, batches <= 200)
    // -----------------------------------------------------------
    final allLocal = _repository.allForSync();
    final dirtySessions = allLocal
        .where((s) => _syncMeta.isDirty(s) && s.endedAtUtc != null)
        .toList();

    if (dirtySessions.isNotEmpty) {
      const int batchSize = 200;
      for (int i = 0; i < dirtySessions.length; i += batchSize) {
        final end = (i + batchSize < dirtySessions.length)
            ? i + batchSize
            : dirtySessions.length;
        final batch = dirtySessions.sublist(i, end);

        // Snapshot updatedAt timestamps at the exact instant of dispatch
        final batchSnapshots = {for (final s in batch) s.id: s.updatedAt};

        try {
          await _dataSource.pushBatch(userId: _userId, sessions: batch);
          for (final s in batch) {
            // Acknowledge ONLY the exact timestamp pushed. If the user edited mid-flight,
            // local session will have a higher updatedAt and stay dirty for next cycle.
            _syncMeta.markSynced(s.id, batchSnapshots[s.id]!);
          }
        } catch (e) {
          final errorMsg = e.toString();
          if (errorMsg.contains('reading_sessions_user_cap') ||
              errorMsg.contains('P0001')) {
            rethrow; // Surface storage cap error immediately
          }

          // Poison-pill recovery: retry batch individually to isolate invalid rows
          debugPrint('[SyncCoordinator] Batch failed, isolating rows: $e');
          for (final s in batch) {
            try {
              await _dataSource.pushSingle(userId: _userId, session: s);
              _syncMeta.markSynced(s.id, batchSnapshots[s.id]!);
            } catch (singleErr) {
              _syncMeta.markQuarantined(s.id, singleErr.toString());
            }
          }
        }
      }

      await _syncMeta.save(_prefs);
    }

    // -----------------------------------------------------------
    // Step 3: SUCCESS STATE
    // -----------------------------------------------------------
    if (_syncMeta.quarantine.isNotEmpty) {
      state = SyncState.needsAttention(
        message:
            '${_syncMeta.quarantine.length} sessions could not sync.',
        quarantinedCount: _syncMeta.quarantine.length,
      );
    } else {
      state = SyncState.synced();
    }
  }

  // -------------------------------------------------------------
  // Guest Import Methods
  // -------------------------------------------------------------

  /// Evaluates whether the user should be prompted to import guest sessions.
  bool shouldPromptGuestImport() {
    if (_syncMeta.importChoice != null) return false;
    final guestRaw = _prefs.getString(AccountScope.guestSessionsKey);
    if (guestRaw == null || guestRaw.trim().isEmpty) return false;

    try {
      final list = json.decode(guestRaw) as List<dynamic>;
      for (final item in list) {
        final s = ReadingSession.fromMap(Map<String, dynamic>.from(item as Map));
        if (s.endedAtUtc != null && s.deletedAt == null) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Executes user's guest history import choice.
  Future<void> handleGuestImport(GuestImportChoice choice) async {
    _syncMeta.importChoice = choice;
    await _syncMeta.save(_prefs);

    if (choice == GuestImportChoice.merge) {
      final guestRaw = _prefs.getString(AccountScope.guestSessionsKey);
      if (guestRaw != null && guestRaw.isNotEmpty) {
        try {
          final list = json.decode(guestRaw) as List<dynamic>;
          final completedGuest = <ReadingSession>[];
          for (final item in list) {
            final s = ReadingSession.fromMap(
              Map<String, dynamic>.from(item as Map),
            );
            // Copy completed sessions only; never copy running timers
            if (s.endedAtUtc != null) {
              completedGuest.add(s);
            }
          }

          if (completedGuest.isNotEmpty) {
            await _repository.applyRemote(completedGuest);
            // Record in guest import log for audit/idempotence
            final importLogRaw =
                _prefs.getString(AccountScope.guestImportLogKey) ?? '[]';
            final importLog = List<String>.from(json.decode(importLogRaw) as List);
            if (!importLog.contains(_userId)) {
              importLog.add(_userId);
              await _prefs.setString(
                AccountScope.guestImportLogKey,
                json.encode(importLog),
              );
            }
          }
        } catch (e) {
          debugPrint('[SyncCoordinator] Error importing guest sessions: $e');
        }
      }
    }

    // Trigger sync cycle to push imported history or pull cloud history
    await sync();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for the [SyncCoordinator]. Returns null when in guest scope.
final syncCoordinatorProvider =
    StateNotifierProvider<SyncCoordinator, SyncState>((ref) {
  final scope = ref.watch(accountScopeProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(sessionRepositoryProvider);

  if (scope.isGuest || !scope.isUser) {
    // When in guest scope, coordinator is inactive and reports local-only state
    return _GuestSyncCoordinator(prefs);
  }

  final webRepo = repo as WebSessionRepository;
  final client = Supabase.instance.client;
  final dataSource = SupabaseSessionDataSource(client);

  return SyncCoordinator(
    prefs: prefs,
    repository: webRepo,
    dataSource: dataSource,
    userId: scope.userId!,
  );
});

class _GuestSyncCoordinator extends SyncCoordinator {
  _GuestSyncCoordinator(SharedPreferences prefs)
      : super(
          prefs: prefs,
          repository: WebSessionRepository(prefs),
          dataSource: _NoopDataSource(),
          userId: 'guest',
          syncMeta: SyncMeta(userId: 'guest'),
        ) {
    state = const SyncState.localOnly();
  }

  @override
  void _init() {}

  @override
  Future<void> sync({int? firstPullOverlap}) async {
    state = const SyncState.localOnly();
  }
}

class _NoopDataSource implements CloudSessionDataSource {
  @override
  Future<CloudPullResponse> pullSessions({
    required String userId,
    required int afterServerSeq,
    int limit = 500,
  }) async =>
      const CloudPullResponse(rows: [], maxServerSeq: 0);

  @override
  Future<void> pushBatch({
    required String userId,
    required List<ReadingSession> sessions,
  }) async {}

  @override
  Future<void> pushSingle({
    required String userId,
    required ReadingSession session,
  }) async {}
}
