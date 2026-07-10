import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/performance_model.dart';

class PerformancePdfService {
  PerformancePdfService._();

  static Future<void> downloadAnnualReport({
    required String employeeName,
    required String department,
    required String jobTitle,
    required int year,
    required List<PerformanceModel> records,
    required String narrative,
  }) async {
    final pdf = pw.Document();

    // Sort records by month
    final sorted = List<PerformanceModel>.from(records)
      ..sort((a, b) => a.month.compareTo(b.month));

    // Compute quarterly averages
    final q1 = _quarterAvg(sorted, [1, 2, 3]);
    final q2 = _quarterAvg(sorted, [4, 5, 6]);
    final q3 = _quarterAvg(sorted, [7, 8, 9]);
    final q4 = _quarterAvg(sorted, [10, 11, 12]);

    // Best and worst months
    double? bestScore;
    double? worstScore;
    String bestMonth = '—';
    String worstMonth = '—';
    for (final r in sorted) {
      if (bestScore == null || r.overallScore > bestScore) {
        bestScore = r.overallScore;
        bestMonth = _fmtMonth(r.month);
      }
      if (worstScore == null || r.overallScore < worstScore) {
        worstScore = r.overallScore;
        worstMonth = _fmtMonth(r.month);
      }
    }

    // Overall annual average
    final annualAvg = sorted.isEmpty
        ? 0.0
        : sorted.fold(0.0, (s, r) => s + r.overallScore) / sorted.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _buildHeader(employeeName, year, ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          // Employee info
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Employee', employeeName),
                    _infoRow('Department', department),
                    _infoRow('Job Title', jobTitle),
                  ],
                )),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Year', year.toString()),
                    _infoRow('Annual Average', '${annualAvg.toStringAsFixed(1)}/5'),
                    _infoRow('Months Scored', '${sorted.length}'),
                  ],
                )),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Monthly scores table
          pw.Text('Monthly Performance Scores',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _cell('Month', bold: true),
                  _cell('Score', bold: true),
                  _cell('Rating', bold: true),
                ],
              ),
              // Data rows
              ...sorted.map((r) => pw.TableRow(
                children: [
                  _cell(_fmtMonth(r.month)),
                  _cell(r.overallScore.toStringAsFixed(1)),
                  _cell(_ratingLabel(r.overallScore)),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),

          // Quarterly averages
          pw.Text('Quarterly Averages',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _cell('Quarter', bold: true),
                  _cell('Average Score', bold: true),
                  _cell('Rating', bold: true),
                ],
              ),
              if (q1 != null)
                pw.TableRow(children: [
                  _cell('Q1 (Jan–Mar)'),
                  _cell(q1.toStringAsFixed(1)),
                  _cell(_ratingLabel(q1)),
                ]),
              if (q2 != null)
                pw.TableRow(children: [
                  _cell('Q2 (Apr–Jun)'),
                  _cell(q2.toStringAsFixed(1)),
                  _cell(_ratingLabel(q2)),
                ]),
              if (q3 != null)
                pw.TableRow(children: [
                  _cell('Q3 (Jul–Sep)'),
                  _cell(q3.toStringAsFixed(1)),
                  _cell(_ratingLabel(q3)),
                ]),
              if (q4 != null)
                pw.TableRow(children: [
                  _cell('Q4 (Oct–Dec)'),
                  _cell(q4.toStringAsFixed(1)),
                  _cell(_ratingLabel(q4)),
                ]),
            ],
          ),
          pw.SizedBox(height: 10),

          // Best/worst highlight
          pw.Row(children: [
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Best Month', style: pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
                pw.SizedBox(height: 4),
                pw.Text(bestMonth,
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                pw.Text('${bestScore?.toStringAsFixed(1) ?? "—"}/5',
                    style: const pw.TextStyle(fontSize: 13, color: PdfColors.green700)),
              ]),
            )),
            pw.SizedBox(width: 12),
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Weakest Month', style: pw.TextStyle(fontSize: 12, color: PdfColors.red800)),
                pw.SizedBox(height: 4),
                pw.Text(worstMonth,
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                pw.Text('${worstScore?.toStringAsFixed(1) ?? "—"}/5',
                    style: const pw.TextStyle(fontSize: 13, color: PdfColors.red700)),
              ]),
            )),
          ]),
          pw.SizedBox(height: 20),

          // AI Narrative
          if (narrative.isNotEmpty) ...[
            pw.Text('Annual Performance Narrative',
                style: pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                narrative,
                style: const pw.TextStyle(fontSize: 13, lineSpacing: 4),
              ),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      name: '${employeeName.replaceAll(' ', '_')}_Annual_Performance_$year.pdf',
      onLayout: (_) async => pdf.save(),
    );
  }

  static pw.Widget _buildHeader(String name, int year, pw.Context ctx) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(
            colors: [PdfColors.blue700, PdfColors.blue400],
          ),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('HRNovva',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Annual Performance Report — $year',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 13)),
            ],
          )),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(name,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(
              'Generated ${DateFormat('d MMM yyyy').format(DateTime.now())}',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ]),
        ]),
      );

  static pw.Widget _buildFooter(pw.Context ctx) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('Confidential — HRNovva HR System',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ]),
      );

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.Text(value,
              style: const pw.TextStyle(fontSize: 12)),
        ]),
      );

  static double? _quarterAvg(List<PerformanceModel> records, List<int> months) {
    final qRecords = records.where((r) {
      final m = int.tryParse(r.month.split('-').last) ?? 0;
      return months.contains(m);
    }).toList();
    if (qRecords.isEmpty) return null;
    return qRecords.fold(0.0, (s, r) => s + r.overallScore) / qRecords.length;
  }

  static String _fmtMonth(String month) {
    try {
      return DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
    } catch (_) {
      return month;
    }
  }

  static String _ratingLabel(double score) {
    if (score >= 4.5) return 'Excellent';
    if (score >= 3.5) return 'Good';
    if (score >= 2.5) return 'Average';
    if (score >= 1.5) return 'Below Average';
    return 'Poor';
  }
}
