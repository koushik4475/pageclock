import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/engine/stopwatch_engine.dart';
import '../core/models/reading_session.dart';
import '../core/repository/session_repository.dart';
import '../stats/stats_engine.dart';
import '../core/services/export_service.dart';
import '../core/services/pdf_service.dart';

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
      title: 'PageClock',
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
      home: const MainNavigationShell(),
    );
  }
}

// -------------------------------------------------------------
// Main Navigation Shell (Ultra-Minimalist Sidebar & Dock)
// -------------------------------------------------------------
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 1; // Default to Insights

  final _screens = const [
    TimerScreen(),
    AnalyticsScreen(),
    SessionsHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        body: Row(
          children: [
            // Linear-Style Desktop Sidebar
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.surfaceLight,
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accentIndigo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.timer_outlined, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'pageclock.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSidebarItem(0, 'Focus Timer', Icons.schedule_rounded, isDark),
                  _buildSidebarItem(1, 'Insights', Icons.analytics_outlined, isDark),
                  _buildSidebarItem(2, 'Session Log', Icons.history_rounded, isDark),
                  _buildSidebarItem(3, 'Settings', Icons.tune_rounded, isDark),

                  const Spacer(),

                  // Bottom Developer Badge
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Koushik',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'koushikhy.netlify.app',
                          style: TextStyle(fontSize: 10, color: AppColors.accentIndigo),
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
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Bottom Navigation Bar
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
          selectedItemColor: AppColors.accentIndigo,
          unselectedItemColor: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: 'Focus'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Insights'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Log'),
            BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: 'Settings'),
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
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceDarkHover : const Color(0xFFF4F4F5))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.accentIndigo
                    : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sessions = sessionsAsync.value ?? [];
    final now = DateTime.now();
    final dailyTotals = StatsEngine.calculateDailyTotals(sessions);

    final consistency30 = StatsEngine.calculateConsistency(
      dailyTotals: dailyTotals,
      today: now,
      windowDays: 30,
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
                            'Reading Analytics',
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
                      final tileWidth = (constraints.maxWidth - 36) / 4;
                      final isStacked = constraints.maxWidth < 640;

                      if (isStacked) {
                        return Column(
                          children: [
                            _buildBentoTile(
                              title: '30D CONSISTENCY',
                              value: '${consistency30.percentage.toInt()}%',
                              subtext: '${consistency30.activeDays} of 30 days completed',
                              badgeText: consistency30.percentage >= 80 ? 'EXCELLENT' : 'ON TRACK',
                              badgeColor: AppColors.accentEmerald,
                              isDark: isDark,
                            ),
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
                          Expanded(
                            child: _buildBentoTile(
                              title: '30D CONSISTENCY',
                              value: '${consistency30.percentage.toInt()}%',
                              subtext: '${consistency30.activeDays} of 30 days met',
                              badgeText: consistency30.percentage >= 80 ? 'EXCELLENT' : 'ON TRACK',
                              badgeColor: AppColors.accentEmerald,
                              isDark: isDark,
                            ),
                          ),
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
                        subtitle: 'Minutes read per day • Goal: 30m',
                        isDark: isDark,
                        child: _buildPrecision7DayChart(dailyTotals, now, isDark),
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

                  // Row 3: Total Summary Banner
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
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }

  Widget _buildPrecision7DayChart(Map<DateTime, int> dailyTotals, DateTime now, bool isDark) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 120,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 30,
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
              reservedSize: 32,
              interval: 30,
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
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 16,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 4,
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
              interval: 4,
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
        title: const Text('PageClock', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
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
// Screen 4: Session Log
// -------------------------------------------------------------
class SessionsHistoryScreen extends ConsumerWidget {
  const SessionsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final sessions = sessionsAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Reading Log', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.separated(
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

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text('$durationMins minutes', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(DateFormat('EEEE, MMM d • h:mm a').format(date), style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                trailing: Text(s.source.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentIndigo)),
              );
            },
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 5: Settings (PDF Only + Custom Time Guard)
// -------------------------------------------------------------
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
                title: const Text('Export Records (PDF Only)'),
                subtitle: const Text('Official report • Developed by Koushik (koushikhy.netlify.app)'),
                onTap: () async {
                  final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                  await SessionPdfService.printOrSharePdf(sessions);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
