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
import 'features/app_update/app_update_service.dart';
import 'features/app_update/update_dialog.dart';
import 'features/calendar/calendar_screen.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.04 * _glowPulse.value),
                        const Color(0xFFE4E4E7).withOpacity(0.015 * _glowPulse.value),
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
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141417),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF27272A),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 34,
                              color: Color(0xFFE040FB),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'PageClock',
                          style: TextStyle(
                            color: Color(0xFFFAFAFA),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Offline-First Reading & Focus Tracker',
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
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
}

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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableWidth = MediaQuery.sizeOf(context).width;
    final useExpandedSidebar = availableWidth >= 1024;
    final useNavigationRail = availableWidth >= 600 && availableWidth < 1024;
    final currentIndex = ref.watch(mainTabNavigationIndexProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final sessions = sessionsAsync.value ?? [];
    final appThemeId = ref.watch(appThemeIdProvider);
    final isSpecial1 = appThemeId == AppThemeId.special1;
    final colorScheme = Theme.of(context).colorScheme;

    final screens = [
      const TogglTimerScreen(),
      CalendarScreen(sessions: sessions),
      ReportsScreen(sessions: sessions),
      const TogglSettingsScreen(),
    ];

    if (useExpandedSidebar) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Row(
          children: [
            Container(
              width: 230,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: colorScheme.outline,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'PageClock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'NAVIGATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSidebarItem(0, 'Timer', Icons.schedule_rounded, isDark, currentIndex, colorScheme),
                  _buildSidebarItem(1, 'Calendar', Icons.calendar_today_rounded, isDark, currentIndex, colorScheme),
                  _buildSidebarItem(2, 'Reports', Icons.bar_chart_rounded, isDark, currentIndex, colorScheme),
                  _buildSidebarItem(3, 'Settings', Icons.settings_outlined, isDark, currentIndex, colorScheme),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PageClock Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '100% Private & Local',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE040FB)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
        ),
      );
    }

    if (useNavigationRail) {
      return Scaffold(
        backgroundColor: isSpecial1
            ? Special1Palette.background
            : (isDark ? const Color(0xFF0F0B15) : AppColors.bgLight),
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) => ref
                    .read(mainTabNavigationIndexProvider.notifier)
                    .state = index,
                labelType: NavigationRailLabelType.all,
                backgroundColor: colorScheme.surface,
                selectedIconTheme: IconThemeData(color: colorScheme.primary),
                unselectedIconTheme:
                    IconThemeData(color: colorScheme.onSurfaceVariant),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.access_time_rounded),
                    selectedIcon: Icon(Icons.access_time_filled_rounded),
                    label: Text('Timer'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today_rounded),
                    label: Text('Calendar'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart_rounded),
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
                color: colorScheme.outline,
              ),
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: screens,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Compact phones and narrow iPad multitasking windows use bottom navigation.
    return Scaffold(
      backgroundColor: isSpecial1
          ? Special1Palette.background
          : (isDark ? const Color(0xFF0F0B15) : AppColors.bgLight),
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (idx) => ref.read(mainTabNavigationIndexProvider.notifier).state = idx,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              activeIcon: Icon(Icons.access_time_filled_rounded),
              label: 'Timer',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int idx, String title, IconData icon, bool isDark, int currentIndex, ColorScheme colorScheme) {
    final isSelected = currentIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: InkWell(
        onTap: () => ref.read(mainTabNavigationIndexProvider.notifier).state = idx,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
