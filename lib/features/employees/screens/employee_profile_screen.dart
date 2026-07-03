// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/constants/app_constants.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../leave/models/leave_request_model.dart';
import '../../leave/providers/leave_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';
import '../../payroll/models/payroll_model.dart';
import '../../payroll/providers/payroll_provider.dart';
import '../../payroll/services/payslip_pdf_service.dart';
import '../../settings/providers/settings_provider.dart';

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeeAsync = ref.watch(employeeByIdProvider(widget.employeeId));

    return Scaffold(
      backgroundColor: context.appBg,
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (employee) {
          if (employee == null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_off_outlined, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('Employee not found', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
              ]),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(
                employee: employee,
                onEdit: () => context.push('/employees/new?editId=${employee.id}'),
              ),
              _TabBar(controller: _tabs),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _ProfileTab(employee: employee),
                    _QRTab(employee: employee),
                    _AttendanceTab(employeeId: widget.employeeId),
                    _LeaveProfileTab(employee: employee),
                    _PayrollProfileTab(employee: employee),
                    _LoansTab(employee: employee),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Profile header
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.employee, required this.onEdit});
  final EmployeeModel employee;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      color: context.appBg,
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: context.appSubtext),
            ),
          ),
          const SizedBox(width: 16),
          _LargeAvatar(name: employee.fullName, photoUrl: employee.profilePhotoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.fullName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.appText)),
              const SizedBox(height: 4),
              Text(employee.jobTitle.isEmpty ? employee.department : employee.jobTitle,
                style: TextStyle(fontSize: 14, color: context.appSubtext)),
              const SizedBox(height: 6),
              Row(children: [
                _Pill(employee.department, AppColors.pillBlueBg, AppColors.pillBlueText),
                const SizedBox(width: 8),
                _Pill(
                  employee.isActive ? 'Active' : 'Inactive',
                  employee.isActive ? AppColors.pillGreenBg : AppColors.pillRedBg,
                  employee.isActive ? AppColors.pillGreenText : AppColors.pillRedText,
                ),
                if (employee.contractType != 'permanent') ...[
                  const SizedBox(width: 8),
                  _Pill(_ctLabel(employee.contractType), AppColors.pillNavyBg, AppColors.pillNavyText),
                ],
              ]),
            ]),
          ),
          OutlinedButton.icon(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryBlue),
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  static String _ctLabel(String c) => switch (c) {
    'fixed_term' => 'Fixed Term', 'probation' => 'Probation', 'part_time' => 'Part Time', _ => 'Permanent',
  };
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(child: Image.network(photoUrl!, width: 80, height: 80, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initials()));
    }
    return _initials();
  }

  Widget _initials() {
    final colors = AppColors.gradientForName(name);
    final parts = name.split(' ');
    final initials = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
      alignment: Alignment.center,
      child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.bg, this.fg);
  final String label; final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab bar
// ─────────────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appBg,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: context.appSubtext,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        indicatorColor: AppColors.primaryBlue,
        indicatorWeight: 2.5,
        dividerColor: context.appBg,
        tabs: const [
          Tab(text: 'Profile'), Tab(text: 'QR Code'), Tab(text: 'Attendance'),
          Tab(text: 'Leave'), Tab(text: 'Payroll'), Tab(text: 'Loans'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Profile tab
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Hero banner ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(children: [
            // Gradient top strip
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryBlue.withAlpha(180), AppColors.primaryBlue.withAlpha(60)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: context.appCard, width: 4),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 12)],
                      ),
                      child: _LargeAvatar(name: employee.fullName, photoUrl: employee.profilePhotoUrl),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(employee.fullName,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.appText)),
                          const SizedBox(height: 2),
                          Text(employee.jobTitle.isEmpty ? employee.department : employee.jobTitle,
                              style: TextStyle(fontSize: 13, color: context.appSubtext)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Row(children: [
                    _StatChip(Icons.business_rounded, employee.department, AppColors.pillBlueBg, AppColors.pillBlueText),
                    const SizedBox(width: 8),
                    _StatChip(
                      Icons.circle,
                      employee.isActive ? 'Active' : 'Inactive',
                      employee.isActive ? AppColors.pillGreenBg : AppColors.pillRedBg,
                      employee.isActive ? AppColors.pillGreenText : AppColors.pillRedText,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(Icons.calendar_today_rounded, 'Since ${_shortDate(employee.startDate)}',
                        AppColors.pillNavyBg, AppColors.pillNavyText),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── 3-column quick stats ──────────────────────────────────────────────
        Row(children: [
          Expanded(child: _QuickStat(Icons.account_balance_wallet_rounded, 'Salary',
              _fmtRwf(employee.grossSalary), AppColors.primaryBlue)),
          const SizedBox(width: 12),
          Expanded(child: _QuickStat(Icons.badge_rounded, 'Contract',
              _ctLabel(employee.contractType), AppColors.successGreen)),
          const SizedBox(width: 12),
          Expanded(child: _QuickStat(Icons.beach_access_rounded, 'Annual Leave',
              '${employee.leaveBalances['annual'] ?? 18} days', const Color(0xFF9C27B0))),
        ]),
        const SizedBox(height: 20),
        // ── Content row ───────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Left: Personal + Employment
          Expanded(
            child: Column(children: [
              _Section(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                children: [
                  _Field('Full Name', employee.fullName),
                  _Field('National ID', employee.nationalId.isEmpty ? '—' : employee.nationalId),
                  _Field('Phone', employee.phone.isEmpty ? '—' : employee.phone),
                  _Field('Email', employee.email.isEmpty ? '—' : employee.email),
                  _Field('Date of Birth', EmployeeModel.fmtDate(employee.dateOfBirth)),
                  _Field('Emergency Contact', employee.emergencyContact.isEmpty ? '—' : employee.emergencyContact),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Employment',
                icon: Icons.work_outline_rounded,
                children: [
                  _Field('Department', employee.department),
                  _Field('Job Title', employee.jobTitle.isEmpty ? '—' : employee.jobTitle),
                  _Field('Role', _capitalize(employee.role)),
                  _Field('Start Date', EmployeeModel.fmtDate(employee.startDate)),
                  if (employee.endDate != null) _Field('End Date', EmployeeModel.fmtDate(employee.endDate)),
                  _Field('RSSB Number', employee.rssbNumber.isEmpty ? '—' : employee.rssbNumber),
                ],
              ),
            ]),
          ),
          const SizedBox(width: 14),
          // Right: Salary + Leave
          Expanded(
            child: Column(children: [
              _Section(
                title: 'Salary & Compensation',
                icon: Icons.payments_outlined,
                children: [
                  _Field('Salary Type', _stLabel(employee.salaryType)),
                  if (employee.salaryType == 'fixed_monthly') _Field('Monthly Salary', _fmtRwf(employee.salaryAmount)),
                  if (employee.salaryType == 'daily_rate') _Field('Daily Rate', _fmtRwf(employee.dailyRate)),
                  if (employee.salaryType == 'hourly_rate') _Field('Hourly Rate', _fmtRwf(employee.hourlyRate)),
                  _Field('Transport Allowance', _fmtRwf(employee.transportAllowance)),
                  _Field('Housing Allowance', _fmtRwf(employee.housingAllowance)),
                  _Field('Bank Account', employee.bankAccount.isEmpty ? '—' : employee.bankAccount),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Leave Balances',
                icon: Icons.beach_access_rounded,
                children: [
                  _LeaveBalanceRow('Annual', employee.leaveBalances['annual'] ?? 18, AppConstants.annualLeaveDaysPerYear, AppColors.primaryBlue),
                  _LeaveBalanceRow('Sick', employee.leaveBalances['sick'] ?? 10, 10, AppColors.successGreen),
                  _LeaveBalanceRow('Maternity', employee.leaveBalances['maternity'] ?? 84, AppConstants.maternityLeaveDays, const Color(0xFF9C27B0)),
                  _LeaveBalanceRow('Paternity', employee.leaveBalances['paternity'] ?? 4, AppConstants.paternityLeaveDays, const Color(0xFF00897B)),
                ],
              ),
              if (employee.notes != null && employee.notes!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'Notes',
                  icon: Icons.notes_rounded,
                  children: [
                    Text(employee.notes!, style: TextStyle(fontSize: 13, color: context.appText, height: 1.5)),
                  ],
                ),
              ],
            ]),
          ),
        ]),
      ]),
    );
  }

  static String _ctLabel(String c) => switch (c) {
    'fixed_term' => 'Fixed Term', 'probation' => 'Probation', 'part_time' => 'Part Time', _ => 'Permanent',
  };
  static String _stLabel(String s) => switch (s) {
    'daily_rate' => 'Daily Rate', 'hourly_rate' => 'Hourly Rate', _ => 'Fixed Monthly',
  };
  static String _capitalize(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
  static String _shortDate(DateTime d) => DateFormat('MMM yyyy').format(d);
  static String _fmtRwf(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer('RWF ');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.icon, this.label, this.bg, this.fg);
  final IconData icon;
  final String label;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: fg),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    ]),
  );
}

class _QuickStat extends StatelessWidget {
  const _QuickStat(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.appCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.appBorder),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 17, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.appSubtext)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText),
            overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.appBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText)),
        ]),
      ),
      Divider(height: 1, color: context.appBorder),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: children),
      ),
    ]),
  );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 130,
        child: Text(label, style: TextStyle(fontSize: 12, color: context.appSubtext)),
      ),
      Expanded(
        child: Text(value ?? '—',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText)),
      ),
    ]),
  );
}

class _LeaveBalanceRow extends StatelessWidget {
  const _LeaveBalanceRow(this.label, this.balance, this.total, this.color);
  final String label;
  final int balance, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (balance / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.appSubtext)),
          const Spacer(),
          Text('$balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          Text(' / $total d', style: TextStyle(fontSize: 11, color: context.appSubtext)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: context.appBorder,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
//  QR Code tab
// ─────────────────────────────────────────────────────────────────────────────
class _QRTab extends ConsumerStatefulWidget {
  const _QRTab({required this.employee});
  final EmployeeModel employee;

  @override
  ConsumerState<_QRTab> createState() => _QRTabState();
}

class _QRTabState extends ConsumerState<_QRTab> {
  final GlobalKey _qrKey = GlobalKey();
  bool _regenerating = false;

  Future<void> _downloadPng() async {
    try {
      final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', '${widget.employee.fullName.replaceAll(' ', '_')}_QR.png')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _printBadge() async {
    final e = widget.employee;
    final qrData = e.qrCode ?? '${e.companyId}_${e.id}';
    await Printing.layoutPdf(
      name: '${e.fullName} - ID Badge',
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (ctx) => pw.Center(
            child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Text('HRNova', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData, width: 200, height: 200),
              pw.SizedBox(height: 16),
              pw.Text(e.fullName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${e.department} · ${e.jobTitle}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(qrData, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ]),
          ),
        ));
        return doc.save();
      },
    );
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Regenerate QR Code?', style: TextStyle(fontWeight: FontWeight.w700, color: ctx.appText)),
        content: const Text('The old QR code will stop working immediately. All printed badges will need to be reprinted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warningAmber, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _regenerating = true);
    try {
      await ref.read(employeesNotifierProvider.notifier).regenerateQR(widget.employee.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final qrData = e.qrCode ?? '${e.companyId}_${e.id}';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.brightBlue]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.business_center, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('HRNova', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 180,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.darkNavy),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.darkNavy),
                ),
                const SizedBox(height: 16),
                Text(e.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('${e.department} · ${e.jobTitle.isEmpty ? "Employee" : e.jobTitle}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(qrData, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primaryBlue), foregroundColor: AppColors.primaryBlue),
              onPressed: _downloadPng,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download PNG'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primaryBlue), foregroundColor: AppColors.primaryBlue),
              onPressed: _printBadge,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print Badge'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.warningAmber), foregroundColor: AppColors.warningAmber),
              onPressed: _regenerating ? null : _regenerate,
              icon: _regenerating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Regenerate'),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Attendance tab — real Firestore data
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab({required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  static String _pad(int v) => v.toString().padLeft(2, '0');

  static String _fmtTime(DateTime t) => '${_pad(t.hour)}:${_pad(t.minute)}';

  static String _statusFromRecord(AttendanceModel r) {
    if (r.isOnLeave) return 'on_leave';
    if (r.isAbsent) return 'absent';
    if (r.isLate) return 'late';
    if (r.checkInTime != null) return 'on_time';
    return 'absent';
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(employeeAttendanceByMonthProvider(
        (employeeId: widget.employeeId, year: _month.year, month: _month.month)));

    final records = recordsAsync.value ?? [];

    // Build day→record map keyed by day-of-month
    final recMap = <int, AttendanceModel>{};
    for (final r in records) {
      recMap[r.date.day] = r;
    }

    // Build status map for calendar
    final statusMap = <int, String>{};
    for (final entry in recMap.entries) {
      statusMap[entry.key] = _statusFromRecord(entry.value);
    }

    final present = statusMap.values.where((s) => s == 'on_time').length;
    final late    = statusMap.values.where((s) => s == 'late').length;
    final absent  = statusMap.values.where((s) => s == 'absent').length;
    final leave   = statusMap.values.where((s) => s == 'on_leave').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Month nav + summary chips
        Row(children: [
          _monthNavBtn(Icons.chevron_left_rounded, _prevMonth, context),
          const SizedBox(width: 12),
          Text(DateFormat('MMMM yyyy').format(_month),
              style: TextStyle(
                  color: context.appText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          _monthNavBtn(Icons.chevron_right_rounded, _nextMonth, context),
          const Spacer(),
          _chip('$present Present', AppColors.successGreen, AppColors.pillGreenBg),
          const SizedBox(width: 8),
          _chip('$late Late', AppColors.warningAmber, AppColors.pillAmberBg),
          const SizedBox(width: 8),
          _chip('$absent Absent', AppColors.errorRed, AppColors.pillRedBg),
          const SizedBox(width: 8),
          _chip('$leave Leave', AppColors.primaryBlue, AppColors.pillBlueBg),
        ]),
        const SizedBox(height: 20),
        // Calendar grid
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appBorder),
          ),
          child: recordsAsync.isLoading
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator()))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(d,
                                    style: TextStyle(
                                        color: context.appSubtext,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  _CalendarGrid(month: _month, data: statusMap),
                  const SizedBox(height: 16),
                  Wrap(spacing: 16, runSpacing: 6, children: [
                    _legendItem('On Time', AppColors.successGreen),
                    _legendItem('Late', AppColors.warningAmber),
                    _legendItem('Absent', AppColors.errorRed),
                    _legendItem('On Leave', AppColors.primaryBlue),
                    _legendItem('Weekend / No Data', context.appBorder),
                  ]),
                ]),
        ),
        const SizedBox(height: 20),
        // Detail table
        Container(
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: context.appTint,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                Expanded(flex: 10, child: _hTxt('DAY', context)),
                Expanded(flex: 8, child: _hTxt('DATE', context)),
                Expanded(flex: 10, child: _hTxt('CHECK IN', context)),
                Expanded(flex: 10, child: _hTxt('CHECK OUT', context)),
                Expanded(flex: 10, child: _hTxt('STATUS', context)),
              ]),
            ),
            Divider(height: 1, color: context.appBorder),
            if (recordsAsync.isLoading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())
            else
              ..._buildDetailRows(context, recMap),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _buildDetailRows(
      BuildContext context, Map<int, AttendanceModel> recMap) {
    final rows = <Widget>[];
    final daysInMonth =
        DateUtils.getDaysInMonth(_month.year, _month.month);
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final weekday = date.weekday;
      final isWeekend = weekday == 6 || weekday == 7;
      if (isWeekend) continue;
      final rec = recMap[d];
      if (rec == null) continue;
      final status = _statusFromRecord(rec);
      final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][weekday - 1];
      final dateLabel = DateFormat('MMM d').format(date);
      rows.add(Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
              flex: 10,
              child: Text(dayName,
                  style:
                      TextStyle(color: context.appSubtext, fontSize: 12))),
          Expanded(
              flex: 8,
              child: Text(dateLabel,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500))),
          Expanded(
              flex: 10,
              child: Text(
                  rec.checkInTime != null
                      ? _fmtTime(rec.checkInTime!)
                      : '—',
                  style:
                      TextStyle(color: context.appText, fontSize: 12))),
          Expanded(
              flex: 10,
              child: Text(
                  rec.checkOutTime != null
                      ? _fmtTime(rec.checkOutTime!)
                      : '—',
                  style:
                      TextStyle(color: context.appText, fontSize: 12))),
          Expanded(flex: 10, child: _StatusChip(status)),
        ]),
      ));
      rows.add(Divider(height: 1, color: context.appBorder));
    }
    if (rows.isNotEmpty && rows.last is Divider) rows.removeLast();
    return rows;
  }

  Widget _monthNavBtn(IconData icon, VoidCallback onTap, BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appBorder)),
          child: Icon(icon, color: context.appText, size: 16),
        ),
      );

  Widget _chip(String label, Color fg, Color bg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _legendItem(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ]);

  Text _hTxt(String t, BuildContext ctx) => Text(t,
      style: TextStyle(
          color: ctx.appSubtext,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.month, required this.data});
  final DateTime month;
  final Map<int, String> data;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    // weekday: 1=Mon … 7=Sun; we want offset so Mon = column 0
    final startOffset = firstDay.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final day = cellIndex - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 36));
              }
              final date = DateTime(month.year, month.month, day);
              final isWeekend =
                  date.weekday == 6 || date.weekday == 7;
              final status = data[day];
              final cellColor = isWeekend || status == null
                  ? context.appBorder.withAlpha(80)
                  : _statusColor(status);
              final textColor = isWeekend || status == null
                  ? context.appSubtext
                  : Colors.white;

              return Expanded(
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('$day',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: isWeekend || status == null
                              ? FontWeight.w400
                              : FontWeight.w700)),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  static Color _statusColor(String status) => switch (status) {
    'on_time'  => AppColors.successGreen,
    'late'     => AppColors.warningAmber,
    'absent'   => AppColors.errorRed,
    'on_leave' => AppColors.primaryBlue,
    _          => AppColors.textSecondary,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'on_time'  => ('On Time',  AppColors.pillGreenBg, AppColors.pillGreenText),
      'late'     => ('Late',     AppColors.pillAmberBg, AppColors.pillAmberText),
      'absent'   => ('Absent',   AppColors.pillRedBg,   AppColors.pillRedText),
      'on_leave' => ('On Leave', AppColors.pillBlueBg,  AppColors.pillBlueText),
      _          => ('—',        AppColors.pillNavyBg,  AppColors.pillNavyText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Leave tab
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveProfileTab extends ConsumerWidget {
  const _LeaveProfileTab({required this.employee});
  final EmployeeModel employee;

  static const _balances = [
    ('annual',    'Annual Leave',    AppColors.primaryBlue,   Icons.flight_takeoff_rounded,  AppConstants.annualLeaveDaysPerYear),
    ('sick',      'Sick Leave',      AppColors.successGreen,  Icons.local_hospital_rounded,  10),
    ('maternity', 'Maternity Leave', Color(0xFF9C27B0),       Icons.child_care_rounded,      AppConstants.maternityLeaveDays),
    ('paternity', 'Paternity Leave', Color(0xFF00897B),       Icons.family_restroom_rounded, AppConstants.paternityLeaveDays),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(employeeLeaveRequestsProvider(employee.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Left column: Balance cards ─────────────────────────────────────
        SizedBox(
          width: 320,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Leave Balances',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appText)),
              TextButton.icon(
                onPressed: () => _showAdjustDialog(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Adjust', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 10),
            ..._balances.map((t) {
              final bal = employee.leaveBalances[t.$1] ?? t.$5;
              final used = (t.$5 - bal).clamp(0, t.$5);
              final pct = t.$5 > 0 ? (bal / t.$5).clamp(0.0, 1.0) : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: t.$3, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: t.$3.withAlpha(18),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(t.$4, size: 16, color: t.$3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText)),
                        Text('${used} used · ${t.$5} total',
                            style: TextStyle(fontSize: 11, color: context.appSubtext)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$bal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.$3, height: 1)),
                        Text('days left', style: TextStyle(fontSize: 10, color: context.appSubtext)),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: context.appBorder,
                            valueColor: AlwaysStoppedAnimation(t.$3),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(pct * 100).round()}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.$3)),
                    ]),
                  ]),
                ),
              );
            }),
          ]),
        ),
        const SizedBox(width: 20),
        // ── Right column: History ──────────────────────────────────────────
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Leave History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appText)),
              const Spacer(),
              requestsAsync.when(
                data: (r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pillBlueBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('${r.length} request${r.length != 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ]),
            const SizedBox(height: 12),
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.appTint,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: context.appBorder),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: _hTxt('TYPE', context)),
                Expanded(flex: 4, child: _hTxt('PERIOD', context)),
                Expanded(flex: 1, child: _hTxt('DAYS', context)),
                Expanded(flex: 2, child: _hTxt('SOURCE', context)),
                Expanded(flex: 2, child: _hTxt('STATUS', context)),
              ]),
            ),
            requestsAsync.when(
              loading: () => Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: context.appBorder), left: BorderSide(color: context.appBorder), right: BorderSide(color: context.appBorder)),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.textSecondary)),
              data: (requests) => requests.isEmpty
                  ? Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 220),
                      decoration: BoxDecoration(
                        color: context.appCard,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: context.appBorder), left: BorderSide(color: context.appBorder), right: BorderSide(color: context.appBorder)),
                      ),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inbox_outlined, size: 40, color: context.appSubtext),
                          const SizedBox(height: 8),
                          Text('No leave requests yet', style: TextStyle(fontSize: 13, color: context.appSubtext)),
                        ]),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: context.appCard,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: context.appBorder), left: BorderSide(color: context.appBorder), right: BorderSide(color: context.appBorder)),
                      ),
                      child: Column(
                        children: requests.asMap().entries.map((e) => Column(children: [
                          if (e.key > 0) Divider(height: 1, color: context.appBorder),
                          _LeaveHistoryRow(req: e.value),
                        ])).toList(),
                      ),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _hTxt(String t, BuildContext ctx) => Text(t,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ctx.appSubtext, letterSpacing: 0.5));

  void _showAdjustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AdjustLeaveDialog(employeeId: employee.id),
    );
  }
}

class _LeaveHistoryRow extends StatelessWidget {
  const _LeaveHistoryRow({required this.req});
  final LeaveRequestModel req;

  @override
  Widget build(BuildContext context) {
    final dateF = DateFormat('MMM d');
    final dotColor = switch (req.leaveType) {
      'annual'    => AppColors.primaryBlue,
      'sick'      => AppColors.successGreen,
      'maternity' => const Color(0xFF9C27B0),
      'paternity' => const Color(0xFF00897B),
      _           => AppColors.textSecondary,
    };
    final (bg, fg) = switch (req.status) {
      'approved' => (AppColors.pillGreenBg, AppColors.pillGreenText),
      'rejected' => (AppColors.pillRedBg,   AppColors.pillRedText),
      _          => (AppColors.pillAmberBg, AppColors.pillAmberText),
    };
    final srcLabel = switch (req.source) {
      'whatsapp_portal' => 'WhatsApp',
      'web_dashboard'   => 'Web',
      _                 => 'Mobile',
    };

    return InkWell(
      onTap: req.status == 'rejected' && req.rejectedReason != null
          ? () => _showReason(context, req.rejectedReason!)
          : null,
      hoverColor: context.appBorder.withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Type
          Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                    '${req.leaveType[0].toUpperCase()}${req.leaveType.substring(1)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText)),
              ),
            ]),
          ),
          // Period
          Expanded(
            flex: 4,
            child: Text(
              '${dateF.format(req.startDate)} – ${dateF.format(req.endDate)}',
              style: TextStyle(fontSize: 12, color: context.appSubtext),
            ),
          ),
          // Days
          Expanded(
            flex: 1,
            child: Text('${req.totalDays}d',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.appText)),
          ),
          // Source
          Expanded(
            flex: 2,
            child: Text(srcLabel,
                style: TextStyle(fontSize: 11, color: context.appSubtext)),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
                child: Text(
                    '${req.status[0].toUpperCase()}${req.status.substring(1)}',
                    style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (req.status == 'rejected' && req.rejectedReason != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: req.rejectedReason!,
                  child: GestureDetector(
                    onTap: () => _showReason(context, req.rejectedReason!),
                    child: const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.errorRed),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  void _showReason(BuildContext context, String reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: Text(reason),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _AdjustLeaveDialog extends ConsumerStatefulWidget {
  const _AdjustLeaveDialog({required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<_AdjustLeaveDialog> createState() =>
      _AdjustLeaveDialogState();
}

class _AdjustLeaveDialogState
    extends ConsumerState<_AdjustLeaveDialog> {
  String _selectedType = 'annual';
  final _valCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _valCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = int.tryParse(_valCtrl.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(leaveNotifierProvider.notifier).adjustLeaveBalance(
            employeeId: widget.employeeId,
            leaveType: _selectedType,
            newBalance: val,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const types = [
      ('annual', 'Annual Leave'),
      ('sick', 'Sick Leave'),
      ('maternity', 'Maternity Leave'),
      ('paternity', 'Paternity Leave'),
    ];
    return AlertDialog(
      title: const Text('Adjust Leave Balance'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: const InputDecoration(labelText: 'Leave Type'),
          items: types
              .map((t) => DropdownMenuItem(
                  value: t.$1, child: Text(t.$2)))
              .toList(),
          onChanged: (v) =>
              setState(() => _selectedType = v ?? 'annual'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _valCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'New Balance (days)'),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Payroll profile tab
// ─────────────────────────────────────────────────────────────────────────────
class _PayrollProfileTab extends ConsumerWidget {
  const _PayrollProfileTab({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(employeePayslipsProvider(employee.id));

    return payslipsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (payslips) {
        if (payslips.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                    color: AppColors.pillBlueBg, shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    size: 30, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 14),
              Text('No payslips yet',
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Payslips will appear once payroll is run',
                  style: TextStyle(color: context.appSubtext, fontSize: 13)),
            ]),
          );
        }

        final latest = payslips.first;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Latest payslip summary ────────────────────────────────────
            _SectionLabel('Latest Payslip — ${_monthLabel(latest.payrollMonth)}'),
            const SizedBox(height: 12),
            _LatestPayslipCard(ps: latest, employee: employee),
            const SizedBox(height: 24),

            // ── Payment history list ──────────────────────────────────────
            Row(children: [
              _SectionLabel('Payment History'),
              const Spacer(),
              Text('${payslips.length} payslip${payslips.length == 1 ? '' : 's'}',
                  style: TextStyle(color: context.appSubtext, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appBorder)),
              child: Column(
                children: payslips.asMap().entries.map((e) {
                  final i = e.key;
                  final ps = e.value;
                  return _PayslipHistoryRow(
                    ps: ps,
                    employee: employee,
                    isLast: i == payslips.length - 1,
                  );
                }).toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  static String _monthLabel(String month) {
    try {
      return DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
    } catch (_) {
      return month;
    }
  }
}

class _LatestPayslipCard extends ConsumerWidget {
  const _LatestPayslipCard({required this.ps, required this.employee});
  final PayslipModel ps;
  final EmployeeModel employee;

  static final _fmt = NumberFormat('#,##0', 'en_US');
  static String _rwf(double v) => 'RWF ${_fmt.format(v.round())}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApproved = ps.status == 'approved';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: isApproved ? AppColors.pillGreenBg : AppColors.pillAmberBg,
                borderRadius: BorderRadius.circular(100)),
            child: Text(
              isApproved ? 'Approved' : 'Draft',
              style: TextStyle(
                  color: isApproved
                      ? AppColors.successGreen
                      : AppColors.warningAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _downloadPdf(context, ref),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
            label: const Text('Download PDF'),
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
                side: BorderSide(color: context.appBorder)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _LineItem(label: 'Total Earnings', value: _rwf(ps.totalEarnings), bold: false),
          _LineItem(label: 'PAYE Tax', value: _rwf(ps.paye), bold: false),
          _LineItem(label: 'RSSB', value: _rwf(ps.totalEmployeeRssb), bold: false),
          _LineItem(label: 'Loans', value: _rwf(ps.loanDeductions), bold: false),
        ]),
        Divider(height: 24, color: context.appBorder),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NET SALARY',
                style: TextStyle(
                    color: context.appSubtext,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(_rwf(ps.netSalary),
                style: const TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          if (ps.absentDays > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.pillRedBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${ps.absentDays} absent day${ps.absentDays == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AppColors.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ]),
    );
  }

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(companySettingsProvider).value;
    final companyName = settings?.companyName ?? 'Company';
    final doc =
        await PayslipPdfService.generatePayslip(ps, companyName);
    await Printing.layoutPdf(onLayout: (_) async => await doc.save());
  }
}

class _PayslipHistoryRow extends ConsumerWidget {
  const _PayslipHistoryRow(
      {required this.ps, required this.employee, required this.isLast});
  final PayslipModel ps;
  final EmployeeModel employee;
  final bool isLast;

  static final _fmt = NumberFormat('#,##0', 'en_US');
  static String _rwf(double v) => 'RWF ${_fmt.format(v.round())}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _monthLabel(ps.payrollMonth);
    final isApproved = ps.status == 'approved';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${ps.workingDays} working days · ${ps.presentDays} present',
                  style: TextStyle(
                      color: context.appSubtext, fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_rwf(ps.netSalary),
                style: const TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: isApproved
                      ? AppColors.pillGreenBg
                      : AppColors.pillAmberBg,
                  borderRadius: BorderRadius.circular(100)),
              child: Text(
                isApproved ? 'Approved' : 'Draft',
                style: TextStyle(
                    fontSize: 10,
                    color: isApproved
                        ? AppColors.successGreen
                        : AppColors.warningAmber,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _downloadPdf(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.picture_as_pdf_rounded,
                  size: 18, color: context.appSubtext),
            ),
          ),
        ]),
      ),
      if (!isLast) Divider(height: 1, color: context.appBorder),
    ]);
  }

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(companySettingsProvider).value;
    final companyName = settings?.companyName ?? 'Company';
    final doc = await PayslipPdfService.generatePayslip(ps, companyName);
    await Printing.layoutPdf(onLayout: (_) async => await doc.save());
  }

  static String _monthLabel(String month) {
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse('$month-01'));
    } catch (_) {
      return month;
    }
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem(
      {required this.label, required this.value, this.bold = false});
  final String label, value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: context.appSubtext,
                fontSize: 10,
                letterSpacing: 0.3)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: context.appText,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: context.appText,
          fontSize: 14,
          fontWeight: FontWeight.w700));
}


// ─────────────────────────────────────────────────────────────────────────────
//  Loans tab
// ─────────────────────────────────────────────────────────────────────────────
class _LoansTab extends ConsumerStatefulWidget {
  const _LoansTab({required this.employee});
  final EmployeeModel employee;
  @override
  ConsumerState<_LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends ConsumerState<_LoansTab> {
  void _showAddLoan() {
    showDialog(context: context, builder: (_) => _AddLoanDialog(employeeId: widget.employee.id));
  }

  @override
  Widget build(BuildContext context) {
    final loans = widget.employee.loans.cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(children: [
            Text('Loans & Deductions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.appText)),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              onPressed: _showAddLoan,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Loan'),
            ),
          ]),
        ),
        Expanded(
          child: loans.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_balance_outlined, size: 56, color: context.appSubtext),
                  const SizedBox(height: 12),
                  Text('No loans recorded', style: TextStyle(fontSize: 15, color: context.appSubtext)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: loans.length,
                  itemBuilder: (_, i) => _LoanCard(loan: loans[i]),
                ),
        ),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});
  final Map<String, dynamic> loan;

  @override
  Widget build(BuildContext context) {
    final description = loan['description'] as String? ?? 'Loan';
    final total = (loan['totalAmount'] as num?)?.toDouble() ?? 0;
    final paid = (loan['amountPaid'] as num?)?.toDouble() ?? 0;
    final monthly = (loan['monthlyDeduction'] as num?)?.toDouble() ?? 0;
    final remaining = (total - paid).clamp(0.0, total);
    final progress = total > 0 ? paid / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.appBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.pillBlueBg, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.primaryBlue)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(description, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.appText)),
            Text('RWF ${_fmt(monthly)}/month deduction', style: TextStyle(fontSize: 12, color: context.appSubtext)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('RWF ${_fmt(remaining)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.appText)),
            Text('remaining', style: TextStyle(fontSize: 11, color: context.appSubtext)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, backgroundColor: context.appBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.successGreen), minHeight: 6))),
          const SizedBox(width: 10),
          Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appSubtext)),
        ]),
        const SizedBox(height: 4),
        Text('Paid RWF ${_fmt(paid)} of RWF ${_fmt(total)}', style: TextStyle(fontSize: 11, color: context.appSubtext)),
      ]),
    );
  }

  static String _fmt(double v) {
    if (v == 0) return '0';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _AddLoanDialog extends ConsumerStatefulWidget {
  const _AddLoanDialog({required this.employeeId});
  final String employeeId;
  @override
  ConsumerState<_AddLoanDialog> createState() => _AddLoanDialogState();
}

class _AddLoanDialogState extends ConsumerState<_AddLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _descCtrl.dispose(); _totalCtrl.dispose(); _monthlyCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(employeesNotifierProvider.notifier).addLoan(widget.employeeId, {
        'description': _descCtrl.text.trim(),
        'totalAmount': double.tryParse(_totalCtrl.text.trim()) ?? 0,
        'monthlyDeduction': double.tryParse(_monthlyCtrl.text.trim()) ?? 0,
        'amountPaid': 0,
        'startDate': DateTime.now().toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.errorRed, content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Add Loan / Deduction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: context.appText)),
      content: SizedBox(
        width: 400,
        child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DlgField('Description', _descCtrl, hint: 'e.g. Salary advance, laptop loan…', required: true),
          const SizedBox(height: 12),
          _DlgField('Total Amount (RWF)', _totalCtrl, keyboard: TextInputType.number, required: true),
          const SizedBox(height: 12),
          _DlgField('Monthly Deduction (RWF)', _monthlyCtrl, keyboard: TextInputType.number, required: true),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Add Loan'),
        ),
      ],
    );
  }
}

class _DlgField extends StatelessWidget {
  const _DlgField(this.label, this.ctrl, {this.hint, this.keyboard, this.required = false});
  final String label; final TextEditingController ctrl; final String? hint;
  final TextInputType? keyboard; final bool required;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText)),
    const SizedBox(height: 5),
    TextFormField(controller: ctrl, keyboardType: keyboard, style: TextStyle(fontSize: 13, color: context.appText),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: context.appSubtext, fontSize: 13),
        filled: true, fillColor: context.appField,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.primaryBlue)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
  ]);
}
