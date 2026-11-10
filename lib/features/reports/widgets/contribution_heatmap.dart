import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// GitHub Contribution Matrix Heatmap Widget
/// Displays a multi-week square grid (7 rows: Sun-Sat) with activity intensity levels
class ContributionHeatmap extends StatelessWidget {
  final Map<DateTime, int> dailyTotals; // Key: Date normalized to midnight, Value: minutes
  final int weeksToShow;
  final Function(DateTime date, int minutes)? onCellTap;

  const ContributionHeatmap({
    super.key,
    required this.dailyTotals,
    this.weeksToShow = 16,
    this.onCellTap,
  });

  Color _getColorForIntensity(int minutes, bool isDark) {
    if (minutes <= 0) {
      return isDark ? const Color(0xFF1E1E24) : const Color(0xFFEBEDF0);
    } else if (minutes < 15) {
      return const Color(0xFF0E4429); // Level 1 (GitHub Dark Emerald)
    } else if (minutes < 30) {
      return const Color(0xFF006D32); // Level 2
    } else if (minutes < 60) {
      return const Color(0xFF26A641); // Level 3
    } else {
      return const Color(0xFF39D353); // Level 4 (Highest bright emerald)
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate grid start date: align to Sunday
    // weeksToShow weeks ago Sunday
    final currentWeekday = today.weekday % 7; // Sunday is 0, Monday is 1, ..., Saturday is 6
    final thisSunday = today.subtract(Duration(days: currentWeekday));
    final startDate = thisSunday.subtract(Duration(days: (weeksToShow - 1) * 7));

    // Group weeks
    final List<List<DateTime>> weeks = [];
    for (int w = 0; w < weeksToShow; w++) {
      final List<DateTime> weekDays = [];
      for (int d = 0; d < 7; d++) {
        final day = startDate.add(Duration(days: (w * 7) + d));
        weekDays.add(day);
      }
      weeks.add(weekDays);
    }

    // Month labels for columns
    final List<String> monthLabels = [];
    for (int w = 0; w < weeksToShow; w++) {
      final firstDayOfWeek = weeks[w].first;
      if (w == 0 || firstDayOfWeek.day <= 7) {
        monthLabels.add(DateFormat('MMM').format(firstDayOfWeek));
      } else {
        monthLabels.add('');
      }
    }

    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121215) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CONTRIBUTION GRID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
              // Intensity Legend
              Row(
                children: [
                  Text(
                    'Less',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ...[0, 10, 25, 45, 75].map((lvl) {
                    return Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: _getColorForIntensity(lvl, isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable Grid View
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Show most recent weeks on right
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Labels Column (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
                Padding(
                  padding: const EdgeInsets.only(top: 18.0, right: 6),
                  child: Column(
                    children: List.generate(7, (d) {
                      // Only label alternate days to save space like Toggl / GitHub
                      final showText = d % 2 == 0;
                      return Container(
                        height: 14,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          showText ? dayLabels[d] : '',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Weeks Columns
                ...List.generate(weeks.length, (wIdx) {
                  final week = weeks[wIdx];
                  final monthText = monthLabels[wIdx];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Header
                        Container(
                          height: 14,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            monthText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 7 Days in Week
                        ...List.generate(7, (dIdx) {
                          final date = week[dIdx];
                          final isFuture = date.isAfter(today);
                          final normalizedDate = DateTime(date.year, date.month, date.day);
                          final minutes = dailyTotals[normalizedDate] ?? 0;

                          return Tooltip(
                            message: '${DateFormat('EEE, MMM d').format(date)}: ${minutes}m focus',
                            preferBelow: false,
                            child: InkWell(
                              onTap: isFuture
                                  ? null
                                  : () {
                                      if (onCellTap != null) {
                                        onCellTap!(normalizedDate, minutes);
                                      }
                                    },
                              borderRadius: BorderRadius.circular(3),
                              child: Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: isFuture
                                      ? Colors.transparent
                                      : _getColorForIntensity(minutes, isDark),
                                  borderRadius: BorderRadius.circular(3),
                                  border: date == today
                                      ? Border.all(
                                          color: const Color(0xFF6366F1),
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
