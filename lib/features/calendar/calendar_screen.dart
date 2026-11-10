import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format/formatters.dart';
import '../../core/models/reading_session.dart';
import '../../core/settings/app_settings.dart';
import '../../core/navigation/main_tab_navigation.dart';

/// 24-Hour Calendar Timeline Screen matching Toggl Track UI
/// Features:
/// 1. Top horizontal weekday strip (S M T W T F S) with current day highlighted
/// 2. Total tracked duration in top-right
/// 3. Vertical 24-hour timeline (12 am ... 11 pm)
/// 4. Current time glowing horizontal needle with live pulse indicator
/// 5. Colored time-slot session cards positioned at their exact start/end hours
class CalendarScreen extends ConsumerStatefulWidget {
  final List<ReadingSession> sessions;
  final VoidCallback? onStartFocus;

  const CalendarScreen({
    super.key,
    required this.sessions,
    this.onStartFocus,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarSessionSegment {
  final ReadingSession session;
  final double top;
  final double height;
  final int durationMs;

  const _CalendarSessionSegment({
    required this.session,
    required this.top,
    required this.height,
    required this.durationMs,
  });
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDay;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);

    // Scroll to current hour on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hour = DateTime.now().hour;
      final targetScroll = (hour * 60.0).clamp(0.0, 24 * 60.0);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final settings = ref.watch(settingsProvider);
    final weekStartDay = settings.weekStartDay;

    // Split entries at local-day boundaries so overnight sessions appear
    // on both dates instead of producing a negative-height block.
    final dayStart = DateTime.utc(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final daySegments = <_CalendarSessionSegment>[];
    for (final session in widget.sessions) {
      if (session.deletedAt != null || session.endedAtUtc == null) continue;
      final offset = Duration(minutes: session.tzOffsetMin);
      final sessionStart = DateTime.fromMillisecondsSinceEpoch(
        session.startedAtUtc,
        isUtc: true,
      ).add(offset);
      final sessionEnd = DateTime.fromMillisecondsSinceEpoch(
        session.endedAtUtc!,
        isUtc: true,
      ).add(offset);
      if (!sessionEnd.isAfter(dayStart) || !sessionStart.isBefore(dayEnd)) {
        continue;
      }
      final boundedStart =
          sessionStart.isBefore(dayStart) ? dayStart : sessionStart;
      final boundedEnd = sessionEnd.isAfter(dayEnd) ? dayEnd : sessionEnd;
      final segmentMs = boundedEnd.difference(boundedStart).inMilliseconds;
      if (segmentMs <= 0) continue;
      final top = boundedStart.difference(dayStart).inMilliseconds / 60000.0;
      final height = segmentMs / 60000.0;
      daySegments.add(
        _CalendarSessionSegment(
          session: session,
          top: top,
          height: height < 1 ? 1 : height,
          durationMs: segmentMs,
        ),
      );
    }

    // Calculate the time overlap (not the whole session) on this selected day.
    final totalMs = daySegments.fold<int>(
      0,
      (sum, segment) => sum + segment.durationMs,
    );
    final durationFormatted = AppFormatters.formatDuration(
      totalMs,
      format: settings.durationFormat,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Calendar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
            tooltip: 'Settings',
            onPressed: () {
              ref.read(mainTabNavigationIndexProvider.notifier).state = 3;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected date row + Total time header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppFormatters.formatDate(_selectedDay, settings.dateFormat).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  ),
                ),
                Text(
                  durationFormatted,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal 7-Day Strip (Sun to Sat)
          _buildWeekdayStrip(isDark, today, weekStartDay, colorScheme.primary),
          const SizedBox(height: 8),

          Divider(
            height: 1,
            color: isDark ? const Color(0xFF1E172B) : const Color(0xFFE5E7EB),
          ),

          // 24-Hour Timeline Grid
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 24 * 60.0, // 60 pixels per hour
                child: Stack(
                  children: [
                    // Hour grid lines & labels
                    ...List.generate(24, (hour) {
                      final topOffset = hour * 60.0;
                      final label = _formatHourLabel(hour, settings.use24HourClock);

                      return Positioned(
                        top: topOffset,
                        left: 0,
                        right: 0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFF71717A)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: isDark
                                    ? const Color(0xFF1E172B)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Session Time Blocks (split at selected-day boundaries)
                    ...daySegments.map((segment) {
                      final session = segment.session;
                      return Positioned(
                        top: segment.top,
                        left: 72,
                        right: 16,
                        height: segment.height,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.55),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                session.subjectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                              if (session.bookTitle != null && session.bookTitle!.isNotEmpty)
                                Text(
                                  session.bookTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Live Current Time Indicator Needle (if viewing today)
                    if (_selectedDay == today) _buildLiveTimeNeedle(now, colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayStrip(
    bool isDark,
    DateTime today,
    int weekStartDay,
    Color accent,
  ) {
    final daysFromWeekStart = (today.weekday - weekStartDay + 7) % 7;
    final weekStart = today.subtract(Duration(days: daysFromWeekStart));
    final dayLabels = weekStartDay == DateTime.monday
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final dayDate = weekStart.add(Duration(days: i));
          final isSelected = dayDate.year == _selectedDay.year &&
              dayDate.month == _selectedDay.month &&
              dayDate.day == _selectedDay.day;
          final isToday = dayDate.year == today.year &&
              dayDate.month == today.month &&
              dayDate.day == today.day;

          return InkWell(
            onTap: () => setState(() => _selectedDay = DateTime(dayDate.year, dayDate.month, dayDate.day)),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: isSelected
                  ? BoxDecoration(
                      color: accent, // Active day uses the selected theme accent
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Column(
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayDate.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isToday
                              ? accent
                              : (isDark ? Colors.white : const Color(0xFF111827))),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLiveTimeNeedle(DateTime now, Color accent) {
    final currentMinute = now.hour * 60.0 + now.minute;

    return Positioned(
      top: currentMinute,
      left: 54,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent,
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHourLabel(int hour, bool use24HourClock) {
    if (use24HourClock) return hour.toString().padLeft(2, '0') + ':00';
    if (hour == 0) return '12 am';
    if (hour < 12) return '$hour am';
    if (hour == 12) return '12 pm';
    return '${hour - 12} pm';
  }
}
