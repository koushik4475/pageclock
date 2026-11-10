import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/reading_session.dart';
import '../../stats/stats_engine.dart';

class SessionPdfService {
  static Future<Uint8List> generatePdf(
    List<ReadingSession> sessions, {
    Map<String, dynamic>? settingsSnapshot,
  }) async {
    final pdf = pw.Document();

    final activeSessions = sessions.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    final totalMinutes = activeSessions.fold<int>(0, (sum, s) => sum + (s.durationMs / 60000).round());
    final totalHours = (totalMinutes / 60.0).toStringAsFixed(1);
    final avgSession = activeSessions.isNotEmpty ? (totalMinutes / activeSessions.length).round() : 0;
    final longestSession = activeSessions.isNotEmpty
        ? activeSessions.map((s) => (s.durationMs / 60000).round()).reduce((a, b) => a > b ? a : b)
        : 0;

    final dailyTotals = StatsEngine.calculateDailyTotals(activeSessions);
    final now = DateTime.now();

    final streaks = StatsEngine.calculateStreaks(
      dailyTotals: dailyTotals,
      today: now,
      thresholdMinutes: (settingsSnapshot?['streakThresholdMinutes'] as num?)?.toInt() ?? 10,
    );

    final consistency30 = StatsEngine.calculateConsistency(
      dailyTotals: dailyTotals,
      today: now,
      windowDays: 30,
      thresholdMinutes: (settingsSnapshot?['streakThresholdMinutes'] as num?)?.toInt() ?? 10,
    );

    final last7DaysData = List.generate(7, (idx) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - idx));
      final dayName = DateFormat('E').format(date);
      final mins = dailyTotals[date] ?? 0;
      return {'day': dayName, 'mins': mins};
    });

    final maxMins = last7DaysData.map((e) => e['mins'] as int).fold<int>(60, (max, v) => v > max ? v : max);

    // Subject/Project breakdown
    final Map<String, int> projectBreakdown = {};
    for (final s in activeSessions) {
      final key = s.subjectName;
      final mins = (s.durationMs / 60000).round();
      projectBreakdown[key] = (projectBreakdown[key] ?? 0) + mins;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 26,
                      height: 26,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#6366F1'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'P',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'PageClock',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#09090B'),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EEF2FF'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    'FOCUS & READING REPORT',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#4F46E5'),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Offline-First Reading Tracker | Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} (${DateTime.now().timeZoneName}) | v1.0.0',
              style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 0.75, color: PdfColor.fromHex('#E5E7EB')),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColor.fromHex('#E5E7EB')),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PageClock • 100% Offline-First & Private',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#9CA3AF')),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#9CA3AF')),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          // 4 Executive Summary Bento Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.75),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL SESSIONS', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 3),
                      pw.Text('${activeSessions.length}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.75),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL FOCUS TIME', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 3),
                      pw.Text('$totalHours hrs', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4F46E5'))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.75),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CURRENT / BEST STREAK', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 3),
                      pw.Text('${streaks.currentStreak}d / ${streaks.bestStreak}d', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#059669'))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.75),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('30-DAY CONSISTENCY', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 3),
                      pw.Text('${consistency30.percentage.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7C3AED'))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Visual Bar Chart Container
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F9FAFB'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.75),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PAST 7 DAYS READING VELOCITY (MINUTES)',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8, color: PdfColor.fromHex('#374151')),
                    ),
                    pw.Text('Peak: $maxMins mins | Avg session: $avgSession mins | Longest: $longestSession mins', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#6B7280'))),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  height: 75,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: last7DaysData.map((data) {
                      final mins = data['mins'] as int;
                      final day = data['day'] as String;
                      final heightRatio = maxMins > 0 ? (mins / maxMins).clamp(0.04, 1.0) : 0.04;
                      final barHeight = 55.0 * heightRatio;

                      return pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('$mins', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4B5563'))),
                          pw.SizedBox(height: 3),
                          pw.Container(
                            width: 22,
                            height: barHeight,
                            decoration: pw.BoxDecoration(
                              color: mins > 0 ? PdfColor.fromHex('#6366F1') : PdfColor.fromHex('#E5E7EB'),
                              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(3)),
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(day, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6B7280'))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Text(
            'DETAILED SESSION LOG',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8, color: PdfColor.fromHex('#374151')),
          ),
          pw.SizedBox(height: 8),

          if (activeSessions.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              alignment: pw.Alignment.center,
              child: pw.Text('No sessions recorded yet.', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#6B7280'))),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Date & Start Time', 'Project', 'Duration', 'Type', 'Notes'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#18181B'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              cellHeight: 22,
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.center,
                5: pw.Alignment.centerLeft,
              },
              data: List<List<String>>.generate(activeSessions.length, (i) {
                final s = activeSessions[i];
                final date = DateTime.fromMillisecondsSinceEpoch(s.startedAtUtc);
                final mins = (s.durationMs / 60000).round();
                return [
                  '${i + 1}',
                  DateFormat('yyyy-MM-dd  HH:mm').format(date),
                  s.subjectName,
                  '$mins mins',
                  s.source.toUpperCase(),
                  s.note ?? '—',
                ];
              }),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> printOrSharePdf(
    List<ReadingSession> sessions, {
    Map<String, dynamic>? settingsSnapshot,
  }) async {
    final pdfBytes = await generatePdf(sessions, settingsSnapshot: settingsSnapshot);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'pageclock-export-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }
}
