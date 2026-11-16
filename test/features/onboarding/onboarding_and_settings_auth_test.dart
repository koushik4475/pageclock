import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pageclock/features/settings/toggl_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding & Settings Auth Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('OnboardingScreen renders title, features, sign in, and skip buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Welcome to PageClock'), findsOneWidget);
      expect(find.text('READ · FOCUS · TRACK'), findsOneWidget);
      expect(find.text('Sign In / Sync Account'), findsOneWidget);
      expect(find.text('Skip for now (Continue as Guest)'), findsOneWidget);
    });

    testWidgets('OnboardingScreen Skip button sets onboardingCompleted flag to true', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(container.read(onboardingCompletedProvider), isFalse);

      final skipButton = find.text('Skip for now (Continue as Guest)');
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(container.read(onboardingCompletedProvider), isTrue);
      expect(prefs.getBool(OnboardingCompletedNotifier.key), isTrue);
    });

    testWidgets('TogglSettingsScreen displays ACCOUNT & CLOUD SYNC card at bottom for Guest mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
          ],
          child: const MaterialApp(
            home: TogglSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT & CLOUD SYNC'), findsOneWidget);
      expect(find.text('Guest / Offline Mode'), findsOneWidget);
      expect(find.text('Sign In / Sync Account'), findsOneWidget);
    });
  });
}
