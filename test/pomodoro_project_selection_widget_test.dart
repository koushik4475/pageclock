import 'package:flutter/material.dart';
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
            data: MediaQueryData(size: Size(400, 900)),
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
    await tester.tap(find.text('Coding'));
    await tester.pumpAndSettle();

    expect(find.text('Coding'), findsOneWidget);
    final focusField = tester.widget<TextField>(find.byType(TextField).first);
    expect(focusField.decoration?.hintText, "I'm focusing on Coding...");

    // Selecting a project must not overwrite the independently editable task.
    await tester.enterText(focusField.controller == null
        ? find.byType(TextField).first
        : find.byType(TextField).first, 'Build a feature');
    await tester.pump();
    expect(find.text('Build a feature'), findsOneWidget);
    expect(find.text('Coding'), findsOneWidget);
  });
}
