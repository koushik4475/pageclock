import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/stopwatch_engine.dart';
import '../../core/models/reading_session.dart';
import '../../core/theme/theme_provider.dart';
import '../../stats/stats_engine.dart';

class PageClockDashboardScreen extends ConsumerWidget {
  final List<ReadingSession> sessions;
  final VoidCallback onOpenTimer;
  final ValueChanged<int> onNavigate;

  const PageClockDashboardScreen({
    super.key,
    required this.sessions,
    required this.onOpenTimer,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final stopwatch = ref.watch(stopwatchProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
    final todaySummary = StatsEngine.calculateDailyFocusSummary(
      sessions: sessions,
      localStart: today,
      localEnd: today.add(const Duration(days: 1)),
      currentSession: stopwatch.currentSession,
      nowUtcMs: now.toUtc().millisecondsSinceEpoch,
    );
    final todayMinutes = (todaySummary.totalMilliseconds / 60000).round();
    final goalMinutes = settings.dailyGoalMinutes;
    final progress = goalMinutes <= 0
        ? 0.0
        : (todayMinutes / goalMinutes).clamp(0.0, 1.0).toDouble();
    final streaks = StatsEngine.calculateStreaks(
      dailyTotals: dailyTotals,
      today: today,
      thresholdMinutes: settings.streakThresholdMinutes,
    );
    final daysFromStart = (today.weekday - settings.weekStartDay + 7) % 7;
    final weekStart = today.subtract(Duration(days: daysFromStart));
    final weekMinutes = List<int>.generate(7, (index) {
      return dailyTotals[weekStart.add(Duration(days: index))] ?? 0;
    });
    final weekTotal = weekMinutes.fold<int>(0, (sum, value) => sum + value);
    final maxDayMinutes = math.max(
      1,
      weekMinutes.fold<int>(0, (maxValue, value) => math.max(maxValue, value)),
    ).toInt();
    final completed = sessions
        .where((s) => s.endedAtUtc != null && s.deletedAt == null)
        .toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final recentSessions = completed.take(4).toList();
    ReadingSession? latestBook;
    for (final session in completed) {
      if (session.bookTitle?.trim().isNotEmpty == true) {
        latestBook = session;
        break;
      }
    }

    final name = settings.profileName.trim();
    final greetingName = name.isEmpty ? 'there' : name;
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final isActive = stopwatch.status != StopwatchStatus.idle;
    final timerLabel = isActive
        ? _formatTimer(stopwatch.elapsedMs)
        : settings.pomodoroFocusMinutes.toString().padLeft(2, '0') + ':00';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1080;
            final horizontalPadding = desktop
                ? 30.0
                : (constraints.maxWidth >= 700 ? 24.0 : 16.0);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 22, horizontalPadding, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardHeader(
                        greeting: greeting + ', ' + greetingName,
                        dateLabel: _dateLabel(now),
                        isDark: isDark,
                        onToggleTheme: () {
                          ref.read(settingsProvider.notifier).update(
                                (current) => current.copyWith(
                                  themeId: isDark
                                      ? AppThemeId.pageClockClassic.storageId
                                      : AppThemeId.defaultDark.storageId,
                                ),
                              );
                        },
                        onOpenSettings: () => onNavigate(4),
                      ),
                      const SizedBox(height: 24),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _FocusHeroCard(
                                isDark: isDark,
                                timerLabel: timerLabel,
                                isActive: isActive,
                                isPaused: stopwatch.status == StopwatchStatus.paused,
                                sessionTitle: stopwatch.currentSession?.note ??
                                    stopwatch.currentSession?.subjectName ??
                                    'Deep reading session',
                                focusMinutes: settings.pomodoroFocusMinutes,
                                onOpenTimer: onOpenTimer,
                              ),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _TodayProgressCard(
                                    todayMinutes: todayMinutes,
                                    goalMinutes: goalMinutes,
                                    progress: progress,
                                    currentStreak: streaks.currentStreak,
                                    bestStreak: streaks.bestStreak,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 18),
                                  _ContinueReadingCard(
                                    session: latestBook,
                                    isDark: isDark,
                                    onOpenTimer: onOpenTimer,
                                    onOpenReports: () => onNavigate(3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _FocusHeroCard(
                          isDark: isDark,
                          timerLabel: timerLabel,
                          isActive: isActive,
                          isPaused: stopwatch.status == StopwatchStatus.paused,
                          sessionTitle: stopwatch.currentSession?.note ??
                              stopwatch.currentSession?.subjectName ??
                              'Deep reading session',
                          focusMinutes: settings.pomodoroFocusMinutes,
                          onOpenTimer: onOpenTimer,
                        ),
                        const SizedBox(height: 16),
                        _TodayProgressCard(
                          todayMinutes: todayMinutes,
                          goalMinutes: goalMinutes,
                          progress: progress,
                          currentStreak: streaks.currentStreak,
                          bestStreak: streaks.bestStreak,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _ContinueReadingCard(
                          session: latestBook,
                          isDark: isDark,
                          onOpenTimer: onOpenTimer,
                          onOpenReports: () => onNavigate(3),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _WeeklyProgressCard(
                                minutes: weekMinutes,
                                weekStart: weekStart,
                                totalMinutes: weekTotal,
                                maximumMinutes: maxDayMinutes,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              flex: 5,
                              child: _RecentSessionsCard(
                                sessions: recentSessions,
                                isDark: isDark,
                                onViewAll: () => onNavigate(3),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _WeeklyProgressCard(
                          minutes: weekMinutes,
                          weekStart: weekStart,
                          totalMinutes: weekTotal,
                          maximumMinutes: maxDayMinutes,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _RecentSessionsCard(
                          sessions: recentSessions,
                          isDark: isDark,
                          onViewAll: () => onNavigate(3),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _QuickActions(
                        onStart: onOpenTimer,
                        onCalendar: () => onNavigate(2),
                        onReports: () => onNavigate(3),
                        onSettings: () => onNavigate(4),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'Your time stays on this device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String greeting;
  final String dateLabel;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;

  const _DashboardHeader({
    required this.greeting,
    required this.dateLabel,
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isDark ? 'Switch to PageClock Light' : 'Switch to PageClock Night',
          onPressed: onToggleTheme,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: colors.onSurfaceVariant,
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: onOpenSettings,
          icon: Icon(Icons.settings_outlined, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FocusHeroCard extends StatelessWidget {
  final bool isDark;
  final String timerLabel;
  final bool isActive;
  final bool isPaused;
  final String sessionTitle;
  final int focusMinutes;
  final VoidCallback onOpenTimer;

  const _FocusHeroCard({
    required this.isDark,
    required this.timerLabel,
    required this.isActive,
    required this.isPaused,
    required this.sessionTitle,
    required this.focusMinutes,
    required this.onOpenTimer,
  });

  @override
  Widget build(BuildContext context) {
    final lightGradient = const [
      Color(0xFFFFE5C7),
      Color(0xFFFFF1DF),
      Color(0xFFF8DCC5),
    ];
    final darkGradient = const [
      Color(0xFF182235),
      Color(0xFF111827),
      Color(0xFF241A1B),
    ];
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 350),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? darkGradient : lightGradient,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF354256) : const Color(0xFFE9C9AA),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : const Color(0xFFC47B43).withOpacity(0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -38,
            child: Icon(
              Icons.menu_book_rounded,
              size: 220,
              color: isDark
                  ? const Color(0xFFFF9B43).withOpacity(0.10)
                  : const Color(0xFFB9682A).withOpacity(0.13),
            ),
          ),
          Positioned(
            right: 35,
            top: 0,
            child: Icon(
              Icons.wb_twilight_rounded,
              size: 54,
              color: isDark
                  ? const Color(0xFFFFA34A).withOpacity(0.55)
                  : const Color(0xFFFF9C24).withOpacity(0.82),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : const Color(0xFFEAD1B7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 15, color: const Color(0xFFFF7A00)),
                    const SizedBox(width: 7),
                    Text(
                      isActive ? 'YOUR FOCUS SESSION' : 'READING & FOCUS',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF56351E),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  timerLabel,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
                    fontSize: 64,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isActive ? sessionTitle : 'Make room for a deep reading session',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? const Color(0xFFD2D8E3) : const Color(0xFF4B5563),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isActive
                    ? (isPaused ? 'Session paused · ready when you are' : 'Your session is in progress')
                    : 'A little focus today adds up over time.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF745B48),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 23),
              FilledButton.icon(
                onPressed: onOpenTimer,
                icon: Icon(isActive ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded),
                label: Text(isActive ? 'Continue session' : 'Open focus timer'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your ' + focusMinutes.toString() + '-minute Pomodoro is ready in Timer.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF795C43),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayProgressCard extends StatelessWidget {
  final int todayMinutes;
  final int goalMinutes;
  final double progress;
  final int currentStreak;
  final int bestStreak;
  final bool isDark;

  const _TodayProgressCard({
    required this.todayMinutes,
    required this.goalMinutes,
    required this.progress,
    required this.currentStreak,
    required this.bestStreak,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _SurfaceCard(
      isDark: isDark,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's progress",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                'Goal: ' + goalMinutes.toString() + ' min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: colors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          todayMinutes.toString(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'of ' + goalMinutes.toString() + ' min',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    _MiniMetric(
                      icon: Icons.local_fire_department_rounded,
                      value: currentStreak.toString() + ' days',
                      label: 'Reading streak',
                    ),
                    const SizedBox(height: 14),
                    Divider(color: colors.outline.withOpacity(0.7), height: 1),
                    const SizedBox(height: 14),
                    _MiniMetric(
                      icon: Icons.emoji_events_outlined,
                      value: bestStreak.toString() + ' days',
                      label: 'Best streak',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final ReadingSession? session;
  final bool isDark;
  final VoidCallback onOpenTimer;
  final VoidCallback onOpenReports;

  const _ContinueReadingCard({
    required this.session,
    required this.isDark,
    required this.onOpenTimer,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _SurfaceCard(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recently tracked',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(onPressed: onOpenReports, child: const Text('View reports')),
            ],
          ),
          const SizedBox(height: 12),
          if (session == null)
            Row(
              children: [
                Container(
                  width: 54,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: colors.primary, size: 28),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Text(
                    'Your recent reading and focus sessions will appear here.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Container(
                  width: 54,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: colors.primary, size: 28),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session!.bookTitle?.trim().isNotEmpty == true
                            ? session!.bookTitle!
                            : session!.subjectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMinutes((StatsEngine.activeDurationMs(session!) / 60000).round()) +
                            ' · ' + _relativeDate(session!.startedAtUtc),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open focus timer',
                  onPressed: onOpenTimer,
                  icon: Icon(Icons.play_circle_fill_rounded, color: colors.primary, size: 30),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final List<int> minutes;
  final DateTime weekStart;
  final int totalMinutes;
  final int maximumMinutes;
  final bool isDark;

  const _WeeklyProgressCard({
    required this.minutes,
    required this.weekStart,
    required this.totalMinutes,
    required this.maximumMinutes,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _SurfaceCard(
      isDark: isDark,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'This week',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                _formatMinutes(totalMinutes),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your tracked reading and focus time',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = minutes[index];
                final fraction = value / maximumMinutes;
                final barHeight = value == 0 ? 5.0 : 12.0 + fraction * 92.0;
                final weekday = weekStart.add(Duration(days: index)).weekday;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          value == 0 ? '' : _formatCompactMinutes(value),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 7),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [colors.primary, colors.primary.withOpacity(0.55)],
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          names[weekday - 1],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSessionsCard extends StatelessWidget {
  final List<ReadingSession> sessions;
  final bool isDark;
  final VoidCallback onViewAll;

  const _RecentSessionsCard({
    required this.sessions,
    required this.isDark,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _SurfaceCard(
      isDark: isDark,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent sessions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View reports')),
            ],
          ),
          const SizedBox(height: 7),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 34, color: colors.primary),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No sessions yet',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Start your first session to see your progress here.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...sessions.map((session) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(Icons.menu_book_rounded, color: colors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.bookTitle?.trim().isNotEmpty == true
                                  ? session.bookTitle!
                                  : session.subjectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _relativeDate(session.startedAtUtc),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatMinutes((StatsEngine.activeDurationMs(session) / 60000).round()),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onCalendar;
  final VoidCallback onReports;
  final VoidCallback onSettings;

  const _QuickActions({
    required this.onStart,
    required this.onCalendar,
    required this.onReports,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final actions = [
      _QuickActionData('Start session', Icons.play_arrow_rounded, onStart),
      _QuickActionData('Calendar', Icons.calendar_month_rounded, onCalendar),
      _QuickActionData('Reports', Icons.bar_chart_rounded, onReports),
      _QuickActionData('Settings', Icons.settings_rounded, onSettings),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((action) {
        return SizedBox(
          width: 176,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.outline.withOpacity(0.65)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, color: colors.primary, size: 23),
                    const SizedBox(height: 7),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionData(this.label, this.icon, this.onTap);
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _SurfaceCard({
    required this.isDark,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _formatTimer(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return hours.toString().padLeft(2, '0') + ':' + minuteText + ':' + secondText;
  }
  return minuteText + ':' + secondText;
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0 min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return minutes.toString() + ' min';
  if (remainder == 0) return hours.toString() + 'h';
  return hours.toString() + 'h ' + remainder.toString() + 'm';
}

String _formatCompactMinutes(int minutes) {
  if (minutes >= 60) return (minutes / 60).toStringAsFixed(1) + 'h';
  return minutes.toString() + 'm';
}

String _dateLabel(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  return weekdays[date.weekday - 1] + ', ' + date.day.toString() +
      ' ' + months[date.month - 1] + ' ' + date.year.toString();
}

String _relativeDate(int epochMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return difference.toString() + ' days ago';
  return date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString();
}
