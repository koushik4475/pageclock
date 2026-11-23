import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/db/app_database.dart';
import 'package:pageclock/core/models/reading_session.dart';

void main() {
  late AppDatabase database;
  late DriftSessionRepository repository;

  ReadingSession session({
    required int updatedAt,
    String? note,
    int? deletedAt,
  }) {
    return ReadingSession(
      id: 'sync-session-1',
      startedAtUtc: 1700000000000,
      endedAtUtc: 1700001800000,
      durationMs: 1800000,
      tzOffsetMin: 0,
      source: 'timer',
      note: note,
      createdAt: 1700000000000,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSessionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('allForSync includes completed rows and tombstones', () async {
    await repository.saveSession(session(updatedAt: 1000, note: 'Reading'));
    await repository.saveSession(
      session(updatedAt: 2000, note: null, deletedAt: 2000),
    );

    final rows = await repository.allForSync();

    expect(rows, hasLength(1));
    expect(rows.single.deletedAt, 2000);
  });

  test('applyRemote keeps newer local rows and accepts newer remote rows', () async {
    await repository.saveSession(session(updatedAt: 3000, note: 'Local newer'));

    await repository.applyRemote([
      session(updatedAt: 2000, note: 'Remote older'),
    ]);
    expect((await repository.allForSync()).single.note, 'Local newer');

    await repository.applyRemote([
      session(updatedAt: 4000, note: 'Remote newer'),
    ]);
    expect((await repository.allForSync()).single.note, 'Remote newer');
  });

  test('applying an identical remote row does not emit a local change', () async {
    final row = session(updatedAt: 6000, note: 'Same on both devices');
    await repository.saveSession(row);

    final emissions = <List<ReadingSession>>[];
    final initial = Completer<void>();
    final subscription = repository.watchAllSessions().listen((rows) {
      emissions.add(rows);
      if (!initial.isCompleted) initial.complete();
    });
    await initial.future;

    await repository.applyRemote([row]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // The sync listener watches this stream; an unchanged pull must not
    // re-emit or schedule another pull->merge->push cycle.
    expect(emissions, hasLength(1));
    await subscription.cancel();
  });

  test('equal timestamp tombstone wins over a live remote row', () async {
    await repository.saveSession(
      session(updatedAt: 5000, note: null, deletedAt: 5000),
    );

    await repository.applyRemote([
      session(updatedAt: 5000, note: 'Live remote'),
    ]);

    final row = (await repository.allForSync()).single;
    expect(row.deletedAt, 5000);
  });
}
