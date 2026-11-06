import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_session.dart';

abstract class SessionRepository {
  Future<void> saveSession(ReadingSession session);
  Future<void> updateSession(ReadingSession session);
  Future<void> softDeleteSession(String id);
  Future<ReadingSession?> getActiveSession();
  Future<List<ReadingSession>> getAllSessions();
  Future<List<ReadingSession>> getSessionsBetween(int startUtc, int endUtc);
  Stream<List<ReadingSession>> watchAllSessions();
  Stream<ReadingSession?> watchActiveSession();
}

class InMemorySessionRepository implements SessionRepository {
  final Map<String, ReadingSession> _storage = {};
  final _controller = StreamController<List<ReadingSession>>.broadcast();
  final _activeController = StreamController<ReadingSession?>.broadcast();

  InMemorySessionRepository([List<ReadingSession>? initial]) {
    if (initial != null) {
      for (final s in initial) {
        _storage[s.id] = s;
      }
    }
  }

  void _notify() {
    final list = _storage.values.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    _controller.add(list);

    final active = _storage.values.firstWhere(
      (s) => s.endedAtUtc == null && s.deletedAt == null,
      orElse: () => null as dynamic,
    );
    _activeController.add(active);
  }

  @override
  Future<void> saveSession(ReadingSession session) async {
    _storage[session.id] = session;
    _notify();
  }

  @override
  Future<void> updateSession(ReadingSession session) async {
    _storage[session.id] = session;
    _notify();
  }

  @override
  Future<void> softDeleteSession(String id) async {
    final existing = _storage[id];
    if (existing != null) {
      _storage[id] = existing.copyWith(
        deletedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      _notify();
    }
  }

  @override
  Future<ReadingSession?> getActiveSession() async {
    for (final s in _storage.values) {
      if (s.endedAtUtc == null && s.deletedAt == null) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<List<ReadingSession>> getAllSessions() async {
    final list = _storage.values.where((s) => s.deletedAt == null).toList();
    list.sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return list;
  }

  @override
  Future<List<ReadingSession>> getSessionsBetween(int startUtc, int endUtc) async {
    return _storage.values
        .where((s) =>
            s.deletedAt == null &&
            s.startedAtUtc >= startUtc &&
            s.startedAtUtc <= endUtc)
        .toList();
  }

  @override
  Stream<List<ReadingSession>> watchAllSessions() => _controller.stream;

  @override
  Stream<ReadingSession?> watchActiveSession() => _activeController.stream;
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return InMemorySessionRepository();
});
