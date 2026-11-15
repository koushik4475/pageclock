import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models/reading_session.dart';
import 'core/navigation/main_tab_navigation.dart';
import 'core/engine/stopwatch_engine.dart';
import 'core/services/notification_service.dart';
import 'core/repository/session_repository.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/pageclock_brand_mark.dart';
import 'features/app_update/app_update_service.dart';
import 'features/app_update/update_dialog.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
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
                          child: Center(
                            child: PageClockBrandMark(
                              size: 58,
                              inkColor: Theme.of(context).colorScheme.onSurface,
                              accentColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'PageClock',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'READ · FOCUS · TRACK',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final currentIndex = ref.watch(mainTabNavigationIndexProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final sessions = sessionsAsync.value ?? const <ReadingSession>[];
    final settings = ref.watch(settingsProvider);
    final stopwatchState = ref.watch(stopwatchProvider);
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1120;
    final isTablet = width >= 720 && width < 1120;

    void navigate(int index) {
      ref.read(mainTabNavigationIndexProvider.notifier).state = index;
    }

    final screens = [
      DashboardScreen(
        sessions: sessions,
        settings: settings,
        stopwatchState: stopwatchState,
        onNavigate: navigate,
      ),
      const TogglTimerScreen(),
      CalendarScreen(sessions: sessions),
      ReportsScreen(sessions: sessions),
      const TogglSettingsScreen(),
    ];
    final selectedIndex = currentIndex.clamp(0, screens.length - 1).toInt();
    final pageStack = IndexedStack(index: selectedIndex, children: screens);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            Container(
              width: 248,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  right: BorderSide(color: colors.outline.withOpacity(.75)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PageClockBrandMark(
                        size: 44,
                        inkColor: colors.onSurface,
                        accentColor: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  color: colors.onSurface,
                                ),
                                children: [
                                  const TextSpan(text: 'Page'),
                                  TextSpan(text: 'Clock', style: TextStyle(color: colors.primary)),
                                ],
                              ),
                            ),
                            Text(
                              'READ · FOCUS · TRACK',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'WORKSPACE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSidebarItem(0, 'Dashboard', Icons.space_dashboard_rounded, selectedIndex, colors, () => navigate(0)),
                  _buildSidebarItem(1, 'Timer', Icons.timer_outlined, selectedIndex, colors, () => navigate(1)),
                  _buildSidebarItem(2, 'Calendar', Icons.calendar_month_outlined, selectedIndex, colors, () => navigate(2)),
                  _buildSidebarItem(3, 'Reports', Icons.insights_outlined, selectedIndex, colors, () => navigate(3)),
                  _buildSidebarItem(4, 'Settings', Icons.settings_outlined, selectedIndex, colors, () => navigate(4)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.primary.withOpacity(.16)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A little progress, daily.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your sessions stay private and on this device.',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.4,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: SizedBox.expand(child: pageStack),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: navigate,
              labelType: NavigationRailLabelType.selected,
              minWidth: 78,
              backgroundColor: colors.surface,
              selectedIconTheme: IconThemeData(color: colors.primary),
              unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
              selectedLabelTextStyle: TextStyle(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
              ),
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 26, top: 8),
                child: PageClockBrandMark(
                  size: 44,
                  inkColor: colors.onSurface,
                  accentColor: colors.primary,
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: Text('Timer')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: Text('Calendar')),
                NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: Text('Reports')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: Text('Settings')),
              ],
            ),
            VerticalDivider(width: 1, color: colors.outline.withOpacity(.75)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: SizedBox.expand(child: pageStack),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: pageStack,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: navigate,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withOpacity(.13),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: 'Timer'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    String title,
    IconData icon,
    int currentIndex,
    ColorScheme colors,
    VoidCallback onTap,
  ) {
    final selected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? colors.primary.withOpacity(.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? colors.onSurface : colors.onSurfaceVariant,
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
}
