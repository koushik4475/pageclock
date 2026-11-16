import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pageclock/core/db/app_database.dart';
import 'package:pageclock/core/models/subject.dart';
import 'package:pageclock/core/repository/drift_subject_repository.dart';
import 'package:pageclock/core/repository/subject_repository_contract.dart';

void main() {
  Subject subject(String id, String name, {bool archived = false}) => Subject(
        id: id,
        name: name,
        color: '#F97316',
        archived: archived,
      );

  test('Drift persists subject edits, archive/restore and duplicate validation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftSubjectRepository(database);

    try {
      await repository.saveSubject(subject('one', 'Reading'));
      await repository.saveSubject(subject('two', 'Coding'));
      await repository.saveSubject(subject('one', 'Deep Reading'));

      final renamed = await repository.getAllSubjects(includeArchived: false);
      expect(renamed.map((item) => item.name), ['Coding', 'Deep Reading']);

      await repository.setArchived('one', true);
      expect(
        (await repository.getAllSubjects(includeArchived: false))
            .map((item) => item.id),
        ['two'],
      );

      await repository.saveSubject(subject('three', 'Deep Reading'));
      await expectLater(
        repository.setArchived('one', false),
        throwsA(isA<SubjectNameConflictException>()),
      );

      final archived = await repository.getAllSubjects();
      expect(archived.singleWhere((item) => item.id == 'one').archived, isTrue);
    } finally {
      await repository.dispose();
    }
  });
}
