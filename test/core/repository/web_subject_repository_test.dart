import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pageclock/core/models/subject.dart';
import 'package:pageclock/core/repository/subject_repository_contract.dart';
import 'package:pageclock/core/repository/web_subject_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Subject subject(String id, String name, {bool archived = false}) => Subject(
        id: id,
        name: name,
        color: '#F97316',
        archived: archived,
      );

  group('WebSubjectRepository', () {
    test(
      'persists active and archived subjects across repository instances',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final first = WebSubjectRepository(prefs, storageKey: 'subjects_guest');

        await first.saveSubject(subject('reading', '  Reading  '));
        await first.setArchived('reading', true);
        await first.dispose();

        final reopened = WebSubjectRepository(
          prefs,
          storageKey: 'subjects_guest',
        );
        final all = await reopened.getAllSubjects();
        expect(all, hasLength(1));
        expect(all.single.name, 'Reading');
        expect(all.single.archived, isTrue);
        expect(
          await reopened.getAllSubjects(includeArchived: false),
          isEmpty,
        );
        await reopened.dispose();
      },
    );

    test(
      'rejects duplicate active names but permits reuse after archive',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repository = WebSubjectRepository(
          prefs,
          storageKey: 'subjects_guest',
        );

        await repository.saveSubject(subject('one', 'Reading'));
        await expectLater(
          repository.saveSubject(subject('two', ' reading ')),
          throwsA(isA<SubjectNameConflictException>()),
        );

        await repository.setArchived('one', true);
        await repository.saveSubject(subject('two', 'Reading'));
        expect(
          (await repository.getAllSubjects(includeArchived: false))
              .map((item) => item.id),
          ['two'],
        );

        await expectLater(
          repository.setArchived('one', false),
          throwsA(isA<SubjectNameConflictException>()),
        );
        await repository.dispose();
      },
    );

    test('watch stream does not miss writes after its initial snapshot', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = WebSubjectRepository(
        prefs,
        storageKey: 'subjects_guest',
      );
      final iterator = StreamIterator(repository.watchSubjects());

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);

      await repository.saveSubject(subject('reading', 'Reading'));
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.single.name, 'Reading');

      await iterator.cancel();
      await repository.dispose();
    });

    test('keeps guest and user subject partitions isolated', () async {
      final prefs = await SharedPreferences.getInstance();
      final guest = WebSubjectRepository(prefs, storageKey: 'subjects_guest');
      final user = WebSubjectRepository(
        prefs,
        storageKey: 'subjects_user_alice',
      );

      await guest.saveSubject(subject('guest-reading', 'Guest Reading'));
      await user.saveSubject(subject('user-reading', 'User Reading'));

      expect(
        (await guest.getAllSubjects()).map((item) => item.name),
        ['Guest Reading'],
      );
      expect(
        (await user.getAllSubjects()).map((item) => item.name),
        ['User Reading'],
      );
      await guest.dispose();
      await user.dispose();
    });
  });
}
