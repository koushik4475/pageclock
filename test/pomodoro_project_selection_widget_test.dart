import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/repository/subject_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/core/models/subject.dart';
import 'package:pageclock/features/timer/toggl_timer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('selected Pomodoro project is reflected on the main timer screen',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final subjects = InMemorySubjectRepository([
      const Subject(id: 'custom-tag', name: 'Custom Tag', color: '#F97316'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectRepositoryProvider.overrideWithValue(subjects),
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(360, 640)),
            child: TogglTimerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose Project'));
    await tester.pumpAndSettle();
    // Ensure the picker remains usable in a compact viewport; its content
    // must scroll instead of overflowing the modal route.
    await tester.ensureVisible(find.text('Custom Tag'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Custom Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Custom Tag'), findsOneWidget);
    final focusField = tester.widget<TextField>(find.byType(TextField).first);
    expect(focusField.decoration?.hintText, "I'm focusing on Custom Tag...");

    // Selecting a project must not overwrite the independently editable task.
    await tester.enterText(find.byType(TextField).first, 'Build a feature');
    await tester.pump();
    expect(find.text('Build a feature'), findsOneWidget);
    expect(find.text('Custom Tag'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await subjects.dispose();
  });
  testWidgets('managed subjects replace legacy project choices in the timer picker',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final subjects = InMemorySubjectRepository([
      const Subject(id: 'math', name: 'Mathematics', color: '#4F46E5'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
          subjectRepositoryProvider.overrideWithValue(subjects),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(360, 640)),
            child: TogglTimerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose Project'));
    await tester.pumpAndSettle();

    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Coding'), findsNothing);
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(find.text('Mathematics'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await subjects.dispose();
  });


  testWidgets('compact picker keeps create action visible and only offers focus tags',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final subjects = InMemorySubjectRepository();
    await tester.view.setPhysicalSize(const Size(360, 640));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await subjects.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
          subjectRepositoryProvider.overrideWithValue(subjects),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(360, 640)),
            child: TogglTimerScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose Project'));
    await tester.pumpAndSettle();

    expect(find.text('General Focus'), findsOneWidget);
    expect(find.text('Coding'), findsNothing);
    expect(find.text('Reading'), findsNothing);
    expect(find.text('Deep Work'), findsNothing);
    expect(find.text('Study'), findsNothing);
    final createAction = find.byKey(
      const ValueKey('timer-create-custom-tag-action'),
    );
    expect(createAction, findsOneWidget);
    expect(tester.getRect(createAction).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await tester.tap(createAction);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timer-custom-tag-field')),
      'Product design',
    );
    await tester.tap(find.byKey(const ValueKey('timer-custom-tag-create')));
    await tester.pumpAndSettle();

    expect(find.text('Product design'), findsOneWidget);
    final stored = await subjects.getAllSubjects(includeArchived: false);
    expect(stored.map((subject) => subject.name), contains('Product design'));

    await tester.tap(find.byTooltip('Choose Project'));
    await tester.pumpAndSettle();
    expect(find.text('Product design'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
