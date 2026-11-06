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

// Calm Palette
class CalmPalette {
  static const primaryLight = Color(0xFF3B6E66); // Soothing sage slate
  static const surfaceLight = Color(0xFFF9FAF8); // Warm paper white
  static const containerLight = Color(0xFFEAEFEA);
  static const accentSage = Color(0xFF5A8D83);

  static const primaryDark = Color(0xFF81A89F);
  static const surfaceDark = Color(0xFF141918); // Deep forest twilight
  static const containerDark = Color(0xFF1E2624);
  static const accentWarm = Color(0xFFE5A86D); // Muted ember for StandBy clock
}

// State Providers
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final dailyGoalMinutesProvider = StateProvider<int>((ref) => 30);
final targetFocusDurationMinutesProvider = StateProvider<int?>((ref) => 25); // Target focus duration (default 25m Pomodoro)
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
        scaffoldBackgroundColor: CalmPalette.surfaceLight,
        colorScheme: ColorScheme.light(
          primary: CalmPalette.primaryLight,
          surface: CalmPalette.surfaceLight,
          surfaceVariant: CalmPalette.containerLight,
          secondary: CalmPalette.accentSage,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: CalmPalette.surfaceLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Color(0xFF1B2E2B),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: CalmPalette.surfaceDark,
        colorScheme: ColorScheme.dark(
          primary: CalmPalette.primaryDark,
          surface: CalmPalette.surfaceDark,
          surfaceVariant: CalmPalette.containerDark,
          secondary: CalmPalette.accentWarm,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: CalmPalette.surfaceDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Color(0xFFE0EAE7),
          ),
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
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Icon(Icons.spa_outlined, size: 30, color: CalmPalette.primaryLight),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.hourglass_empty_rounded),
                  selectedIcon: Icon(Icons.hourglass_full_rounded),
                  label: Text('Focus'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_rounded),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Insights'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_edu_rounded),
                  selectedIcon: Icon(Icons.history_edu),
                  label: Text('Log'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune_rounded),
                  selectedIcon: Icon(Icons.tune),
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
            icon: Icon(Icons.hourglass_empty_rounded),
            selectedIcon: Icon(Icons.hourglass_full_rounded),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_rounded),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_edu_rounded),
            selectedIcon: Icon(Icons.history_edu),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 1: Calm Focus Timer
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
        title: const Text('Set Custom Focus Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter target focus duration in minutes (or leave 0 for open stopwatch):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                suffixText: 'mins',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [15, 25, 45, 60, 90].map((mins) {
                return ActionChip(
                  label: Text('$mins m'),
                  onPressed: () {
                    ref.read(targetFocusDurationMinutesProvider.notifier).state = mins;
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(targetFocusDurationMinutesProvider.notifier).state = null; // Open mode
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
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopwatchState = ref.watch(stopwatchProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final dailyGoal = ref.watch(dailyGoalMinutesProvider);
    final targetMins = ref.watch(targetFocusDurationMinutesProvider);

    final sessions = sessionsAsync.value ?? [];
    final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final todayMinutes = dailyTotals[todayKey] ?? 0;
    final dailyProgress = (todayMinutes / dailyGoal).clamp(0.0, 1.0);

    // Session progress if target set
    double sessionProgress = 0.0;
    if (targetMins != null && targetMins > 0) {
      final elapsedMins = stopwatchState.elapsedMs / 60000.0;
      sessionProgress = (elapsedMins / targetMins).clamp(0.0, 1.0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PageClock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: 'StandBy Clock Mode',
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
          final isCompact = constraints.maxHeight < 560;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Daily Goal Pill
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              value: dailyProgress,
                              strokeWidth: 3.5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Daily Goal: $todayMinutes / $dailyGoal mins (${(dailyProgress * 100).toInt()}%)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompact) const Spacer(),

                    // Target Session Duration Selector
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: stopwatchState.status == StopwatchStatus.idle
                          ? () => _showCustomDurationDialog(context, ref)
                          : null,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              targetMins == null ? 'Target: Open timer' : 'Target: $targetMins mins (custom)',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Central Breathing Clock Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: isCompact ? 190 : 250,
                          height: isCompact ? 190 : 250,
                          child: CircularProgressIndicator(
                            value: targetMins != null ? sessionProgress : null,
                            strokeWidth: 4,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatDuration(stopwatchState.elapsedMs),
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    fontSize: isCompact ? 46 : 64,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -1,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stopwatchState.status == StopwatchStatus.running
                                  ? 'DEEP READING'
                                  : (stopwatchState.status == StopwatchStatus.paused
                                      ? 'PAUSED'
                                      : 'READY'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: stopwatchState.status == StopwatchStatus.running
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (!isCompact) const Spacer(),
                    const SizedBox(height: 32),

                    // Soft Minimal Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (stopwatchState.status == StopwatchStatus.idle)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () => ref.read(stopwatchProvider.notifier).start(),
                            icon: const Icon(Icons.play_arrow_rounded, size: 24),
                            label: const Text('Begin Focus', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          )
                        else ...[
                          if (stopwatchState.status == StopwatchStatus.running)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () => ref.read(stopwatchProvider.notifier).pause(),
                              icon: const Icon(Icons.pause_rounded),
                              label: const Text('Pause'),
                            )
                          else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () => ref.read(stopwatchProvider.notifier).resume(),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Resume'),
                            ),
                          const SizedBox(width: 16),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: () async {
                              final session = await ref.read(stopwatchProvider.notifier).stop();
                              if (session == null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Session under 1 min discarded.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Complete'),
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
// StandBy Fullscreen Clock Mode (Calm & Elegant)
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
      backgroundColor: const Color(0xFF0C0F0E), // Ambient twilight black
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 28),
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
                                      color: CalmPalette.accentWarm,
                                      fontSize: 112,
                                      fontWeight: FontWeight.w200,
                                      letterSpacing: -2,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    amPmStr,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.5,
                                ),
                              ),
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
                                color: CalmPalette.accentWarm,
                                fontSize: 90,
                                fontWeight: FontWeight.w200,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              amPmStr,
                              style: const TextStyle(color: Colors.white54, fontSize: 22),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white60, fontSize: 16),
                        ),
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
          style: TextStyle(color: Colors.white30, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
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
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: CalmPalette.accentWarm,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => ref.read(stopwatchProvider.notifier).start(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Focus', style: TextStyle(fontWeight: FontWeight.w600)),
              )
            else ...[
              if (stopwatchState.status == StopwatchStatus.running)
                IconButton.filledTonal(
                  onPressed: () => ref.read(stopwatchProvider.notifier).pause(),
                  icon: const Icon(Icons.pause_rounded),
                )
              else
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: CalmPalette.accentWarm, foregroundColor: Colors.black),
                  onPressed: () => ref.read(stopwatchProvider.notifier).resume(),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () => ref.read(stopwatchProvider.notifier).stop(),
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Screen 2: Analytics & Insights
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
        appBar: AppBar(title: const Text('Insights')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.spa_outlined, size: 64, color: Theme.of(context).hintColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text('Quiet pages await', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              const Text('Log your first focus session to unveil patterns.'),
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
      appBar: AppBar(title: const Text('Insights')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Consistency (30d)',
                      value: '${consistency30.percentage.toInt()}%',
                      subtitle: '${consistency30.activeDays} of 30 days met',
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MetricCard(
                      title: 'Streak',
                      value: '${streaks.currentStreak}d',
                      subtitle: 'Longest: ${streaks.bestStreak}d',
                      icon: Icons.local_fire_department_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Day Trend',
                      value: '${dailyTrend.deltaMinutes >= 0 ? '+' : ''}${dailyTrend.deltaMinutes}m',
                      subtitle: '${dailyTrend.percentageChange.toStringAsFixed(1)}% vs yesterday',
                      icon: dailyTrend.deltaMinutes >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      iconColor: dailyTrend.deltaMinutes >= 0 ? Colors.teal : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MetricCard(
                      title: 'Weekly Slope',
                      value: weeklyTrend.direction == TrendDirection.increasing
                          ? '▲ Ascending'
                          : (weeklyTrend.direction == TrendDirection.decreasing
                              ? '▼ Softening'
                              : '— Constant'),
                      subtitle: '${weeklyTrend.deltaHours >= 0 ? '+' : ''}${weeklyTrend.deltaHours.toStringAsFixed(1)}h vs last week',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Text('Past 7 Days (Minutes)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF2B3A37),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()} mins',
                            const TextStyle(color: Colors.white, fontSize: 12),
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
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                            width: 16,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text('Past 4 Weeks (Hours)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
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
                            color: CalmPalette.accentSage,
                            width: 22,
                            borderRadius: BorderRadius.circular(6),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Screen 3: Sessions History
// -------------------------------------------------------------
class SessionsHistoryScreen extends ConsumerWidget {
  const SessionsHistoryScreen({super.key});

  void _showAddManualDialog(BuildContext context, WidgetRef ref) {
    int durationMinutes = 30;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Reading Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter recorded reading minutes:'),
            const SizedBox(height: 14),
            TextField(
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
        title: const Text('Reading Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add manual entry',
            onPressed: () => _showAddManualDialog(context, ref),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 56, color: Theme.of(context).hintColor.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      const Text('Your reading log is clean and empty.'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, idx) {
                    final s = sessions[idx];
                    final date = DateTime.fromMillisecondsSinceEpoch(s.startedAtUtc);
                    final durationMins = (s.durationMs / 60000).round();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        child: Icon(
                          s.source == 'manual' ? Icons.edit_note_rounded : Icons.hourglass_bottom_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text('$durationMins minutes', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('EEEE, MMM d • h:mm a').format(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
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
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) {
                          final numVal = int.tryParse(val) ?? 0;
                          // If entered value is 12+ while unit is hr, auto-switch to min
                          if (numVal > 12 && unit == 'hr') {
                            setDialogState(() {
                              unit = 'min';
                            });
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
                          if (unit == 'hr' && numVal > 12) {
                            unit = 'min'; // prevent unreasonable hour targets
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  unit == 'hr'
                      ? 'Note: Values >12 automatically switch to minutes.'
                      : 'Setting target in minutes.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final numVal = int.tryParse(controller.text) ?? 30;
                  int finalMinutes;
                  if (unit == 'hr') {
                    finalMinutes = numVal * 60;
                  } else {
                    finalMinutes = numVal;
                  }
                  if (finalMinutes > 0) {
                    onSaved(finalMinutes);
                  }
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
    final targetMins = ref.watch(targetFocusDurationMinutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: Text(themeMode.name.toUpperCase()),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox(),
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeProvider.notifier).state = mode;
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Calm Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Twilight Dark')),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Focus Target Preset'),
                subtitle: Text(targetMins == null ? 'Open timer' : '$targetMins minutes per focus block'),
                trailing: TextButton(
                  onPressed: () {
                    // Quick cycle presets
                    final next = targetMins == null ? 15 : (targetMins == 15 ? 25 : (targetMins == 25 ? 45 : (targetMins == 45 ? 60 : null)));
                    ref.read(targetFocusDurationMinutesProvider.notifier).state = next;
                  },
                  child: Text(targetMins == null ? 'Open' : '${targetMins}m (Cycle)'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
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
                leading: const Icon(Icons.check_circle_outline),
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
                leading: const Icon(Icons.auto_fix_high_rounded),
                title: const Text('Load Demo Reading History'),
                subtitle: const Text('Populate 28 days of realistic reading records to preview graphs'),
                onTap: () {
                  ref.read(sessionRepositoryProvider).seedSampleData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample data populated! Check Insights tab.')),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: CalmPalette.primaryLight),
                title: const Text('Export Records (PDF Only)'),
                subtitle: const Text('Official report • Developed by Koushik (koushikhy.netlify.app)'),
                onTap: () async {
                  final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                  if (sessions.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No reading records to export.')),
                      );
                    }
                    return;
                  }
                  await SessionPdfService.printOrSharePdf(sessions);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Export Records (Backup CSV)'),
                subtitle: const Text('Download raw tabular backup data'),
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
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Privacy & Policy'),
                subtitle: const Text('100% offline, zero tracking'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Zero-Data Policy'),
                      content: const Text(
                        'PageClock works 100% offline. No analytics, no ads, and no external tracking. Your reading history is solely stored in your local SQLite database.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Clear All Local Data', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete all reading data?'),
                      content: const Text('This will delete all sessions locally on this device.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () async {
                            final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
                            for (final s in sessions) {
                              await ref.read(sessionRepositoryProvider).softDeleteSession(s.id);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Confirm Clear'),
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
