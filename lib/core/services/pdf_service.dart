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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PageClock',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
                pw.Text(
                  'Reading Focus Report',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Developed by Koushik • Portfolio: koushikhy.netlify.app',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PageClock — Offline-First Reading Tracker | koushikhy.netlify.app',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
        build: (context) => [
          // Summary Statistics Card
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Total Sessions', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('${activeSessions.length}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Total Reading Time', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('$totalHours hrs ($totalMinutes m)', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Report Generated', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          pw.Text('Reading Session Log', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          // Table of records
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Date & Time', 'Duration', 'Type', 'Note'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellHeight: 28,
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
                DateFormat('yyyy-MM-dd HH:mm').format(date),
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
      filename: 'PageClock_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
