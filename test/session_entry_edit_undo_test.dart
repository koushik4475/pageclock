import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:pageclock/core/db/app_database.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/repository/web_session_repository.dart';

ReadingSession _session({String note = 'Chapter 1'}) {
  const durationMs = 30 * 60 * 1000;
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return ReadingSession(
    id: 'entry-undo-test',
    startedAtUtc: now - durationMs,
    endedAtUtc: now,
    durationMs: durationMs,
    tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
    subjectId: 'Reading',
    note: note,
    source: 'manual',
    createdAt: now - durationMs,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session entry edit and undo persistence', () {
    test('copyWith can explicitly clear a deleted timestamp and description', () {
      final session = _session().copyWith(
        deletedAt: 1234,
        note: 'Old description',
      );

      final restored = session.copyWith(
        clearDeletedAt: true,
        clearNote: true,
      );

      expect(restored.deletedAt, isNull);
      expect(restored.note, isNull);
      expect(restored.id, session.id);
      expect(restored.createdAt, session.createdAt);
    });

    test('in-memory repository restores only the exact unchanged deletion', () async {
      final session = _session();
      final repository = InMemorySessionRepository([session]);
      const deletedAt = 5000;

      await repository.softDeleteSession(
        session.id,
        deletedAt: deletedAt,
      );
      expect(await repository.getAllSessions(), isEmpty);

      final restored = await repository.restoreSoftDeletedSession(
        session: session,
        expectedDeletedAt: deletedAt,
      );

      expect(restored, isTrue);
      expect(await repository.getAllSessions(), hasLength(1));
      expect((await repository.getAllSessions()).single.id, session.id);
    });

    test('stale undo cannot overwrite a later edit to the deleted record', () async {
      final session = _session();
      final repository = InMemorySessionRepository([session]);
      const deletedAt = 6000;

      await repository.softDeleteSession(
        session.id,
        deletedAt: deletedAt,
      );
      await repository.updateSession(
        session.copyWith(
          deletedAt: deletedAt,
          updatedAt: deletedAt + 1,
          note: 'Changed after deletion',
        ),
      );

      final restored = await repository.restoreSoftDeletedSession(
        session: session,
        expectedDeletedAt: deletedAt,
      );

      expect(restored, isFalse);
      expect(await repository.getAllSessions(), isEmpty);
    });

    test('native Drift repository restores only the matching soft deletion', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftSessionRepository(database);
      final session = _session();
      const deletedAt = 8000;

      try {
        await repository.saveSession(session);
        await repository.softDeleteSession(
          session.id,
          deletedAt: deletedAt,
        );
        expect(await repository.getAllSessions(), isEmpty);

        final restored = await repository.restoreSoftDeletedSession(
          session: session,
          expectedDeletedAt: deletedAt,
        );

        expect(restored, isTrue);
        final saved = await repository.getAllSessions();
        expect(saved, hasLength(1));
        expect(saved.single.id, session.id);
        expect(saved.single.deletedAt, isNull);
      } finally {
        await database.close();
      }
    });

    test('web reset is safe when the session key does not exist yet', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = WebSessionRepository(preferences);

      await expectLater(repository.hardDeleteAll(), completes);
      expect(await repository.getAllSessions(), isEmpty);
    });

    test('web repository persists delete and undo across repository recreation', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final session = _session();
      final repository = WebSessionRepository(preferences);
      const deletedAt = 7000;

      await repository.saveSession(session);
      await repository.softDeleteSession(
        session.id,
        deletedAt: deletedAt,
      );
      expect(await repository.getAllSessions(), isEmpty);

      final restored = await repository.restoreSoftDeletedSession(
        session: session,
        expectedDeletedAt: deletedAt,
      );
      expect(restored, isTrue);

      final reopened = WebSessionRepository(preferences);
      final saved = await reopened.getAllSessions();
      expect(saved, hasLength(1));
      expect(saved.single.id, session.id);
      expect(saved.single.note, session.note);
      expect(saved.single.deletedAt, isNull);
    });
  });
}
