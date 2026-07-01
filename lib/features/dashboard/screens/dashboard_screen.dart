import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashHeader(),
            const SizedBox(height: 24),
            const _KpiRow(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(flex: 3, child: _AttendanceTable()),
                SizedBox(width: 20),
                Expanded(flex: 2, child: _QuickActionsPanel()),
              ],
            ),
            const SizedBox(height: 20),
            const _DeptStats(),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Dashboard',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Tuesday, 1 July 2026',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: const [
              Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 16),
              SizedBox(width: 6),
              Text(
                'Kigali Group Ltd',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.pillGreenBg,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: const [
              Icon(Icons.circle, color: AppColors.successGreen, size: 7),
              SizedBox(width: 6),
              Text(
                'Active',
                style: TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    const kpis = [
      _KpiData('Total Employees', '47', Icons.people_rounded, AppColors.primaryBlue, AppColors.pillBlueBg, null),
      _KpiData('Present Today', '41', Icons.check_circle_rounded, AppColors.successGreen, AppColors.pillGreenBg, '+2'),
      _KpiData('On Leave', '3', Icons.beach_access_rounded, AppColors.warningAmber, AppColors.pillAmberBg, null),
      _KpiData('Absent Today', '3', Icons.cancel_rounded, AppColors.errorRed, AppColors.pillRedBg, null),
      _KpiData('Late Arrivals', '2', Icons.schedule_rounded, Color(0xFF9B59B6), Color(0xFFF0E8FF), null),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: data.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              if (data.badge != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.pillGreenBg, borderRadius: BorderRadius.circular(100)),
                  child: Text(data.badge!, style: const TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(data.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Attendance table ──────────────────────────────────────────────────────────
class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable();

  static const _rows = [
    _AttRow('Jean-Paul Habimana', '07:58', 'On Time'),
    _AttRow('Alice Uwimana', '08:03', 'On Time'),
    _AttRow('Eric Nshimiyimana', '08:31', 'Late'),
    _AttRow('Grace Mukamana', '—', 'Absent'),
    _AttRow('Patrick Ndikumana', '08:00', 'On Time'),
    _AttRow('Sandra Igiraneza', '08:12', 'On Time'),
    _AttRow('David Uwizeye', '—', 'Absent'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Row(
              children: [
                const Text(
                  'Today\'s Attendance',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(color: AppColors.primaryBlue, fontSize: 13)),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.cardBorder, height: 1),
          Container(
            color: AppColors.backgroundBlue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Employee', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Clock In', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
              ],
            ),
          ),
          ..._rows.map((r) => _AttendanceRow(row: r)),
        ],
      ),
    );
  }
}

class _AttRow {
  const _AttRow(this.name, this.time, this.status);
  final String name, time, status;
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.row});
  final _AttRow row;

  @override
  Widget build(BuildContext context) {
    final isLate = row.status == 'Late';
    final isAbsent = row.status == 'Absent';
    final pillBg = isAbsent ? AppColors.pillRedBg : isLate ? AppColors.pillAmberBg : AppColors.pillGreenBg;
    final pillText = isAbsent ? AppColors.pillRedText : isLate ? AppColors.pillAmberText : AppColors.pillGreenText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.gradientForName(row.name),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      row.name[0],
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(row.time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(100)),
                child: Text(row.status, style: TextStyle(color: pillText, fontSize: 12, fontWeight: FontWeight.w500)),
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
  const _QuickActionsPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        const _ActionCard('Add Employee', Icons.person_add_rounded, AppColors.primaryBlue),
        const SizedBox(height: 10),
        const _ActionCard('Approve Leave Requests', Icons.event_available_rounded, AppColors.warningAmber),
        const SizedBox(height: 10),
        const _ActionCard('Process Payroll', Icons.payments_rounded, AppColors.successGreen),
        const SizedBox(height: 10),
        const _ActionCard('Generate Report', Icons.bar_chart_rounded, Color(0xFF9B59B6)),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nova AI Assistant',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Get insights on attendance patterns and workforce analytics.',
                style: TextStyle(color: Color(0xFF8899BB), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Ask Nova',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
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
  const _ActionCard(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Department stats ─────────────────────────────────────────────────────────
class _DeptStats extends StatelessWidget {
  const _DeptStats();

  static const _depts = [
    ('Operations', 18, AppColors.primaryBlue),
    ('Finance', 12, AppColors.successGreen),
    ('HR', 8, AppColors.warningAmber),
    ('IT', 6, Color(0xFF9B59B6)),
    ('Sales', 3, AppColors.errorRed),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employees by Department',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ..._depts.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DeptBar(name: d.$1, count: d.$2, color: d.$3, total: 47),
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
    final pct = count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('$count employees', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, constraints) {
          return Stack(
            children: [
              Container(
                height: 6,
                width: constraints.maxWidth,
                decoration: BoxDecoration(color: AppColors.backgroundBlue, borderRadius: BorderRadius.circular(100)),
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
