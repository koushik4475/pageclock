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
    // Unmount the screen first, then dispose the provider container.
    // StopwatchNotifier.dispose cancels its periodic ticker synchronously;
    // the test deliberately avoids awaiting persistence during teardown.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
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
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected render exception at viewport $size',
      );
    }

    // Confirm the session stayed active throughout the responsive-layout
    // checks, then stop it through the real engine path. Stopping in the test
    // body (rather than async teardown) deterministically cancels the periodic
    // ticker before Flutter verifies fake-async invariants.
    final notifier = container.read(stopwatchEngineProvider.notifier);
    final activeState = container.read(stopwatchEngineProvider);
    expect(activeState.isRunning, isTrue);
    expect(activeState.isPaused, isFalse);

    await notifier.stop(minSessionDurationMs: 0);
    expect(notifier.state.status, StopwatchStatus.idle);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // The teardown now only unmounts the screen and disposes its provider
    // container; no stopwatch ticker or persistence operation remains active.
  });
}
