import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/payroll_model.dart';

class PayslipPdfService {
  PayslipPdfService._();

  static final _fmt = NumberFormat('#,##0', 'en_US');
  static String _rwf(double v) => 'RWF ${_fmt.format(v.round())}';

  static Future<pw.Document> generatePayslip(
      PayslipModel ps, String companyName) async {
    final doc = pw.Document();
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime.parse('${ps.payrollMonth}-01'));

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(companyName,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('PAYSLIP — $monthLabel',
                    style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('HRNova',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _blue)),
                pw.Text('hr-management-system',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ]),
            ],
          ),
          pw.Divider(thickness: 1.5, color: _blue),
          pw.SizedBox(height: 8),

          // ── Employee Info ───────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(children: [
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('Employee', ps.fullName),
                      _infoRow('Department', ps.department),
                      _infoRow('Job Title', ps.position),
                    ]),
              ),
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('National ID', ps.nationalId.isEmpty ? '—' : ps.nationalId),
                      _infoRow('RSSB No.', ps.rssbNumber.isEmpty ? '—' : ps.rssbNumber),
                      _infoRow('Bank Account',
                          ps.bankAccountNumber.isEmpty ? '—' : ps.bankAccountNumber),
                    ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 14),

          // ── Earnings ────────────────────────────────────────────────────
          _sectionTitle('EARNINGS'),
          pw.SizedBox(height: 4),
          _table([
            ['Basic Salary', _rwf(ps.baseSalary)],
            if (ps.transportAllowance > 0)
              ['Transport Allowance', _rwf(ps.transportAllowance)],
            if (ps.housingAllowance > 0)
              ['Housing Allowance', _rwf(ps.housingAllowance)],
            if (ps.bonuses > 0)
              [ps.bonusDescription?.isNotEmpty == true
                  ? 'Bonus — ${ps.bonusDescription}'
                  : 'Bonus / Adjustment',
               _rwf(ps.bonuses)],
          ], totalLabel: 'Total Earnings', totalValue: _rwf(ps.totalEarnings)),
          pw.SizedBox(height: 10),

          // ── Pre-statutory deductions ───────────────────────────────────
          if (ps.absentDeduction > 0 || ps.lateDeduction > 0) ...[
            _sectionTitle('ATTENDANCE DEDUCTIONS'),
            pw.SizedBox(height: 4),
            _table([
              if (ps.absentDeduction > 0)
                ['Absent (${ps.absentDays} day${ps.absentDays == 1 ? '' : 's'})',
                 '- ${_rwf(ps.absentDeduction)}'],
              if (ps.lateDeduction > 0)
                ['Late Arrival (${ps.totalLateMinutes} min)',
                 '- ${_rwf(ps.lateDeduction)}'],
            ],
                totalLabel: 'Adjusted Gross',
                totalValue: _rwf(ps.adjustedGross),
                isTotalHighlighted: true),
            pw.SizedBox(height: 10),
          ],

          // ── Deductions ─────────────────────────────────────────────────
          _sectionTitle('DEDUCTIONS'),
          pw.SizedBox(height: 4),
          _table([
            ['RSSB — Pension (Employee 6%)', '- ${_rwf(ps.pensionEmployee)}'],
            ['RSSB — Maternity (Employee 0.3%)', '- ${_rwf(ps.maternityEmployee)}'],
            ['PAYE Tax', '- ${_rwf(ps.paye)}'],
            if (ps.loanDeductions > 0)
              ['Loan Repayment', '- ${_rwf(ps.loanDeductions)}'],
            if (ps.extraDeductions > 0)
              [ps.extraDeductionsDescription?.isNotEmpty == true
                  ? 'Deduction — ${ps.extraDeductionsDescription}'
                  : 'Other Deduction',
               '- ${_rwf(ps.extraDeductions)}'],
          ], totalLabel: 'Total Deductions', totalValue: '- ${_rwf(ps.totalDeductions)}'),
          pw.SizedBox(height: 12),

          // ── Net salary ─────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              color: _blue,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NET SALARY',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(_rwf(ps.netSalary),
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ── Employer contributions ──────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('EMPLOYER CONTRIBUTIONS (for information only)',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 6),
                  pw.Row(children: [
                    pw.Expanded(
                        child: _infoRow(
                            'Pension (Employer 6%)', _rwf(ps.pensionEmployer))),
                    pw.Expanded(
                        child: _infoRow(
                            'Maternity (Employer 0.3%)', _rwf(ps.maternityEmployer))),
                    pw.Expanded(
                        child: _infoRow(
                            'Occupational Hazard (2%)', _rwf(ps.occupationalHazard))),
                  ]),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                  _infoRow('Total Employer Cost', _rwf(ps.totalEmployerCost)),
                ]),
          ),
          pw.SizedBox(height: 12),

          // ── Note ────────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFFF8E1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'RSSB and PAYE contributions are due to RRA by the 15th of the following month.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange800),
            ),
          ),
          pw.Spacer(),

          // ── Footer ──────────────────────────────────────────────────────
          pw.Divider(color: PdfColors.grey300),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Powered by HRNova',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Generated ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ]),
        ],
      ),
    ));

    return doc;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue),
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.Text('$label: ',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  static pw.Widget _table(
    List<List<String>> rows, {
    required String totalLabel,
    required String totalValue,
    bool isTotalHighlighted = false,
  }) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      children: [
        ...rows.map((row) => pw.TableRow(
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: pw.Text(row[0],
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: pw.Text(row[1],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right)),
              ],
            )),
        pw.TableRow(
          decoration: pw.BoxDecoration(
              color: isTotalHighlighted ? _blueLight : PdfColors.grey100),
          children: [
            pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(totalLabel,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(totalValue,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
      ],
    );
  }

  static const _blue = PdfColor.fromInt(0xFF1A6FE6);
  static const _blueLight = PdfColor.fromInt(0xFFE8F1FF);
}
