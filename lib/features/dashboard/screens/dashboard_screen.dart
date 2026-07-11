import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/providers/leave_provider.dart';
import '../../leave/models/leave_request_model.dart';
import '../../performance/providers/performance_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../reports/providers/reports_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    if (role == AppConstants.roleManager) {
      return const _ManagerDashboard();
    }
    return Scaffold(
      backgroundColor: context.appBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.section, vertical: AppSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashHeader(),
            const SizedBox(height: 24),
            _KpiRow(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _AttendanceTable()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _QuickActionsPanel()),
              ],
            ),
            const SizedBox(height: 20),
            _DeptStats(),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _DashHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyName = ref.watch(companySettingsProvider).value?.companyName ?? 'HRNovva';
    final companyStatus = ref.watch(companyStatusProvider).value ?? 'active';
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                color: context.appText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              today,
              style: TextStyle(color: context.appSubtext, fontSize: 15),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              const AppIcon(AppIcons.businessRounded, color: AppColors.primaryBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                companyName,
                style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: companyStatus == 'active' ? context.pillGreenBg : context.pillAmberBg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: companyStatus == 'active' ? AppColors.successGreen : AppColors.warningAmber,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                companyStatus == 'active' ? 'Active' : companyStatus,
                style: TextStyle(
                  color: companyStatus == 'active' ? AppColors.successGreen : AppColors.warningAmber,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────
class _KpiRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _now = DateTime.now();
    final today = DateTime(_now.year, _now.month, _now.day);
    final employeesAsync = ref.watch(employeesProvider);
    final recordsAsync = ref.watch(attendanceByDateProvider(today));
    final onLeave = ref.watch(approvedLeavesTodayProvider).value ?? 0;

    final totalEmployees = employeesAsync.value?.where((e) => e.isActive).length ?? 0;
    final records = recordsAsync.value ?? [];
    final present = records.where((r) => r.checkInTime != null && !r.isLate && !r.isOnLeave).length;
    final late    = records.where((r) => r.isLate && r.checkInTime != null).length;
    final absent  = (totalEmployees - present - late - onLeave).clamp(0, totalEmployees);

    final kpis = [
      _KpiData('Total Employees', '$totalEmployees', null),
      _KpiData('Present Today', '${present + late}', null),
      _KpiData('On Leave', '$onLeave', null),
      _KpiData('Absent Today', '$absent', null),
      _KpiData('Late Arrivals', '$late', null),
    ];

    return Row(
      children: List.generate(kpis.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < kpis.length - 1 ? 14 : 0),
            child: _KpiCard(data: kpis[i]),
          ),
        );
      }),
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.badge);
  final String label, value;
  final String? badge;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(data.label, style: TextStyle(color: context.appSubtext, fontSize: 14)),
              if (data.badge != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: context.pillGreenBg, borderRadius: BorderRadius.circular(100)),
                  child: Text(data.badge!, style: const TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(data.value, style: TextStyle(color: context.appText, fontSize: 30, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Attendance table ──────────────────────────────────────────────────────────
class _AttendanceTable extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _now = DateTime.now();
    final today = DateTime(_now.year, _now.month, _now.day);
    final employeesAsync = ref.watch(employeesProvider);
    final recordsAsync = ref.watch(attendanceByDateProvider(today));

    final employees = employeesAsync.value ?? [];
    final records = recordsAsync.value ?? [];
    final recMap = {for (final r in records) r.employeeId: r};

    // Build display rows: employees who checked in today
    final rows = employees
        .where((e) => e.isActive && recMap.containsKey(e.id))
        .take(7)
        .map((e) {
          final r = recMap[e.id]!;
          final isLate = r.isLate;
          final isOut = r.checkOutTime != null;
          final status = r.isOnLeave ? 'On Leave' : isLate ? 'Late' : 'On Time';
          final timeStr = r.checkInTime != null
              ? '${r.checkInTime!.hour.toString().padLeft(2, '0')}:${r.checkInTime!.minute.toString().padLeft(2, '0')}'
              : '—';
          return (name: e.fullName, time: timeStr, status: status, checkedOut: isOut);
        })
        .toList();

    // Only block on employees — attendance shows empty state while its query runs
    final loading = employeesAsync.isLoading;

    return Container(
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Row(
              children: [
                Text("Today's Attendance", style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/attendance'),
                  child: const Text('View All', style: TextStyle(color: AppColors.primaryBlue, fontSize: 15)),
                ),
              ],
            ),
          ),
          Divider(color: context.appBorder, height: 1),
          Container(
            color: context.appTint,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Employee', style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Clock In', style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5))),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No attendance records yet for today',
                  style: TextStyle(color: context.appSubtext, fontSize: 15),
                ),
              ),
            )
          else
            ...rows.map((r) => _AttendanceRow(
                  name: r.name, time: r.time, status: r.status,
                )),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.name, required this.time, required this.status});
  final String name, time, status;

  @override
  Widget build(BuildContext context) {
    final isLate = status == 'Late';
    final isAbsent = status == 'Absent';
    final isLeave = status == 'On Leave';
    final pillBg = isAbsent
        ? context.pillRedBg
        : isLate
            ? context.pillAmberBg
            : isLeave
                ? context.pillNavyBg
                : context.pillGreenBg;
    final pillText = isAbsent
        ? context.pillRedText
        : isLate
            ? context.pillAmberText
            : isLeave
                ? context.pillNavyText
                : context.pillGreenText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.appBorder))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.gradientForName(name), begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w400), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(time, style: TextStyle(color: context.appSubtext, fontSize: 15))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(100)),
                child: Text(status, style: TextStyle(color: pillText, fontSize: 14, fontWeight: FontWeight.w400)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActionsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesProvider).value?.where((e) => e.isActive).toList() ?? [];
    final settings = ref.watch(companySettingsProvider).value;
    final annualEntitlement = settings?.annualLeaveDays ?? AppConstants.annualLeaveDaysPerYear;
    final anomalyDocs = ref.watch(reportsStreamProvider('anomaly_alert')).valueOrNull ?? [];

    // Count burnout risk employees
    final burnoutCount = employees.where((emp) {
      final months = DateTime.now().difference(emp.startDate).inDays ~/ 30;
      final balance = (emp.leaveBalances['annual'] as num?)?.toInt() ?? annualEntitlement;
      return months >= 5 && balance >= annualEntitlement;
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        _ActionCard('Add Employee', AppIcons.personAddRounded, AppColors.primaryBlue,
            onTap: () => context.push('/employees/new')),
        const SizedBox(height: 10),
        _ActionCard('Approve Leave Requests', AppIcons.eventAvailableRounded, AppColors.warningAmber,
            onTap: () => context.push('/leave')),
        const SizedBox(height: 10),
        _ActionCard('Process Payroll', AppIcons.paymentsRounded, AppColors.successGreen,
            onTap: () => context.push('/payroll')),
        const SizedBox(height: 10),
        _ActionCard('Generate Report', AppIcons.barChartRounded, const Color(0xFF9B59B6),
            onTap: () => context.push('/reports')),
        // ── Burnout risk card ──────────────────────────────────────────────────
        if (burnoutCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warningAmber.withAlpha(60)),
            ),
            child: Row(children: [
              const AppIcon(AppIcons.warningAmberRounded, color: AppColors.warningAmber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$burnoutCount employee${burnoutCount == 1 ? '' : 's'} at burnout risk — no leave taken in 5+ months',
                  style: const TextStyle(color: AppColors.warningAmber, fontSize: 14, height: 1.3),
                ),
              ),
            ]),
          ),
        ],
        // ── Latest anomaly alert ──────────────────────────────────────────────
        if (anomalyDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: AppColors.warningAmber, width: 3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const AppIcon(AppIcons.autoAwesomeRounded, color: AppColors.warningAmber, size: 15),
                const SizedBox(width: 6),
                const Text('AI Anomaly Alert', style: TextStyle(color: AppColors.warningAmber, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 6),
              Text(
                (anomalyDocs.first['summary'] as String?) ??
                    (anomalyDocs.first['report'] as String? ?? '').split('\n').take(3).join(' '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.appSubtext, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => context.push('/reports'),
                child: Text('View full report →',
                    style: const TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF0A1628)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: const AppIcon(AppIcons.autoAwesomeRounded, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(height: 12),
              const Text('Nova AI Assistant', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text('Get insights on attendance patterns and workforce analytics.', style: TextStyle(color: Color(0xFF8899BB), fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => context.push('/nova-ai'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(100)),
                  child: const Text('Ask Nova', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.label, this.icon, this.color, {this.onTap});
  final String label;
  final IconRef icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: AppIcon(icon, color: context.appText, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w500))),
              AppIcon(AppIcons.arrowForwardIosRounded, color: context.appText, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Department stats ─────────────────────────────────────────────────────────
class _DeptStats extends ConsumerWidget {
  static const _deptColors = [
    AppColors.primaryBlue,
    AppColors.successGreen,
    AppColors.warningAmber,
    Color(0xFF9B59B6),
    AppColors.errorRed,
    Color(0xFF00897B),
    Color(0xFF546E7A),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.value?.where((e) => e.isActive).toList() ?? [];
    final total = employees.length;

    // Count by department
    final deptCounts = <String, int>{};
    for (final e in employees) {
      deptCounts[e.department] = (deptCounts[e.department] ?? 0) + 1;
    }
    final sorted = deptCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(7).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Employees by Department', style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          if (top.isEmpty)
            Text('No department data yet', style: TextStyle(color: context.appSubtext, fontSize: 15))
          else
            ...top.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DeptBar(
                    name: entry.value.key.isEmpty ? 'Unassigned' : entry.value.key,
                    count: entry.value.value,
                    color: _deptColors[entry.key % _deptColors.length],
                    total: total,
                  ),
                )),
        ],
      ),
    );
  }
}

class _DeptBar extends StatelessWidget {
  const _DeptBar({required this.name, required this.count, required this.color, required this.total});
  final String name;
  final int count, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w400)),
            const Spacer(),
            Text('$count employee${count == 1 ? '' : 's'}', style: TextStyle(color: context.appSubtext, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, constraints) {
          return Stack(
            children: [
              Container(
                height: 6, width: constraints.maxWidth,
                decoration: BoxDecoration(color: context.appTint, borderRadius: BorderRadius.circular(100)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                height: 6,
                width: constraints.maxWidth * pct,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MANAGER DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

class _ManagerDashboard extends ConsumerWidget {
  const _ManagerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.section, vertical: AppSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ManagerHeader(),
            const SizedBox(height: 24),
            _ManagerKpiRow(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _AttendanceTable()),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _ManagerPendingLeavePanel(),
                      const SizedBox(height: 20),
                      _ManagerPerformanceCard(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyName = ref.watch(companySettingsProvider).value?.companyName ?? 'HRNovva';
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Team Dashboard',
              style: TextStyle(
                color: context.appText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(today, style: TextStyle(color: context.appSubtext, fontSize: 15)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(100)),
          child: Row(children: [
            const AppIcon(AppIcons.businessRounded, color: AppColors.primaryBlue, size: 16),
            const SizedBox(width: 6),
            Text(companyName, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    );
  }
}

class _ManagerKpiRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final employeesAsync = ref.watch(employeesProvider);
    final recordsAsync = ref.watch(attendanceByDateProvider(today));
    final onLeave = ref.watch(approvedLeavesTodayProvider).value ?? 0;

    final totalActive = employeesAsync.value?.where((e) => e.isActive).length ?? 0;
    final records = recordsAsync.value ?? [];
    final present = records.where((r) => r.checkInTime != null && !r.isLate && !r.isOnLeave).length;
    final late    = records.where((r) => r.isLate && r.checkInTime != null).length;
    final absent  = (totalActive - present - late - onLeave).clamp(0, totalActive);

    final kpis = [
      _KpiData('Present', '${present + late}', null),
      _KpiData('Late', '$late', null),
      _KpiData('Absent', '$absent', null),
      _KpiData('On Leave', '$onLeave', null),
    ];

    return Row(
      children: List.generate(kpis.length, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i < kpis.length - 1 ? 14 : 0),
          child: _KpiCard(data: kpis[i]),
        ),
      )),
    );
  }
}

// ── Manager pending leave panel ───────────────────────────────────────────────

class _ManagerPendingLeavePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeaveRequestsProvider);
    final pending = pendingAsync.value ?? [];

    return Container(
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Text('Pending Leave', style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              if (pending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warningAmber.withAlpha(30), borderRadius: BorderRadius.circular(100)),
                  child: Text('${pending.length}', style: const TextStyle(color: AppColors.warningAmber, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/leave'),
                child: const Text('View All', style: TextStyle(color: AppColors.primaryBlue, fontSize: 14)),
              ),
            ]),
          ),
          Divider(color: context.appBorder, height: 1),
          if (pendingAsync.isLoading)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No pending requests', style: TextStyle(color: context.appSubtext, fontSize: 14))),
            )
          else
            ...pending.take(5).map((req) => _PendingLeaveRow(req: req)),
        ],
      ),
    );
  }
}

class _PendingLeaveRow extends ConsumerStatefulWidget {
  const _PendingLeaveRow({required this.req});
  final LeaveRequestModel req;

  @override
  ConsumerState<_PendingLeaveRow> createState() => _PendingLeaveRowState();
}

class _PendingLeaveRowState extends ConsumerState<_PendingLeaveRow> {
  bool _loading = false;

  String _fmt(DateTime d) => DateFormat('MMM d').format(d);

  Future<void> _approve() async {
    setState(() => _loading = true);
    final err = await ref.read(leaveNotifierProvider.notifier).approveLeaveGuarded(widget.req);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _reject() async {
    final reason = await AppDialogShell.show<String>(
      context: context,
      alignment: Alignment.center,
      child: _RejectReasonDialog(employeeName: widget.req.employeeName),
    );
    if (reason == null || !mounted) return;
    setState(() => _loading = true);
    final err = await ref.read(leaveNotifierProvider.notifier).rejectLeaveGuarded(widget.req, reason);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.appBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.gradientForName(req.employeeName), begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(req.employeeName.isNotEmpty ? req.employeeName[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.employeeName, style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  Text(
                    '${req.leaveType.replaceAll('_', ' ')} · ${_fmt(req.startDate)} – ${_fmt(req.endDate)} (${req.totalDays}d)',
                    style: TextStyle(color: context.appSubtext, fontSize: 12),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox(height: 28, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _approve,
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(color: AppColors.successGreen.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.successGreen.withAlpha(60))),
                    child: const Center(child: Text('Approve', style: TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w500))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _reject,
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(color: AppColors.errorRed.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.errorRed.withAlpha(60))),
                    child: const Center(child: Text('Reject', style: TextStyle(color: AppColors.errorRed, fontSize: 13, fontWeight: FontWeight.w500))),
                  ),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.employeeName});
  final String employeeName;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reject ${widget.employeeName}\'s Leave',
            style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: context.appText),
            decoration: InputDecoration(
              hintText: 'Reason for rejection',
              hintStyle: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w300),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.appBorder)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
              filled: true, fillColor: Colors.transparent,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              HRNovaButton.text(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
                textColor: context.appSubtext,
              ),
              HRNovaButton.text(
                label: 'Reject',
                onPressed: () {
                  final r = _ctrl.text.trim();
                  if (r.isEmpty) return;
                  Navigator.pop(context, r);
                },
                textColor: AppColors.errorRed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Manager performance card ──────────────────────────────────────────────────

class _ManagerPerformanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final perfAsync = ref.watch(performanceByMonthProvider(month));
    final employeesAsync = ref.watch(employeesProvider);

    final scores = perfAsync.value ?? [];
    final employees = employeesAsync.value?.where((e) => e.isActive).toList() ?? [];
    final total = employees.length;
    final scored = scores.length;
    final avgScore = scored > 0
        ? scores.map((s) => s.overallScore).reduce((a, b) => a + b) / scored
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF9B59B6).withAlpha(25), borderRadius: BorderRadius.circular(10)),
              child: const AppIcon(AppIcons.trendingUpRounded, color: Color(0xFF9B59B6), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance', style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(DateFormat('MMMM yyyy').format(now), style: TextStyle(color: context.appSubtext, fontSize: 13)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avgScore > 0 ? avgScore.toStringAsFixed(1) : '—',
                    style: TextStyle(color: context.appText, fontSize: 32, fontWeight: FontWeight.w600),
                  ),
                  Text('Avg Score / 5.0', style: TextStyle(color: context.appSubtext, fontSize: 13)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$scored / $total', style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w500)),
                  Text('Employees scored', style: TextStyle(color: context.appSubtext, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          LayoutBuilder(builder: (ctx, c) {
            final pct = total > 0 ? scored / total : 0.0;
            return Stack(children: [
              Container(height: 6, width: c.maxWidth, decoration: BoxDecoration(color: context.appTint, borderRadius: BorderRadius.circular(100))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                height: 6,
                width: c.maxWidth * pct,
                decoration: BoxDecoration(color: const Color(0xFF9B59B6), borderRadius: BorderRadius.circular(100)),
              ),
            ]);
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/performance'),
              icon: const AppIcon(AppIcons.starRounded, size: 18),
              label: const Text('Score Employees'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
