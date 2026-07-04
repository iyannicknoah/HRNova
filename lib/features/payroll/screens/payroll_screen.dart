import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/payroll_model.dart';
import '../providers/payroll_provider.dart';
import '../services/payslip_pdf_service.dart';
import '../../../core/utils/download_helper.dart';

final _numFmt = NumberFormat('#,##0', 'en_US');
String _rwf(double v) => 'RWF ${_numFmt.format(v.round())}';
String _rwfShort(double v) {
  if (v >= 1000000) return 'RWF ${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return 'RWF ${(v / 1000).toStringAsFixed(0)}K';
  return _rwf(v);
}

String _monthLabel(String m) {
  try { return DateFormat('MMMM yyyy').format(DateTime.parse('$m-01')); }
  catch (_) { return m; }
}

final _selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

// ─────────────────────────────────────────────────────────────────────────────
class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});
  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  bool _approving = false;
  bool _sending   = false;
  int  _sendProgress = 0;
  int  _sendTotal    = 0;

  @override
  Widget build(BuildContext context) {
    final month       = ref.watch(_selectedMonthProvider);
    final runAsync    = ref.watch(payrollRunByMonthProvider(month));
    final payslipsAsync = ref.watch(payslipsByMonthProvider(month));
    final calcState   = ref.watch(payrollNotifierProvider);
    final settings    = ref.watch(companySettingsProvider).value;

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(children: [
        // ── Fixed top bar ──────────────────────────────────────────────────
        _TopBar(month: month, calcState: calcState, runAsync: runAsync),

        // ── Month selector ─────────────────────────────────────────────────
        _MonthStrip(month: month),

        // ── Scrollable content ─────────────────────────────────────────────
        Expanded(
          child: calcState.isRunning
              ? _CalcProgress(state: calcState)
              : runAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error:   (e, _) => Center(child: Text('$e')),
                  data: (run) {
                    if (run == null && calcState.payslips.isEmpty) {
                      return _PreRunLayout(month: month);
                    }
                    if (run == null && calcState.payslips.isNotEmpty) {
                      return _ResultLayout(
                        month:       month,
                        payslips:    calcState.payslips,
                        run:         null,
                        payslipsAsync: const AsyncData([]),
                        approving:   _approving,
                        onApprove:   () => _approve(month),
                        onSend:      null,
                        sending:     _sending,
                        sendProgress: _sendProgress,
                        sendTotal:   _sendTotal,
                        onExportRra: () => _export(month, 'rra-paye'),
                        onExportRssb: () => _export(month, 'rssb'),
                        settings:    settings,
                      );
                    }
                    return _ResultLayout(
                      month:        month,
                      payslips:     payslipsAsync.value ?? [],
                      run:          run,
                      payslipsAsync: payslipsAsync,
                      approving:    _approving,
                      onApprove:    run?.status == 'draft' ? () => _approve(month) : null,
                      onSend:       run?.status == 'approved' ? _sendPayslips : null,
                      sending:      _sending,
                      sendProgress: _sendProgress,
                      sendTotal:    _sendTotal,
                      onExportRra:  () => _export(month, 'rra-paye'),
                      onExportRssb: () => _export(month, 'rssb'),
                      settings:     settings,
                    );
                  },
                ),
        ),
      ]),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approve(String month) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Approve & Lock Payroll?',
        body: 'This locks the ${_monthLabel(month)} payroll permanently. '
              'Loan balances will be updated. This cannot be undone.',
        confirmLabel: 'Approve',
        confirmColor: AppColors.successGreen,
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _approving = true);
    try {
      if (ref.read(payrollNotifierProvider).payslips.isNotEmpty &&
          ref.read(payrollRunByMonthProvider(month)).value == null) {
        await ref.read(payrollNotifierProvider.notifier).savePayroll(month);
      }
      await ref.read(payrollNotifierProvider.notifier).approvePayroll(month);
      if (mounted) _snack('Payroll approved and locked ✓', AppColors.successGreen);
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _sendPayslips() async {
    final month    = ref.read(_selectedMonthProvider);
    final payslips = ref.read(payslipsByMonthProvider(month)).value ?? [];
    final settings = ref.read(companySettingsProvider).value;
    final pending  = payslips.where((p) => !p.emailSent).toList();
    if (pending.isEmpty) return;

    setState(() { _sending = true; _sendProgress = 0; _sendTotal = pending.length; });
    int sent = 0;
    for (final ps in pending) {
      try {
        final doc    = await PayslipPdfService.generatePayslip(ps, settings?.companyName ?? 'Company');
        final bytes  = await doc.save();
        final b64    = base64Encode(bytes);
        await ApiService().post('/api/exports/send-payslip', data: {
          'employeeId':   ps.employeeId,
          'payrollMonth': month,
          'pdfBase64':    b64,
        });
        sent++;
      } catch (_) {}
      if (mounted) setState(() => _sendProgress = sent);
    }
    if (mounted) {
      setState(() => _sending = false);
      _snack('Sent $sent of ${pending.length} payslips', AppColors.successGreen);
    }
  }

  Future<void> _export(String month, String type) async {
    final companyId = ref.read(currentCompanyIdProvider);
    if (companyId == null) return;
    try {
      final bytes = await ApiService().getBytes('/api/exports/$type/$companyId/$month');
      final label = type == 'rra-paye' ? 'RRA_PAYE' : 'RSSB';
      downloadBytes(bytes, 'HRNova_${label}_$month.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (mounted) _snack('Export failed: $e', AppColors.errorRed);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.month, required this.calcState, required this.runAsync});
  final String month;
  final PayrollState calcState;
  final AsyncValue<PayrollRunModel?> runAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = runAsync.value;
    final isApproved = run?.status == 'approved';
    final isDraft    = run?.status == 'draft';

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 24, 16),
      decoration: BoxDecoration(
        color: context.appCard,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Title
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payroll',
              style: TextStyle(color: context.appText, fontSize: 20,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text('Rwanda 2025 · PAYE + RSSB',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),

        const SizedBox(width: 16),

        // Month badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: context.appTint,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: context.appBorder)),
          child: Text(_monthLabel(month),
              style: TextStyle(color: context.appText, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),

        const SizedBox(width: 10),

        // Status pill
        if (isApproved)
          _pill('Approved', AppColors.successGreen, AppColors.pillGreenBg, Icons.lock_rounded)
        else if (isDraft)
          _pill('Draft', AppColors.warningAmber, AppColors.pillAmberBg, Icons.edit_outlined)
        else if (calcState.payslips.isNotEmpty)
          _pill('Calculated', AppColors.primaryBlue, AppColors.pillBlueBg, Icons.check_circle_outline),

        const Spacer(),

        // Run button in header when nothing calculated yet
        if (!calcState.isRunning && run == null && calcState.payslips.isEmpty)
          FilledButton.icon(
            onPressed: () => ref.read(payrollNotifierProvider.notifier).runPayroll(month),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('Run ${_monthLabel(month)}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
      ]),
    );
  }

  static Widget _pill(String label, Color fg, Color bg, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: fg),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTH STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _MonthStrip extends ConsumerWidget {
  const _MonthStrip({required this.month});
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = List.generate(12, (i) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: months.map((m) {
            final sel = m == month;
            final label = DateFormat('MMM yy').format(DateTime.parse('$m-01'));
            return GestureDetector(
              onTap: () {
                ref.read(_selectedMonthProvider.notifier).state = m;
                ref.read(payrollNotifierProvider.notifier).reset();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: sel ? AppColors.primaryBlue : context.appBorder),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: sel ? Colors.white : context.appSubtext,
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRE-RUN LAYOUT  (nothing calculated yet)
// ─────────────────────────────────────────────────────────────────────────────
class _PreRunLayout extends ConsumerWidget {
  const _PreRunLayout({required this.month});
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _monthLabel(month);
    final empCount = ref.watch(Provider.autoDispose(
        (r) => r.watch(employeesProvider).value?.where((e) => e.isActive).length ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Top: hero section ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue.withAlpha(18),
                AppColors.primaryBlue.withAlpha(4),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            // Text
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Company Payroll — $label',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text(
                  empCount > 0
                      ? 'Will process salaries for $empCount active employees at once'
                      : 'Processes all active employees in one run',
                  style: TextStyle(color: context.appSubtext, fontSize: 15),
                ),
              ]),
            ),
            const SizedBox(width: 24),
            // CTA
            FilledButton.icon(
              onPressed: () => ref.read(payrollNotifierProvider.notifier).runPayroll(month),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text('Run $label'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Middle: what gets calculated + rates side by side ───────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Left: what is calculated
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.calculate_rounded,
                      color: AppColors.primaryBlue, size: 16),
                  const SizedBox(width: 8),
                  Text('What gets calculated for each employee',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 16),
                ...[
                  (Icons.attach_money_rounded,     AppColors.successGreen,         'Base Salary',       'Monthly, daily or hourly rate'),
                  (Icons.account_balance_rounded,  AppColors.primaryBlue,           'PAYE Tax',          'Rwanda 2025 progressive brackets'),
                  (Icons.health_and_safety_rounded, const Color(0xFF9B59B6),        'RSSB (Employee)',   'Pension 6% + Maternity 0.3%'),
                  (Icons.business_rounded,         AppColors.warningAmber,          'RSSB (Employer)',   'Pension 6% + Maternity 0.3% + Occ. Hazard 2%'),
                  (Icons.timer_off_rounded,        AppColors.errorRed,              'Deductions',        'Absent days & late arrivals'),
                  (Icons.credit_card_rounded,      const Color(0xFF6C757D),         'Loan Repayments',   'Active loans deducted from net'),
                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: e.$2.withAlpha(18),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(e.$1, size: 16, color: e.$2),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.$3,
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text(e.$4,
                          style: TextStyle(
                              color: context.appSubtext, fontSize: 15)),
                    ]),
                  ]),
                )),
              ]),
            ),
          ),

          const SizedBox(width: 16),

          // Right: tax rates + deadline
          Expanded(
            flex: 3,
            child: Column(children: [

              // PAYE rates
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: context.appCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.gavel_rounded,
                        color: AppColors.primaryBlue, size: 15),
                    const SizedBox(width: 8),
                    Text('Rwanda 2025 Tax Rates',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 14),

                  // PAYE brackets
                  _RateSection('PAYE (Income Tax)', [
                    ('0 – 60,000 RWF', '0%', AppColors.successGreen),
                    ('60,001 – 100,000 RWF', '20%', AppColors.warningAmber),
                    ('100,001 – 200,000 RWF', '30%', AppColors.errorRed),
                    ('> 200,000 RWF', '30%', AppColors.errorRed),
                  ], context),

                  const SizedBox(height: 12),
                  Divider(height: 1, color: context.appBorder),
                  const SizedBox(height: 12),

                  // RSSB rates
                  _RateSection('RSSB Contributions', [
                    ('Employee Pension', '6%', AppColors.primaryBlue),
                    ('Employee Maternity', '0.3%', AppColors.primaryBlue),
                    ('Employer Pension', '6%', const Color(0xFF9B59B6)),
                    ('Employer Maternity', '0.3%', const Color(0xFF9B59B6)),
                    ('Employer Occ. Hazard', '2%', const Color(0xFF9B59B6)),
                  ], context),
                ]),
              ),

              const SizedBox(height: 12),

              // Deadline notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.pillAmberBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warningAmber.withAlpha(80)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.warningAmber, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Filing Deadline',
                          style: TextStyle(
                              color: AppColors.warningAmber,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text(
                        'RSSB & PAYE are due to RRA by the 15th of the following month.',
                        style: TextStyle(
                            color: AppColors.warningAmber,
                            fontSize: 15,
                            height: 1.5)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// Helper for rate section inside the rates card
Widget _RateSection(String title, List<(String, String, Color)> rates, BuildContext context) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title,
        style: TextStyle(
            color: context.appSubtext,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3)),
    const SizedBox(height: 10),
    ...rates.map((r) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Text(r.$1,
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: r.$3.withAlpha(18),
              borderRadius: BorderRadius.circular(6)),
          child: Text(r.$2,
              style: TextStyle(
                  color: r.$3,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    )),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// CALCULATING PROGRESS
// ─────────────────────────────────────────────────────────────────────────────
class _CalcProgress extends StatelessWidget {
  const _CalcProgress({required this.state});
  final PayrollState state;

  @override
  Widget build(BuildContext context) {
    final pct = state.total > 0 ? state.progress / state.total : 0.0;
    final isSaving = state.step == PayrollStep.saving;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appBorder)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Animated icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: AppColors.pillBlueBg,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.calculate_rounded,
                  color: AppColors.primaryBlue, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              isSaving ? 'Saving to database…' : 'Calculating payroll…',
              style: TextStyle(color: context.appText, fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isSaving
                  ? 'Writing payslips to Firestore'
                  : state.currentName.isNotEmpty
                      ? 'Processing: ${state.currentName}'
                      : 'Loading employee data…',
              style: TextStyle(color: context.appSubtext, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: context.appTint,
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryBlue),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Employee ${state.progress} of ${state.total}',
                  style: TextStyle(color: context.appSubtext, fontSize: 14)),
              Text('${(pct * 100).round()}%',
                  style: const TextStyle(color: AppColors.primaryBlue,
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT LAYOUT  (after calculation or from Firestore)
// ─────────────────────────────────────────────────────────────────────────────
class _ResultLayout extends ConsumerWidget {
  const _ResultLayout({
    required this.month,
    required this.payslips,
    required this.run,
    required this.payslipsAsync,
    required this.approving,
    required this.onApprove,
    required this.onSend,
    required this.sending,
    required this.sendProgress,
    required this.sendTotal,
    required this.onExportRra,
    required this.onExportRssb,
    required this.settings,
  });

  final String month;
  final List<PayslipModel> payslips;
  final PayrollRunModel? run;
  final AsyncValue<List<PayslipModel>> payslipsAsync;
  final bool approving;
  final VoidCallback? onApprove;
  final VoidCallback? onSend;
  final bool sending;
  final int sendProgress, sendTotal;
  final VoidCallback onExportRra, onExportRssb;
  final dynamic settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApproved = run?.status == 'approved';
    final list = run != null ? (payslipsAsync.value ?? []) : payslips;

    double tEarnings = 0, tGross = 0, tNet = 0, tPaye = 0, tRssb = 0;
    for (final p in list) {
      tEarnings += p.totalEarnings;
      tGross    += p.adjustedGross;
      tNet      += p.netSalary;
      tPaye     += p.paye;
      tRssb     += p.totalEmployeeRssb;
    }

    // Anomaly: employees with ≥5 absent days or zero net
    final anomalies = list.where((p) => p.absentDays >= 5 || p.netSalary == 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Action bar ──────────────────────────────────────────────────────
        Row(children: [
          Text('${list.length} employees · ${_monthLabel(month)}',
              style: TextStyle(color: context.appText, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),

          if (!isApproved) ...[
            // Save draft
            if (run == null)
              _OutBtn(
                icon: Icons.save_outlined,
                label: 'Save Draft',
                onTap: () => ref.read(payrollNotifierProvider.notifier).savePayroll(month),
              ),
            const SizedBox(width: 10),
            // Approve
            if (onApprove != null)
              _FillBtn(
                icon: approving
                    ? null
                    : Icons.lock_rounded,
                label: approving ? 'Approving…' : 'Approve & Lock',
                color: AppColors.successGreen,
                onTap: approving ? null : onApprove,
                loading: approving,
              ),
          ],

          if (isApproved) ...[
            // Send payslips
            if (sending)
              _SendingChip(progress: sendProgress, total: sendTotal)
            else
              _OutBtn(
                icon: Icons.mark_email_read_rounded,
                label: 'Send Payslips',
                onTap: onSend,
                color: AppColors.primaryBlue,
              ),
            const SizedBox(width: 8),
            _OutBtn(icon: Icons.download_rounded, label: 'RRA PAYE',
                onTap: onExportRra),
            const SizedBox(width: 8),
            _OutBtn(icon: Icons.download_rounded, label: 'RSSB',
                onTap: onExportRssb),
          ],
        ]),

        const SizedBox(height: 16),

        // ── Metric cards ────────────────────────────────────────────────────
        _MetricGrid(
          employees: list.length,
          totalEarnings: tEarnings,
          totalGross: tGross,
          totalNet: tNet,
          totalPaye: tPaye,
          totalRssb: tRssb,
        ),

        const SizedBox(height: 16),

        // ── Anomaly warnings ────────────────────────────────────────────────
        if (anomalies.isNotEmpty) ...[
          _AnomalyBanner(anomalies: anomalies),
          const SizedBox(height: 16),
        ],

        // ── Payslip table ───────────────────────────────────────────────────
        _PayslipTable(
          payslips: list,
          month: month,
          isLocked: isApproved,
          settings: settings,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC GRID
// ─────────────────────────────────────────────────────────────────────────────
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.employees,
    required this.totalEarnings,
    required this.totalGross,
    required this.totalNet,
    required this.totalPaye,
    required this.totalRssb,
  });

  final int employees;
  final double totalEarnings, totalGross, totalNet, totalPaye, totalRssb;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _M('Employees',       employees.toString(),  AppColors.primaryBlue,   AppColors.pillBlueBg,   Icons.people_rounded),
      _M('Total Earnings',  _rwfShort(totalEarnings),  AppColors.successGreen, AppColors.pillGreenBg, Icons.trending_up_rounded),
      _M('Adj. Gross',      _rwfShort(totalGross),     const Color(0xFF9B59B6), const Color(0xFFF3E8FF), Icons.calculate_rounded),
      _M('Total Net',       _rwfShort(totalNet),       AppColors.primaryBlue,   AppColors.pillBlueBg,   Icons.account_balance_wallet_rounded),
      _M('Total PAYE',      _rwfShort(totalPaye),      AppColors.warningAmber,  AppColors.pillAmberBg,  Icons.gavel_rounded),
      _M('Employee RSSB',   _rwfShort(totalRssb),      AppColors.errorRed,      AppColors.pillRedBg,    Icons.health_and_safety_rounded),
    ];

    return Row(
      children: cards.asMap().entries.map((e) {
        final i = e.key; final m = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < cards.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: m.bg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(m.icon, color: m.color, size: 16),
                ),
              ]),
              const SizedBox(height: 10),
              Text(m.value,
                  style: TextStyle(color: context.appText, fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(m.label,
                  style: TextStyle(color: context.appSubtext, fontSize: 12,
                      letterSpacing: 0.3)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _M {
  const _M(this.label, this.value, this.color, this.bg, this.icon);
  final String label, value;
  final Color color, bg;
  final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// ANOMALY BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _AnomalyBanner extends StatelessWidget {
  const _AnomalyBanner({required this.anomalies});
  final List<PayslipModel> anomalies;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.warningAmber.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warningAmber.withAlpha(80))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 16),
          const SizedBox(width: 8),
          Text('${anomalies.length} anomaly warning${anomalies.length > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.warningAmber,
                  fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        ...anomalies.map((p) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '• ${p.fullName}: ${p.absentDays} absent days'
            '${p.netSalary == 0 ? ' · net salary is RWF 0' : ''}',
            style: const TextStyle(color: AppColors.warningAmber, fontSize: 14),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYSLIP TABLE
// ─────────────────────────────────────────────────────────────────────────────
class _PayslipTable extends StatelessWidget {
  const _PayslipTable({
    required this.payslips,
    required this.month,
    required this.isLocked,
    required this.settings,
  });

  final List<PayslipModel> payslips;
  final String month;
  final bool isLocked;
  final dynamic settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: context.appTint,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            _hdr('Employee', flex: 3),
            _hdr('Department', flex: 2),
            _hdr('Earnings', flex: 2),
            _hdr('Adj. Gross', flex: 2),
            _hdr('PAYE', flex: 2),
            _hdr('RSSB', flex: 2),
            _hdr('Net Salary', flex: 2),
            _hdr('', flex: 1),
          ]),
        ),
        Divider(height: 1, color: context.appBorder),

        if (payslips.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('No payslips',
                style: TextStyle(color: context.appSubtext))),
          )
        else
          ...payslips.asMap().entries.map((e) {
            final isLast = e.key == payslips.length - 1;
            return _PayslipRow(
              ps: e.value,
              month: month,
              isLocked: isLocked,
              settings: settings,
              isLast: isLast,
            );
          }),
      ]),
    );
  }

  static Widget _hdr(String t, {required int flex}) => Expanded(
    flex: flex,
    child: Text(t, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 13,
        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _PayslipRow extends ConsumerStatefulWidget {
  const _PayslipRow({
    required this.ps,
    required this.month,
    required this.isLocked,
    required this.settings,
    required this.isLast,
  });

  final PayslipModel ps;
  final String month;
  final bool isLocked, isLast;
  final dynamic settings;

  @override
  ConsumerState<_PayslipRow> createState() => _PayslipRowState();
}

class _PayslipRowState extends ConsumerState<_PayslipRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.ps;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hover ? context.appTint : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            // Employee
            Expanded(flex: 3, child: Row(children: [
              _Avatar(name: p.fullName),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: TextStyle(color: context.appText,
                    fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(p.position, style: TextStyle(color: context.appSubtext, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ])),
            ])),
            // Dept
            Expanded(flex: 2, child: Text(p.department,
                style: TextStyle(color: context.appSubtext, fontSize: 14),
                overflow: TextOverflow.ellipsis)),
            // Earnings
            Expanded(flex: 2, child: Text(_rwf(p.totalEarnings),
                style: TextStyle(color: context.appText, fontSize: 14,
                    fontWeight: FontWeight.w500))),
            // Adj Gross
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_rwf(p.adjustedGross),
                  style: TextStyle(color: context.appText, fontSize: 14,
                      fontWeight: FontWeight.w500)),
              if (p.absentDays > 0)
                Text('-${p.absentDays}d',
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
            ])),
            // PAYE
            Expanded(flex: 2, child: Text(_rwf(p.paye),
                style: TextStyle(color: context.appSubtext, fontSize: 14))),
            // RSSB
            Expanded(flex: 2, child: Text(_rwf(p.totalEmployeeRssb),
                style: TextStyle(color: context.appSubtext, fontSize: 14))),
            // Net
            Expanded(flex: 2, child: Text(_rwf(p.netSalary),
                style: const TextStyle(color: AppColors.successGreen,
                    fontSize: 15, fontWeight: FontWeight.w800))),
            // Actions
            Expanded(flex: 1, child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!widget.isLocked)
                _TinyBtn(Icons.tune_rounded, 'Adjust', _showAdjust),
              _TinyBtn(Icons.picture_as_pdf_rounded, 'PDF', _downloadPdf),
            ])),
          ]),
        ),
        if (!widget.isLast) Divider(height: 1, color: context.appBorder),
      ]),
    );
  }

  Future<void> _downloadPdf() async {
    final name = widget.settings?.companyName ?? 'Company';
    final doc = await PayslipPdfService.generatePayslip(widget.ps, name);
    await Printing.layoutPdf(onLayout: (_) async => await doc.save());
  }

  Future<void> _showAdjust() async {
    final bonusCtrl    = TextEditingController(
        text: widget.ps.bonuses > 0 ? widget.ps.bonuses.toStringAsFixed(0) : '');
    final bonusDescCtrl = TextEditingController(text: widget.ps.bonusDescription ?? '');
    final deductCtrl   = TextEditingController(
        text: widget.ps.extraDeductions > 0 ? widget.ps.extraDeductions.toStringAsFixed(0) : '');
    final deductDescCtrl = TextEditingController(text: widget.ps.extraDeductionsDescription ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appCard,
        title: Text('Adjust — ${widget.ps.fullName}',
            style: TextStyle(color: ctx.appText, fontWeight: FontWeight.w700)),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _AdjField(ctrl: bonusCtrl, label: 'Bonus (RWF)', type: TextInputType.number),
          const SizedBox(height: 10),
          _AdjField(ctrl: bonusDescCtrl, label: 'Bonus reason'),
          const SizedBox(height: 16),
          _AdjField(ctrl: deductCtrl, label: 'Extra Deduction (RWF)', type: TextInputType.number),
          const SizedBox(height: 10),
          _AdjField(ctrl: deductDescCtrl, label: 'Deduction reason'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );

    if (ok == true && mounted) {
      await ref.read(payrollNotifierProvider.notifier).adjustPayslip(
        widget.month, widget.ps.employeeId,
        bonuses: double.tryParse(bonusCtrl.text) ?? 0,
        bonusDescription: bonusDescCtrl.text.trim().isEmpty ? null : bonusDescCtrl.text.trim(),
        extraDeductions: double.tryParse(deductCtrl.text) ?? 0,
        extraDeductionsDescription: deductDescCtrl.text.trim().isEmpty ? null : deductDescCtrl.text.trim(),
      );
    }
    bonusCtrl.dispose(); bonusDescCtrl.dispose();
    deductCtrl.dispose(); deductDescCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
    final colors = AppColors.gradientForName(name);
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Text(initials, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TinyBtn extends StatelessWidget {
  const _TinyBtn(this.icon, this.tooltip, this.onTap);
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: context.appSubtext)),
    ),
  );
}

class _OutBtn extends StatelessWidget {
  const _OutBtn({required this.icon, required this.label, this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: color ?? context.appText,
      side: BorderSide(color: color?.withAlpha(100) ?? context.appBorder),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}

class _FillBtn extends StatelessWidget {
  const _FillBtn({required this.label, required this.color,
    this.icon, this.onTap, this.loading = false});
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: loading
        ? const SizedBox(width: 15, height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 15),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class _SendingChip extends StatelessWidget {
  const _SendingChip({required this.progress, required this.total});
  final int progress, total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
        color: context.appTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder)),
    child: Row(children: [
      const SizedBox(width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
      const SizedBox(width: 8),
      Text('Sending $progress of $total…',
          style: TextStyle(color: context.appSubtext, fontSize: 15)),
    ]),
  );
}

class _AdjField extends StatelessWidget {
  const _AdjField({required this.ctrl, required this.label,
    this.type = TextInputType.text});
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: type,
    style: TextStyle(color: context.appText, fontSize: 15),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.appSubtext, fontSize: 15),
      filled: true, fillColor: context.appField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appBorder)),
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor});
  final String title, body, confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.appCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(title, style: TextStyle(color: context.appText,
        fontWeight: FontWeight.w700, fontSize: 17)),
    content: Text(body, style: TextStyle(color: context.appSubtext, height: 1.5)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel')),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(backgroundColor: confirmColor),
        child: Text(confirmLabel),
      ),
    ],
  );
}
