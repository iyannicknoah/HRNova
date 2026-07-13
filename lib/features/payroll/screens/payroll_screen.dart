import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_table.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/payroll_model.dart';
import '../providers/payroll_provider.dart';
import '../services/payslip_pdf_service.dart';
import '../../../core/utils/download_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/row_actions_menu.dart';

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

final _deptFilterProvider   = StateProvider<String?>((ref) => null);
final _branchFilterProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});
  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  bool _approving  = false;
  bool _sending    = false;
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
                        month:        month,
                        payslips:     calcState.payslips,
                        run:          null,
                        payslipsAsync: const AsyncData([]),
                        approving:    _approving,
                        onApprove:    () => _approve(month),
                        onSend:       null,
                        sending:      _sending,
                        sendProgress: _sendProgress,
                        sendTotal:    _sendTotal,
                        onExportRra:  () => _export(month, 'rra-paye'),
                        onExportRssb: () => _export(month, 'rssb'),
                        onExportPayroll: () => _export(month, 'payroll'),
                        onExportPayrollPdf: () => _exportPayrollPdf(
                            month, calcState.payslips, settings?.companyName ?? 'Company'),
                        settings:     settings,
                        onRecalculate: null,
                      );
                    }
                    return _ResultLayout(
                      month:         month,
                      payslips:      payslipsAsync.value ?? [],
                      run:           run,
                      payslipsAsync: payslipsAsync,
                      approving:     _approving,
                      onApprove:     run?.status == 'draft' ? () => _approve(month) : null,
                      onSend:        run?.status == 'approved' ? _sendPayslips : null,
                      sending:       _sending,
                      sendProgress:  _sendProgress,
                      sendTotal:     _sendTotal,
                      onExportRra:   () => _export(month, 'rra-paye'),
                      onExportRssb:  () => _export(month, 'rssb'),
                      onExportPayroll: () => _export(month, 'payroll'),
                      onExportPayrollPdf: () => _exportPayrollPdf(
                          month, payslipsAsync.value ?? [], settings?.companyName ?? 'Company'),
                      settings:      settings,
                      onRecalculate: run?.status == 'draft'
                          ? () => _deleteDraftAndRecalc(month)
                          : null,
                    );
                  },
                ),
        ),
      ]),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approve(String month) async {
    final ok = await AppDialogShell.show<bool>(
      context: context,
      alignment: Alignment.center,
      child: _ConfirmDialog(
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
    if (pending.isEmpty) {
      _snack('All payslips already sent', AppColors.primaryBlue);
      return;
    }

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
      final label = switch (type) {
        'rra-paye' => 'RRA_PAYE',
        'rssb' => 'RSSB',
        'payroll' => 'Payroll_Bank_Payment',
        _ => type,
      };
      downloadBytes(bytes, 'HRNovva_${label}_$month.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (mounted) _snack('Export failed: $e', AppColors.errorRed);
    }
  }

  Future<void> _exportPayrollPdf(String month, List<PayslipModel> payslips, String companyName) async {
    if (payslips.isEmpty) {
      _snack('No payroll data to export', AppColors.warningAmber);
      return;
    }
    try {
      final doc = await PayslipPdfService.generatePayrollBankSummary(payslips, companyName, month);
      final bytes = await doc.save();
      downloadBytes(bytes, 'HRNovva_Payroll_Bank_Payment_$month.pdf', 'application/pdf');
    } catch (e) {
      if (mounted) _snack('PDF export failed: $e', AppColors.errorRed);
    }
  }

  Future<void> _deleteDraftAndRecalc(String month) async {
    final ok = await AppDialogShell.show<bool>(
      context: context,
      alignment: Alignment.center,
      child: _ConfirmDialog(
        title: 'Delete Draft & Recalculate?',
        body: 'This deletes the saved ${_monthLabel(month)} draft and re-runs the calculation. '
              'Any manual bonus or deduction adjustments will be lost.',
        confirmLabel: 'Recalculate',
        confirmColor: AppColors.warningAmber,
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(payrollNotifierProvider.notifier).deleteDraft(month);
      if (mounted) {
        await ref.read(payrollNotifierProvider.notifier).runPayroll(month);
      }
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.errorRed);
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Title
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payroll',
              style: TextStyle(color: context.appText, fontSize: 20,
                  fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          Text('Rwanda 2025 · PAYE + RSSB',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),

        const SizedBox(width: 16),

        // Status pill
        if (isApproved)
          const StatusBadge(text: 'Approved', type: StatusType.success)
        else if (isDraft)
          const StatusBadge(text: 'Draft', type: StatusType.warning)
        else if (calcState.payslips.isNotEmpty)
          const StatusBadge(text: 'Calculated', type: StatusType.info),

        const Spacer(),
      ]),
    );
  }
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: months.map((m) {
                  final sel = m == month;
                  final label = DateFormat('MMM yy').format(DateTime.parse('$m-01'));
                  return GestureDetector(
                    onTap: () {
                      ref.read(_selectedMonthProvider.notifier).state = m;
                      ref.read(payrollNotifierProvider.notifier).reset();
                      ref.read(_deptFilterProvider.notifier).state   = null;
                      ref.read(_branchFilterProvider.notifier).state = null;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 6),
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
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Text
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Company Payroll — $label',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
            HRNovaButton(
              label: 'Run $label',
              icon: AppIcons.playArrowRounded,
              onPressed: () => ref.read(payrollNotifierProvider.notifier).runPayroll(month),
              isFullWidth: false,
              height: 52,
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
              decoration: context.cardDeco(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const AppIcon(AppIcons.calculateRounded,
                      color: AppColors.primaryBlue, size: 16),
                  const SizedBox(width: 8),
                  Text('What gets calculated for each employee',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                ...[
                  (AppIcons.attachMoneyRounded,     AppColors.successGreen,         'Base Salary',       'Monthly, daily or hourly rate'),
                  (AppIcons.accountBalanceRounded,  AppColors.primaryBlue,           'PAYE Tax',          'Rwanda 2025 progressive brackets'),
                  (AppIcons.healthAndSafetyRounded, const Color(0xFF9B59B6),        'RSSB (Employee)',   'Pension 6% + Maternity 0.3%'),
                  (AppIcons.businessRounded,         AppColors.warningAmber,          'RSSB (Employer)',   'Pension 6% + Maternity 0.3% + Occ. Hazard 2%'),
                  (AppIcons.timerOffRounded,        AppColors.errorRed,              'Deductions',        'Absent days & late arrivals'),
                  (AppIcons.creditCardRounded,      const Color(0xFF6C757D),         'Loan Repayments',   'Active loans deducted from net'),
                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: e.$2.withAlpha(18),
                          borderRadius: BorderRadius.circular(10)),
                      child: AppIcon(e.$1, size: 16, color: e.$2),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.$3,
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
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
                decoration: context.cardDeco(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const AppIcon(AppIcons.gavelRounded,
                        color: AppColors.primaryBlue, size: 15),
                    const SizedBox(width: 8),
                    Text('Rwanda 2025 Tax Rates',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
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
                  color: context.pillAmberBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warningAmber.withAlpha(80)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const AppIcon(AppIcons.calendarTodayRounded,
                      color: AppColors.warningAmber, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Filing Deadline',
                          style: TextStyle(
                              color: AppColors.warningAmber,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
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
            fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w600)),
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
          decoration: context.cardDeco(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Animated icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: context.pillBlueBg,
                  borderRadius: BorderRadius.circular(16)),
              child: const AppIcon(AppIcons.calculateRounded,
                  color: AppColors.primaryBlue, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              isSaving ? 'Saving to database…' : 'Calculating payroll…',
              style: TextStyle(color: context.appText, fontSize: 17,
                  fontWeight: FontWeight.w600),
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
                      fontSize: 14, fontWeight: FontWeight.w600)),
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
    required this.onExportPayroll,
    required this.onExportPayrollPdf,
    required this.settings,
    this.onRecalculate,
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
  final VoidCallback onExportRra, onExportRssb, onExportPayroll, onExportPayrollPdf;
  final dynamic settings;
  final VoidCallback? onRecalculate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApproved = run?.status == 'approved';
    final rawList = run != null ? (payslipsAsync.value ?? []) : payslips;
    final canExport = ref.watch(currentUserRoleProvider) != AppConstants.roleBranchHrAdmin;
    const noPermissionMsg = "You don't have permission to do this — only Group HR can send payslips or generate exports.";

    // ── Filter ────────────────────────────────────────────────────────────────
    final selectedDept     = ref.watch(_deptFilterProvider);
    final selectedBranchId = ref.watch(_branchFilterProvider);

    final list = rawList.where((p) {
      if (selectedDept != null && p.department != selectedDept) return false;
      if (selectedBranchId != null && p.branchId != selectedBranchId) return false;
      return true;
    }).toList();

    final depts     = rawList.map((p) => p.department).toSet().toList()..sort();
    final branchIds = rawList.map((p) => p.branchId).whereType<String>().toSet().toList();
    final branchNameById = <String, String>{
      for (final b in ref.watch(branchesStreamProvider).value ?? []) b.id: b.name,
    };

    final hasFilter = selectedDept != null || selectedBranchId != null;

    double tEarnings = 0, tGross = 0, tNet = 0, tPaye = 0, tRssb = 0;
    for (final p in list) {
      tEarnings += p.totalEarnings;
      tGross    += p.adjustedGross;
      tNet      += p.netSalary;
      tPaye     += p.paye;
      tRssb     += p.totalEmployeeRssb;
    }

    final anomalies = list.where((p) => p.absentDays >= 5 || p.netSalary == 0).toList();

    final countLabel = hasFilter
        ? '${list.length} of ${rawList.length} employees · ${_monthLabel(month)}'
        : '${list.length} employees · ${_monthLabel(month)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Action bar ──────────────────────────────────────────────────────
        Row(children: [
          Text(countLabel,
              style: TextStyle(color: context.appText, fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Spacer(),

          if (!isApproved) ...[
            if (onRecalculate != null) ...[
              _OutBtn(
                icon: AppIcons.refreshRounded,
                label: 'Recalculate',
                onTap: onRecalculate,
                color: AppColors.warningAmber,
              ),
              const SizedBox(width: 8),
            ],
            if (run == null)
              _OutBtn(
                icon: AppIcons.saveOutlined,
                label: 'Save Draft',
                onTap: () => ref.read(payrollNotifierProvider.notifier).savePayroll(month),
              ),
            const SizedBox(width: 10),
            if (onApprove != null)
              _FillBtn(
                icon: approving ? null : AppIcons.lockRounded,
                label: approving ? 'Approving…' : 'Approve & Lock',
                color: AppColors.successGreen,
                onTap: approving ? null : onApprove,
                loading: approving,
              ),
          ],

          if (isApproved) ...[
            if (sending)
              _SendingChip(progress: sendProgress, total: sendTotal)
            else
              _OutBtn(
                icon: AppIcons.markEmailReadRounded,
                label: 'Send Payslips',
                onTap: canExport ? onSend : null,
                color: AppColors.primaryBlue,
                tooltip: canExport ? null : noPermissionMsg,
              ),
            const SizedBox(width: 8),
            _OutBtn(icon: AppIcons.downloadRounded, label: 'RRA PAYE',
                onTap: canExport ? onExportRra : null,
                tooltip: canExport ? null : noPermissionMsg),
            const SizedBox(width: 8),
            _OutBtn(icon: AppIcons.downloadRounded, label: 'RSSB',
                onTap: canExport ? onExportRssb : null,
                tooltip: canExport ? null : noPermissionMsg),
            const SizedBox(width: 8),
            _OutBtn(icon: AppIcons.accountBalanceRounded, label: 'Bank Payment (Excel)',
                onTap: canExport ? onExportPayroll : null,
                color: AppColors.successGreen,
                tooltip: canExport ? null : noPermissionMsg),
            const SizedBox(width: 8),
            _OutBtn(icon: AppIcons.pictureAsPdfRounded, label: 'Bank Payment (PDF)',
                onTap: canExport ? onExportPayrollPdf : null,
                color: AppColors.successGreen,
                tooltip: canExport ? null : noPermissionMsg),
          ],
        ]),

        const SizedBox(height: 14),

        // ── Filter bar ──────────────────────────────────────────────────────
        if (depts.length >= 2 || branchIds.length >= 2)
          _FilterBar(
            depts: depts,
            branchIds: branchIds,
            branchNameById: branchNameById,
            selectedDept: selectedDept,
            selectedBranchId: selectedBranchId,
          ),

        const SizedBox(height: 2),

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
          _AnomalyButton(anomalies: anomalies),
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
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryBlue, Color(0xFF2979E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Total Net Payout', style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(_rwfShort(totalNet),
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1)),
                const SizedBox(height: 8),
                Text('$employees employee${employees == 1 ? '' : 's'} this run',
                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Row(children: [
                Expanded(child: MetricCard(label: 'Employees', value: employees.toString())),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(label: 'Total Earnings', value: _rwfShort(totalEarnings))),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(label: 'Adj. Gross', value: _rwfShort(totalGross))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: MetricCard(label: 'Total PAYE', value: _rwfShort(totalPaye))),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(label: 'Employee RSSB', value: _rwfShort(totalRssb))),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ]),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANOMALY BUTTON + DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _AnomalyButton extends StatelessWidget {
  const _AnomalyButton({required this.anomalies});
  final List<PayslipModel> anomalies;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => AppDialogShell.show(
        context: context,
        alignment: Alignment.center,
        maxWidth: 480,
        child: _AnomalyDialogContent(anomalies: anomalies),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.warningAmber.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warningAmber.withAlpha(80))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const AppIcon(AppIcons.warningAmberRounded, color: AppColors.warningAmber, size: 16),
          const SizedBox(width: 8),
          Text('${anomalies.length} anomaly warning${anomalies.length > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.warningAmber,
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 6),
          const AppIcon(AppIcons.chevronRightRounded, color: AppColors.warningAmber, size: 14),
        ]),
      ),
    );
  }
}

class _AnomalyDialogContent extends StatelessWidget {
  const _AnomalyDialogContent({required this.anomalies});
  final List<PayslipModel> anomalies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AppIcon(AppIcons.warningAmberRounded, color: AppColors.warningAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${anomalies.length} Anomaly Warning${anomalies.length > 1 ? 's' : ''}',
                style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: AppIcon(AppIcons.closeRounded, color: context.appSubtext),
          ),
        ]),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: anomalies.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '• ${p.fullName}: ${p.absentDays} absent days'
                  '${p.netSalary == 0 ? ' · net salary is RWF 0' : ''}',
                  style: TextStyle(color: context.appText, fontSize: 14, height: 1.4),
                ),
              )).toList(),
            ),
          ),
        ),
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
      decoration: context.cardDeco(),
      child: Column(children: [
        AppTableHeader(
          columns: const ['Employee', 'Department', 'Earnings', 'Adj. Gross', 'PAYE', 'RSSB', 'Net Salary', ''],
          flex: const [3, 2, 2, 2, 2, 2, 2, 1],
        ),

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(children: [
            // Employee
            Expanded(flex: 3, child: Row(children: [
              _Avatar(name: p.fullName),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: TextStyle(color: context.appText,
                    fontSize: 15, fontWeight: FontWeight.w500),
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
                    fontWeight: FontWeight.w400))),
            // Adj Gross
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_rwf(p.adjustedGross),
                  style: TextStyle(color: context.appText, fontSize: 14,
                      fontWeight: FontWeight.w400)),
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
                    fontSize: 15, fontWeight: FontWeight.w700))),
            // Actions
            Expanded(flex: 1, child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.isLocked)
                Tooltip(
                  message: widget.ps.emailSent ? 'Payslip emailed' : 'Not emailed yet',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AppIcon(
                      widget.ps.emailSent
                          ? AppIcons.markEmailReadRounded
                          : AppIcons.mailOutlineRounded,
                      size: 15,
                      color: widget.ps.emailSent
                          ? AppColors.successGreen
                          : context.appSubtext,
                    ),
                  ),
                ),
              RowActionsMenu(actions: [
                if (!widget.isLocked)
                  RowAction(label: 'Adjust', icon: AppIcons.tuneRounded, onTap: _showAdjust),
                RowAction(label: 'Download PDF', icon: AppIcons.pictureAsPdfRounded, onTap: _downloadPdf),
              ]),
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
            style: TextStyle(color: ctx.appText, fontWeight: FontWeight.w600)),
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
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _OutBtn extends StatelessWidget {
  const _OutBtn({required this.icon, required this.label, this.onTap, this.color, this.tooltip});
  final IconRef icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      onPressed: onTap,
      icon: AppIcon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? context.appText,
        side: BorderSide(color: color?.withAlpha(100) ?? context.appBorder),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _FillBtn extends StatelessWidget {
  const _FillBtn({required this.label, required this.color,
    this.icon, this.onTap, this.loading = false});
  final IconRef? icon;
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
        : AppIcon(icon!, size: 15),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
        borderRadius: BorderRadius.circular(8)),
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
  Widget build(BuildContext context) => HRNovaTextField(
    label: label,
    controller: ctrl,
    keyboardType: type,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR  (dept + branch)
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.depts,
    required this.branchIds,
    required this.branchNameById,
    required this.selectedDept,
    required this.selectedBranchId,
  });

  final List<String> depts;
  final List<String> branchIds;
  final Map<String, String> branchNameById;
  final String? selectedDept;
  final String? selectedBranchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFilter = selectedDept != null || selectedBranchId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const AppIcon(AppIcons.filterListRounded, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          if (depts.length >= 2) ...[
            _DropFilter(
              value: selectedDept ?? 'All Departments',
              items: ['All Departments', ...depts],
              onChanged: (v) => ref.read(_deptFilterProvider.notifier).state =
                  (v == 'All Departments') ? null : v,
            ),
            const SizedBox(width: 8),
          ],
          if (branchIds.length >= 2) ...[
            _DropFilter(
              value: selectedBranchId != null
                  ? (branchNameById[selectedBranchId] ?? selectedBranchId!)
                  : 'All Branches',
              items: [
                'All Branches',
                ...branchIds.map((id) => branchNameById[id] ?? id),
              ],
              onChanged: (name) {
                if (name == 'All Branches') {
                  ref.read(_branchFilterProvider.notifier).state = null;
                } else {
                  final id = branchNameById.entries
                      .firstWhere((e) => e.value == name,
                          orElse: () => MapEntry(name ?? '', name ?? ''))
                      .key;
                  ref.read(_branchFilterProvider.notifier).state = id;
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          if (hasFilter)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                ref.read(_deptFilterProvider.notifier).state   = null;
                ref.read(_branchFilterProvider.notifier).state = null;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.appTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppIcon(AppIcons.closeRounded, size: 13, color: context.appSubtext),
                  const SizedBox(width: 4),
                  Text('Clear', style: TextStyle(color: context.appSubtext, fontSize: 13)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _DropFilter extends StatelessWidget {
  const _DropFilter({required this.value, required this.items, required this.onChanged});

  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(color: context.appText, fontSize: 13),
          dropdownColor: context.appCard,
          icon: AppIcon(AppIcons.keyboardArrowDownRounded, size: 16, color: context.appSubtext),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor});
  final String title, body, confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: context.appText,
            fontWeight: FontWeight.w600, fontSize: 17)),
        const SizedBox(height: 12),
        Text(body, style: TextStyle(color: context.appSubtext, height: 1.5)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    ),
  );
}
