import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../attendance/models/attendance_model.dart';
import '../../branches/models/branch_model.dart';
import '../../employees/models/employee_model.dart';
import '../../performance/models/performance_model.dart';

// ── Clean minimal palette (no bright colors) ─────────────────────────────────
const _navy    = PdfColor.fromInt(0xFF1A1A2E);   // page title bar
const _blue    = PdfColor.fromInt(0xFF4A9EFF);   // accent (headings only)
const _green   = PdfColor.fromInt(0xFF1DB87A);   // kept for status text only
const _amber   = PdfColor.fromInt(0xFFF5A623);   // kept for status text only
const _red     = PdfColor.fromInt(0xFFE5534B);   // kept for status text only
const _grey    = PdfColor.fromInt(0xFF64748B);   // secondary text
const _lightGrey = PdfColor.fromInt(0xFFF5F5F5); // table header bg (very light)
const _white   = PdfColor.fromInt(0xFFFFFFFF);
const _black   = PdfColor.fromInt(0xFF1A1A1A);   // primary text
const _divider = PdfColor.fromInt(0xFFE2E8F0);   // row divider

// ── Attendance PDF ─────────────────────────────────────────────────────────────
class AttendancePdfService {
  AttendancePdfService._();

  static Future<void> download({
    required String companyName,
    required String period,
    required List<EmployeeModel> employees,
    required List<AttendanceModel> records,
    required String workEndTime,
    required String? branchName,
  }) async {
    final pdf = pw.Document();

    DateTime endDtA(DateTime day) {
      final p = workEndTime.split(':');
      return DateTime(day.year, day.month, day.day,
          int.parse(p[0]), p.length > 1 ? int.parse(p[1]) : 0);
    }

    bool isPresent(AttendanceModel r) =>
        r.checkInTime != null && r.checkInTime!.isBefore(endDtA(r.date));

    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('d MMM');

    // Group records by employee
    final byEmp = <String, List<AttendanceModel>>{};
    for (final r in records) {
      byEmp.putIfAbsent(r.employeeId, () => []).add(r);
    }

    // Stats
    final totalDays = records.isNotEmpty
        ? records.map((r) => r.date).toSet().length
        : 0;
    final presentCount = records.where((r) => isPresent(r)).length;
    final lateCount = records.where((r) => r.isLate && isPresent(r)).length;
    final totalPossible = totalDays * employees.length;
    final rate = totalPossible > 0
        ? ((presentCount / totalPossible) * 100).round()
        : 0;

    // Sort employees by name
    final sortedEmps = List<EmployeeModel>.from(employees)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Attendance Report', period,
            branchName != null ? 'Branch: $branchName' : null),
        footer: (_) => _footer(),
        build: (ctx) => [
          // Summary row
          _sectionTitle('Summary'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Total Employees', '${employees.length}', _blue),
            pw.SizedBox(width: 10),
            _statBox('Working Days', '$totalDays', _grey),
            pw.SizedBox(width: 10),
            _statBox('Attendance Rate', '$rate%',
                rate >= 80 ? _green : rate >= 60 ? _amber : _red),
            pw.SizedBox(width: 10),
            _statBox('Total Present', '$presentCount', _green),
            pw.SizedBox(width: 10),
            _statBox('Total Late', '$lateCount', _amber),
            pw.SizedBox(width: 10),
            _statBox('Absent',
                '${(totalPossible - presentCount).clamp(0, totalPossible)}', _red),
          ]),
          pw.SizedBox(height: 20),

          // Per-employee breakdown
          _sectionTitle('Employee Attendance Details'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: ['Employee', 'Department', 'Present', 'Late',
                    'Absent', 'Rate', 'Avg Check-in']
                    .map((h) => _th(h))
                    .toList(),
              ),
              // Rows
              ...sortedEmps.asMap().entries.map((entry) {
                final i = entry.key;
                final emp = entry.value;
                final recs = byEmp[emp.id] ?? [];
                final pres = recs.where((r) => isPresent(r)).length;
                final late = recs.where((r) => r.isLate && isPresent(r)).length;
                final absent = (totalDays - pres).clamp(0, totalDays);
                final empRate = totalDays > 0
                    ? ((pres / totalDays) * 100).round()
                    : 0;
                final checkIns = recs
                    .where((r) => r.checkInTime != null)
                    .map((r) => r.checkInTime!)
                    .toList();
                final avgCheckIn = checkIns.isEmpty
                    ? '—'
                    : (() {
                        final avgMin = checkIns
                                .map((t) => t.hour * 60 + t.minute)
                                .reduce((a, b) => a + b) ~/
                            checkIns.length;
                        return '${(avgMin ~/ 60).toString().padLeft(2, '0')}:${(avgMin % 60).toString().padLeft(2, '0')}';
                      })();
                final bg = i.isEven ? _white : _lightGrey;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _td(emp.fullName, bold: true),
                    _td(emp.department),
                    _tdColor('$pres', _green),
                    _tdColor('$late', _amber),
                    _tdColor('$absent', absent > 0 ? _red : _grey),
                    _tdColor('$empRate%',
                        empRate >= 80 ? _green : empRate >= 60 ? _amber : _red),
                    _td(avgCheckIn),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),
          // Day-by-day log for each employee
          _sectionTitle('Daily Attendance Log'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: ['Employee', 'Date', 'Status', 'Check-In', 'Check-Out']
                    .map((h) => _th(h))
                    .toList(),
              ),
              ...(() {
                  final sorted = List<AttendanceModel>.from(records)
                    ..sort((a, b) {
                        final empCmp = (employees.firstWhere(
                                (e) => e.id == a.employeeId,
                                orElse: () => employees.first).fullName)
                            .compareTo(employees.firstWhere(
                                (e) => e.id == b.employeeId,
                                orElse: () => employees.first).fullName);
                        if (empCmp != 0) return empCmp;
                        return a.date.compareTo(b.date);
                      });
                  return sorted.map((r) {
                    final emp = employees.firstWhere((e) => e.id == r.employeeId,
                        orElse: () => employees.first);
                    final status = r.isOnLeave
                        ? 'On Leave'
                        : isPresent(r)
                            ? (r.isLate ? 'Late' : 'Present')
                            : 'Absent';
                    final statusColor = r.isOnLeave
                        ? _blue
                        : isPresent(r)
                            ? (r.isLate ? _amber : _green)
                            : _red;
                    return pw.TableRow(
                      children: [
                        _td(emp.fullName),
                        _td(dateFmt.format(r.date)),
                        _tdColor(status, statusColor),
                        _td(r.checkInTime != null
                            ? timeFmt.format(r.checkInTime!)
                            : '—'),
                        _td(r.checkOutTime != null
                            ? timeFmt.format(r.checkOutTime!)
                            : '—'),
                      ],
                    );
                  }).toList();
                })(),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Attendance_Report_$period.pdf',
    );
  }
}

// ── Performance PDF ────────────────────────────────────────────────────────────
class PerformanceReportPdfService {
  PerformanceReportPdfService._();

  static Future<void> download({
    required String companyName,
    required String month,
    required List<PerformanceModel> records,
    required String? branchName,
  }) async {
    final pdf = pw.Document();
    final period = DateFormat('MMMM yyyy')
        .format(DateFormat('yyyy-MM').parse(month));

    final sorted = List<PerformanceModel>.from(records)
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));

    final avg = records.isEmpty
        ? 0.0
        : records.fold(0.0, (s, r) => s + r.overallScore) / records.length;

    // Collect all criteria names
    final allCriteria = <String>{};
    for (final r in records) {
      allCriteria.addAll(r.scores.keys);
    }
    final criteriaList = allCriteria.toList()..sort();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Performance Report', period,
            branchName != null ? 'Branch: $branchName' : null),
        footer: (_) => _footer(),
        build: (ctx) => [
          // Summary
          _sectionTitle('Summary'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Employees Scored', '${records.length}', _blue),
            pw.SizedBox(width: 10),
            _statBox('Company Average', avg.toStringAsFixed(1), _scoreColor(avg)),
            pw.SizedBox(width: 10),
            if (sorted.isNotEmpty) ...[
              _statBox('Top Performer', sorted.first.employeeName.split(' ').first, _green),
              pw.SizedBox(width: 10),
              _statBox('Top Score', sorted.first.overallScore.toStringAsFixed(1), _green),
            ],
            if (sorted.length > 1) ...[
              pw.SizedBox(width: 10),
              _statBox('Needs Attention', sorted.last.employeeName.split(' ').first, _red),
              pw.SizedBox(width: 10),
              _statBox('Lowest Score', sorted.last.overallScore.toStringAsFixed(1), _red),
            ],
          ]),
          pw.SizedBox(height: 20),

          // Main scores table
          _sectionTitle('Performance Scores'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              ...{for (int i = 0; i < criteriaList.length; i++)
                  (i + 5): const pw.FlexColumnWidth(1.5)},
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: [
                  _th('#'),
                  _th('Employee'),
                  _th('Department'),
                  _th('Score'),
                  _th('Rating'),
                  ...criteriaList.map((c) => _th(c.length > 10 ? '${c.substring(0, 9)}…' : c)),
                ],
              ),
              ...sorted.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final r = entry.value;
                final bg = entry.key.isEven ? _white : _lightGrey;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _td('$rank'),
                    _td(r.employeeName, bold: true),
                    _td(r.department),
                    _tdColor(r.overallScore.toStringAsFixed(1),
                        _scoreColor(r.overallScore), bold: true),
                    _tdColor(_ratingLabel(r.overallScore),
                        _scoreColor(r.overallScore)),
                    ...criteriaList.map((c) {
                      final score = r.scores[c];
                      return score != null
                          ? _tdColor(score.toStringAsFixed(1), _scoreColor(score))
                          : _td('—');
                    }),
                  ],
                );
              }),
            ],
          ),

          // AI Reviews
          if (records.any((r) => r.aiReview != null && r.aiReview!.isNotEmpty)) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('AI Performance Reviews'),
            pw.SizedBox(height: 8),
            ...sorted
                .where((r) => r.aiReview != null && r.aiReview!.isNotEmpty)
                .map((r) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 10),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _lightGrey),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(children: [
                              pw.Text(r.employeeName,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 11)),
                              pw.Spacer(),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: _scoreColor(r.overallScore),
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(4)),
                                ),
                                child: pw.Text(
                                    '${r.overallScore.toStringAsFixed(1)} — ${_ratingLabel(r.overallScore)}',
                                    style: const pw.TextStyle(
                                        color: _white, fontSize: 9)),
                              ),
                            ]),
                            pw.SizedBox(height: 6),
                            pw.Text(r.aiReview!,
                                style: const pw.TextStyle(fontSize: 10)),
                          ]),
                    )),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Performance_Report_$month.pdf',
    );
  }

  static PdfColor _scoreColor(double score) {
    if (score >= 4.0) return _green;
    if (score >= 3.0) return _amber;
    return _red;
  }

  static String _ratingLabel(double score) {
    if (score >= 4.5) return 'Excellent';
    if (score >= 4.0) return 'Very Good';
    if (score >= 3.0) return 'Good';
    if (score >= 2.0) return 'Needs Improvement';
    return 'Poor';
  }
}

// ── Branches PDF ───────────────────────────────────────────────────────────────
class BranchesReportPdfService {
  BranchesReportPdfService._();

  static Future<void> download({
    required String companyName,
    required String period,
    required List<BranchModel> branches,
    required List<EmployeeModel> employees,
    required List<AttendanceModel> records,
    required String workEndTime,
    required Map<String, double> payrollByBranch,
  }) async {
    final pdf = pw.Document();

    DateTime endDtB(DateTime day) {
      final p = workEndTime.split(':');
      return DateTime(day.year, day.month, day.day,
          int.parse(p[0]), p.length > 1 ? int.parse(p[1]) : 0);
    }

    bool isPresent(AttendanceModel r) =>
        r.checkInTime != null && r.checkInTime!.isBefore(endDtB(r.date));

    final totalDays = records.isNotEmpty
        ? records.map((r) => r.date).toSet().length
        : 0;

    // Per-branch stats
    final branchStats = <String, Map<String, dynamic>>{};
    for (final b in branches) {
      final empCount = employees.where((e) => e.isActive && e.branchId == b.id).length;
      final branchRecs = records.where((r) => r.branchId == b.id).toList();
      final present = branchRecs.where((r) => isPresent(r)).length;
      final late = branchRecs.where((r) => r.isLate && isPresent(r)).length;
      final maxPossible = totalDays * (empCount == 0 ? 1 : empCount);
      final rate = maxPossible > 0 ? ((present / maxPossible) * 100).round() : 0;
      branchStats[b.id] = {
        'name': b.name,
        'empCount': empCount,
        'present': present,
        'late': late,
        'absent': (maxPossible - present).clamp(0, maxPossible),
        'rate': rate,
        'payroll': payrollByBranch[b.id] ?? 0.0,
      };
    }

    final rwfFmt = NumberFormat('#,###');
    final totalEmps = employees.where((e) => e.isActive).length;
    final totalPresent = records.where((r) => isPresent(r)).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Branches Report', period, null),
        footer: (_) => _footer(),
        build: (ctx) => [
          // Company overview
          _sectionTitle('Company Overview'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Total Branches', '${branches.length}', _blue),
            pw.SizedBox(width: 10),
            _statBox('Active Employees', '$totalEmps', _navy),
            pw.SizedBox(width: 10),
            _statBox('Working Days', '$totalDays', _grey),
            pw.SizedBox(width: 10),
            _statBox('Total Present', '$totalPresent', _green),
          ]),
          pw.SizedBox(height: 20),

          // Branch comparison table
          _sectionTitle('Branch Performance Comparison'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: ['Branch', 'Employees', 'Present', 'Late',
                    'Absent', 'Att. Rate', 'Payroll (RWF)']
                    .map((h) => _th(h))
                    .toList(),
              ),
              ...branches.asMap().entries.map((entry) {
                final b = entry.value;
                final s = branchStats[b.id]!;
                final rate = s['rate'] as int;
                final bg = entry.key.isEven ? _white : _lightGrey;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _td(s['name'] as String, bold: true),
                    _td('${s['empCount']}'),
                    _tdColor('${s['present']}', _green),
                    _tdColor('${s['late']}', _amber),
                    _tdColor('${s['absent']}',
                        (s['absent'] as int) > 0 ? _red : _grey),
                    _tdColor('$rate%',
                        rate >= 80 ? _green : rate >= 60 ? _amber : _red,
                        bold: true),
                    _td(s['payroll'] > 0
                        ? 'RWF ${rwfFmt.format((s['payroll'] as double).round())}'
                        : '—'),
                  ],
                );
              }),
              // Totals row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: [
                  _th('TOTAL'),
                  _th('$totalEmps'),
                  _th('$totalPresent'),
                  _th('${records.where((r) => r.isLate && isPresent(r)).length}'),
                  _th('${records.isEmpty ? 0 : (totalDays * totalEmps - totalPresent).clamp(0, totalDays * totalEmps)}'),
                  _th(totalDays * totalEmps > 0
                      ? '${((totalPresent / (totalDays * totalEmps)) * 100).round()}%'
                      : '—'),
                  _th(payrollByBranch.values.isNotEmpty
                      ? 'RWF ${rwfFmt.format(payrollByBranch.values.fold<double>(0, (s, v) => s + v).round())}'
                      : '—'),
                ],
              ),
            ],
          ),

          // Per-branch employee list
          pw.SizedBox(height: 20),
          _sectionTitle('Employee Roster by Branch'),
          pw.SizedBox(height: 8),
          ...branches.map((b) {
            final branchEmps = employees
                .where((e) => e.isActive && e.branchId == b.id)
                .toList()
              ..sort((a, c) => a.fullName.compareTo(c.fullName));
            if (branchEmps.isEmpty) return pw.SizedBox();
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(b.name,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: _blue)),
                ),
                pw.Table(
                  border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(25),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _lightGrey),
                      children: ['#', 'Name', 'Department', 'Role', 'Salary Type']
                          .map((h) => _th(h))
                          .toList(),
                    ),
                    ...branchEmps.asMap().entries.map((e) {
                      final i = e.key;
                      final emp = e.value;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                            color: i.isEven ? _white : _lightGrey),
                        children: [
                          _td('${i + 1}'),
                          _td(emp.fullName, bold: true),
                          _td(emp.department),
                          _td(_capitalize(emp.role)),
                          _td(_stLabel(emp.salaryType)),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Branches_Report_$period.pdf',
    );
  }
}

// ── Shared PDF helpers (clean minimal style) ──────────────────────────────────
pw.Widget _header(String company, String title, String period, String? sub) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const pw.BoxDecoration(color: _navy),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('HRNova',
                  style: pw.TextStyle(fontSize: 11, color: _white, fontWeight: pw.FontWeight.bold)),
              pw.Text(company, style: const pw.TextStyle(fontSize: 9, color: _grey)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text(title,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _white)),
              pw.Text(period, style: const pw.TextStyle(fontSize: 10, color: _grey)),
              if (sub != null) pw.Text(sub, style: const pw.TextStyle(fontSize: 9, color: _grey)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Generated', style: const pw.TextStyle(fontSize: 9, color: _grey)),
              pw.Text(DateFormat('d MMM yyyy, HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: _grey)),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
    ],
  );
}

pw.Widget _footer() {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _divider)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Confidential — HRNova HR Management System',
            style: const pw.TextStyle(fontSize: 8, color: _grey)),
        pw.Text(DateFormat('d MMM yyyy').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: _grey)),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String text) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    decoration: const pw.BoxDecoration(
      color: _lightGrey,
      border: pw.Border(left: pw.BorderSide(color: _blue, width: 3)),
    ),
    child: pw.Text(text,
        style: pw.TextStyle(color: _black, fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget _statBox(String label, String value, PdfColor color) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _divider),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: _lightGrey,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
    ),
  );
}

pw.Widget _th(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(text,
        style: pw.TextStyle(
            color: _black,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget _td(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : null)),
  );
}

pw.Widget _tdColor(String text, PdfColor color, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : null)),
  );
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}';

String _stLabel(String t) {
  switch (t) {
    case 'fixed_monthly': return 'Fixed Monthly';
    case 'daily_rate': return 'Daily Rate';
    case 'hourly_rate': return 'Hourly Rate';
    default: return t;
  }
}

// ── Public data class for group branch stats ───────────────────────────────────
class GroupBranchStat {
  const GroupBranchStat({
    required this.branchName, required this.total, required this.present,
    required this.late, required this.onLeave, required this.absent, required this.rate,
  });
  final String branchName;
  final int total, present, late, onLeave, absent;
  final double rate;
}

// ── Group Report PDF ───────────────────────────────────────────────────────────
class GroupReportPdfService {
  GroupReportPdfService._();

  static Future<void> download({
    required String companyName,
    required String date,
    required int totalEmployees,
    required int totalPresent,
    required int totalLate,
    required int totalOnLeave,
    required int totalAbsent,
    required double overallRate,
    required List<GroupBranchStat> branchStats,
    String? aiReport,
  }) async {
    final pdf = pw.Document();
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(parsedDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Group Daily Report', dateLabel, null),
        footer: (_) => _footer(),
        build: (ctx) => [
          _sectionTitle('Group Summary'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Total Employees', '$totalEmployees', _blue),
            pw.SizedBox(width: 10),
            _statBox('Overall Rate', '${overallRate.toStringAsFixed(1)}%',
                overallRate >= 80 ? _green : overallRate >= 60 ? _amber : _red),
            pw.SizedBox(width: 10),
            _statBox('Present', '$totalPresent', _green),
            pw.SizedBox(width: 10),
            _statBox('Late', '$totalLate', _amber),
            pw.SizedBox(width: 10),
            _statBox('On Leave', '$totalOnLeave', _blue),
            pw.SizedBox(width: 10),
            _statBox('Absent', '$totalAbsent', _red),
          ]),
          if (branchStats.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Branch Breakdown'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(2),
                6: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _lightGrey),
                  children: ['Branch', 'Employees', 'Present', 'Late',
                      'On Leave', 'Absent', 'Rate']
                      .map((h) => _th(h)).toList(),
                ),
                ...branchStats.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final rc = s.rate >= 90 ? _green : s.rate >= 70 ? _amber : _red;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: i.isEven ? _white : _lightGrey),
                    children: [
                      _td(s.branchName, bold: true),
                      _td('${s.total}'),
                      _tdColor('${s.present}', _green),
                      _tdColor('${s.late}', _amber),
                      _tdColor('${s.onLeave}', _blue),
                      _tdColor('${s.absent}', s.absent > 0 ? _red : _grey),
                      _tdColor('${s.rate.toStringAsFixed(1)}%', rc, bold: true),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _lightGrey),
                  children: [
                    _th('TOTAL'), _th('$totalEmployees'), _th('$totalPresent'),
                    _th('$totalLate'), _th('$totalOnLeave'), _th('$totalAbsent'),
                    _th('${overallRate.toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
            if (branchStats.length >= 2) ...[
              pw.SizedBox(height: 20),
              _sectionTitle('Highlights'),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _green),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Best Performing Branch',
                        style: pw.TextStyle(color: _green, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(branchStats.first.branchName,
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${branchStats.first.present}/${branchStats.first.total} · '
                        '${branchStats.first.rate.toStringAsFixed(1)}%',
                        style: const pw.TextStyle(color: _green, fontSize: 10)),
                  ]),
                )),
                pw.SizedBox(width: 12),
                pw.Expanded(child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _red),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Needs Attention',
                        style: pw.TextStyle(color: _red, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(branchStats.last.branchName,
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${branchStats.last.present}/${branchStats.last.total} · '
                        '${branchStats.last.rate.toStringAsFixed(1)}%',
                        style: const pw.TextStyle(color: _red, fontSize: 10)),
                  ]),
                )),
              ]),
            ],
          ],
          if (aiReport != null && aiReport.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('AI Generated Report'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGrey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(aiReport, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Group_Report_$date.pdf',
    );
  }
}

// ── Daily Report PDF ───────────────────────────────────────────────────────────
class DailyReportPdfService {
  DailyReportPdfService._();

  static Future<void> download({
    required String companyName,
    required String dateLabel,
    required String dateKey,
    required int totalActive,
    required int present,
    required int late,
    required int absent,
    required int onLeave,
    required int rate,
    String? aiReport,
    String? branchName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Daily Attendance Report', dateLabel,
            branchName != null ? 'Branch: $branchName' : null),
        footer: (_) => _footer(),
        build: (ctx) => [
          _sectionTitle('Attendance Overview'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Active Employees', '$totalActive', _blue),
            pw.SizedBox(width: 10),
            _statBox('Attendance Rate', '$rate%',
                rate >= 80 ? _green : rate >= 60 ? _amber : _red),
            pw.SizedBox(width: 10),
            _statBox('Present', '$present', _green),
            pw.SizedBox(width: 10),
            _statBox('Late', '$late', _amber),
            pw.SizedBox(width: 10),
            _statBox('Absent', '$absent', _red),
            pw.SizedBox(width: 10),
            _statBox('On Leave', '$onLeave', _blue),
          ]),
          pw.SizedBox(height: 20),
          _sectionTitle('Attendance Breakdown'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: ['Status', 'Count'].map((h) => _th(h)).toList(),
              ),
              pw.TableRow(children: [
                _td('On Time (Present & Punctual)'),
                _tdColor('${present - late}', _green),
              ]),
              pw.TableRow(children: [
                _td('Late (Present but Late)'),
                _tdColor('$late', _amber),
              ]),
              pw.TableRow(children: [
                _td('Absent'),
                _tdColor('$absent', _red),
              ]),
              pw.TableRow(children: [
                _td('On Leave'),
                _tdColor('$onLeave', _blue),
              ]),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: [_th('Total Employees'), _th('$totalActive')],
              ),
            ],
          ),
          if (aiReport != null && aiReport.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('AI Daily Summary'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGrey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(aiReport, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Daily_Report_$dateKey.pdf',
    );
  }
}

// ── Weekly Report PDF ──────────────────────────────────────────────────────────
class WeeklyReportPdfService {
  WeeklyReportPdfService._();

  static Future<void> download({
    required String companyName,
    required String period,
    required String fileKey,
    required int totalActive,
    required int totalPresent,
    required int totalLate,
    required int avgRate,
    required List<(String day, int present, int total)> dayStats,
    String? aiReport,
    String? branchName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Weekly Attendance Report', period,
            branchName != null ? 'Branch: $branchName' : null),
        footer: (_) => _footer(),
        build: (ctx) => [
          _sectionTitle('Weekly Summary'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Employees', '$totalActive', _blue),
            pw.SizedBox(width: 10),
            _statBox('Avg Attendance Rate', '$avgRate%',
                avgRate >= 80 ? _green : avgRate >= 60 ? _amber : _red),
            pw.SizedBox(width: 10),
            _statBox('Total Present', '$totalPresent', _green),
            pw.SizedBox(width: 10),
            _statBox('Total Late', '$totalLate', _amber),
          ]),
          pw.SizedBox(height: 20),
          _sectionTitle('Day-by-Day Attendance'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: ['Day', 'Present', 'Employees', 'Rate']
                    .map((h) => _th(h)).toList(),
              ),
              ...dayStats.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final rate = s.$3 > 0 ? ((s.$2 / s.$3) * 100).round() : 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? _white : _lightGrey),
                  children: [
                    _td(s.$1, bold: true),
                    _tdColor('${s.$2}', _green),
                    _td('${s.$3}'),
                    _tdColor('$rate%',
                        rate >= 80 ? _green : rate >= 60 ? _amber : _red,
                        bold: true),
                  ],
                );
              }),
            ],
          ),
          if (aiReport != null && aiReport.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('AI Weekly Summary'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGrey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(aiReport, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Weekly_Report_$fileKey.pdf',
    );
  }
}

// ── Monthly Report PDF ─────────────────────────────────────────────────────────
class MonthlyReportPdfService {
  MonthlyReportPdfService._();

  static Future<void> download({
    required String companyName,
    required String month,
    required int totalActive,
    required int present,
    required int late,
    required int absent,
    required int workDays,
    required int rate,
    required Map<String, int> leaveByType,
    required double totalGross,
    required int payrollCount,
    String? aiReport,
    String? branchName,
  }) async {
    final pdf = pw.Document();
    final period = DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(month));
    final rwfFmt = NumberFormat('#,###');
    const typeLabels = {
      'annual': 'Annual', 'sick': 'Sick', 'maternity': 'Maternity',
      'paternity': 'Paternity', 'unpaid': 'Unpaid', 'emergency': 'Emergency',
    };

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(companyName, 'Monthly HR Report', period,
            branchName != null ? 'Branch: $branchName' : null),
        footer: (_) => _footer(),
        build: (ctx) => [
          _sectionTitle('Monthly Overview'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Attendance Rate', '$rate%',
                rate >= 80 ? _green : rate >= 60 ? _amber : _red),
            pw.SizedBox(width: 10),
            _statBox('Present Days', '$present', _green),
            pw.SizedBox(width: 10),
            _statBox('Late Days', '$late', _amber),
            pw.SizedBox(width: 10),
            _statBox('Absent Days', '$absent', _red),
            pw.SizedBox(width: 10),
            _statBox('Working Days', '$workDays', _blue),
            pw.SizedBox(width: 10),
            _statBox('Active Employees', '$totalActive', _navy),
          ]),
          if (leaveByType.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Leave by Type (Approved Days)'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _lightGrey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _lightGrey),
                  children: ['Leave Type', 'Approved Days'].map((h) => _th(h)).toList(),
                ),
                ...leaveByType.entries.toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: i.isEven ? _white : _lightGrey),
                    children: [
                      _td(typeLabels[e.key] ?? _capitalize(e.key)),
                      _tdColor('${e.value}', _blue),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _lightGrey),
                  children: [
                    _th('Total Leave Days'),
                    _th('${leaveByType.values.fold(0, (a, b) => a + b)}'),
                  ],
                ),
              ],
            ),
          ],
          if (totalGross > 0) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Payroll Summary'),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _statBox('Employees Paid', '$payrollCount', _blue),
              pw.SizedBox(width: 10),
              _statBox('Total Gross Payroll',
                  'RWF ${rwfFmt.format(totalGross.round())}', _green),
            ]),
          ],
          if (aiReport != null && aiReport.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('AI Monthly Summary'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGrey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(aiReport, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Monthly_Report_$month.pdf',
    );
  }
}
