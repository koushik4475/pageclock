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
    // Unmount the screen first so its UI ticker is cancelled, then dispose
    // the provider container so StopwatchNotifier.dispose cancels the engine
    // ticker. Avoid awaiting persistence cleanup in this layout test: the
    // in-memory repository is isolated to this test and is discarded.
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
    // checks. Teardown disposes both the screen and notifier tickers.
    final activeState = container.read(stopwatchEngineProvider);
    expect(activeState.isRunning, isTrue);
    expect(activeState.isPaused, isFalse);
  });
}
