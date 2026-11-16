import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/navigation/initial_destination.dart';

void main() {
  group('PageClock initial destination', () {
    test('restored authentication bypasses onboarding even on first launch', () {
      expect(
        resolvePageClockInitialDestination(
          isAuthenticated: true,
          onboardingCompleted: false,
          isWeb: true,
        ),
        PageClockInitialDestination.workspace,
      );
    });

    test('guest first launch opens onboarding', () {
      expect(
        resolvePageClockInitialDestination(
          isAuthenticated: false,
          onboardingCompleted: false,
          isWeb: true,
        ),
        PageClockInitialDestination.onboarding,
      );
    });

    test('completed guest web launch opens workspace without a second splash', () {
      expect(
        resolvePageClockInitialDestination(
          isAuthenticated: false,
          onboardingCompleted: true,
          isWeb: true,
        ),
        PageClockInitialDestination.workspace,
      );
    });

    test('completed guest native launch retains the native splash', () {
      expect(
        resolvePageClockInitialDestination(
          isAuthenticated: false,
          onboardingCompleted: true,
          isWeb: false,
        ),
        PageClockInitialDestination.splash,
      );
    });
  });
}
