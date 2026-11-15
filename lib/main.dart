import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models/reading_session.dart';
import 'core/navigation/main_tab_navigation.dart';
import 'core/engine/stopwatch_engine.dart';
import 'core/services/notification_service.dart';
import 'core/repository/session_repository.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/pageclock_brand_mark.dart';
import 'features/app_update/app_update_service.dart';
import 'features/app_update/update_dialog.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/dashboard/pageclock_dashboard_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/toggl_settings_screen.dart';
import 'features/timer/toggl_timer_screen.dart';

export 'core/theme/app_colors.dart';

final sessionsStreamProvider = StreamProvider<List<ReadingSession>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.watchAllSessions();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await NotificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PageClockApp(),
    ),
  );
}

class PageClockApp extends ConsumerWidget {
  const PageClockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final appThemeId = ref.watch(appThemeIdProvider);
    final selectedTheme = appThemeDataFor(appThemeId);

    return MaterialApp(
      title: 'PageClock',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: selectedTheme,
      darkTheme: selectedTheme,
      home: const SplashScreen(),
    );
  }
}

// -------------------------------------------------------------
// Fast, Elegant Splash Screen (< 1.2s fluid handoff)
// -------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );

    _glowPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.15, end: 0.45).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.45, end: 0.25).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_animController);

    _animController.forward();

    Future.delayed(const Duration(milliseconds: 1150), () {
      if (mounted) {
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
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return Center(
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withOpacity(0.12 * _glowPulse.value),
                        colors.secondary.withOpacity(0.04 * _glowPulse.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: colors.outline),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.28 : 0.08),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: PageClockBrandMark(
                              size: 60,
                              inkColor: colors.onSurface,
                              accentColor: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: colors.onSurface,
                            ),
                            children: [
                              const TextSpan(text: 'Page'),
                              TextSpan(
                                text: 'Clock',
                                style: TextStyle(color: colors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'READ · FOCUS · TRACK',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}}

// -------------------------------------------------------------
// Main Navigation Shell (Responsive Desktop Sidebar & Mobile Tabs)
// -------------------------------------------------------------
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  @override
  void initState() {
    super.initState();
    NotificationService.setTimerActionHandler(_handleTimerNotificationAction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
      final settings = ref.read(settingsProvider);
      NotificationService.syncTimer(ref.read(stopwatchProvider), settings);
      NotificationService.scheduleDailyReminder(settings);
    });
  }

  Future<void> _handleTimerNotificationAction(String action) async {
    final stopwatch = ref.read(stopwatchProvider.notifier);
    switch (action) {
      case 'pause':
        await stopwatch.pause();
        break;
      case 'resume':
        await stopwatch.resume();
        break;
      case 'stop':
        await stopwatch.stop(minSessionDurationMs: 0, forceSave: true);
        break;
    }
  }

  void _checkAutoUpdate() async {
    if (kIsWeb) return;
    try {
      final active = await ref.read(sessionRepositoryProvider).getActiveSession();
      if (active != null) return;

      final update = await AppUpdateService().checkForUpdate();
      if (mounted && update.hasUpdate && update.releaseInfo != null) {
        UpdateDialog.show(context, update.releaseInfo!);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final currentIndex = ref.watch(mainTabNavigationIndexProvider);
    final sessions = ref.watch(sessionsStreamProvider).value ?? [];

    final screens = [
      PageClockDashboardScreen(
        sessions: sessions,
        onOpenTimer: () => _selectTab(1),
        onNavigate: _selectTab,
      ),
      const TogglTimerScreen(),
      CalendarScreen(sessions: sessions),
      ReportsScreen(sessions: sessions),
      const TogglSettingsScreen(),
    ];

    if (width >= 1100) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: Row(
          children: [
            _buildDesktopSidebar(currentIndex, isDark, colors),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    if (width >= 700) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: _selectTab,
              backgroundColor: colors.surface,
              indicatorColor: colors.primary.withOpacity(isDark ? 0.18 : 0.12),
              selectedIconTheme: IconThemeData(color: colors.primary, size: 22),
              unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 21),
              selectedLabelTextStyle: TextStyle(
                color: colors.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer_rounded),
                  label: Text('Timer'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: Text('Calendar'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.query_stats_outlined),
                  selectedIcon: Icon(Icons.query_stats_rounded),
                  label: Text('Reports'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colors.outline.withOpacity(0.65),
            ),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _selectTab,
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withOpacity(isDark ? 0.18 : 0.12),
        height: 70,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    ref.read(mainTabNavigationIndexProvider.notifier).state = index;
  }

  Widget _buildDesktopSidebar(
    int currentIndex,
    bool isDark,
    ColorScheme colors,
  ) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(
            color: colors.outline.withOpacity(0.65),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PageClockBrandMark(
                size: 42,
                inkColor: colors.onSurface,
                accentColor: colors.primary,
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: colors.onSurface,
                  ),
                  children: [
                    const TextSpan(text: 'Page'),
                    TextSpan(
                      text: 'Clock',
                      style: TextStyle(color: colors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),
          Text(
            'WORKSPACE',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined, currentIndex, colors),
          _buildNavItem(1, 'Timer', Icons.timer_outlined, currentIndex, colors),
          _buildNavItem(2, 'Calendar', Icons.calendar_month_outlined, currentIndex, colors),
          _buildNavItem(3, 'Reports', Icons.query_stats_outlined, currentIndex, colors),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2433) : const Color(0xFFFFE9D4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE8CCB1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_stories_rounded, color: colors.primary, size: 25),
                const SizedBox(height: 10),
                Text(
                  'Read more. Focus better.',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Build a steady reading habit, one session at a time.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildNavItem(4, 'Settings', Icons.settings_outlined, currentIndex, colors),
          const SizedBox(height: 6),
          Text(
            'PRIVATE BY DESIGN · STORED LOCALLY',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String title,
    IconData icon,
    int currentIndex,
    ColorScheme colors,
  ) {
    final selected = index == currentIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? colors.primary.withOpacity(0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _selectTab(index),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 13),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? colors.onSurface : colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

