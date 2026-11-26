import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pageclock/core/repository/subject_repository.dart';
import 'package:pageclock/features/subjects/subject_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySubjectRepository repository;

  setUp(() {
    repository = InMemorySubjectRepository();
  });

  tearDown(() async {
    await repository.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: SubjectManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> createSubject(
    WidgetTester tester,
    String name,
  ) async {
    await tester.tap(find.byKey(const ValueKey('create-subject')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('subject-name-field')),
      name,
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Save subject'));
    await tester.tap(find.text('Save subject'));
    await tester.pumpAndSettle();
    expect(find.text('New subject'), findsNothing);
  }

  testWidgets('shows a useful empty state and creates a colour-coded subject',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('No subjects yet'), findsOneWidget);
    expect(find.text('Create your first subject'), findsOneWidget);

    await tester.tap(find.text('Create your first subject'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('subject-name-field')),
      'Reading',
    );
    await tester.pump();
    await tester.tap(find.text('Teal'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save subject'));
    await tester.tap(find.text('Save subject'));
    await tester.pumpAndSettle();
    expect(find.text('New subject'), findsNothing);

    final saved = await repository.getAllSubjects(includeArchived: false);
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Reading');
    expect(saved.single.color, '#0F766E');
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('rejects duplicate names and keeps the existing subject',
      (tester) async {
    await pumpScreen(tester);
    await createSubject(tester, 'Reading');
    await createSubject(tester, ' reading ');

    expect(
      find.text('An active subject named "reading" already exists.'),
      findsOneWidget,
    );
    expect(
      (await repository.getAllSubjects(includeArchived: false))
          .map((subject) => subject.name),
      ['Reading'],
    );
  });

  testWidgets('renames a subject and archives then restores it', (tester) async {
    await pumpScreen(tester);
    await createSubject(tester, 'Reading');

    final subjectId = (await repository.getAllSubjects()).single.id;
    await tester.tap(find.byKey(ValueKey('edit-subject-$subjectId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('subject-name-field')),
      'Deep Reading',
    );
    await tester.tap(find.text('Save subject'));
    await tester.pumpAndSettle();

    expect(find.text('Deep Reading'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('archive-subject-$subjectId')));
    await tester.pumpAndSettle();
    expect(find.text('No subjects yet'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Deep Reading'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('restore-subject-$subjectId')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing archived yet'), findsOneWidget);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Deep Reading'), findsOneWidget);
  });

  testWidgets('shows storage corruption without enabling destructive writes',
      (tester) async {
    final corruptedRepository = _CorruptedSubjectRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectRepositoryProvider.overrideWithValue(corruptedRepository),
        ],
        child: const MaterialApp(home: SubjectManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Existing data is preserved'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-subject')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const ValueKey('create-subject'))).onPressed,
      isNull,
    );
    await corruptedRepository.dispose();
  });
}

class _CorruptedSubjectRepository extends InMemorySubjectRepository {
  @override
  String? get storageIssue =>
      'Stored subjects could not be read. Existing data is preserved.';
}
