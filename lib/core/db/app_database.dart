import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';
import '../models/reading_session.dart';
import '../repository/session_repository.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ReadingSessions, Subjects, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
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
            pausedTotalMs: Value(session.pausedTotalMs),
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
  Future<ReadingSession?> getActiveSession() async {
    final query = db.select(db.readingSessions)
      ..where((t) => t.endedAtUtc.isNull() & t.deletedAt.isNull());
    final entry = await query.getSingleOrNull();
    return entry != null ? _mapEntryToDomain(entry) : null;
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
      ..where((t) => t.endedAtUtc.isNull() & t.deletedAt.isNull());
    return query.watchSingleOrNull().map((entry) => entry != null ? _mapEntryToDomain(entry) : null);
  }

  ReadingSession _mapEntryToDomain(ReadingSessionEntry entry) {
    return ReadingSession(
      id: entry.id,
      startedAtUtc: entry.startedAtUtc,
      endedAtUtc: entry.endedAtUtc,
      pausedTotalMs: entry.pausedTotalMs,
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
