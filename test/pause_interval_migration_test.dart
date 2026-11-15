import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/db/app_database.dart';
import 'package:pageclock/core/models/reading_session.dart';

void main() {
  test('v2 database upgrade adds pause history without losing sessions', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE reading_sessions (
            id TEXT NOT NULL PRIMARY KEY,
            started_at_utc INTEGER NOT NULL,
            ended_at_utc INTEGER,
            paused_at_utc INTEGER,
            paused_total_ms INTEGER NOT NULL DEFAULT 0,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            tz_offset_min INTEGER NOT NULL DEFAULT 0,
            subject_id TEXT,
            note TEXT,
            source TEXT NOT NULL DEFAULT 'timer',
            device_id TEXT NOT NULL DEFAULT 'local',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          )
        ''');
        database.execute('''
          CREATE TABLE subjects (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0
          )
        ''');
        database.execute(
          "INSERT INTO reading_sessions (id, started_at_utc, ended_at_utc, paused_total_ms, duration_ms, tz_offset_min, created_at, updated_at) VALUES ('legacy', 1700000000000, 1700001800000, 300000, 1500000, 330, 1700000000000, 1700001800000)",
        );
        database.execute('PRAGMA user_version = 2');
      },
    );

    final database = AppDatabase.forTesting(executor);
    final migratedColumn = await database.customSelect(
      "SELECT pause_intervals_json FROM reading_sessions WHERE id = 'legacy'",
    ).getSingle();
    expect(migratedColumn.read<String>('pause_intervals_json'), '[]');

    final sessions = await DriftSessionRepository(database).getAllSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'legacy');
    expect(sessions.single.pauseIntervals, isEmpty);
    expect(sessions.single.pausedTotalMs, 300000);
    expect(sessions.single.durationMs, 1500000);

    await database.close();
  });
  test('self-healing an orphaned paused session closes its final pause', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final pausedAt = now - 30 * 60000;
    final startedAt = pausedAt - 15 * 60000;
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftSessionRepository(database);

    try {
      await repository.saveSession(ReadingSession(
        id: 'orphaned-paused',
        startedAtUtc: startedAt,
        pausedAtUtc: pausedAt,
        tzOffsetMin: 0,
        createdAt: startedAt,
        updatedAt: pausedAt,
      ));
      await repository.saveSession(ReadingSession(
        id: 'newest-running',
        startedAtUtc: now - 60000,
        tzOffsetMin: 0,
        createdAt: now - 60000,
        updatedAt: now,
      ));

      final active = await repository.getActiveSession();
      expect(active?.id, 'newest-running');

      final sessions = await repository.getAllSessions();
      final orphaned = sessions.singleWhere((session) => session.id == 'orphaned-paused');
      expect(orphaned.endedAtUtc, isNotNull);
      expect(orphaned.pausedAtUtc, isNull);
      expect(orphaned.pauseIntervals, hasLength(1));
      expect(orphaned.pauseIntervals.single.startedAtUtc, pausedAt);
      expect(orphaned.pauseIntervals.single.endedAtUtc, orphaned.endedAtUtc);
      expect(orphaned.pausedTotalMs, orphaned.pauseIntervals.single.durationMs);
      expect(orphaned.durationMs, 15 * 60000);
      expect(orphaned.activeDurationMs(), 15 * 60000);
    } finally {
      await database.close();
    }
  });

}
