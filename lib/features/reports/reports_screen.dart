import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/format/formatters.dart';
import '../../core/models/reading_session.dart';
import '../../core/services/pdf_service.dart';
import '../../core/settings/app_settings.dart';
import '../../stats/stats_engine.dart';
import '../../core/navigation/main_tab_navigation.dart';
import 'widgets/contribution_heatmap.dart';

/// Reports Screen matching Toggl Track UI
/// Features:
/// 1. GitHub-style daily contribution square heatmap (weeks x 7 days)
/// 2. Filter Pills: "This week", "This month", "All time"
/// 3. Tracked Hours Big Counter (00:00:00) with "DETAILS" action
/// 4. GROUP BY: Projects / Categories Donut / Semi-Circle Chart
/// 5. Breakdown list with color swatches & hours
/// 6. Empty state support for every chart
/// 7. Working PDF export button
class ReportsScreen extends ConsumerStatefulWidget {
  final List<ReadingSession> sessions;

  const ReportsScreen({super.key, required this.sessions});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _groupByIndex = 0; // 0: Projects, 1: Books
  String _selectedFilter = 'This week';

  List<ReadingSession> _filterSessions(
    List<ReadingSession> all,
    int weekStartDay,
  ) {
    final active = all.where((s) => s.deletedAt == null).toList();
    final now = DateTime.now();

    if (_selectedFilter == 'This week') {
      final daysFromWeekStart = (now.weekday - weekStartDay + 7) % 7;
      final startOfWeek = now.subtract(Duration(days: daysFromWeekStart));
      final midnightStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      return active.where((s) => s.startedAtUtc >= midnightStart.millisecondsSinceEpoch).toList();
    } else if (_selectedFilter == 'This month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      return active.where((s) => s.startedAtUtc >= startOfMonth.millisecondsSinceEpoch).toList();
    }
    // 'All time'
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final filteredSessions =
        _filterSessions(widget.sessions, settings.weekStartDay);
    final dailyTotals = StatsEngine.calculateDailyTotals(widget.sessions);

    // Calculate total duration for current filtered period
    final totalMs = filteredSessions.fold<int>(0, (acc, s) => acc + s.durationMs);
    final formattedTotal = AppFormatters.formatDuration(
      totalMs,
      format: settings.durationFormat,
    );

    // Grouping by Project (Subject) or Book
    final Map<String, int> distribution = {};
    for (final s in filteredSessions) {
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Reports',
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
              Icons.file_download_outlined,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
            tooltip: 'Export PDF Report',
            onPressed: () async {
              try {
                final settings = ref.read(settingsProvider).toJson();
                await SessionPdfService.printOrSharePdf(widget.sessions, settingsSnapshot: settings);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF report shared successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
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
                      AppFormatters.formatDate(date, settings.dateFormat) +
                          ': ' + mins.toString() + ' minutes logged',
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
                  _buildFilterPill('This week', isDark, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterPill('This month', isDark, colorScheme),
                  const SizedBox(width: 8),
                  _buildFilterPill('All time', isDark, colorScheme),
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
                        'TRACKED HOURS ($_selectedFilter.toUpperCase())',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                        ),
                      ),
                      Text(
                        '${filteredSessions.length} SESSIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: colorScheme.primary,
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
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E172B) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _groupByIndex = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _groupByIndex == 0
                                    ? (isDark ? const Color(0xFF2D233F) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Projects',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _groupByIndex == 0
                                      ? (isDark ? Colors.white : const Color(0xFF111827))
                                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _groupByIndex = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _groupByIndex == 1
                                    ? (isDark ? const Color(0xFF2D233F) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Books',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _groupByIndex == 1
                                      ? (isDark ? Colors.white : const Color(0xFF111827))
                                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (distribution.isEmpty || totalMins == 0) ...[
                    // Empty state
                    Container(
                      height: 160,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.donut_large_rounded,
                            size: 48,
                            color: isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No sessions recorded for this period',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Donut Chart
                    Center(
                      child: SizedBox(
                        height: 200,
                        width: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 65,
                                startDegreeOffset: -90,
                                sections: List.generate(sortedEntries.length, (i) {
                                  final entry = sortedEntries[i];
                                  final color = palette[i % palette.length];
                                  return PieChartSectionData(
                                    value: entry.value.toDouble(),
                                    color: color,
                                    radius: 20,
                                    showTitle: false,
                                    badgeWidget: null,
                                  );
                                }),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(totalMins / 60.0).toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  _groupByIndex == 0 ? 'Projects' : 'Books',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Legend and Breakdown Rows
                    ...List.generate(sortedEntries.length, (i) {
                      final entry = sortedEntries[i];
                      final color = palette[i % palette.length];
                      final h = (entry.value / 60.0).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
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

  Widget _buildFilterPill(String title, bool isDark, ColorScheme colorScheme) {
    final isSelected = _selectedFilter == title;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = title),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.14)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
