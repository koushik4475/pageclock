import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/account/account_scope.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/pageclock_brand_mark.dart';
import '../../../main.dart';
import '../../auth/presentation/auth_dialogs.dart';

/// Provider tracking whether the user has finished or skipped the initial onboarding.
final onboardingCompletedProvider = StateNotifierProvider<OnboardingCompletedNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingCompletedNotifier(prefs);
});

class OnboardingCompletedNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const String key = 'pageclock_onboarding_completed_v1';

  OnboardingCompletedNotifier(this._prefs) : super(_prefs.getBool(key) ?? false);

  Future<void> complete() async {
    await _prefs.setBool(key, true);
    state = true;
  }
}

/// Modern, welcoming Onboarding screen that allows users to sign in or skip to guest mode.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  void _navigateToMainShell() {
    ref.read(onboardingCompletedProvider.notifier).complete();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _onSignInPressed() async {
    await showSignInDialog(context);
    if (!mounted) return;
    final scope = ref.read(accountScopeProvider);
    if (scope.isUser) {
      _navigateToMainShell();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: PageClockBrandMark(
                          size: 60,
                          inkColor: theme.colorScheme.onSurface,
                          accentColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title & Tagline
                  Text(
                    'Welcome to PageClock',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'READ · FOCUS · TRACK',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Feature highlights cards
                  _buildFeatureRow(
                    context,
                    icon: Icons.timer_outlined,
                    title: 'Distraction-Free Focus',
                    description: 'Track reading sessions with modern flip clocks and customizable studio presets.',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    icon: Icons.insights_outlined,
                    title: 'Insights & Reading Streaks',
                    description: 'Monitor daily goals, consistency scores, and export detailed PDF/CSV reports.',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    icon: Icons.cloud_sync_outlined,
                    title: 'Optional Cloud Backup',
                    description: 'Sign in to sync reading sessions across devices or continue offline privately.',
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: _onSignInPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Sign In / Sync Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: _navigateToMainShell,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      side: BorderSide(color: theme.colorScheme.outline),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Skip for now (Continue as Guest)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Offline reassurance notice
                  Text(
                    'Guest mode is 100% private and stays offline on this device. You can sign in anytime later from Settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
