import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/reading_session.dart';

/// 24-Hour Calendar Timeline Screen matching Toggl Track UI
/// Features:
/// 1. Top horizontal weekday strip (S M T W T F S) with current day highlighted
/// 2. Total tracked duration in top-right
/// 3. Vertical 24-hour timeline (12 am ... 11 pm)
/// 4. Current time glowing horizontal needle with live pulse indicator
/// 5. Colored time-slot session cards positioned at their exact start/end hours
class CalendarScreen extends StatefulWidget {
  final List<ReadingSession> sessions;
  final VoidCallback? onStartFocus;

  const CalendarScreen({
    super.key,
    required this.sessions,
    this.onStartFocus,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter sessions for the selected day
    final daySessions = widget.sessions.where((s) {
      if (s.deletedAt != null) return false;
      final start = s.startTime;
      return start.year == _selectedDay.year &&
          start.month == _selectedDay.month &&
          start.day == _selectedDay.day;
    }).toList();

    // Calculate total tracked time for the selected day
    final totalMs = daySessions.fold<int>(0, (acc, s) => acc + s.durationMs);
    final totalHours = totalMs ~/ 3600000;
    final totalMinutes = (totalMs % 3600000) ~/ 60000;
    final totalSeconds = (totalMs % 60000) ~/ 1000;
    final durationFormatted =
        '${totalHours.toString().padLeft(2, '0')}:${totalMinutes.toString().padLeft(2, '0')}:${totalSeconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          'Calendar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
            onPressed: () {},
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
                  DateFormat('EEEE, MMM d').format(_selectedDay).toUpperCase(),
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
          _buildWeekdayStrip(isDark, today),
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
                      final label = _formatHourLabel(hour);

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

                    // Session Time Blocks
                    ...daySessions.map((session) {
                      final start = session.startTime;
                      final end = session.endTime ?? start.add(Duration(milliseconds: session.durationMs));

                      final startMinute = start.hour * 60 + start.minute;
                      final endMinute = end.hour * 60 + end.minute;
                      final durationMinutes = (endMinute - startMinute).clamp(15, 24 * 60);

                      final top = startMinute * 1.0;
                      final height = durationMinutes * 1.0;

                      return Positioned(
                        top: top,
                        left: 72,
                        right: 16,
                        height: height,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE040FB).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE040FB).withOpacity(0.55),
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF472B6),
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
                    if (_selectedDay == today) _buildLiveTimeNeedle(now),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayStrip(bool isDark, DateTime today) {
    // Current week starting from Sunday
    final currentWeekday = today.weekday % 7;
    final thisSunday = today.subtract(Duration(days: currentWeekday));
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final dayDate = thisSunday.add(Duration(days: i));
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
                  ? const BoxDecoration(
                      color: Color(0xFFE040FB), // Signature Toggl magenta/pink active pill
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
                              ? const Color(0xFFE040FB)
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

  Widget _buildLiveTimeNeedle(DateTime now) {
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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFE040FB),
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

  String _formatHourLabel(int hour) {
    if (hour == 0) return '12 am';
    if (hour < 12) return '$hour am';
    if (hour == 12) return '12 pm';
    return '${hour - 12} pm';
  }
}
