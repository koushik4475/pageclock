import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/timer/widgets/fullscreen_ambient_focus_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('fullscreen controls remain separated after landscape resize',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    final repository = InMemorySessionRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppleMacFlipClockScreen(
            targetMinutes: 25,
            description: 'Build a feature',
            projectName: 'Coding',
          ),
        ),
      ),
    );
    await tester.pump();

    await container.read(stopwatchEngineProvider.notifier).start(
          subjectId: 'Coding',
          note: 'Build a feature',
        );
    await tester.pump();

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    tester.view.physicalSize = const Size(900, 400);
    await tester.pump();

    final pauseRect = tester.getRect(find.text('Pause'));
    final stopRect = tester.getRect(find.text('Stop'));
    expect(pauseRect.overlaps(stopRect), isFalse);
    expect(pauseRect.left, greaterThanOrEqualTo(0));
    expect(stopRect.right, lessThanOrEqualTo(900));
    expect(pauseRect.bottom, lessThanOrEqualTo(400));
    expect(stopRect.bottom, lessThanOrEqualTo(400));
  });
}
