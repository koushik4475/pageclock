import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/db/app_database.dart';
import 'package:pageclock/core/models/reading_session.dart';

void main() {
  late AppDatabase database;
  late DriftSessionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSessionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('SQLite handles concurrent session writes and ordered reads', () async {
    const total = 2000;
    final base = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

    await Future.wait(List.generate(total, (index) {
      final start = base + index * 60000;
      return repository.saveSession(
        ReadingSession(
          id: 'pressure-$index',
          startedAtUtc: start,
          endedAtUtc: start + 45000,
          durationMs: 45000,
          tzOffsetMin: 330,
          subjectId: 'subject-${index % 8}',
          note: 'SQLite persistence pressure record $index',
          source: index.isEven ? 'timer' : 'manual',
          createdAt: start,
          updatedAt: start + 45000,
        ),
      );
    }));

    final sessions = await repository.getAllSessions();
    expect(sessions, hasLength(total));
    expect(sessions.first.id, 'pressure-${total - 1}');
    expect(sessions.last.id, 'pressure-0');
    expect(sessions[1000].note, 'SQLite persistence pressure record 999');
  });

  test('active-session recovery keeps newest and closes orphaned timers', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var index = 0; index < 3; index++) {
      await repository.saveSession(
        ReadingSession(
          id: 'orphan-$index',
          startedAtUtc: now - (3000 - index * 1000),
          tzOffsetMin: 0,
          createdAt: now - (3000 - index * 1000),
          updatedAt: now,
        ),
      );
    }

    final active = await repository.getActiveSession();
    expect(active?.id, 'orphan-2');

    final all = await repository.getAllSessions();
    final open = all.where((session) => session.endedAtUtc == null).toList();
    expect(open, hasLength(1));
    expect(open.single.id, 'orphan-2');

    final recovered = all.where((session) => session.id != 'orphan-2');
    expect(recovered.every((session) => session.endedAtUtc != null), isTrue);
    expect(recovered.every((session) => session.durationMs >= 0), isTrue);
  });

  test('soft deletion is durable and does not remove unrelated sessions', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['keep-a', 'delete-me', 'keep-b']) {
      await repository.saveSession(
        ReadingSession(
          id: id,
          startedAtUtc: now,
          endedAtUtc: now + 1000,
          durationMs: 1000,
          tzOffsetMin: 0,
          createdAt: now,
          updatedAt: now + 1000,
        ),
      );
    }

    await repository.softDeleteSession('delete-me');
    final visible = await repository.getAllSessions();
    expect(visible.map((session) => session.id).toSet(), {'keep-a', 'keep-b'});
  });
}
