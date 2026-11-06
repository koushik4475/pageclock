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

// Theme Mode Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Settings Providers
final dailyGoalMinutesProvider = StateProvider<int>((ref) => 30);
final consistencyThresholdMinutesProvider = StateProvider<int>((ref) => 10);
final weekStartDayProvider = StateProvider<int>((ref) => DateTime.monday);

// Sessions Provider
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final _screens = const [
    TimerScreen(),
    AnalyticsScreen(),
    SessionsHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Icon(Icons.menu_book_rounded, size: 32, color: Color(0xFF1E88E5)),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer),
                  label: Text('Timer'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Analytics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('History'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 1: Timer / Today
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopwatchState = ref.watch(stopwatchProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final dailyGoal = ref.watch(dailyGoalMinutesProvider);

    final sessions = sessionsAsync.value ?? [];
    final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final todayMinutes = dailyTotals[todayKey] ?? 0;
    final progress = (todayMinutes / dailyGoal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PageClock'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'iPhone StandBy Clock Mode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FullscreenClockModeScreen()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 500;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Daily Goal Progress
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Today: $todayMinutes / $dailyGoal mins',
                                    style: Theme.of(context).textTheme.titleMedium),
                                Text('${(progress * 100).toInt()}% of daily goal',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isCompact) const Spacer(),

                    const SizedBox(height: 16),
                    // Timer Display
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatDuration(stopwatchState.elapsedMs),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: isCompact ? 56 : 76,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stopwatchState.status == StopwatchStatus.running
                          ? 'READING SESSION ACTIVE'
                          : (stopwatchState.status == StopwatchStatus.paused
                              ? 'PAUSED'
                              : 'READY TO READ'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: stopwatchState.status == StopwatchStatus.running
                                ? Colors.green
                                : (stopwatchState.status == StopwatchStatus.paused
                                    ? Colors.orange
                                    : Theme.of(context).hintColor),
                            letterSpacing: 1.2,
                          ),
                    ),
                    if (!isCompact) const Spacer(),
                    const SizedBox(height: 24),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (stopwatchState.status == StopwatchStatus.idle)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () => ref.read(stopwatchProvider.notifier).start(),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Reading', style: TextStyle(fontSize: 18)),
                          )
                        else ...[
                          if (stopwatchState.status == StopwatchStatus.running)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                              onPressed: () => ref.read(stopwatchProvider.notifier).pause(),
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause'),
                            )
                          else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                              onPressed: () => ref.read(stopwatchProvider.notifier).resume(),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Resume'),
                            ),
                          const SizedBox(width: 20),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            onPressed: () async {
                              final session = await ref.read(stopwatchProvider.notifier).stop();
                              if (session == null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Session under 1 min discarded.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop & Save'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// StandBy / iPhone Full-Screen Clock Mode
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
            // Exit button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Standby Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;

                    if (isLandscape) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left side: Giant Clock
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
                                      color: Color(0xFFFF5722),
                                      fontSize: 108,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    amPmStr,
                                    style: const TextStyle(
                                      color: Color(0xFFFF8A65),
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const VerticalDivider(color: Colors.white24, width: 64),
                          // Right side: Active Reading Timer & Controls
                          _buildStandByTimerWidget(context, stopwatchState),
                        ],
                      );
                    }

                    // Portrait Mode
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
                                color: Color(0xFFFF5722),
                                fontSize: 88,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              amPmStr,
                              style: const TextStyle(
                                color: Color(0xFFFF8A65),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                        const SizedBox(height: 48),
                        _buildStandByTimerWidget(context, stopwatchState),
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

  Widget _buildStandByTimerWidget(BuildContext context, StopwatchState stopwatchState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'READING TIMER',
          style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          TimerScreen.formatDuration(stopwatchState.elapsedMs),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stopwatchState.status == StopwatchStatus.idle)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                onPressed: () => ref.read(stopwatchProvider.notifier).start(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              )
            else ...[
              if (stopwatchState.status == StopwatchStatus.running)
                IconButton.filledTonal(
                  onPressed: () => ref.read(stopwatchProvider.notifier).pause(),
                  icon: const Icon(Icons.pause),
                )
              else
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF5722)),
                  onPressed: () => ref.read(stopwatchProvider.notifier).resume(),
                  icon: const Icon(Icons.play_arrow),
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
// Screen 2: Analytics & Charts
// -------------------------------------------------------------
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final consistencyThreshold = ref.watch(consistencyThresholdMinutesProvider);
    final weekStartDay = ref.watch(weekStartDayProvider);

    final sessions = sessionsAsync.value ?? [];
    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_graph, size: 72, color: Theme.of(context).hintColor),
              const SizedBox(height: 16),
              const Text('No reading data yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Start your first reading session to see analytics!'),
            ],
          ),
        ),
      );
    }

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

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Trend summary cards
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Consistency (30d)',
                      value: '${consistency30.percentage.toInt()}%',
                      subtitle: '${consistency30.activeDays} of 30 days',
                      icon: Icons.calendar_today,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: 'Streak',
                      value: '${streaks.currentStreak}d',
                      subtitle: 'Best: ${streaks.bestStreak}d',
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Daily Trend',
                      value: '${dailyTrend.deltaMinutes >= 0 ? '+' : ''}${dailyTrend.deltaMinutes}m',
                      subtitle: '${dailyTrend.percentageChange.toStringAsFixed(1)}% vs yesterday',
                      icon: dailyTrend.deltaMinutes >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      iconColor: dailyTrend.deltaMinutes >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: 'Weekly Trend',
                      value: weeklyTrend.direction == TrendDirection.increasing
                          ? '▲ Increasing'
                          : (weeklyTrend.direction == TrendDirection.decreasing
                              ? '▼ Decreasing'
                              : '— Steady'),
                      subtitle: '${weeklyTrend.deltaHours >= 0 ? '+' : ''}${weeklyTrend.deltaHours.toStringAsFixed(1)}h vs last wk',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Last 7 days Bar Chart
              Text('Last 7 Days (Minutes)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()} mins',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final date = now.subtract(Duration(days: 6 - val.toInt()));
                            return Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 11));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(7, (idx) {
                      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - idx));
                      final mins = (dailyTotals[date] ?? 0).toDouble();
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: mins,
                            color: Theme.of(context).colorScheme.primary,
                            width: 18,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 4-Week Trend Bar Chart
              Text('Last 4 Weeks (Hours)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx == 3) return const Text('This Wk');
                            return Text('${3 - idx}w ago');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
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

                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: hours,
                            color: Colors.teal,
                            width: 22,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 3: Sessions History & Manual CRUD
// -------------------------------------------------------------
class SessionsHistoryScreen extends ConsumerWidget {
  const SessionsHistoryScreen({super.key});

  void _showAddManualDialog(BuildContext context, WidgetRef ref) {
    int durationMinutes = 30;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Manual Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter reading duration:'),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutes', border: OutlineInputBorder()),
              onChanged: (val) {
                durationMinutes = int.tryParse(val) ?? 30;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
              final session = ReadingSession(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                startedAtUtc: nowUtc - (durationMinutes * 60000),
                endedAtUtc: nowUtc,
                durationMs: durationMinutes * 60000,
                tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
                source: 'manual',
                createdAt: nowUtc,
                updatedAt: nowUtc,
              );
              await ref.read(sessionRepositoryProvider).saveSession(session);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final sessions = sessionsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add manual session',
            onPressed: () => _showAddManualDialog(context, ref),
          ),
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
                      Icon(Icons.history, size: 64, color: Theme.of(context).hintColor),
                      const SizedBox(height: 12),
                      const Text('No reading sessions logged yet.'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final s = sessions[idx];
                    final date = DateTime.fromMillisecondsSinceEpoch(s.startedAtUtc);
                    final durationMins = (s.durationMs / 60000).round();

                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(s.source == 'manual' ? Icons.edit_note : Icons.timer),
                      ),
                      title: Text('$durationMins minutes'),
                      subtitle: Text(DateFormat('EEE, MMM d, yyyy • h:mm a').format(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref.read(sessionRepositoryProvider).softDeleteSession(s.id),
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
// Screen 4: Settings
// -------------------------------------------------------------
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final dailyGoal = ref.watch(dailyGoalMinutesProvider);
    final consistencyThreshold = ref.watch(consistencyThresholdMinutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                subtitle: Text(themeMode.name.toUpperCase()),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeProvider.notifier).state = mode;
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Daily Reading Goal'),
                subtitle: Text('$dailyGoal minutes'),
                trailing: SizedBox(
                  width: 140,
                  child: Slider(
                    min: 5,
                    max: 120,
                    divisions: 23,
                    value: dailyGoal.toDouble(),
                    onChanged: (val) => ref.read(dailyGoalMinutesProvider.notifier).state = val.toInt(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Consistency Threshold'),
                subtitle: Text('At least $consistencyThreshold minutes/day counts towards streaks'),
                trailing: SizedBox(
                  width: 140,
                  child: Slider(
                    min: 5,
                    max: 60,
                    divisions: 11,
                    value: consistencyThreshold.toDouble(),
                    onChanged: (val) =>
                        ref.read(consistencyThresholdMinutesProvider.notifier).state = val.toInt(),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Sessions (CSV)'),
                onTap: () async {
                  final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                  final csv = SessionExportService.exportToCsv(sessions);
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('CSV Export Preview'),
                        content: SingleChildScrollView(child: Text(csv.isEmpty ? 'No data' : csv)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('100% offline, zero data collection'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Privacy Policy'),
                      content: const Text(
                        'PageClock is 100% offline and collects zero personal data. All reading metrics and notes remain exclusively on your device.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete All Data', style: TextStyle(color: Colors.red)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete all reading data?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                            for (final s in sessions) {
                              await ref.read(sessionRepositoryProvider).softDeleteSession(s.id);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Delete All'),
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
