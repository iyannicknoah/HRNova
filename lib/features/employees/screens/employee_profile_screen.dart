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
import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';
import '../widgets/employee_form_panel.dart';

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _showEditPanel = false;

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
    final settingsAsync = ref.watch(companySettingsProvider);
    final departments = settingsAsync.value?.departments ?? const [];

    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
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
          return Stack(
            fit: StackFit.expand,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(
                    employee: employee,
                    onEdit: () => setState(() => _showEditPanel = true),
                  ),
                  _TabBar(controller: _tabs),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _ProfileTab(employee: employee),
                        _QRTab(employee: employee),
                        _PlaceholderTab(icon: Icons.access_time_rounded, label: 'Attendance', hint: 'Part 6 — Attendance & Verification'),
                        _PlaceholderTab(icon: Icons.beach_access_rounded, label: 'Leave', hint: 'Part 7 — Leave Management'),
                        _PlaceholderTab(icon: Icons.account_balance_wallet_rounded, label: 'Payroll', hint: 'Part 8 — Payroll & Payslips'),
                        _LoansTab(employee: employee),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showEditPanel) ...[
                GestureDetector(
                  onTap: () => setState(() => _showEditPanel = false),
                  child: Container(color: Colors.black.withAlpha(40)),
                ),
                Positioned(
                  top: 0, right: 0, bottom: 0,
                  width: 480,
                  child: EmployeeFormPanel(
                    key: ValueKey('edit_${employee.id}'),
                    initial: employee,
                    departments: departments,
                    onClose: () => setState(() => _showEditPanel = false),
                    onSaved: () => setState(() => _showEditPanel = false),
                  ),
                ),
              ],
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
      color: AppColors.backgroundBlue,
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 16),
          _LargeAvatar(name: employee.fullName, photoUrl: employee.profilePhotoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(employee.jobTitle.isEmpty ? employee.department : employee.jobTitle,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        indicatorColor: AppColors.primaryBlue,
        indicatorWeight: 2.5,
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
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: [
            _InfoCard('Personal Information', [
              _InfoRow('Full Name', employee.fullName),
              _InfoRow('National ID', employee.nationalId.isEmpty ? '—' : employee.nationalId),
              _InfoRow('Phone', employee.phone.isEmpty ? '—' : employee.phone),
              _InfoRow('Email', employee.email.isEmpty ? '—' : employee.email),
              _InfoRow('Date of Birth', EmployeeModel.fmtDate(employee.dateOfBirth)),
              _InfoRow('Emergency Contact', employee.emergencyContact.isEmpty ? '—' : employee.emergencyContact),
            ]),
            const SizedBox(height: 16),
            _InfoCard('Employment', [
              _InfoRow('Department', employee.department),
              _InfoRow('Job Title', employee.jobTitle.isEmpty ? '—' : employee.jobTitle),
              _InfoRow('Contract Type', _ctLabel(employee.contractType)),
              _InfoRow('Start Date', EmployeeModel.fmtDate(employee.startDate)),
              if (employee.endDate != null) _InfoRow('End Date', EmployeeModel.fmtDate(employee.endDate)),
              _InfoRow('RSSB Number', employee.rssbNumber.isEmpty ? '—' : employee.rssbNumber),
              _InfoRow('Role', _capitalize(employee.role)),
            ]),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [
            _InfoCard('Salary & Compensation', [
              _InfoRow('Salary Type', _stLabel(employee.salaryType)),
              if (employee.salaryType == 'fixed_monthly') _InfoRow('Monthly Salary', _fmtRwf(employee.salaryAmount)),
              if (employee.salaryType == 'daily_rate') _InfoRow('Daily Rate', _fmtRwf(employee.dailyRate)),
              if (employee.salaryType == 'hourly_rate') _InfoRow('Hourly Rate', _fmtRwf(employee.hourlyRate)),
              _InfoRow('Transport Allowance', _fmtRwf(employee.transportAllowance)),
              _InfoRow('Housing Allowance', _fmtRwf(employee.housingAllowance)),
              _InfoRow('Bank Account', employee.bankAccount.isEmpty ? '—' : employee.bankAccount),
            ]),
            const SizedBox(height: 16),
            _InfoCard('Leave Balances', [
              _InfoRow('Annual Leave', '${employee.leaveBalances['annual'] ?? 18} days'),
              _InfoRow('Sick Leave', '${employee.leaveBalances['sick'] ?? 10} days'),
              _InfoRow('Maternity Leave', '${employee.leaveBalances['maternity'] ?? 84} days'),
              _InfoRow('Paternity Leave', '${employee.leaveBalances['paternity'] ?? 4} days'),
            ]),
            if (employee.notes != null && employee.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoCard('Notes', [_InfoRow('', employee.notes!)]),
            ],
          ])),
        ],
      ),
    );
  }

  static String _ctLabel(String c) => switch (c) {
    'fixed_term' => 'Fixed Term', 'probation' => 'Probation', 'part_time' => 'Part Time', _ => 'Permanent',
  };
  static String _stLabel(String s) => switch (s) {
    'daily_rate' => 'Daily Rate', 'hourly_rate' => 'Hourly Rate', _ => 'Fixed Monthly',
  };
  static String _capitalize(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
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

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.title, this.rows);
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      const Divider(color: AppColors.cardBorder, height: 1),
      const SizedBox(height: 12),
      ...rows,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty) ...[
        SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
    ]),
  );
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
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Regenerate QR Code?', style: TextStyle(fontWeight: FontWeight.w700)),
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
//  Placeholder tabs
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.label, required this.hint});
  final IconData icon; final String label, hint;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(color: AppColors.pillBlueBg, shape: BoxShape.circle),
        child: Icon(icon, size: 34, color: AppColors.primaryBlue),
      ),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    ]),
  );
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
            const Text('Loans & Deductions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_balance_outlined, size: 56, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No loans recorded', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.pillBlueBg, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.primaryBlue)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('RWF ${_fmt(monthly)}/month deduction', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('RWF ${_fmt(remaining)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Text('remaining', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.successGreen), minHeight: 6))),
          const SizedBox(width: 10),
          Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 4),
        Text('Paid RWF ${_fmt(paid)} of RWF ${_fmt(total)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Add Loan / Deduction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    const SizedBox(height: 5),
    TextFormField(controller: ctrl, keyboardType: keyboard, style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true, fillColor: AppColors.lightBlue50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryBlue)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
  ]);
}
