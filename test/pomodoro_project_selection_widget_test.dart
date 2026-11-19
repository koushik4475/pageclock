import 'dart:convert';

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

  testWidgets('selecting a built-in project updates the focus hint',
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
    await tester.ensureVisible(find.text('Coding'));
    await tester.tap(find.text('Coding'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, "I'm focusing on Coding...");
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom Pomodoro tags can be created and persisted',
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
    await tester.tap(find.text('Create custom tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Design');
    await tester.tap(find.text('Create tag'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, "I'm focusing on Design...");
    final raw = preferences.getString('pageclock_app_settings_v1');
    expect(raw, isNotNull);
    final saved = AppSettings.fromJson(
      jsonDecode(raw!) as Map<String, dynamic>,
    );
    expect(saved.customPomodoroProjects, contains('Design'));
    expect(saved.lastSelectedProject, 'Design');
    expect(tester.takeException(), isNull);
  });
}
