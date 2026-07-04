import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/providers/leave_provider.dart';
import '../../settings/providers/settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
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
    final companyName = ref.watch(companySettingsProvider).value?.companyName ?? 'HRNova';
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
                fontWeight: FontWeight.w800,
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
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                companyName,
                style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: companyStatus == 'active' ? AppColors.pillGreenBg : AppColors.pillAmberBg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              Icon(Icons.circle,
                  color: companyStatus == 'active' ? AppColors.successGreen : AppColors.warningAmber,
                  size: 7),
              const SizedBox(width: 6),
              Text(
                companyStatus == 'active' ? 'Active' : companyStatus,
                style: TextStyle(
                  color: companyStatus == 'active' ? AppColors.successGreen : AppColors.warningAmber,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
      _KpiData('Total Employees', '$totalEmployees', Icons.people_rounded, AppColors.primaryBlue, AppColors.pillBlueBg, null),
      _KpiData('Present Today', '${present + late}', Icons.check_circle_rounded, AppColors.successGreen, AppColors.pillGreenBg, null),
      _KpiData('On Leave', '$onLeave', Icons.beach_access_rounded, AppColors.warningAmber, AppColors.pillAmberBg, null),
      _KpiData('Absent Today', '$absent', Icons.cancel_rounded, AppColors.errorRed, AppColors.pillRedBg, null),
      _KpiData('Late Arrivals', '$late', Icons.schedule_rounded, const Color(0xFF9B59B6), const Color(0xFFF0E8FF), null),
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
  const _KpiData(this.label, this.value, this.icon, this.color, this.bg, this.badge);
  final String label, value;
  final IconData icon;
  final Color color, bg;
  final String? badge;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: data.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              if (data.badge != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.pillGreenBg, borderRadius: BorderRadius.circular(100)),
                  child: Text(data.badge!, style: const TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(data.value, style: TextStyle(color: context.appText, fontSize: 30, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(data.label, style: TextStyle(color: context.appSubtext, fontSize: 14)),
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
      decoration: context.cardDeco(16),
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
                Expanded(flex: 3, child: Text('Employee', style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Clock In', style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
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
        ? AppColors.pillRedBg
        : isLate
            ? AppColors.pillAmberBg
            : isLeave
                ? AppColors.pillNavyBg
                : AppColors.pillGreenBg;
    final pillText = isAbsent
        ? AppColors.pillRedText
        : isLate
            ? AppColors.pillAmberText
            : isLeave
                ? AppColors.pillNavyText
                : AppColors.pillGreenText;

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
                  child: Center(child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
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
                child: Text(status, style: TextStyle(color: pillText, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActionsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        _ActionCard('Add Employee', Icons.person_add_rounded, AppColors.primaryBlue,
            onTap: () => context.push('/employees/new')),
        const SizedBox(height: 10),
        _ActionCard('Approve Leave Requests', Icons.event_available_rounded, AppColors.warningAmber,
            onTap: () => context.push('/leave')),
        const SizedBox(height: 10),
        _ActionCard('Process Payroll', Icons.payments_rounded, AppColors.successGreen,
            onTap: () => context.push('/payroll')),
        const SizedBox(height: 10),
        _ActionCard('Generate Report', Icons.bar_chart_rounded, const Color(0xFF9B59B6),
            onTap: () => context.push('/reports')),
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
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(height: 12),
              const Text('Nova AI Assistant', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Get insights on attendance patterns and workforce analytics.', style: TextStyle(color: Color(0xFF8899BB), fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => context.push('/nova-ai'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(100)),
                  child: const Text('Ask Nova', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.label, this.icon, this.color, {this.onTap});
  final String label;
  final IconData icon;
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
            color: context.appCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500))),
              Icon(Icons.arrow_forward_ios_rounded, color: context.appSubtext, size: 13),
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
      decoration: context.cardDeco(16),
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
            Text(name, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
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
