import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/providers/leave_provider.dart';
import '../../payroll/providers/payroll_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/reports_provider.dart';
import 'nova_ai_screen.dart';

// ── Attendance helpers (mirror attendance_screen logic) ───────────────────────
DateTime _endOfWorkDt(DateTime day, String workEndTime) {
  final parts = workEndTime.split(':');
  return DateTime(day.year, day.month, day.day,
      int.parse(parts[0]), parts.length > 1 ? int.parse(parts[1]) : 0);
}

bool _wasPresent(AttendanceModel r, String wet) =>
    r.checkInTime != null && r.checkInTime!.isBefore(_endOfWorkDt(r.date, wet));

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabs;
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this); // placeholder; rebuilt in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final role = ref.read(currentUserRoleProvider);
    _isGroup = role == AppConstants.roleGroupHrAdmin;
    final tabCount = _isGroup ? 5 : 4;
    if (_tabs.length != tabCount) {
      _tabs.dispose();
      _tabs = TabController(length: tabCount, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(isGroup: _isGroup, tabs: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                if (_isGroup) const _GroupTab(),
                const _DailyTab(),
                const _WeeklyTab(),
                const _MonthlyTab(),
                const NovaAiView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header + TabBar ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isGroup;
  final TabController tabs;
  const _Header({required this.isGroup, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final labels = [
      if (isGroup) 'Group',
      'Daily',
      'Weekly',
      'Monthly',
      'Ask Nova',
    ];
    return Container(
      color: context.appCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 10),
                Text('Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.appText)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9EFF).withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 13),
                      const SizedBox(width: 4),
                      Text('AI-Powered', style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primaryBlue,
            indicatorWeight: 2,
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: context.appSubtext,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: labels.map((l) => Tab(text: l)).toList(),
          ),
          Divider(height: 1, color: context.appBorder),
        ],
      ),
    );
  }
}

// ── Branch filter dropdown shared widget ──────────────────────────────────────
class _BranchFilter extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _BranchFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesStreamProvider).valueOrNull ?? [];
    if (branches.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: context.appField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          dropdownColor: context.appCard,
          hint: Text('All branches', style: TextStyle(color: context.appSubtext, fontSize: 13)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All branches', style: TextStyle(fontSize: 13, color: context.appText)),
            ),
            ...branches.map((b) => DropdownMenuItem<String?>(
                  value: b.id,
                  child: Text(b.name, style: TextStyle(fontSize: 13, color: context.appText)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _ReportCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final report = doc['report'] as String? ?? '';
    final generatedAt = doc['generatedAt'];
    String timeStr = '';
    if (generatedAt is String) {
      try {
        timeStr = DateFormat('d MMM y, HH:mm').format(DateTime.parse(generatedAt));
      } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: context.cardDeco(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded, color: AppColors.primaryBlue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _docLabel(doc),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.appText),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: TextStyle(fontSize: 11, color: context.appSubtext)),
              ],
            ),
            const SizedBox(height: 12),
            Text(report, style: TextStyle(fontSize: 13, color: context.appText, height: 1.65)),
          ],
        ),
      ),
    );
  }

  String _docLabel(Map<String, dynamic> doc) {
    final type = doc['type'] as String? ?? '';
    switch (type) {
      case 'daily':       return 'Daily — ${doc['date'] ?? ''}';
      case 'weekly':      return 'Week of ${doc['startDate'] ?? ''}';
      case 'monthly':     return 'Monthly — ${doc['month'] ?? ''}';
      case 'group_daily': return 'Group Daily — ${doc['date'] ?? ''}';
      case 'end_of_day':  return 'End of Day — ${doc['date'] ?? ''}';
      default:            return doc['id'] as String? ?? '';
    }
  }
}

// ── Generate button ────────────────────────────────────────────────────────────
class _GenButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final String label;
  const _GenButton({required this.loading, required this.onTap, this.label = 'Generate Report'});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome_rounded, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

// ── Live stat card ────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: context.appSubtext, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── AI summary panel ──────────────────────────────────────────────────────────
class _AiSummaryPanel extends StatelessWidget {
  final bool loading;
  final String? error;
  final String? freshReport;
  final Map<String, dynamic>? savedDoc;
  final VoidCallback onGenerate;
  final String periodLabel;

  const _AiSummaryPanel({
    required this.loading,
    required this.error,
    required this.freshReport,
    required this.savedDoc,
    required this.onGenerate,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final reportText = freshReport ?? (savedDoc?['report'] as String?);
    final genAt = savedDoc?['generatedAt'];
    String timeStr = '';
    if (genAt != null) {
      try {
        final dt = genAt is DateTime ? genAt : DateTime.tryParse(genAt.toString());
        if (dt != null) timeStr = DateFormat('d MMM, HH:mm').format(dt);
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 16),
            const SizedBox(width: 8),
            Text('AI Summary — $periodLabel',
                style: const TextStyle(
                    color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (timeStr.isNotEmpty)
              Text(timeStr,
                  style: TextStyle(color: context.appSubtext, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(children: [
              SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
              SizedBox(width: 12),
              Text('Generating AI summary…',
                  style: TextStyle(color: AppColors.primaryBlue, fontSize: 13)),
            ]),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.all(14),
            child: _ErrorBanner(error!),
          )
        else if (reportText != null && reportText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(reportText,
                style: TextStyle(fontSize: 13, color: context.appText, height: 1.65)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'No AI summary for this period yet.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Generate AI Summary', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ── Daily live data section ───────────────────────────────────────────────────
class _DailyLiveSection extends ConsumerWidget {
  final DateTime date;
  final String? branchId;
  const _DailyLiveSection({required this.date, this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateKey = leaveDateKey(date);
    final recordsAsync = ref.watch(attendanceByDateProvider(date));
    final empsAsync = ref.watch(employeesProvider);
    final onLeaveIds =
        ref.watch(approvedLeavesByDateProvider(dateKey)).valueOrNull ?? const <String>{};
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    final allEmps = empsAsync.valueOrNull ?? [];
    final emps = allEmps.where((e) =>
        e.isActive && (branchId == null || e.branchId == branchId)).toList();
    final totalActive = emps.length;

    final allRecords = recordsAsync.valueOrNull ?? [];
    final records = branchId != null
        ? allRecords.where((r) => r.branchId == branchId).toList()
        : allRecords;

    final isLoading = recordsAsync.isLoading || empsAsync.isLoading;
    if (isLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primaryBlue)));
    }

    final present = records.where((r) => _wasPresent(r, wet)).length;
    final late = records.where((r) => r.isLate && _wasPresent(r, wet)).length;
    final onLeave = branchId != null
        ? emps.where((e) => onLeaveIds.contains(e.id)).length
        : onLeaveIds.length;
    final absent = (totalActive - present - onLeave).clamp(0, totalActive);
    final rate = totalActive > 0 ? ((present / totalActive) * 100).round() : 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Live Attendance', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: context.appSubtext)),
      const SizedBox(height: 10),
      Row(children: [
        _StatTile(label: 'Attendance\nRate', value: '$rate%',
            color: rate >= 80 ? AppColors.successGreen : rate >= 60 ? AppColors.warningAmber : AppColors.errorRed,
            icon: Icons.trending_up_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Present', value: '$present',
            color: AppColors.successGreen, icon: Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Late', value: '$late',
            color: AppColors.warningAmber, icon: Icons.schedule_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Absent', value: '$absent',
            color: AppColors.errorRed, icon: Icons.cancel_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'On Leave', value: '$onLeave',
            color: AppColors.primaryBlue, icon: Icons.beach_access_rounded),
      ]),
      const SizedBox(height: 6),
      Text('Total active employees: $totalActive',
          style: TextStyle(fontSize: 11, color: context.appSubtext)),
    ]);
  }
}

// ── Weekly live data section ──────────────────────────────────────────────────
class _WeeklyLiveSection extends ConsumerWidget {
  final DateTime weekStart;
  final String? branchId;
  const _WeeklyLiveSection({required this.weekStart, this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empsAsync = ref.watch(employeesProvider);
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';
    // Fetch attendance for the month(s) of this week
    final monthAsync = ref.watch(
        attendanceByMonthProvider((year: weekStart.year, month: weekStart.month)));

    final emps = (empsAsync.valueOrNull ?? [])
        .where((e) => e.isActive && (branchId == null || e.branchId == branchId))
        .toList();
    final totalActive = emps.length;
    if (empsAsync.isLoading || monthAsync.isLoading) {
      return const Center(child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primaryBlue)));
    }

    final allRecords = monthAsync.valueOrNull ?? [];
    final weekDays = List.generate(5, (i) => weekStart.add(Duration(days: i)));
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Filter records to this week and optionally branch
    final weekRecords = allRecords.where((r) {
      final d = r.date;
      return !d.isBefore(weekStart) && !d.isAfter(weekEnd) &&
          (branchId == null || r.branchId == branchId);
    }).toList();

    int totalPresent = 0, totalLate = 0;
    final Map<int, (int, int)> dayStats = {};   // weekday → (present, late)
    for (final r in weekRecords) {
      if (_wasPresent(r, wet)) {
        totalPresent++;
        if (r.isLate) totalLate++;
        final wd = r.date.weekday;
        final prev = dayStats[wd] ?? (0, 0);
        dayStats[wd] = (prev.$1 + 1, prev.$2 + (r.isLate ? 1 : 0));
      }
    }
    final workingDays = weekDays.length;
    final maxPossible = workingDays * (totalActive == 0 ? 1 : totalActive);
    final avgRate = maxPossible > 0 ? ((totalPresent / maxPossible) * 100).round() : 0;
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Live Attendance This Week', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: context.appSubtext)),
      const SizedBox(height: 10),
      Row(children: [
        _StatTile(label: 'Avg Rate', value: '$avgRate%',
            color: avgRate >= 80 ? AppColors.successGreen : avgRate >= 60 ? AppColors.warningAmber : AppColors.errorRed,
            icon: Icons.trending_up_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Total\nPresent', value: '$totalPresent',
            color: AppColors.successGreen, icon: Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Total\nLate', value: '$totalLate',
            color: AppColors.warningAmber, icon: Icons.schedule_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Employees', value: '$totalActive',
            color: AppColors.primaryBlue, icon: Icons.people_rounded),
      ]),
      const SizedBox(height: 14),
      // Day-by-day bars
      ...List.generate(weekDays.length, (i) {
        final wd = weekDays[i].weekday;
        final stats = dayStats[wd] ?? (0, 0);
        final pct = totalActive > 0 ? stats.$1 / totalActive : 0.0;
        final dayColor = pct >= 0.8 ? AppColors.successGreen : pct >= 0.6 ? AppColors.warningAmber : AppColors.errorRed;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 32,
                child: Text(dayLabels[i],
                    style: TextStyle(fontSize: 12, color: context.appSubtext, fontWeight: FontWeight.w600))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: context.appBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(dayColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${stats.$1}/$totalActive',
                style: TextStyle(fontSize: 11, color: context.appSubtext)),
          ]),
        );
      }),
    ]);
  }
}

// ── Monthly live data section ─────────────────────────────────────────────────
class _MonthlyLiveSection extends ConsumerWidget {
  final DateTime month;
  final String? branchId;
  const _MonthlyLiveSection({required this.month, this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = DateFormat('yyyy-MM').format(month);
    final attAsync = ref.watch(
        attendanceByMonthProvider((year: month.year, month: month.month)));
    final leavesAsync = ref.watch(allLeaveRequestsProvider);
    final payrollAsync = ref.watch(payrollRunByMonthProvider(monthKey));
    final empsAsync = ref.watch(employeesProvider);
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    if (attAsync.isLoading || empsAsync.isLoading) {
      return const Center(child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primaryBlue)));
    }

    final totalActive = (empsAsync.valueOrNull ?? [])
        .where((e) => e.isActive && (branchId == null || e.branchId == branchId))
        .length;
    final allRecords = attAsync.valueOrNull ?? [];
    final records = branchId != null
        ? allRecords.where((r) => r.branchId == branchId).toList()
        : allRecords;
    final present = records.where((r) => _wasPresent(r, wet)).length;
    final late = records.where((r) => r.isLate && _wasPresent(r, wet)).length;

    // Count elapsed working days this month
    final now = DateTime.now();
    final lastDay = (month.year == now.year && month.month == now.month)
        ? now.day
        : DateUtils.getDaysInMonth(month.year, month.month);
    int workDays = 0;
    for (int d = 1; d <= lastDay; d++) {
      if (DateTime(month.year, month.month, d).weekday <= 5) workDays++;
    }
    final maxPossible = workDays * (totalActive == 0 ? 1 : totalActive);
    final rate = maxPossible > 0 ? ((present / maxPossible) * 100).round() : 0;

    // Leave breakdown
    final allLeaves = (leavesAsync.valueOrNull ?? []).where((l) {
      return l.status == 'approved' &&
          l.startDate.year == month.year &&
          l.startDate.month == month.month;
    }).toList();
    final leaveByType = <String, int>{};
    for (final l in allLeaves) {
      leaveByType[l.leaveType] = (leaveByType[l.leaveType] ?? 0) + l.totalDays;
    }

    // Payroll summary from run model
    final payrollRun = payrollAsync.valueOrNull;
    final totalGross = payrollRun?.totalGross ?? 0.0;
    final payrollCount = payrollRun?.employeeCount ?? 0;

    final typeLabels = {
      'annual': 'Annual', 'sick': 'Sick', 'maternity': 'Maternity',
      'paternity': 'Paternity', 'unpaid': 'Unpaid', 'emergency': 'Emergency',
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Live Monthly Overview', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: context.appSubtext)),
      const SizedBox(height: 10),
      Row(children: [
        _StatTile(label: 'Attendance\nRate', value: '$rate%',
            color: rate >= 80 ? AppColors.successGreen : rate >= 60 ? AppColors.warningAmber : AppColors.errorRed,
            icon: Icons.trending_up_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Present\nDays', value: '$present',
            color: AppColors.successGreen, icon: Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Late\nDays', value: '$late',
            color: AppColors.warningAmber, icon: Icons.schedule_rounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Working\nDays', value: '$workDays',
            color: AppColors.primaryBlue, icon: Icons.calendar_month_rounded),
      ]),
      if (leaveByType.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Leave Taken (Approved)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appSubtext)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: leaveByType.entries.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.appField,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appBorder),
            ),
            child: Text('${typeLabels[e.key] ?? e.key}: ${e.value} day${e.value == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: context.appText)),
          )).toList(),
        ),
      ],
      if (totalGross > 0) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.successGreen.withAlpha(50)),
          ),
          child: Row(children: [
            const Icon(Icons.payments_rounded, color: AppColors.successGreen, size: 16),
            const SizedBox(width: 8),
            Text('Payroll processed: ',
                style: TextStyle(fontSize: 13, color: context.appSubtext)),
            Text('RWF ${NumberFormat('#,###').format(totalGross.round())}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.successGreen)),
            Text(' ($payrollCount employees)',
                style: TextStyle(fontSize: 12, color: context.appSubtext)),
          ]),
        ),
      ],
    ]);
  }
}

// ── DAILY TAB ─────────────────────────────────────────────────────────────────
class _DailyTab extends ConsumerStatefulWidget {
  const _DailyTab();
  @override
  ConsumerState<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends ConsumerState<_DailyTab> {
  String? _branchId;
  DateTime _date = DateTime.now();
  final _fmt = DateFormat('yyyy-MM-dd');

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('daily'));
    final notifier = ref.read(reportNotifierProvider('daily').notifier);
    final docs     = ref.watch(reportsStreamProvider('daily')).valueOrNull ?? [];
    final dateFmt  = DateFormat('d MMM yyyy');
    final savedDoc = docs.firstWhere(
      (d) => (d['date'] as String?) == _fmt.format(_date),
      orElse: () => docs.isNotEmpty ? docs.first : <String, dynamic>{},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls
          Row(
            children: [
              if (_showBranchFilter) ...[
                _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
                const SizedBox(width: 10),
              ],
              _DateChip(date: _date, onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2024), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              }),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                onTap: () => notifier.generateDaily(date: _fmt.format(_date), branchId: _branchId),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AutoNote('Morning reports are sent automatically to HR Admin and Manager at 9:30am every working day.'),
          const SizedBox(height: 20),
          // Live attendance data
          _DailyLiveSection(date: _date, branchId: _branchId),
          const SizedBox(height: 20),
          // AI summary panel
          _AiSummaryPanel(
            loading: state.loading,
            error: state.error,
            freshReport: state.report,
            savedDoc: savedDoc.isNotEmpty ? savedDoc : null,
            periodLabel: dateFmt.format(_date),
            onGenerate: () => notifier.generateDaily(date: _fmt.format(_date), branchId: _branchId),
          ),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
          const SizedBox(height: 20),
          const _AnomalySection(),
        ],
      ),
    );
  }
}

// ── ANOMALY SECTION ───────────────────────────────────────────────────────────
class _AnomalySection extends ConsumerWidget {
  const _AnomalySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(reportsStreamProvider('anomaly_alert')).valueOrNull ?? [];
    if (docs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 16),
          const SizedBox(width: 6),
          Text('AI Anomaly Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
        ]),
        const SizedBox(height: 10),
        ...docs.take(5).map((d) => _AnomalyCard(doc: d)),
      ],
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({required this.doc});
  final Map<String, dynamic> doc;

  @override
  Widget build(BuildContext context) {
    final report = (doc['report'] as String?) ?? (doc['summary'] as String?) ?? '';
    final ts = doc['generatedAt'];
    String dateLabel = '';
    if (ts != null) {
      try {
        final dt = ts is DateTime ? ts : DateTime.tryParse(ts.toString());
        if (dt != null) dateLabel = DateFormat('d MMM y, HH:mm').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.warningAmber, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.warningAmber, size: 14),
          const SizedBox(width: 6),
          const Text('Anomaly Alert', style: TextStyle(color: AppColors.warningAmber, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (dateLabel.isNotEmpty)
            Text(dateLabel, style: TextStyle(color: context.appSubtext, fontSize: 12)),
        ]),
        if (report.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(report, style: TextStyle(color: context.appText, fontSize: 14, height: 1.45)),
        ],
      ]),
    );
  }
}

// ── WEEKLY TAB ────────────────────────────────────────────────────────────────
class _WeeklyTab extends ConsumerStatefulWidget {
  const _WeeklyTab();
  @override
  ConsumerState<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends ConsumerState<_WeeklyTab> {
  String? _branchId;
  DateTime _weekStart = _calcWeekStart(DateTime.now());

  static DateTime _calcWeekStart(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day - diff);
  }

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('weekly'));
    final notifier = ref.read(reportNotifierProvider('weekly').notifier);
    final docs     = ref.watch(reportsStreamProvider('weekly')).valueOrNull ?? [];
    final fmt      = DateFormat('yyyy-MM-dd');
    final displayFmt = DateFormat('d MMM');

    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekStartStr = fmt.format(_weekStart);
    final savedDoc = docs.firstWhere(
      (d) => (d['startDate'] as String?) == weekStartStr,
      orElse: () => docs.isNotEmpty ? docs.first : <String, dynamic>{},
    );
    final periodLabel = '${displayFmt.format(_weekStart)} – ${displayFmt.format(weekEnd)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_showBranchFilter) ...[
                _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
                const SizedBox(width: 10),
              ],
              // Week navigator
              Container(
                decoration: BoxDecoration(
                  color: context.appField,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        periodLabel,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: _weekStart.isBefore(DateTime.now().subtract(const Duration(days: 7)))
                          ? () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)))
                          : null,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                onTap: () => notifier.generateWeekly(startDate: weekStartStr, branchId: _branchId),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Live weekly breakdown
          _WeeklyLiveSection(weekStart: _weekStart, branchId: _branchId),
          const SizedBox(height: 20),
          // AI summary panel
          _AiSummaryPanel(
            loading: state.loading,
            error: state.error,
            freshReport: state.report,
            savedDoc: savedDoc.isNotEmpty ? savedDoc : null,
            periodLabel: periodLabel,
            onGenerate: () => notifier.generateWeekly(startDate: weekStartStr, branchId: _branchId),
          ),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
        ],
      ),
    );
  }
}

// ── MONTHLY TAB ───────────────────────────────────────────────────────────────
class _MonthlyTab extends ConsumerStatefulWidget {
  const _MonthlyTab();
  @override
  ConsumerState<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends ConsumerState<_MonthlyTab> {
  String? _branchId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_month);

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('monthly'));
    final notifier = ref.read(reportNotifierProvider('monthly').notifier);
    final docs     = ref.watch(reportsStreamProvider('monthly')).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_showBranchFilter) ...[
                _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
                const SizedBox(width: 10),
              ],
              // Month navigator
              Container(
                decoration: BoxDecoration(
                  color: context.appField,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        DateFormat('MMMM yyyy').format(_month),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: _month.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                          ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                          : null,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                onTap: () => notifier.generateMonthly(month: _monthKey, branchId: _branchId),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Live monthly overview
          _MonthlyLiveSection(month: _month, branchId: _branchId),
          const SizedBox(height: 20),
          // AI summary panel
          Builder(builder: (_) {
            final sd = docs.firstWhere(
              (d) => (d['month'] as String?) == _monthKey,
              orElse: () => docs.isNotEmpty ? docs.first : <String, dynamic>{},
            );
            return _AiSummaryPanel(
              loading: state.loading,
              error: state.error,
              freshReport: state.report,
              savedDoc: sd.isNotEmpty ? sd : null,
              periodLabel: DateFormat('MMMM yyyy').format(_month),
              onGenerate: () => notifier.generateMonthly(month: _monthKey, branchId: _branchId),
            );
          }),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
        ],
      ),
    );
  }
}

// ── GROUP TAB (group_hr_admin only) ───────────────────────────────────────────
class _GroupTab extends ConsumerStatefulWidget {
  const _GroupTab();
  @override
  ConsumerState<_GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends ConsumerState<_GroupTab> {
  DateTime _date = DateTime.now();
  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('group'));
    final notifier = ref.read(reportNotifierProvider('group').notifier);
    final docs     = ref.watch(reportsStreamProvider('group_daily')).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateChip(date: _date, onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2024), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              }),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                label: 'Generate Group Report',
                onTap: () => notifier.generateGroupDaily(date: _fmt.format(_date)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AutoNote('Group reports are sent automatically to Group HR Admin at 9:30am every working day.'),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(state.error!),
          ],
          if (state.report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(doc: {'type': 'group_daily', 'report': state.report, 'date': _fmt.format(_date)}),
          ],
          // Branch comparison from latest group report
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GroupBranchChart(doc: docs.first),
            const SizedBox(height: 20),
            Text('Previous Group Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
        ],
      ),
    );
  }
}

class _GroupBranchChart extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _GroupBranchChart({required this.doc});

  @override
  Widget build(BuildContext context) {
    final summary = doc['summary'] as Map<String, dynamic>?;
    if (summary == null) return const SizedBox.shrink();
    final branches = (summary['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (branches.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: context.cardDeco(12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Branch Attendance Comparison', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.appText)),
          const SizedBox(height: 16),
          ...branches.map((b) {
            final rate = (b['attendanceRate'] ?? b['avgAttendanceRate'] ?? 0) as num;
            final name = b['branchName'] as String? ?? 'Branch';
            final color = rate >= 90 ? AppColors.successGreen : rate >= 70 ? AppColors.warningAmber : AppColors.errorRed;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontSize: 13, color: context.appText, fontWeight: FontWeight.w600)),
                      Text('${rate.toInt()}%', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 8,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Date chip ─────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateChip({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: context.appField,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: context.appSubtext),
            const SizedBox(width: 6),
            Text(
              isToday ? 'Today' : DateFormat('d MMM yyyy').format(date),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 14, color: context.appSubtext),
          ],
        ),
      ),
    );
  }
}

// ── Auto-delivery info note ───────────────────────────────────────────────────
class _AutoNote extends StatelessWidget {
  final String message;
  const _AutoNote(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_send_rounded, color: AppColors.primaryBlue, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) {
    final clean = message.replaceAll(RegExp(r'Exception:|DioException.*'), '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.errorRed.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(clean.isNotEmpty ? clean : 'Something went wrong.', style: const TextStyle(fontSize: 12, color: AppColors.errorRed))),
        ],
      ),
    );
  }
}
