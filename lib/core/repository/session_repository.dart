import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_session.dart';
import '../settings/app_settings.dart';
import 'web_session_repository.dart';
import 'session_repository_platform_stub.dart'
    if (dart.library.io) 'session_repository_platform_native.dart' as platform;

abstract class SessionRepository {
  Future<void> saveSession(ReadingSession session);
  Future<void> updateSession(ReadingSession session);
  Future<void> softDeleteSession(String id);
  Future<ReadingSession?> getActiveSession();
  Future<List<ReadingSession>> getAllSessions();
  Future<List<ReadingSession>> getSessionsBetween(int startUtc, int endUtc);
  Stream<List<ReadingSession>> watchAllSessions();
  Stream<ReadingSession?> watchActiveSession();
  void seedSampleData();
  Future<void> hardDeleteAll();
}

class InMemorySessionRepository implements SessionRepository {
  final Map<String, ReadingSession> _storage = {};
  final _controller = StreamController<List<ReadingSession>>.broadcast();
  final _activeController = StreamController<ReadingSession?>.broadcast();

  InMemorySessionRepository([List<ReadingSession>? initial]) {
    if (initial != null && initial.isNotEmpty) {
      for (final s in initial) {
        _storage[s.id] = s;
      }
    }
  }

  @override
  void seedSampleData() {
    final now = DateTime.now();
    final tz = now.timeZoneOffset.inMinutes;

    // Generate realistic, beautiful 28-day reading history with an ascending trend
    final sampleSessions = <ReadingSession>[];

    // Last 28 days daily reading sessions (1 to 2 sessions per day)
    final dailyMinutesPattern = [
      25, 30, 45, 20, 50, 60, 40, // Week 4 ago
      35, 40, 55, 30, 60, 75, 50, // Week 3 ago
      45, 50, 65, 40, 80, 90, 60, // Week 2 ago
      55, 60, 75, 45, 95, 110, 80 // Current week (ascending)
    ];

    for (int i = 0; i < dailyMinutesPattern.length; i++) {
      final daysAgo = 27 - i;
      final sessionDate = DateTime(now.year, now.month, now.day, 19, 30).subtract(Duration(days: daysAgo));
      final durationMins = dailyMinutesPattern[i];
      final startUtc = sessionDate.toUtc().millisecondsSinceEpoch;
      final durationMs = durationMins * 60 * 1000;

      sampleSessions.add(
        ReadingSession(
          id: 'sample-$i',
          startedAtUtc: startUtc,
          endedAtUtc: startUtc + durationMs,
          durationMs: durationMs,
          tzOffsetMin: tz,
          source: i % 4 == 0 ? 'manual' : 'timer',
          note: i % 3 == 0 ? 'Deep focus chapter' : null,
          createdAt: startUtc,
          updatedAt: startUtc + durationMs,
        ),
      );
    }

    for (final s in sampleSessions) {
      _storage[s.id] = s;
    }
    _notify();
  }

  void _notify() {
    final list = _storage.values.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    _controller.add(list);

    final active = _storage.values.cast<ReadingSession?>().firstWhere(
      (s) => s != null && s.endedAtUtc == null && s.deletedAt == null,
      orElse: () => null,
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
  Future<void> hardDeleteAll() async {
    _storage.clear();
    _notify();
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
  Stream<List<ReadingSession>> watchAllSessions() {
    // Deliver current values immediately
    final list = _storage.values.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return Stream.value(list).concatWith([_controller.stream]);
  }

  @override
  Stream<ReadingSession?> watchActiveSession() => _activeController.stream;
}

extension StreamConcatExtension<T> on Stream<T> {
  Stream<T> concatWith(Iterable<Stream<T>> others) async* {
    yield* this;
    for (final s in others) {
      yield* s;
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return platform.createSessionRepository(prefs);
});
