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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
            subjectRepositoryProvider.overrideWith((ref) => InMemorySubjectRepository()),
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
    await tester.ensureVisible(find.text('Coding'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Coding'));
    await tester.pumpAndSettle();

    expect(find.text('Coding'), findsOneWidget);
    final focusField = tester.widget<TextField>(find.byType(TextField).first);
    expect(focusField.decoration?.hintText, "I'm focusing on Coding...");

    // Selecting a project must not overwrite the independently editable task.
    await tester.enterText(find.byType(TextField).first, 'Build a feature');
    await tester.pump();
    expect(find.text('Build a feature'), findsOneWidget);
    expect(find.text('Coding'), findsOneWidget);
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

}
