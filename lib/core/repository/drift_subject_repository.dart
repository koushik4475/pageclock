import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/subject.dart';
import 'subject_repository_contract.dart';

/// Drift-backed subject storage sharing the same account database as sessions.
class DriftSubjectRepository implements SubjectRepository {
  final AppDatabase db;

  DriftSubjectRepository(this.db);

  Subject _mapRow(SubjectEntry row) => Subject(
        id: row.id,
        name: row.name,
        color: row.color,
        archived: row.archived,
      );

  List<Subject> _sort(
    Iterable<Subject> subjects, {
    required bool includeArchived,
  }) {
    final values = subjects
        .where((subject) => includeArchived || !subject.archived)
        .toList()
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
    return values;
  }

  @override
  Future<List<Subject>> getAllSubjects({bool includeArchived = true}) async {
    final rows = await db.select(db.subjects).get();
    return _sort(rows.map(_mapRow), includeArchived: includeArchived);
  }

  @override
  Stream<List<Subject>> watchSubjects({bool includeArchived = true}) {
    return db.select(db.subjects).watch().map(
          (rows) => _sort(
            rows.map(_mapRow),
            includeArchived: includeArchived,
          ),
        );
  }

  @override
  Future<void> saveSubject(Subject subject) async {
    final normalized = subject.copyWith(
      name: normalizeSubjectName(subject.name),
    );
    await db.transaction(() async {
      final existingRows = await db.select(db.subjects).get();
      ensureUniqueActiveSubjectName(
        normalized,
        existingRows.map(_mapRow),
      );
      await db.into(db.subjects).insertOnConflictUpdate(
            SubjectsCompanion(
              id: Value(normalized.id),
              name: Value(normalized.name),
              color: Value(normalized.color),
              archived: Value(normalized.archived),
            ),
          );
    });
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    await db.transaction(() async {
      final rows = await (db.select(db.subjects)..where((table) => table.id.equals(id))).get();
      if (rows.isEmpty) {
        throw StateError('Subject "$id" was not found.');
      }
      final updated = _mapRow(rows.single).copyWith(archived: archived);
      final allRows = await db.select(db.subjects).get();
      ensureUniqueActiveSubjectName(updated, allRows.map(_mapRow));
      await (db.update(db.subjects)..where((table) => table.id.equals(id))).write(
        SubjectsCompanion(archived: Value(archived)),
      );
    });
  }

  @override
  Future<void> dispose() => db.close();
}
