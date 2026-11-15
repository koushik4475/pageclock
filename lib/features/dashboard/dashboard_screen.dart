import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/engine/stopwatch_engine.dart';
import '../../core/format/formatters.dart';
import '../../core/models/reading_session.dart';
import '../../core/settings/app_settings.dart';
import 'reading_desk_artwork.dart';
import '../../stats/stats_engine.dart';

/// Responsive home dashboard using only data already tracked by PageClock.
///
/// The dashboard is a presentation layer: session lifecycle, reports,
/// calendar, goals and timer behaviour remain owned by their existing screens.
class DashboardScreen extends StatelessWidget {
  final List<ReadingSession> sessions;
  final AppSettings settings;
  final StopwatchState stopwatchState;
  final ValueChanged<int> onNavigate;
  final VoidCallback onToggleTheme;

  const DashboardScreen({
    super.key,
    required this.sessions,
    required this.settings,
    required this.stopwatchState,
    required this.onNavigate,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dailyTotals = StatsEngine.calculateDailyTotals(sessions);
    final todaySummary = StatsEngine.calculateDailyFocusSummary(
      sessions: sessions,
      localStart: today,
      localEnd: today.add(const Duration(days: 1)),
      currentSession: stopwatchState.currentSession,
      nowUtcMs: now.toUtc().millisecondsSinceEpoch,
    );
    final todayMilliseconds = todaySummary.totalMilliseconds;
    final todayMinutes = todayMilliseconds ~/ 60000;
    final goalMinutes = settings.dailyGoalMinutes.clamp(1, 1440).toInt();
    final goalProgress =
        (todayMilliseconds / (goalMinutes * 60000)).clamp(0.0, 1.0).toDouble();
    final streaks = StatsEngine.calculateStreaks(
      dailyTotals: dailyTotals,
      today: today,
      thresholdMinutes: settings.streakThresholdMinutes,
    );

    final daysFromWeekStart = (today.weekday - settings.weekStartDay + 7) % 7;
    final weekStart = today.subtract(Duration(days: daysFromWeekStart));
    final week = List<_DayActivity>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = DateTime(date.year, date.month, date.day);
      return _DayActivity(
        date: date,
        minutes: dailyTotals[key] ?? 0,
      );
    });
    final weekMinutes = week.fold<int>(0, (sum, day) => sum + day.minutes);

    final recentSessions = sessions
        .where((session) =>
            session.deletedAt == null && session.endedAtUtc != null)
        .toList()
      ..sort((a, b) => (b.endedAtUtc ?? b.startedAtUtc)
          .compareTo(a.endedAtUtc ?? a.startedAtUtc));

    final profile = settings.profileName.trim();
    final firstName = profile.isEmpty ? '' : profile.split(RegExp(r'\s+')).first;
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final greetingLine = firstName.isEmpty ? greeting : '$greeting, $firstName';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 600 ? 16 : 28,
                    constraints.maxWidth < 600 ? 18 : 26,
                    constraints.maxWidth < 600 ? 16 : 28,
                    36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardHeader(
                        greeting: greetingLine,
                        date: now,
                        profileName: profile,
                        isDark: isDark,
                        onToggleTheme: onToggleTheme,
                        onOpenSettings: () => onNavigate(4),
                      ),
                      const SizedBox(height: 24),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                children: [
                                  _FocusHeroCard(
                                    settings: settings,
                                    stopwatchState: stopwatchState,
                                    onOpenTimer: () => onNavigate(1),
                                    onOpenSettings: () => onNavigate(4),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 20),
                                  _WeeklyActivityCard(
                                    days: week,
                                    totalMinutes: weekMinutes,
                                    onOpenTimer: () => onNavigate(1),
                                  ),
                                  const SizedBox(height: 20),
                                  _RecentSessionsCard(
                                    sessions: recentSessions,
                                    durationFormat: settings.durationFormat,
                                    onOpenTimer: () => onNavigate(1),
                                    onViewReports: () => onNavigate(3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _TodayProgressCard(
                                    todayMinutes: todayMinutes,
                                    goalMinutes: goalMinutes,
                                    progress: goalProgress,
                                  ),
                                  const SizedBox(height: 20),
                                  _MomentumCard(
                                    currentStreak: streaks.currentStreak,
                                    bestStreak: streaks.bestStreak,
                                    weeklyMinutes: weekMinutes,
                                  ),
                                  const SizedBox(height: 20),
                                  _QuickActionsCard(
                                    onNavigate: onNavigate,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _FocusHeroCard(
                          settings: settings,
                          stopwatchState: stopwatchState,
                          onOpenTimer: () => onNavigate(1),
                          onOpenSettings: () => onNavigate(4),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        if (constraints.maxWidth >= 680)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _TodayProgressCard(
                                  todayMinutes: todayMinutes,
                                  goalMinutes: goalMinutes,
                                  progress: goalProgress,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _MomentumCard(
                                  currentStreak: streaks.currentStreak,
                                  bestStreak: streaks.bestStreak,
                                  weeklyMinutes: weekMinutes,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _TodayProgressCard(
                            todayMinutes: todayMinutes,
                            goalMinutes: goalMinutes,
                            progress: goalProgress,
                          ),
                          const SizedBox(height: 16),
                          _MomentumCard(
                            currentStreak: streaks.currentStreak,
                            bestStreak: streaks.bestStreak,
                            weeklyMinutes: weekMinutes,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _WeeklyActivityCard(
                          days: week,
                          totalMinutes: weekMinutes,
                          onOpenTimer: () => onNavigate(1),
                        ),
                        const SizedBox(height: 16),
                        _RecentSessionsCard(
                          sessions: recentSessions,
                          durationFormat: settings.durationFormat,
                          onOpenTimer: () => onNavigate(1),
                          onViewReports: () => onNavigate(3),
                        ),
                        const SizedBox(height: 16),
                        _QuickActionsCard(
                          onNavigate: onNavigate,
                        ),
                      ],
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
  final DateTime date;
  final String profileName;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;

  const _DashboardHeader({
    required this.greeting,
    required this.date,
    required this.profileName,
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('EEEE, d MMMM y').format(date),
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isDark
              ? 'Switch to PageClock Classic light mode'
              : 'Switch to Night Focus dark mode',
          onPressed: onToggleTheme,
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          color: colors.onSurfaceVariant,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Open settings',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  _profileInitials(profileName),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _profileInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'PC';
  return parts.take(2).map((part) => part.substring(0, 1)).join().toUpperCase();
}

class _FocusHeroCard extends StatelessWidget {
  final AppSettings settings;
  final StopwatchState stopwatchState;
  final VoidCallback onOpenTimer;
  final VoidCallback onOpenSettings;
  final bool isDark;

  const _FocusHeroCard({
    required this.settings,
    required this.stopwatchState,
    required this.onOpenTimer,
    required this.onOpenSettings,
    required this.isDark,
  });

  String _elapsedLabel(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasSession = stopwatchState.status != StopwatchStatus.idle;
    final isRunning = stopwatchState.status == StopwatchStatus.running;
    final timer = hasSession
        ? _elapsedLabel(stopwatchState.elapsedMs)
        : '${settings.pomodoroFocusMinutes.toString().padLeft(2, '0')}:00';
    final session = stopwatchState.currentSession;
    final sessionTitle = (session?.note?.trim().isNotEmpty ?? false)
        ? session!.note!.trim()
        : ((session?.subjectId?.trim().isNotEmpty ?? false)
            ? session!.subjectId!.trim()
            : 'A focused reading session');
    final glow = colors.primary.withOpacity(isDark ? 0.26 : 0.13);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outline.withOpacity(.75)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF171E29), const Color(0xFF0B1018)]
              : [const Color(0xFFFFF7EE), const Color(0xFFFFE4C4)],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(.16) : const Color(0xFFB86B31).withOpacity(.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -52,
            right: -28,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [glow, glow.withOpacity(0)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 16, color: colors.primary),
                          const SizedBox(width: 7),
                          Text(
                            hasSession ? 'FOCUS IN PROGRESS' : 'READING & FOCUS',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primary.withOpacity(.8),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 480;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timer,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: compact ? 49 : 68,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: -2.6,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hasSession
                                    ? (isRunning ? 'Your session is running' : 'Your session is paused')
                                    : 'Make a little room for what matters.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFB3BECC) : const Color(0xFF5D6571),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                hasSession ? sessionTitle : '${settings.pomodoroFocusMinutes}-minute focus preset',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF8793A2) : const Color(0xFF737C88),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 16),
                          ReadingDeskArtwork(
                            width: 248,
                            height: 186,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onOpenTimer,
                      icon: Icon(hasSession ? Icons.open_in_new_rounded : Icons.play_arrow_rounded),
                      label: Text(hasSession ? 'Return to session' : 'Open Focus Timer'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Settings & Clock Studio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outline),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

  const _TodayProgressCard({
    required this.todayMinutes,
    required this.goalMinutes,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final remaining = (goalMinutes - todayMinutes).clamp(0, goalMinutes);
    final achieved = todayMinutes >= goalMinutes;
    return _DashboardPanel(
      title: 'Today at a glance',
      trailing: Text(
        'Goal: ${goalMinutes} min',
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      child: Row(
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
                    backgroundColor: colors.outline.withOpacity(.28),
                    color: colors.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$todayMinutes',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: colors.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text('of $goalMinutes min', style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniInsight(
                  icon: Icons.menu_book_rounded,
                  label: 'Focused today',
                  value: '$todayMinutes min',
                  colors: colors,
                ),
                const SizedBox(height: 14),
                _MiniInsight(
                  icon: Icons.flag_rounded,
                  label: achieved ? 'Daily goal' : 'Still to go',
                  value: achieved ? 'Completed' : '$remaining min',
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentumCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int weeklyMinutes;

  const _MomentumCard({
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hours = weeklyMinutes ~/ 60;
    final minutes = weeklyMinutes % 60;
    return _DashboardPanel(
      title: 'Your reading rhythm',
      child: Column(
        children: [
          Row(
            children: [
              _MomentumTile(
                icon: Icons.local_fire_department_rounded,
                value: '$currentStreak days',
                label: 'Current streak',
                colors: colors,
              ),
              const SizedBox(width: 10),
              _MomentumTile(
                icon: Icons.emoji_events_outlined,
                value: '$bestStreak days',
                label: 'Best streak',
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This week: ${hours}h ${minutes}m focused',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
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

class _WeeklyActivityCard extends StatelessWidget {
  final List<_DayActivity> days;
  final int totalMinutes;
  final VoidCallback onOpenTimer;

  const _WeeklyActivityCard({
    required this.days,
    required this.totalMinutes,
    required this.onOpenTimer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxMinutes = math.max(1, days.fold<int>(0, (max, day) => math.max(max, day.minutes)));
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return _DashboardPanel(
      title: 'This week',
      trailing: Text(
        '${hours}h ${minutes}m total',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.primary),
      ),
      child: totalMinutes == 0
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(.055),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outline.withOpacity(.55)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_graph_rounded,
                      color: colors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your weekly rhythm starts here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Start a focus session and your real reading activity will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onOpenTimer,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Open Focus Timer'),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your focused time, day by day',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 132,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.map((day) {
                      final ratio = day.minutes / maxMinutes;
                      final barHeight = day.minutes == 0
                          ? 4.0
                          : (ratio * 88).clamp(8.0, 88.0).toDouble();
                      final isToday = DateUtils.isSameDay(day.date, DateTime.now());
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                day.minutes == 0 ? '—' : '${day.minutes}m',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isToday
                                        ? [colors.primary, colors.primary.withOpacity(.58)]
                                        : [
                                            colors.primary.withOpacity(.7),
                                            colors.primary.withOpacity(.28),
                                          ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('E').format(day.date),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                  color: isToday ? colors.primary : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RecentSessionsCard extends StatelessWidget {
  final List<ReadingSession> sessions;
  final String durationFormat;
  final VoidCallback onOpenTimer;
  final VoidCallback onViewReports;

  const _RecentSessionsCard({
    required this.sessions,
    required this.durationFormat,
    required this.onOpenTimer,
    required this.onViewReports,
  });

  String _sessionName(ReadingSession session) {
    final note = session.note?.trim() ?? '';
    if (note.isNotEmpty) return note;
    final subject = session.subjectId?.trim() ?? '';
    return subject.isNotEmpty ? subject : 'Focus session';
  }

  String _sessionDate(ReadingSession session) {
    final localTime = DateTime.fromMillisecondsSinceEpoch(
      session.startedAtUtc,
      isUtc: true,
    ).add(Duration(minutes: session.tzOffsetMin));
    return DateFormat('EEE, h:mm a').format(localTime);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = sessions.take(4).toList();
    return _DashboardPanel(
      title: 'Recent sessions',
      trailing: TextButton(
        onPressed: onViewReports,
        child: const Text('View insights'),
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(.09),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.menu_book_rounded, size: 34, color: colors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your reading journey starts here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Start a focus session and your real activity will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onOpenTimer,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start your first session'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _RecentSessionRow(
                    title: _sessionName(items[index]),
                    subtitle: _sessionDate(items[index]),
                    duration: AppFormatters.formatDuration(
                      StatsEngine.activeDurationMs(items[index]),
                      format: durationFormat,
                    ),
                    colors: colors,
                  ),
                  if (index != items.length - 1)
                    Divider(height: 18, color: colors.outline.withOpacity(.5)),
                ],
              ],
            ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _QuickActionsCard({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _DashboardPanel(
      title: 'Quick actions',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _QuickAction(
            icon: Icons.play_circle_outline_rounded,
            label: 'Focus timer',
            onTap: () => onNavigate(1),
            colors: colors,
          ),
          _QuickAction(
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            onTap: () => onNavigate(2),
            colors: colors,
          ),
          _QuickAction(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: () => onNavigate(3),
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _DashboardPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withOpacity(.75)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(.08)
                : const Color(0xFF8D6444).withOpacity(.035),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.35,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colors;

  const _MiniInsight({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: colors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MomentumTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme colors;

  const _MomentumTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 21),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String duration;
  final ColorScheme colors;

  const _RecentSessionRow({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.menu_book_rounded, color: colors.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          duration,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 180),
      child: Material(
        color: colors.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.primary, size: 19),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayActivity {
  final DateTime date;
  final int minutes;

  const _DayActivity({required this.date, required this.minutes});
}
