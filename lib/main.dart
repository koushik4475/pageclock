import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/engine/stopwatch_engine.dart';
import '../core/models/reading_session.dart';
import '../core/repository/session_repository.dart';
import '../stats/stats_engine.dart';
import '../core/services/export_service.dart';
import '../core/services/pdf_service.dart';
import 'features/app_update/app_update_service.dart';
import 'features/app_update/update_dialog.dart';
import 'features/reports/reports_screen.dart';
import 'features/reports/widgets/contribution_heatmap.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/timer/toggl_timer_screen.dart';
import 'features/settings/toggl_settings_screen.dart';

// -------------------------------------------------------------
// Design Tokens: Linear / Vercel Pro Aesthetic
// -------------------------------------------------------------
class AppColors {
  static const bgDark = Color(0xFF09090B); // Obsidian / True deep black
  static const surfaceDark = Color(0xFF121215); // Layer 1 card surface
  static const surfaceDarkHover = Color(0xFF18181B);
  static const borderDark = Color(0xFF27272A); // 1px hairline border
  static const borderDarkSubtle = Color(0xFF1F1F23);

  static const textPrimaryDark = Color(0xFFFAFAFA);
  static const textSecondaryDark = Color(0xFFA1A1AA);
  static const textMutedDark = Color(0xFF71717A);

  static const accentIndigo = Color(0xFF6366F1); // Linear signature indigo
  static const accentEmerald = Color(0xFF10B981); // Crisp success green
  static const accentOrange = Color(0xFFF97316); // StandBy flame

  // Light Mode Tokens
  static const bgLight = Color(0xFFFBFBFB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE4E4E7);
  static const textPrimaryLight = Color(0xFF09090B);
  static const textSecondaryLight = Color(0xFF52525B);
  static const textMutedLight = Color(0xFFA1A1AA);
}

// State Providers
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final dailyGoalMinutesProvider = StateProvider<int>((ref) => 30);
final targetFocusDurationMinutesProvider = StateProvider<int?>((ref) => 25);
final consistencyThresholdMinutesProvider = StateProvider<int>((ref) => 10);
final weekStartDayProvider = StateProvider<int>((ref) => DateTime.monday);
final consistencyWindowDaysProvider = StateProvider<int>((ref) => 30);

final sessionsStreamProvider = StreamProvider<List<ReadingSession>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.watchAllSessions();
});

void main() {
  runApp(const ProviderScope(child: PageClockApp()));
}

class PageClockApp extends ConsumerWidget {
  const PageClockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Productivity',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bgLight,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accentIndigo,
          surface: AppColors.surfaceLight,
          outline: AppColors.borderLight,
        ),
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentIndigo,
          surface: AppColors.surfaceDark,
          outline: AppColors.borderDark,
        ),
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}

// -------------------------------------------------------------
// Luxury Minimalist Dark Splash Screen (Apple & Vercel Inspired)
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
  late Animation<double> _progressLine;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Subtle, elegant micro-animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _glowPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.15, end: 0.45).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.45, end: 0.25).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_animController);

    _progressLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.95, curve: Curves.easeInOutCubic)),
    );

    _animController.forward();

    // Clean, fluid 3-second handoff into main app
    Future.delayed(const Duration(milliseconds: 3100), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainNavigationShell(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
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
    // Apple Mac Calm Minimalist Dark Tokens:
    // Pure calm matte backdrop: #0A0A0C
    // Warm neutral off-white emblem & accents (#E4E4E7 / #A1A1AA)
    // No garish neon blues or flashy gradients
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gentle, warm ambient breath glow
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

          // Central Minimalist Monogram & Title
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
                        // Calm Matte Dark Titanium Emblem
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
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.03),
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.hourglass_empty_rounded,
                              size: 30,
                              color: Color(0xFFE4E4E7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // Title: Warm Serene Off-White
                        const Text(
                          'Productivity',
                          style: TextStyle(
                            color: Color(0xFFFAFAFA),
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle: Quiet Neutral Zinc
                        const Text(
                          'MINDFUL FOCUS & TIME',
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Calm Hairline Pulse Line
                        SizedBox(
                          width: 120,
                          height: 2,
                          child: Stack(
                            children: [
                              // Track line
                              Container(
                                width: 120,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E22),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              // Active warm calm bar
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 120 * _progressLine.value,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: const Color(0xFFE4E4E7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Clean Minimalist Status Indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), // Emerald calm dot
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Offline-First • Realtime',
                              style: TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Signature: Subtle Hardware Branding
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'DESIGNED BY KOUSHIK • V1.0.0',
                style: TextStyle(
                  color: const Color(0xFF3F3F46).withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Main Navigation Shell (Ultra-Minimalist Sidebar & Dock)
// -------------------------------------------------------------
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0; // Default to Timer

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });
  }

  void _checkAutoUpdate() async {
    // Only check and show APK updates when running on native Android mobile
    if (kIsWeb) return;

    try {
      final active = await ref.read(sessionRepositoryProvider).getActiveSession();
      if (active != null) return; // Do not interrupt active focus session

      final update = await AppUpdateService().checkForUpdate();
      if (mounted && update.hasUpdate && update.releaseInfo != null) {
        UpdateDialog.show(context, update.releaseInfo!);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final sessions = sessionsAsync.value ?? [];

    final screens = [
      const TogglTimerScreen(),
      CalendarScreen(sessions: sessions),
      ReportsScreen(sessions: sessions),
      const TogglSettingsScreen(),
    ];

    if (isWide) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0B15) : AppColors.bgLight,
        body: Row(
          children: [
            // Desktop Sidebar
            Container(
              width: 230,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF140E20) : AppColors.surfaceLight,
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF261A3D) : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Brand Mark
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE040FB), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE040FB).withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Productivity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Section Header
                  Text(
                    'WORKSPACE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? const Color(0xFFA1A1AA) : AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSidebarItem(0, 'Timer', Icons.schedule_rounded, isDark),
                  _buildSidebarItem(1, 'Calendar', Icons.calendar_today_rounded, isDark),
                  _buildSidebarItem(2, 'Reports', Icons.bar_chart_rounded, isDark),
                  _buildSidebarItem(3, 'Settings', Icons.settings_outlined, isDark),

                  const Spacer(),

                  // Bottom Profile Indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1D142E) : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E204A) : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Koushik HY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'koushik4475@gmail.com',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE040FB)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile 3-Tab Bottom Navigation Bar matching Toggl Track UI
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0B15) : AppColors.bgLight,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF140E20) : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF241838) : AppColors.borderLight,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFE040FB),
          unselectedItemColor: isDark ? const Color(0xFFA1A1AA) : AppColors.textMutedLight,
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

  Widget _buildSidebarItem(int idx, String title, IconData icon, bool isDark) {
    final isSelected = _currentIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: InkWell(
        onTap: () => setState(() => _currentIndex = idx),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2E1B46) : const Color(0xFFFCE7F3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFFE040FB)
                    : (isDark ? const Color(0xFFA1A1AA) : AppColors.textMutedLight),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? const Color(0xFFA1A1AA) : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 2: World-Class Bento Grid Insights Screen
// -------------------------------------------------------------
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final consistencyThreshold = ref.watch(consistencyThresholdMinutesProvider);
    final weekStartDay = ref.watch(weekStartDayProvider);
    final consistencyWindow = ref.watch(consistencyWindowDaysProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sessions = sessionsAsync.value ?? [];
    final now = DateTime.now();
    final dailyTotals = StatsEngine.calculateDailyTotals(sessions);

    final consistency = StatsEngine.calculateConsistency(
      dailyTotals: dailyTotals,
      today: now,
      windowDays: consistencyWindow,
      thresholdMinutes: consistencyThreshold,
    );
    final streaks = StatsEngine.calculateStreaks(
      dailyTotals: dailyTotals,
      today: now,
      thresholdMinutes: consistencyThreshold,
    );
    final weeklyTrend = StatsEngine.calculateWeeklyTrend(
      dailyTotals: dailyTotals,
      today: now,
      weekStartDay: weekStartDay,
    );
    final dailyTrend = StatsEngine.calculateDailyTrend(
      dailyTotals: dailyTotals,
      today: now,
    );

    // Total stats
    final totalMins = sessions.where((s) => s.deletedAt == null).fold<int>(0, (acc, s) => acc + (s.durationMs / 60000).round());
    final totalHours = (totalMins / 60.0).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INSIGHTS & VELOCITY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Welcome to Productivity',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accentEmerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Offline SQLite • Realtime',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Row 1: 4 Linear Metric Bento Tiles
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 640;

                      final consistencyTile = InkWell(
                        onTap: () {
                          // Cycle between 7, 30, 90 days (PRD §5.2)
                          final next = consistencyWindow == 7 ? 30 : (consistencyWindow == 30 ? 90 : 7);
                          ref.read(consistencyWindowDaysProvider.notifier).state = next;
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: _buildBentoTile(
                          title: '${consistencyWindow}D CONSISTENCY',
                          value: '${consistency.percentage.toInt()}%',
                          subtext: '${consistency.activeDays} of $consistencyWindow days met (tap 7/30/90d)',
                          badgeText: consistency.percentage >= 80 ? 'EXCELLENT' : 'ON TRACK',
                          badgeColor: AppColors.accentEmerald,
                          isDark: isDark,
                        ),
                      );

                      if (isStacked) {
                        return Column(
                          children: [
                            consistencyTile,
                            const SizedBox(height: 12),
                            _buildBentoTile(
                              title: 'STREAK',
                              value: '${streaks.currentStreak}d',
                              subtext: 'All-time best: ${streaks.bestStreak} days',
                              badgeText: '🔥 ACTIVE',
                              badgeColor: AppColors.accentOrange,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildBentoTile(
                              title: 'DAY DELTA',
                              value: '${dailyTrend.deltaMinutes >= 0 ? '+' : ''}${dailyTrend.deltaMinutes}m',
                              subtext: '${dailyTrend.percentageChange.toStringAsFixed(1)}% vs yesterday',
                              badgeText: dailyTrend.deltaMinutes >= 0 ? '▲ UP' : '▼ DOWN',
                              badgeColor: dailyTrend.deltaMinutes >= 0 ? AppColors.accentEmerald : Colors.redAccent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildBentoTile(
                              title: '4-WEEK TREND',
                              value: weeklyTrend.direction == TrendDirection.increasing
                                  ? 'Increasing'
                                  : (weeklyTrend.direction == TrendDirection.decreasing ? 'Decreasing' : 'Steady'),
                              subtext: '${weeklyTrend.deltaHours >= 0 ? '+' : ''}${weeklyTrend.deltaHours.toStringAsFixed(1)}h vs last week',
                              badgeText: weeklyTrend.direction == TrendDirection.increasing ? '▲ ASCENDING' : 'STEADY',
                              badgeColor: AppColors.accentIndigo,
                              isDark: isDark,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: consistencyTile),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoTile(
                              title: 'CURRENT STREAK',
                              value: '${streaks.currentStreak}d',
                              subtext: 'Best: ${streaks.bestStreak} days',
                              badgeText: 'ACTIVE',
                              badgeColor: AppColors.accentOrange,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoTile(
                              title: 'DAILY DELTA',
                              value: '${dailyTrend.deltaMinutes >= 0 ? '+' : ''}${dailyTrend.deltaMinutes}m',
                              subtext: '${dailyTrend.percentageChange.toStringAsFixed(1)}% vs yesterday',
                              badgeText: dailyTrend.deltaMinutes >= 0 ? '▲ UP' : '▼ DOWN',
                              badgeColor: dailyTrend.deltaMinutes >= 0 ? AppColors.accentEmerald : Colors.redAccent,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoTile(
                              title: '4-WEEK REGRESSION',
                              value: weeklyTrend.direction == TrendDirection.increasing
                                  ? 'Ascending'
                                  : (weeklyTrend.direction == TrendDirection.decreasing ? 'Softening' : 'Steady'),
                              subtext: '${weeklyTrend.deltaHours >= 0 ? '+' : ''}${weeklyTrend.deltaHours.toStringAsFixed(1)}h this wk',
                              badgeText: 'SLOPE: ${weeklyTrend.slope.toStringAsFixed(2)}',
                              badgeColor: AppColors.accentIndigo,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Row 2: Precision Charts (Last 7 Days & 4-Week Volume)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 750;

                      final chart7Days = _buildChartCard(
                        title: 'Daily Velocity (Last 7 Days)',
                        subtitle: 'Minutes read per day • Goal: ${ref.watch(dailyGoalMinutesProvider)}m',
                        isDark: isDark,
                        child: _buildPrecision7DayChart(dailyTotals, now, isDark, ref.watch(dailyGoalMinutesProvider)),
                      );

                      final chart4Weeks = _buildChartCard(
                        title: 'Weekly Volume (4-Week Slope)',
                        subtitle: 'Total volume in hours (Linear regression input)',
                        isDark: isDark,
                        child: _buildPrecision4WeekChart(dailyTotals, now, weekStartDay, isDark),
                      );

                      if (isStacked) {
                        return Column(
                          children: [
                            chart7Days,
                            const SizedBox(height: 16),
                            chart4Weeks,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 3, child: chart7Days),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: chart4Weeks),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Row 3: 24-Hour Diurnal Distribution & Category Breakdown (PRD §4 US-4, §5.3, §8)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 750;

                      final hourlyChart = _buildChartCard(
                        title: '24-Hour Diurnal Distribution (Today)',
                        subtitle: 'Reading intensity by hour of day (0h – 23h)',
                        isDark: isDark,
                        child: _buildPrecisionHourlyChart(
                          StatsEngine.calculateHourlyDistribution(sessions, now),
                          isDark,
                        ),
                      );

                      final subjectPieChart = _buildChartCard(
                        title: 'Subject & Book Allocation',
                        subtitle: 'Distribution of reading time by category',
                        isDark: isDark,
                        child: _buildSubjectAllocationPieChart(sessions, isDark),
                      );

                      if (isStacked) {
                        return Column(
                          children: [
                            hourlyChart,
                            const SizedBox(height: 16),
                            subjectPieChart,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 3, child: hourlyChart),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: subjectPieChart),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Row 4: Total Summary Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: isDark ? AppColors.accentIndigo : AppColors.accentIndigo),
                            const SizedBox(width: 12),
                            Text(
                              'Cumulative Reading Record',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$totalHours Hours ($totalMins mins across ${sessions.length} sessions)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
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

  Widget _buildBentoTile({
    required String title,
    required String value,
    required String subtext,
    required String badgeText,
    required Color badgeColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(height: 220, child: ClipRect(child: child)),
        ],
      ),
    );
  }

  Widget _buildPrecision7DayChart(Map<DateTime, int> dailyTotals, DateTime now, bool isDark, int goalMins) {
    // Dynamically calculate maxY to prevent bar overflow
    double maxMins = goalMins.toDouble();
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final m = (dailyTotals[date] ?? 0).toDouble();
      if (m > maxMins) maxMins = m;
    }
    // Add headroom and round up to next 30m interval
    final maxY = ((maxMins * 1.25) / 30).ceil() * 30.0;
    final interval = (maxY / 4).clamp(15.0, 60.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY > 0 ? maxY : 90.0,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goalMins.toDouble(),
              color: AppColors.accentEmerald.withOpacity(0.6),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                style: const TextStyle(color: AppColors.accentEmerald, fontSize: 9, fontWeight: FontWeight.bold),
                labelResolver: (_) => 'Goal: ${goalMins}m',
              ),
            ),
          ],
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (val) {
            return FlLine(
              color: (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: interval,
              getTitlesWidget: (val, meta) {
                return Text(
                  '${val.toInt()}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final date = now.subtract(Duration(days: 6 - val.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
            tooltipRoundedRadius: 6,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} mins',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        barGroups: List.generate(7, (idx) {
          final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - idx));
          final mins = (dailyTotals[date] ?? 0).toDouble();
          final isToday = idx == 6;

          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: mins,
                color: isToday ? AppColors.accentIndigo : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPrecision4WeekChart(
    Map<DateTime, int> dailyTotals,
    DateTime now,
    int weekStartDay,
    bool isDark,
  ) {
    // Dynamically calculate maxY for weekly volume
    double maxHours = 12.0;
    for (int idx = 0; idx < 4; idx++) {
      final offsetWeeks = 3 - idx;
      final daysFromStart = (now.weekday - weekStartDay + 7) % 7;
      final thisWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromStart));
      final targetWeekStart = thisWeekStart.subtract(Duration(days: 7 * offsetWeeks));

      int sumMins = 0;
      for (int d = 0; d < 7; d++) {
        sumMins += dailyTotals[targetWeekStart.add(Duration(days: d))] ?? 0;
      }
      final h = sumMins / 60.0;
      if (h > maxHours) maxHours = h;
    }
    final maxY = ((maxHours * 1.25) / 4).ceil() * 4.0;
    final interval = (maxY / 4).clamp(2.0, 8.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY > 0 ? maxY : 16.0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (val) {
            return FlLine(
              color: (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (val, meta) {
                return Text(
                  '${val.toInt()}h',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                final text = idx == 3 ? 'THIS WK' : '-${3 - idx}W';
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(4, (idx) {
          final offsetWeeks = 3 - idx;
          final daysFromStart = (now.weekday - weekStartDay + 7) % 7;
          final thisWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromStart));
          final targetWeekStart = thisWeekStart.subtract(Duration(days: 7 * offsetWeeks));

          int sumMins = 0;
          for (int d = 0; d < 7; d++) {
            sumMins += dailyTotals[targetWeekStart.add(Duration(days: d))] ?? 0;
          }
          final hours = sumMins / 60.0;
          final isCurrent = idx == 3;

          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: hours,
                color: isCurrent ? AppColors.accentEmerald : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPrecisionHourlyChart(
    Map<int, int> hourlyDistribution,
    bool isDark,
  ) {
    int maxMins = 0;
    for (final m in hourlyDistribution.values) {
      if (m > maxMins) maxMins = m;
    }
    final maxY = maxMins > 60 ? (maxMins + 15).toDouble() : 60.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (val) {
            return FlLine(
              color: (isDark ? AppColors.borderDark : AppColors.borderLight).withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 20,
              getTitlesWidget: (val, meta) {
                return Text(
                  '${val.toInt()}m',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final h = val.toInt();
                if (h % 4 != 0 && h != 23) {
                  return const SizedBox.shrink();
                }
                final label = h == 0 ? '12a' : (h == 12 ? '12p' : (h < 12 ? '${h}a' : '${h - 12}p'));
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(24, (h) {
          final mins = (hourlyDistribution[h] ?? 0).toDouble();
          final hasActivity = mins > 0;

          return BarChartGroupData(
            x: h,
            barRods: [
              BarChartRodData(
                toY: mins,
                color: hasActivity
                    ? AppColors.accentEmerald
                    : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSubjectAllocationPieChart(
    List<ReadingSession> sessions,
    bool isDark,
  ) {
    final Map<String, int> subjectMins = {};
    for (final s in sessions) {
      if (s.deletedAt != null) continue;
      final sub = (s.subjectId != null && s.subjectId!.isNotEmpty) ? s.subjectId! : 'General';
      final mins = (s.durationMs / 60000).round();
      subjectMins[sub] = (subjectMins[sub] ?? 0) + mins;
    }

    if (subjectMins.isEmpty) {
      return Center(
        child: Text(
          'No reading sessions recorded yet',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
      );
    }

    final totalMins = subjectMins.values.fold<int>(0, (sum, m) => sum + m);

    final palette = [
      AppColors.accentIndigo,
      AppColors.accentEmerald,
      AppColors.accentOrange,
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
    ];

    int colorIdx = 0;
    final entries = subjectMins.entries.toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 28,
              sections: entries.map((entry) {
                final color = palette[colorIdx % palette.length];
                colorIdx++;
                final pct = totalMins > 0 ? (entry.value / totalMins * 100) : 0.0;
                return PieChartSectionData(
                  color: color,
                  value: entry.value.toDouble(),
                  title: '${pct.toInt()}%',
                  radius: 36,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(entries.length, (i) {
              final entry = entries[i];
              final color = palette[i % palette.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}m',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Screen 1: Focus Timer (Precision Minimalist)
// -------------------------------------------------------------
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  static String formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showCustomDurationDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(targetFocusDurationMinutesProvider) ?? 25;
    final controller = TextEditingController(text: current.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Target Focus Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter target focus block (mins):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(suffixText: 'mins', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(targetFocusDurationMinutesProvider.notifier).state = null;
              Navigator.pop(ctx);
            },
            child: const Text('Open (No Limit)'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 25;
              ref.read(targetFocusDurationMinutesProvider.notifier).state = val > 0 ? val : null;
              Navigator.pop(ctx);
            },
            child: const Text('Set Target'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopwatchState = ref.watch(stopwatchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetMins = ref.watch(targetFocusDurationMinutesProvider);

    double sessionProgress = 0.0;
    if (targetMins != null && targetMins > 0) {
      final elapsedMins = stopwatchState.elapsedMs / 60000.0;
      sessionProgress = (elapsedMins / targetMins).clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Productivity', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: 'StandBy Clock Mode',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FullscreenClockModeScreen()));
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Target Pill
              InkWell(
                onTap: stopwatchState.status == StopwatchStatus.idle
                    ? () => _showCustomDurationDialog(context, ref)
                    : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.adjust_rounded, size: 14, color: AppColors.accentIndigo),
                      const SizedBox(width: 8),
                      Text(
                        targetMins == null ? 'TARGET: OPEN TIMER' : 'TARGET: $targetMins MINS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Precision Timer Readout
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: targetMins != null ? sessionProgress : null,
                      strokeWidth: 2,
                      backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                      color: AppColors.accentIndigo,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDuration(stopwatchState.elapsedMs),
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stopwatchState.status == StopwatchStatus.running
                            ? 'ACTIVE READING'
                            : (stopwatchState.status == StopwatchStatus.paused ? 'PAUSED' : 'READY'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: stopwatchState.status == StopwatchStatus.running
                              ? AppColors.accentEmerald
                              : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Linear Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (stopwatchState.status == StopwatchStatus.idle)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentIndigo,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => ref.read(stopwatchProvider.notifier).start(),
                      child: const Text('Start Focus Session', style: TextStyle(fontWeight: FontWeight.w600)),
                    )
                  else ...[
                    if (stopwatchState.status == StopwatchStatus.running)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                        onPressed: () => ref.read(stopwatchProvider.notifier).pause(),
                        child: const Text('Pause'),
                      )
                    else
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentIndigo,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => ref.read(stopwatchProvider.notifier).resume(),
                        child: const Text('Resume'),
                      ),
                    const SizedBox(width: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? AppColors.surfaceDarkHover : const Color(0xFFE4E4E7),
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => ref.read(stopwatchProvider.notifier).stop(),
                      child: const Text('Stop & Save'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 3: StandBy Fullscreen Mode
// -------------------------------------------------------------
class FullscreenClockModeScreen extends ConsumerStatefulWidget {
  const FullscreenClockModeScreen({super.key});

  @override
  ConsumerState<FullscreenClockModeScreen> createState() => _FullscreenClockModeScreenState();
}

class _FullscreenClockModeScreenState extends ConsumerState<FullscreenClockModeScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stopwatchState = ref.watch(stopwatchProvider);
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm').format(now);
    final amPmStr = DateFormat('a').format(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0),
                child: OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;

                    if (isLandscape) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: AppColors.accentOrange,
                                      fontSize: 112,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    amPmStr,
                                    style: const TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(dateStr, style: const TextStyle(color: Colors.white60, fontSize: 18)),
                            ],
                          ),
                          const VerticalDivider(color: Colors.white12, width: 64),
                          _buildStandByControls(context, stopwatchState),
                        ],
                      );
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: AppColors.accentOrange,
                                fontSize: 90,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(amPmStr, style: const TextStyle(color: Colors.white54, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(dateStr, style: const TextStyle(color: Colors.white60, fontSize: 16)),
                        const SizedBox(height: 52),
                        _buildStandByControls(context, stopwatchState),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandByControls(BuildContext context, StopwatchState stopwatchState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'READING TIMER',
          style: TextStyle(color: Colors.white30, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          TimerScreen.formatDuration(stopwatchState.elapsedMs),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.w300,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stopwatchState.status == StopwatchStatus.idle)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentOrange),
                onPressed: () => ref.read(stopwatchProvider.notifier).start(),
                child: const Text('Start Focus', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            else ...[
              if (stopwatchState.status == StopwatchStatus.running)
                IconButton.filledTonal(
                  onPressed: () => ref.read(stopwatchProvider.notifier).pause(),
                  icon: const Icon(Icons.pause),
                )
              else
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.accentOrange),
                  onPressed: () => ref.read(stopwatchProvider.notifier).resume(),
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () => ref.read(stopwatchProvider.notifier).stop(),
                icon: const Icon(Icons.stop),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Screen 4: Session Log (CRUD, Manual Entry & Subject Tagging)
// -------------------------------------------------------------
class SessionsHistoryScreen extends ConsumerWidget {
  const SessionsHistoryScreen({super.key});

  void _showAddOrEditSessionDialog(
    BuildContext context,
    WidgetRef ref, {
    ReadingSession? existing,
  }) {
    final isEditing = existing != null;
    final initialMinutes = isEditing ? (existing.durationMs / 60000).round() : 30;
    final initialDate = isEditing
        ? DateTime.fromMillisecondsSinceEpoch(existing.startedAtUtc)
        : DateTime.now();

    final minutesController = TextEditingController(text: initialMinutes.toString());
    final noteController = TextEditingController(text: existing?.note ?? '');
    String selectedSubject = existing?.subjectId ?? 'General';
    DateTime selectedDate = initialDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            title: Text(
              isEditing ? 'Edit Session' : 'Add Past Reading Session',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duration (minutes):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 45',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Subject / Category:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'General', child: Text('General Reading')),
                      DropdownMenuItem(value: 'Fiction', child: Text('Fiction / Novels')),
                      DropdownMenuItem(value: 'Non-Fiction', child: Text('Non-Fiction / Philosophy')),
                      DropdownMenuItem(value: 'Study', child: Text('Study / Academics')),
                      DropdownMenuItem(value: 'Research', child: Text('Research / Tech')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedSubject = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Date & Time:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                selectedDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  selectedDate.hour,
                                  selectedDate.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDate),
                            );
                            if (pickedTime != null) {
                              setDialogState(() {
                                selectedDate = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(DateFormat('HH:mm').format(selectedDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Note (Optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Chapter 4 & 5',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final mins = int.tryParse(minutesController.text) ?? 0;
                  if (mins <= 0) return;

                  final durationMs = mins * 60000;
                  final startEpoch = selectedDate.millisecondsSinceEpoch;
                  final endEpoch = startEpoch + durationMs;
                  final tz = DateTime.now().timeZoneOffset.inMinutes;

                  if (isEditing) {
                    final updated = existing.copyWith(
                      startedAtUtc: startEpoch,
                      endedAtUtc: endEpoch,
                      durationMs: durationMs,
                      subjectId: selectedSubject,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await ref.read(sessionRepositoryProvider).updateSession(updated);
                  } else {
                    final newSession = ReadingSession(
                      id: const Uuid().v4(),
                      startedAtUtc: startEpoch,
                      endedAtUtc: endEpoch,
                      durationMs: durationMs,
                      tzOffsetMin: tz,
                      subjectId: selectedSubject,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                      source: 'manual',
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await ref.read(sessionRepositoryProvider).saveSession(newSession);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(isEditing ? 'Save Changes' : 'Add Session'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteSession(BuildContext context, WidgetRef ref, ReadingSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this session?'),
        content: Text(
          'Delete ${(session.durationMs / 60000).round()}m session from ${DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(session.startedAtUtc))}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ref.read(sessionRepositoryProvider).softDeleteSession(session.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final sessions = (sessionsAsync.value ?? [])
        .where((s) => s.deletedAt == null)
        .toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Reading Log', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        actions: [
          FilledButton.tonalIcon(
            onPressed: () => _showAddOrEditSessionDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Manual Entry'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 48, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      const SizedBox(height: 12),
                      Text(
                        'No reading sessions recorded yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Start a focus timer or add a manual session using the button above.',
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  itemBuilder: (ctx, idx) {
                    final s = sessions[idx];
                    final date = DateTime.fromMillisecondsSinceEpoch(s.startedAtUtc);
                    final durationMins = (s.durationMs / 60000).round();
                    final subject = s.subjectId ?? 'General';
                    final note = s.note;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      title: Row(
                        children: [
                          Text('$durationMins minutes', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentIndigo.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subject,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentIndigo),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy • h:mm a').format(date),
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '“$note”',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.source.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: s.source == 'manual' ? AppColors.accentOrange : AppColors.accentEmerald,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showAddOrEditSessionDialog(context, ref, existing: s),
                            tooltip: 'Edit Session',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () => _confirmDeleteSession(context, ref, s),
                            tooltip: 'Delete Session',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 5: Settings (PDF, CSV/JSON Backup & Restore, Custom Time Guard)
// -------------------------------------------------------------
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showExportDialog(BuildContext context, List<ReadingSession> sessions) {
    final csvStr = SessionExportService.exportToCsv(sessions);
    final jsonStr = SessionExportService.exportToJson(sessions);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Sessions Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found ${sessions.where((s) => s.deletedAt == null).length} active reading sessions.'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart, color: AppColors.accentEmerald),
              title: const Text('Copy as CSV'),
              subtitle: const Text('Tabular format (Excel, Sheets)'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: csvStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: AppColors.accentIndigo),
              title: const Text('Copy as JSON'),
              subtitle: const Text('Raw machine-readable backup'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON copied to clipboard!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Sessions Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste CSV or JSON export content below:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste CSV or JSON text here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final raw = controller.text.trim();
              if (raw.isEmpty) return;

              List<ReadingSession> imported = [];
              try {
                if (raw.startsWith('[') || raw.startsWith('{')) {
                  imported = SessionExportService.importFromJson(raw);
                } else {
                  imported = SessionExportService.importFromCsv(raw);
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to parse: $e')),
                  );
                }
                return;
              }

              if (imported.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No valid sessions found in input.')),
                  );
                }
                return;
              }

              final repo = ref.read(sessionRepositoryProvider);
              for (final s in imported) {
                await repo.saveSession(s);
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully imported ${imported.length} sessions!')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showTimePickerDialog(
    BuildContext context, {
    required String title,
    required int initialMinutes,
    required ValueChanged<int> onSaved,
  }) {
    String unit = initialMinutes >= 60 && initialMinutes % 60 == 0 ? 'hr' : 'min';
    final initialVal = unit == 'hr' ? (initialMinutes / 60).round() : initialMinutes;
    final controller = TextEditingController(text: initialVal.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter duration and select unit (hr / min):'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                        onChanged: (val) {
                          final numVal = int.tryParse(val) ?? 0;
                          if (numVal > 12 && unit == 'hr') {
                            setDialogState(() => unit = 'min');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'hr', label: Text('hr')),
                        ButtonSegment(value: 'min', label: Text('min')),
                      ],
                      selected: {unit},
                      onSelectionChanged: (set) {
                        setDialogState(() {
                          unit = set.first;
                          final numVal = int.tryParse(controller.text) ?? 0;
                          if (unit == 'hr' && numVal > 12) unit = 'min';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final numVal = int.tryParse(controller.text) ?? 30;
                  final finalMins = unit == 'hr' ? numVal * 60 : numVal;
                  if (finalMins > 0) onSaved(finalMins);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final dailyGoal = ref.watch(dailyGoalMinutesProvider);
    final consistencyThreshold = ref.watch(consistencyThresholdMinutesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                title: const Text('Appearance'),
                subtitle: Text(themeMode.name.toUpperCase()),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox(),
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeProvider.notifier).state = mode;
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Obsidian Dark')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Clean Light')),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Daily Goal'),
                subtitle: Text(
                  dailyGoal >= 60
                      ? '${(dailyGoal / 60).toStringAsFixed(dailyGoal % 60 == 0 ? 0 : 1)} hr (${dailyGoal} mins)'
                      : '$dailyGoal minutes',
                ),
                trailing: OutlinedButton(
                  onPressed: () {
                    _showTimePickerDialog(
                      context,
                      title: 'Set Daily Goal',
                      initialMinutes: dailyGoal,
                      onSaved: (val) => ref.read(dailyGoalMinutesProvider.notifier).state = val,
                    );
                  },
                  child: const Text('Customize'),
                ),
              ),
              ListTile(
                title: const Text('Streak Threshold'),
                subtitle: Text(
                  consistencyThreshold >= 60
                      ? '${(consistencyThreshold / 60).toStringAsFixed(consistencyThreshold % 60 == 0 ? 0 : 1)} hr (${consistencyThreshold} mins)'
                      : '$consistencyThreshold minutes / day',
                ),
                trailing: OutlinedButton(
                  onPressed: () {
                    _showTimePickerDialog(
                      context,
                      title: 'Set Streak Threshold',
                      initialMinutes: consistencyThreshold,
                      onSaved: (val) => ref.read(consistencyThresholdMinutesProvider.notifier).state = val,
                    );
                  },
                  child: const Text('Customize'),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accentIndigo),
                title: const Text('Export Records (PDF Report)'),
                subtitle: const Text('Print or share PDF summary • Developed by Koushik'),
                onTap: () async {
                  final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                  await SessionPdfService.printOrSharePdf(sessions);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: AppColors.accentEmerald),
                title: const Text('Export Data (CSV & JSON)'),
                subtitle: const Text('Download raw backup of all reading sessions'),
                onTap: () async {
                  final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                  if (!context.mounted) return;
                  _showExportDialog(context, sessions);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined, color: AppColors.accentOrange),
                title: const Text('Import Data (CSV & JSON)'),
                subtitle: const Text('Restore or migrate sessions from file/text'),
                onTap: () {
                  _showImportDialog(context, ref);
                },
              ),
              const Divider(),
              const _UpdateCheckTile(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Clear All Local Data', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                subtitle: const Text('Purge all sessions and reset history'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Are you sure you want to delete all data?'),
                      content: const Text(
                        'This action will permanently delete all recorded focus sessions stored locally on this device. This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('No, Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () async {
                            final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                            for (final s in sessions) {
                              await ref.read(sessionRepositoryProvider).softDeleteSession(s.id);
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All data has been deleted.')),
                              );
                            }
                          },
                          child: const Text('Yes, Delete All'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateCheckTile extends StatefulWidget {
  const _UpdateCheckTile();

  @override
  State<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<_UpdateCheckTile> {
  bool _isChecking = false;

  void _manualCheck() async {
    setState(() => _isChecking = true);
    final service = AppUpdateService();
    final result = await service.checkForUpdate(force: true);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (result.hasUpdate && result.releaseInfo != null) {
      UpdateDialog.show(context, result.releaseInfo!);
    } else if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Productivity is up to date (${result.currentVersion}).'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update_rounded, color: Color(0xFF34D399)),
      title: const Text('Check for Updates'),
      subtitle: const Text('GitHub Releases • Automated APK updates'),
      trailing: _isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34D399)),
            )
          : OutlinedButton(
              onPressed: _manualCheck,
              child: const Text('Check Now'),
            ),
    );
  }
}

