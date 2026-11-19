import 'package:flutter/material.dart';
import '../../core/account/account_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
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

  testWidgets(
    'creates a custom tag, selects it, and restores it after reopening the timer',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();

      Future<void> pumpTimer() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
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
      }

      await pumpTimer();
      await tester.tap(find.text('Pomodoro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose Project'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create custom tag'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-project-tag-field')),
        'Research',
      );
      await tester.tap(find.text('Create tag'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pomodoro-selected-project-tag')),
          findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      final focusField = tester.widget<TextField>(
        find.byKey(const ValueKey('pomodoro-task-description')),
      );
      expect(focusField.decoration?.hintText, "I'm focusing on Research...");
      expect(
        preferences.getStringList('pageclock_custom_project_tags_v1_guest'),
        ['Research'],
      );

      // Recreate the screen with the same device store to simulate an app
      // restart; the custom tag and last selected project must survive.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpTimer();

      final restoredField = tester.widget<TextField>(
        find.byKey(const ValueKey('pomodoro-task-description')),
      );
      expect(
        restoredField.decoration?.hintText,
        "I'm focusing on Research...",
      );
      await tester.tap(find.byTooltip('Choose Project'));
      await tester.pumpAndSettle();
      expect(find.text('Research'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom Pomodoro tags stay isolated when account scope changes',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'pageclock_custom_project_tags_v1_guest',
      ['Guest tag'],
    );
    await preferences.setStringList(
      'pageclock_custom_project_tags_v1_user_user-1',
      ['User tag'],
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    expect(find.text('Guest tag'), findsOneWidget);
    expect(find.text('User tag'), findsNothing);
    await tester.tap(find.text('Guest tag'));
    await tester.pumpAndSettle();

    await container.read(accountScopeProvider.notifier).setUser('user-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose Project'));
    await tester.pumpAndSettle();
    expect(find.text('User tag'), findsOneWidget);
    expect(find.text('Guest tag'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
