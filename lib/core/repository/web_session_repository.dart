import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_session.dart';
import 'session_repository.dart';

/// Offline-first web repository that persists reading sessions in SharedPreferences
/// with 0 setup, surviving page refresh, browser restarts, and offline mode.
class WebSessionRepository implements SessionRepository {
  final SharedPreferences _prefs;
  static const _storageKey = 'pageclock_web_sessions_v1';

  final Map<String, ReadingSession> _cache = {};
  final _allController = StreamController<List<ReadingSession>>.broadcast();
  final _activeController = StreamController<ReadingSession?>.broadcast();

  WebSessionRepository(this._prefs) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        for (final item in list) {
          final session = ReadingSession.fromMap(item as Map<String, dynamic>);
          _cache[session.id] = session;
        }
      } catch (e) {
        debugPrint('[WebSessionRepository] Error loading sessions: $e');
      }
    }
    _broadcast();
  }

  Future<void> _commit() async {
    try {
      final list = _cache.values.map((s) => s.toMap()).toList();
      final saved = await _prefs.setString(_storageKey, json.encode(list));
      if (!saved) {
        throw StateError('Browser storage rejected the PageClock session update.');
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

  ReadingSession? _getActiveInternal() {
    final openRows = _cache.values
        .where((s) => s.endedAtUtc == null && s.deletedAt == null)
        .toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    if (openRows.isEmpty) return null;

    if (openRows.length > 1) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (int i = 1; i < openRows.length; i++) {
        final orphaned = openRows[i];
        final dur = orphaned.durationMs > 0
            ? orphaned.durationMs
            : (now - orphaned.startedAtUtc - orphaned.pausedTotalMs).clamp(0, 86400000);
        _cache[orphaned.id] = orphaned.copyWith(
          endedAtUtc: now,
          durationMs: dur,
          updatedAt: now,
        );
      }
    }

    return openRows.first;
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
      final timestamp = deletedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
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
    return _getActiveInternal();
  }

  @override
  Future<List<ReadingSession>> getAllSessions() async {
    final list = _cache.values.where((s) => s.deletedAt == null).toList();
    list.sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return list;
  }

  @override
  Future<List<ReadingSession>> getSessionsBetween(int startUtc, int endUtc) async {
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
  Stream<ReadingSession?> watchActiveSession() {
    final initial = _getActiveInternal();
    return Stream.value(initial).concatWith([_activeController.stream]);
  }

  @override
  Future<void> hardDeleteAll() async {
    final previous = Map<String, ReadingSession>.of(_cache);
    _cache.clear();
    try {
      final hadStoredSessions = _prefs.containsKey(_storageKey);
      final removed = await _prefs.remove(_storageKey);
      if (hadStoredSessions && !removed) {
        throw StateError('Browser storage rejected the PageClock data reset.');
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

  @override
  void seedSampleData() {
    // Strictly debug/testing helper
  }
}
