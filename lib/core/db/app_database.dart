import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';
import '../models/reading_session.dart';
import '../repository/session_repository.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ReadingSessions, Subjects])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // Version 1 databases predate pausedAtUtc. pausedTotalMs already
          // existed in v1, so only add the newly introduced nullable column.
          if (from < 2) {
            // Some v1 builds had already shipped pausedAtUtc without bumping
            // schemaVersion. Detect the column first so those databases do
            // not fail with a duplicate-column migration error.
            final columns = await customSelect(
              'PRAGMA table_info(reading_sessions)',
            ).get();
            final hasPausedAtUtc = columns.any(
              (row) => row.read<String>('name') == 'paused_at_utc',
            );
            if (!hasPausedAtUtc) {
              await m.addColumn(
                readingSessions,
                readingSessions.pausedAtUtc,
              );
            }
          }
          // Version 3 stores exact completed pause positions. Existing rows
          // receive the empty-list default and retain their legacy fallback.
          if (from < 3) {
            await m.addColumn(
              readingSessions,
              readingSessions.pauseIntervalsJson,
            );
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pageclock.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

class DriftSessionRepository implements SessionRepository {
  final AppDatabase db;

  DriftSessionRepository(this.db);

  @override
  Future<void> saveSession(ReadingSession session) async {
    await db.into(db.readingSessions).insertOnConflictUpdate(
          ReadingSessionsCompanion(
            id: Value(session.id),
            startedAtUtc: Value(session.startedAtUtc),
            endedAtUtc: Value(session.endedAtUtc),
            pausedAtUtc: Value(session.pausedAtUtc),
            pausedTotalMs: Value(session.pausedTotalMs),
            pauseIntervalsJson: Value(jsonEncode(
              session.pauseIntervals.map((interval) => interval.toMap()).toList(),
            )),
            durationMs: Value(session.durationMs),
            tzOffsetMin: Value(session.tzOffsetMin),
            subjectId: Value(session.subjectId),
            note: Value(session.note),
            source: Value(session.source),
            deviceId: Value(session.deviceId),
            createdAt: Value(session.createdAt),
            updatedAt: Value(session.updatedAt),
            deletedAt: Value(session.deletedAt),
          ),
        );
  }

  @override
  Future<void> updateSession(ReadingSession session) async {
    await saveSession(session);
  }

  @override
  Future<void> softDeleteSession(String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (db.update(db.readingSessions)..where((t) => t.id.equals(id))).write(
      ReadingSessionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> hardDeleteAll() async {
    await db.delete(db.readingSessions).go();
  }

  @override
  void seedSampleData() {}

  @override
  Future<ReadingSession?> getActiveSession() async {
    final query = db.select(db.readingSessions)
      ..where((t) => t.endedAtUtc.isNull() & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)]);
    final openRows = await query.get();
    if (openRows.isEmpty) return null;

    // Self-heal: If multiple open sessions exist, keep newest and auto-close older ones
    if (openRows.length > 1) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (int i = 1; i < openRows.length; i++) {
        final orphaned = openRows[i];
        final orphanedSession = _mapEntryToDomain(orphaned);
        final rawFinalPauseDuration = orphaned.pausedAtUtc == null
            ? 0
            : now - orphaned.pausedAtUtc!;
        final finalPauseDuration = rawFinalPauseDuration <= 0
            ? 0
            : (rawFinalPauseDuration > 86400000
                ? 86400000
                : rawFinalPauseDuration);
        final completedPauseIntervals = [
          ...orphanedSession.pauseIntervals,
          if (finalPauseDuration > 0)
            PauseInterval(
              startedAtUtc: orphaned.pausedAtUtc!,
              endedAtUtc: now,
            ),
        ];
        final updatedPausedTotalMs =
            orphanedSession.pausedTotalMs + finalPauseDuration;
        final effectiveDuration = orphanedSession.activeDurationMs(nowUtcMs: now);
        await (db.update(db.readingSessions)..where((t) => t.id.equals(orphaned.id))).write(
          ReadingSessionsCompanion(
            endedAtUtc: Value(now),
            pausedAtUtc: const Value(null),
            pausedTotalMs: Value(updatedPausedTotalMs),
            pauseIntervalsJson: Value(jsonEncode(
              completedPauseIntervals.map((interval) => interval.toMap()).toList(),
            )),
            durationMs: Value(effectiveDuration),
            updatedAt: Value(now),
          ),
        );
      }
    }

    return _mapEntryToDomain(openRows.first);
  }

  @override
  Future<List<ReadingSession>> getAllSessions() async {
    final query = db.select(db.readingSessions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)]);
    final rows = await query.get();
    return rows.map(_mapEntryToDomain).toList();
  }

  @override
  Future<List<ReadingSession>> getSessionsBetween(int startUtc, int endUtc) async {
    final query = db.select(db.readingSessions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.startedAtUtc.isBiggerOrEqualValue(startUtc) &
          t.startedAtUtc.isSmallerOrEqualValue(endUtc))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)]);
    final rows = await query.get();
    return rows.map(_mapEntryToDomain).toList();
  }

  @override
  Stream<List<ReadingSession>> watchAllSessions() {
    final query = db.select(db.readingSessions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)]);
    return query.watch().map((rows) => rows.map(_mapEntryToDomain).toList());
  }

  @override
  Stream<ReadingSession?> watchActiveSession() {
    final query = db.select(db.readingSessions)
      ..where((t) => t.endedAtUtc.isNull() & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)]);
    return query.watch().map((rows) => rows.isNotEmpty ? _mapEntryToDomain(rows.first) : null);
  }

  List<PauseInterval> _decodePauseIntervals(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => PauseInterval.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      }
    } catch (_) {
      // Preserve access to the session if an older or damaged row contains
      // malformed optional pause metadata; the model uses its legacy fallback.
    }
    return const [];
  }

  ReadingSession _mapEntryToDomain(ReadingSessionEntry entry) {
    return ReadingSession(
      id: entry.id,
      startedAtUtc: entry.startedAtUtc,
      endedAtUtc: entry.endedAtUtc,
      pausedAtUtc: entry.pausedAtUtc,
      pausedTotalMs: entry.pausedTotalMs,
      pauseIntervals: _decodePauseIntervals(entry.pauseIntervalsJson),
      durationMs: entry.durationMs,
      tzOffsetMin: entry.tzOffsetMin,
      subjectId: entry.subjectId,
      note: entry.note,
      source: entry.source,
      deviceId: entry.deviceId,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      deletedAt: entry.deletedAt,
    );
  }
}
