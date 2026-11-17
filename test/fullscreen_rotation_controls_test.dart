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
    // Always stop the engine before disposing the provider container. The
    // periodic ticker otherwise survives a failed assertion and leaks into
    // Flutter's fake-async test invariant checks.
    addTearDown(() async {
      await container.read(stopwatchEngineProvider.notifier).cancel();
    });

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

    // Exercise wide, compact-landscape and narrow-portrait constraints
    // while the stopwatch is actively ticking.
    const viewportSizes = [
      Size(900, 400),
      Size(640, 360),
      Size(400, 900),
      Size(320, 568),
    ];
    for (final size in viewportSizes) {
      tester.view.physicalSize = size;
      await tester.pump();

      final pauseRect = tester.getRect(find.text('Pause'));
      final stopRect = tester.getRect(find.text('Stop'));
      expect(pauseRect.overlaps(stopRect), isFalse);
      expect(pauseRect.left, greaterThanOrEqualTo(0));
      expect(stopRect.right, lessThanOrEqualTo(size.width));
      expect(pauseRect.top, greaterThanOrEqualTo(0));
      expect(stopRect.top, greaterThanOrEqualTo(0));
      expect(pauseRect.bottom, lessThanOrEqualTo(size.height));
      expect(stopRect.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    }
  });
}
