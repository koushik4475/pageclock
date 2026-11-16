/// Resolves the first screen without depending on Flutter's global app state.
///
/// An authenticated session always wins over the onboarding preference. This
/// matters after OAuth redirects, which return to the app in a fresh page load.
enum PageClockInitialDestination {
  onboarding,
  splash,
  workspace,
}

PageClockInitialDestination resolvePageClockInitialDestination({
  required bool isAuthenticated,
  required bool onboardingCompleted,
  required bool isWeb,
}) {
  if (isAuthenticated) return PageClockInitialDestination.workspace;
  if (!onboardingCompleted) return PageClockInitialDestination.onboarding;
  return isWeb
      ? PageClockInitialDestination.workspace
      : PageClockInitialDestination.splash;
}
