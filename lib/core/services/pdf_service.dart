import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/reading_session.dart';

class SessionPdfService {
  static Future<Uint8List> generatePdf(List<ReadingSession> sessions) async {
    final pdf = pw.Document();

    final activeSessions = sessions.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

    final totalMinutes = activeSessions.fold<int>(0, (sum, s) => sum + (s.durationMs / 60000).round());
    final totalHours = (totalMinutes / 60.0).toStringAsFixed(1);
    final avgSession = activeSessions.isNotEmpty ? (totalMinutes / activeSessions.length).round() : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
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
                      width: 28,
                      height: 28,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#6366F1'), // Electric Indigo
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'P',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'productivity.',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#09090B'),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EEF2FF'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Text(
                    'OFFICIAL FOCUS REPORT',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#4F46E5'),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Developed by Koushik  |  Portfolio: koushikhy.netlify.app',
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColor.fromHex('#E5E7EB')),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColor.fromHex('#E5E7EB')),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'productivity.  •  Offline-First Reading Tracker  •  koushikhy.netlify.app',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#9CA3AF')),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#9CA3AF')),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Bento Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL SESSIONS', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 6),
                      pw.Text('${activeSessions.length}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL VOLUME', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 6),
                      pw.Text('$totalHours hrs (${totalMinutes}m)', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4F46E5'))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F9FAFB'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('AVG SESSION', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                      pw.SizedBox(height: 6),
                      pw.Text('$avgSession mins', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#059669'))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          pw.Text(
            'DETAILED READING SESSIONS',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1.0, color: PdfColor.fromHex('#374151')),
          ),
          pw.SizedBox(height: 10),

          // High-precision table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Date & Start Time', 'Duration', 'Source', 'Notes'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#18181B'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            cellHeight: 26,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
              4: pw.Alignment.centerLeft,
            },
            data: List<List<String>>.generate(activeSessions.length, (i) {
              final s = activeSessions[i];
              final date = DateTime.fromMillisecondsSinceEpoch(s.startedAtUtc);
              final mins = (s.durationMs / 60000).round();
              return [
                '${i + 1}',
                DateFormat('yyyy-MM-dd  HH:mm').format(date),
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

  static Future<void> printOrSharePdf(List<ReadingSession> sessions) async {
    final pdfBytes = await generatePdf(sessions);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Productivity_Focus_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
