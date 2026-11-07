import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/models/reading_session.dart';
import '../../stats/stats_engine.dart';
import 'widgets/contribution_heatmap.dart';

/// Reports Screen matching Toggl Track UI
/// Features:
/// 1. GitHub-style daily contribution square heatmap (weeks x 7 days)
/// 2. Filter Pills: "This week", "Projects", "Books"
/// 3. Tracked Hours Big Counter (00:00:00) with "DETAILS" action
/// 4. GROUP BY: Projects / Categories Donut / Semi-Circle Chart
/// 5. Breakdown list with color swatches & hours
class ReportsScreen extends ConsumerStatefulWidget {
  final List<ReadingSession> sessions;

  const ReportsScreen({super.key, required this.sessions});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _groupByIndex = 0; // 0: Projects, 1: Books
  String _selectedFilter = 'This week';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dailyTotals = StatsEngine.calculateDailyTotals(widget.sessions);

    // Calculate total duration
    final totalMs = widget.sessions
        .where((s) => s.deletedAt == null)
        .fold<int>(0, (acc, s) => acc + s.durationMs);
    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;
    final formattedTotal =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Grouping by Project (Subject) or Book
    final Map<String, int> distribution = {};
    for (final s in widget.sessions) {
      if (s.deletedAt != null) continue;
      final key = _groupByIndex == 0
          ? s.subjectName
          : (s.bookTitle ?? 'Uncategorized');
      final mins = (s.durationMs / 60000).round();
      distribution[key] = (distribution[key] ?? 0) + mins;
    }

    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalMins = distribution.values.fold<int>(0, (a, b) => a + b);

    // Color palette from Toggl Track
    const palette = [
      Color(0xFFC084FC), // Lavender purple
      Color(0xFFFACC15), // Amber yellow
      Color(0xFF38BDF8), // Sky blue
      Color(0xFFE2E8F0), // Platinum grey
      Color(0xFFF472B6), // Magenta pink
      Color(0xFF34D399), // Emerald
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          'Reports',
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
              Icons.file_download_outlined,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
            tooltip: 'Export',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. GitHub Contribution Heatmap Card
            ContributionHeatmap(
              dailyTotals: dailyTotals,
              weeksToShow: 18,
              onCellTap: (date, mins) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${DateFormat('EEEE, MMM d, yyyy').format(date)}: ${mins} minutes logged',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Filter Pills Ribbon
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1426) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Icon(
                      Icons.filter_alt_outlined,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill('This week', isDark),
                  const SizedBox(width: 8),
                  _buildFilterPill('Projects', isDark),
                  const SizedBox(width: 8),
                  _buildFilterPill('Books', isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Tracked Hours Overview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF15101E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF261D36) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRACKED HOURS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                        ),
                      ),
                      Text(
                        'DETAILS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: const Color(0xFFE040FB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedTotal,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. GROUP BY Section with Donut & Legend
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF15101E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF261D36) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GROUP BY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Segmented Switch: Projects vs Books
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F182C) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _groupByIndex = 0),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: _groupByIndex == 0
                                  ? BoxDecoration(
                                      color: isDark ? const Color(0xFF331D45) : Colors.white,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: const Color(0xFFE040FB).withOpacity(0.4),
                                      ),
                                    )
                                  : null,
                              child: Text(
                                'Projects',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _groupByIndex == 0
                                      ? const Color(0xFFE040FB)
                                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _groupByIndex = 1),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: _groupByIndex == 1
                                  ? BoxDecoration(
                                      color: isDark ? const Color(0xFF331D45) : Colors.white,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: const Color(0xFFE040FB).withOpacity(0.4),
                                      ),
                                    )
                                  : null,
                              child: Text(
                                'Books',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _groupByIndex == 1
                                      ? const Color(0xFFE040FB)
                                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Donut Chart or Semi-circle
                  if (totalMins == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No focus records logged for this period.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Center(
                      child: SizedBox(
                        height: 180,
                        width: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 54,
                            sections: List.generate(sortedEntries.length, (i) {
                              final entry = sortedEntries[i];
                              final color = palette[i % palette.length];
                              final pct = (entry.value / totalMins * 100).toStringAsFixed(0);

                              return PieChartSectionData(
                                color: color,
                                value: entry.value.toDouble(),
                                title: '$pct%',
                                radius: 36,
                                titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Legend list
                    ...List.generate(sortedEntries.length, (i) {
                      final entry = sortedEntries[i];
                      final color = palette[i % palette.length];
                      final h = (entry.value / 60.0).toStringAsFixed(1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            Text(
                              '${h}h (${entry.value}m)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String title, bool isDark) {
    final isSelected = _selectedFilter == title;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = title),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3B1E4E) : const Color(0xFFFCE7F3))
              : (isDark ? const Color(0xFF1A1426) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE040FB)
                : (isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFFE040FB)
                : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
          ),
        ),
      ),
    );
  }
}
