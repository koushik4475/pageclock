import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_session.dart';
import 'session_repository.dart';
import '../sync/cloud_sync_session_repository.dart';

/// Offline-first web repository that persists reading sessions in SharedPreferences
/// partitioned by account scope.
///
/// Features:
/// 1. Injectable storage partition key (guest vs user:<uid>).
/// 2. Read-merge-write in [_commit] with [SharedPreferences.reload] for cross-tab safety.
/// 3. Tombstone-on-clear for user scope in [hardDeleteAll] to prevent cloud resurrection.
/// 4. Sync methods for cloud coordinator ([allForSync], [applyRemote], [reloadFromStorage]).
class WebSessionRepository implements SessionRepository, CloudSyncSessionRepository {
  final SharedPreferences _prefs;
  final String _storageKey;
  final bool isUserScope;

  static const defaultStorageKey = 'pageclock_web_sessions_v1';

  final Map<String, ReadingSession> _cache = {};
  final _allController = StreamController<List<ReadingSession>>.broadcast();
  final _activeController = StreamController<ReadingSession?>.broadcast();
  final int Function() _nowUtcMs;

  static int _systemUtcNowMs() =>
      DateTime.now().toUtc().millisecondsSinceEpoch;

  WebSessionRepository(
    this._prefs, {
    String storageKey = defaultStorageKey,
    bool? isUser,
    int Function()? nowUtcMs,
  })  : _storageKey = storageKey,
        isUserScope = isUser ?? storageKey.contains('_user_'),
        _nowUtcMs = nowUtcMs ?? _systemUtcNowMs {
    _loadFromStorage();
  }

  String get storageKey => _storageKey;

  void _loadFromStorage() {
    final raw = _prefs.getString(_storageKey);
    _cache.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        for (final item in list) {
          final session = ReadingSession.fromMap(
            Map<String, dynamic>.from(item as Map),
          );
          _cache[session.id] = session;
        }
      } catch (e) {
        debugPrint('[WebSessionRepository] Error loading sessions: $e');
      }
    }
    _broadcast();
  }

  /// Reloads repository data from storage and notifies listeners.
  /// Used by tab sync listeners and external updates.
  Future<void> reloadFromStorage() async {
    try {
      await _prefs.reload();
      _loadFromStorage();
    } catch (e) {
      debugPrint('[WebSessionRepository] Error reloading from storage: $e');
    }
  }

  /// Commits current cache to disk.
  Future<void> _commit() async {
    try {
      final list = _cache.values.map((s) => s.toMap()).toList();
      final saved = await _prefs.setString(_storageKey, json.encode(list));
      if (!saved) {
        throw StateError(
          'Browser storage is full. Please export your reading data.',
        );
      }
      _broadcast();
    } catch (e) {
      debugPrint('[WebSessionRepository] Error saving sessions: $e');
      rethrow;
    }
  }

  void _broadcast() {
    final active = _getActiveInternal();
    _activeController.add(active);

    final all = _cache.values.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    _allController.add(all);
  }

  /// Closes every older open session before exposing the active one.
  ///
  /// The native Drift repository performs the same recovery in its database.
  /// Persisting this repair on web is essential: an in-memory-only repair would
  /// be lost on reload, and a paused orphan would incorrectly count its final
  /// pause as focused time on the next launch.
  Future<void> _reconcileOrphanedSessions() async {
    final openRows = _cache.values
        .where((session) => session.endedAtUtc == null && session.deletedAt == null)
        .toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    if (openRows.length <= 1) return;

    final now = _nowUtcMs();
    final previous = <String, ReadingSession>{};
    final repaired = <String, ReadingSession>{};

    for (final orphaned in openRows.skip(1)) {
      final pausedAt = orphaned.pausedAtUtc;
      final finalPauseMs =
          pausedAt != null && now > pausedAt ? now - pausedAt : 0;
      final completedPauses = <PauseInterval>[
        ...orphaned.pauseIntervals,
        if (finalPauseMs > 0)
          PauseInterval(startedAtUtc: pausedAt!, endedAtUtc: now),
      ];

      // Calculate from the still-open record so a stale denormalized
      // durationMs cannot override the current elapsed/pause state.
      final focusedDurationMs = orphaned.activeDurationMs(nowUtcMs: now);
      final updated = orphaned.copyWith(
        endedAtUtc: now,
        clearPausedAtUtc: true,
        pausedTotalMs: orphaned.pausedTotalMs + finalPauseMs,
        pauseIntervals: completedPauses,
        durationMs: focusedDurationMs,
        updatedAt: now,
      );

      previous[orphaned.id] = orphaned;
      repaired[orphaned.id] = updated;
      _cache[orphaned.id] = updated;
    }

    try {
      await _commit();
    } catch (_) {
      // Roll back only rows that still contain our repair, so a concurrent
      // edit to a different row is not discarded if storage rejects the write.
      for (final entry in repaired.entries) {
        if (identical(_cache[entry.key], entry.value)) {
          _cache[entry.key] = previous[entry.key]!;
        }
      }
      _broadcast();
      rethrow;
    }
  }

  ReadingSession? _getActiveInternal() {
    final openRows = _cache.values
        .where((session) => session.endedAtUtc == null && session.deletedAt == null)
        .toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    return openRows.isEmpty ? null : openRows.first;
  }

  @override
  Future<void> saveSession(ReadingSession session) async {
    final hadPrevious = _cache.containsKey(session.id);
    final previous = _cache[session.id];
    _cache[session.id] = session;
    try {
      await _commit();
    } catch (_) {
      if (hadPrevious) {
        _cache[session.id] = previous!;
      } else {
        _cache.remove(session.id);
      }
      _broadcast();
      rethrow;
    }
  }

  @override
  Future<void> updateSession(ReadingSession session) async {
    await saveSession(session);
  }

  @override
  Future<void> softDeleteSession(String id, {int? deletedAt}) async {
    final session = _cache[id];
    if (session != null) {
      final timestamp =
          deletedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
      _cache[id] = session.copyWith(
        deletedAt: timestamp,
        updatedAt: timestamp,
      );
      try {
        await _commit();
      } catch (_) {
        _cache[id] = session;
        _broadcast();
        rethrow;
      }
    }
  }

  @override
  Future<bool> restoreSoftDeletedSession({
    required ReadingSession session,
    required int expectedDeletedAt,
  }) async {
    final current = _cache[session.id];
    if (current == null ||
        current.deletedAt != expectedDeletedAt ||
        current.updatedAt != expectedDeletedAt) {
      return false;
    }

    _cache[session.id] = session.copyWith(
      clearDeletedAt: true,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    try {
      await _commit();
      return true;
    } catch (_) {
      _cache[session.id] = current;
      _broadcast();
      rethrow;
    }
  }

  @override
  Future<ReadingSession?> getActiveSession() async {
    await _reconcileOrphanedSessions();
    return _getActiveInternal();
  }

  @override
  Future<List<ReadingSession>> getAllSessions() async {
    final list = _cache.values.where((s) => s.deletedAt == null).toList();
    list.sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return list;
  }

  @override
  Future<List<ReadingSession>> getSessionsBetween(
      int startUtc, int endUtc) async {
    return _cache.values
        .where((s) =>
            s.deletedAt == null &&
            s.startedAtUtc >= startUtc &&
            s.startedAtUtc <= endUtc)
        .toList();
  }

  @override
  Stream<List<ReadingSession>> watchAllSessions() {
    final initial = _cache.values.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return Stream.value(initial).concatWith([_allController.stream]);
  }

  @override
  Stream<ReadingSession?> watchActiveSession() async* {
    await _reconcileOrphanedSessions();
    yield _getActiveInternal();
    yield* _activeController.stream;
  }

  @override
  Future<void> hardDeleteAll() async {
    if (isUserScope) {
      // User scope: soft-delete every session with tombstones so that
      // the deletions sync to cloud rather than resurrecting on next pull.
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final previous = Map<String, ReadingSession>.of(_cache);
      for (final id in _cache.keys.toList()) {
        final s = _cache[id]!;
        _cache[id] = s.copyWith(
          deletedAt: now,
          updatedAt: now,
          clearNote: true,
        );
      }
      try {
        await _commit();
      } catch (_) {
        _cache
          ..clear()
          ..addAll(previous);
        _broadcast();
        rethrow;
      }
    } else {
      // Guest scope: remove key from disk and clear in-memory cache
      final previous = Map<String, ReadingSession>.of(_cache);
      _cache.clear();
      try {
        final hadStoredSessions = _prefs.containsKey(_storageKey);
        final removed = await _prefs.remove(_storageKey);
        if (hadStoredSessions && !removed) {
          throw StateError(
              'Browser storage rejected the PageClock data reset.');
        }
        _broadcast();
      } catch (_) {
        _cache
          ..clear()
          ..addAll(previous);
        _broadcast();
        rethrow;
      }
    }
  }

  // -------------------------------------------------------------
  // Sync-only & partition inspection methods
  // -------------------------------------------------------------

  /// Returns all cached sessions including tombstones (`deletedAt != null`).
  Future<List<ReadingSession>> allForSync() async {
    return _cache.values.toList();
  }

  /// Applies remote sessions pulled from cloud into local partition.
  /// Uses LWW conflict resolution; saves to disk without side effects.
  Future<void> applyRemote(List<ReadingSession> remoteRows) async {
    if (remoteRows.isEmpty) return;

    for (final remote in remoteRows) {
      final local = _cache[remote.id];
      if (local == null) {
        _cache[remote.id] = remote;
      } else {
        if (remote.updatedAt > local.updatedAt) {
          _cache[remote.id] = remote;
        } else if (remote.updatedAt == local.updatedAt) {
          // Tombstone wins on tie
          if (remote.deletedAt != null && local.deletedAt == null) {
            _cache[remote.id] = remote;
          } else if (local.deletedAt != null && remote.deletedAt == null) {
            // Keep local tombstone
          } else {
            // Server wins on identical timestamp
            _cache[remote.id] = remote;
          }
        }
      }
    }

    final list = _cache.values.map((s) => s.toMap()).toList();
    await _prefs.setString(_storageKey, json.encode(list));
    _broadcast();
  }

  @override
  void seedSampleData() {
    // Debug/testing helper
  }
}
