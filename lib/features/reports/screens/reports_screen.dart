import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import '../../performance/models/performance_model.dart';
import '../../performance/providers/performance_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/reports_provider.dart';
import '../services/reports_pdf_service.dart';
import 'nova_ai_screen.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabs();
  }

  bool _canSeeBranches(String? role, String? companyType) {
    if (role == AppConstants.roleGroupHrAdmin) return true;
    if (role == AppConstants.roleHrAdmin) return (companyType ?? 'single') == 'multi';
    return false;
  }

  void _syncTabs() {
    final role = ref.read(currentUserRoleProvider);
    final settings = ref.read(companySettingsProvider).value;
    final isGroup = role == AppConstants.roleGroupHrAdmin;
    final showBranches = _canSeeBranches(role, settings?.companyType);
    final count = 6 + (isGroup ? 1 : 0) + (showBranches ? 1 : 0);
    if (_tabs.length != count) {
      _tabs.dispose();
      _tabs = TabController(length: count, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final settings = ref.watch(companySettingsProvider).value;
    final isGroup = role == AppConstants.roleGroupHrAdmin;
    final showBranches = _canSeeBranches(role, settings?.companyType);
    final tabCount = 6 + (isGroup ? 1 : 0) + (showBranches ? 1 : 0);

    if (_tabs.length != tabCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_syncTabs);
      });
    }

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(isGroup: isGroup, showBranches: showBranches, tabs: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                if (isGroup) const _GroupTab(),
                const _AttendanceReportTab(),
                const _PerformanceReportTab(),
                if (showBranches) const _BranchesReportTab(),
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
  final bool showBranches;
  final TabController tabs;
  const _Header({required this.isGroup, required this.showBranches, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final labels = [
      if (isGroup) 'Group',
      'Attendance',
      'Performance',
      if (showBranches) 'Branches',
      'Daily',
      'Weekly',
      'Monthly',
      'Ask Nova',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
          child: Row(
            children: [
              Text('Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appText, letterSpacing: -0.3)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9EFF).withAlpha(22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const AppIcon(AppIcons.autoAwesomeRounded, color: AppColors.primaryBlue, size: 13),
                    const SizedBox(width: 4),
                    const Text('AI-Powered', style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w500)),
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          dividerColor: Colors.transparent,
          tabs: labels.map((l) => Tab(text: l)).toList(),
        ),
        Divider(height: 1, color: context.appBorder),
      ],
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
      decoration: context.cardDeco(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIcon(AppIcons.descriptionRounded, color: AppColors.primaryBlue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _docLabel(doc),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.appText),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: TextStyle(fontSize: 11, color: context.appSubtext)),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownBody(
              data: report,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 13, color: context.appText, height: 1.65),
                h2: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText),
                strong: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
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
          : const AppIcon(AppIcons.autoAwesomeRounded, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ── Live stat card ────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconRef icon;
  final String? sub;
  const _StatTile({required this.label, required this.value, required this.color, required this.icon, this.sub});

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
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700, height: 1)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: context.appSubtext, fontSize: 11),
              textAlign: TextAlign.center),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: TextStyle(color: context.appSubtext.withAlpha(180), fontSize: 10),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}

// ── AI summary trigger bar — the full report renders inline below it ─────────
class _AiSummaryPanel extends StatefulWidget {
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
  State<_AiSummaryPanel> createState() => _AiSummaryPanelState();
}

class _AiSummaryPanelState extends State<_AiSummaryPanel> {
  String? _shownFor;
  bool _dismissed = false;

  String? get _reportText => widget.freshReport ?? (widget.savedDoc?['report'] as String?);

  @override
  void didUpdateWidget(_AiSummaryPanel old) {
    super.didUpdateWidget(old);
    final text = _reportText;
    // The instant a generation finishes, reveal the result inline on the page.
    if (old.loading && !widget.loading && text != null && text.isNotEmpty && text != _shownFor) {
      _shownFor = text;
      setState(() => _dismissed = false);
    } else if (old.loading && !widget.loading && widget.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: _ErrorBanner(widget.error!),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportText = _reportText;
    final hasReport = reportText != null && reportText.isNotEmpty;

    if (!hasReport || _dismissed) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue.withAlpha(200), const Color(0xFF2979E0).withAlpha(200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(45), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const AppIcon(AppIcons.autoAwesomeRounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('AI Summary — ${widget.periodLabel}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              InkWell(
                onTap: () => setState(() => _dismissed = true),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
                  child: const AppIcon(AppIcons.closeRounded, color: Colors.white, size: 15),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            MarkdownBody(
              data: reportText,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 14, color: Colors.white, height: 1.65, fontWeight: FontWeight.w400),
                h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                strong: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                listBullet: const TextStyle(color: Colors.white),
              ),
            ),
          ]),
        ),
    ]);
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

    final rateColor = rate >= 80 ? AppColors.successGreen : rate >= 60 ? AppColors.warningAmber : AppColors.errorRed;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Today\'s Overview', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: context.appSubtext)),
      const SizedBox(height: 12),
      // KPI tiles on top
      Row(children: [
        _StatTile(label: 'Attendance Rate', value: '$rate%', color: rateColor, icon: AppIcons.trendingUpRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Active Employees', value: '$totalActive', color: AppColors.primaryBlue, icon: AppIcons.peopleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Present', value: '$present', color: AppColors.successGreen, icon: AppIcons.checkCircleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Late', value: '$late', color: AppColors.warningAmber, icon: AppIcons.scheduleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Absent', value: '$absent', color: AppColors.errorRed, icon: AppIcons.cancelRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'On Leave', value: '$onLeave', color: const Color(0xFF8B5CF6), icon: AppIcons.beachAccessRounded),
      ]),
      const SizedBox(height: 12),
      // Chart full width below
      _DonutChart(
        title: 'Attendance Breakdown',
        segments: [
          ('Present', present - late, AppColors.successGreen),
          ('Late', late, AppColors.warningAmber),
          ('Absent', absent, AppColors.errorRed),
          ('On Leave', onLeave, AppColors.primaryBlue),
        ],
      ),
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

    final avgRateColor = avgRate >= 80 ? AppColors.successGreen : avgRate >= 60 ? AppColors.warningAmber : AppColors.errorRed;
    final chartDays = List.generate(weekDays.length, (i) {
      final stats = dayStats[weekDays[i].weekday] ?? (0, 0);
      return (dayLabels[i], stats.$1, totalActive == 0 ? 1 : totalActive);
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('This Week\'s Attendance', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: context.appSubtext)),
      const SizedBox(height: 12),
      // KPI tiles on top
      Row(children: [
        _StatTile(label: 'Avg Rate', value: '$avgRate%', color: avgRateColor, icon: AppIcons.trendingUpRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Employees', value: '$totalActive', color: AppColors.primaryBlue, icon: AppIcons.peopleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Total Present', value: '$totalPresent', color: AppColors.successGreen, icon: AppIcons.checkCircleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Total Late', value: '$totalLate', color: AppColors.warningAmber, icon: AppIcons.scheduleRounded),
      ]),
      const SizedBox(height: 12),
      // Chart full width below
      _TrendBarChart(
        title: 'Day-by-Day Attendance Rate',
        days: chartDays,
      ),
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

    final absent = (workDays * totalActive - present).clamp(0, workDays * totalActive);
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    // Per-day trend data
    final byDay = <int, int>{};
    for (final r in records) {
      if (_wasPresent(r, wet)) {
        byDay[r.date.day] = (byDay[r.date.day] ?? 0) + 1;
      }
    }
    final sortedDays = byDay.keys.toList()..sort();
    final trendDays = sortedDays.map((d) =>
        ('$d', byDay[d]!, totalActive == 0 ? 1 : totalActive)).toList();

    final maxLeave = leaveByType.isEmpty
        ? 1.0
        : leaveByType.values.fold(0, (a, b) => a > b ? a : b).toDouble();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Live Monthly Overview', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: context.appSubtext)),
      const SizedBox(height: 10),
      // KPI tiles
      Row(children: [
        _StatTile(label: 'Attendance\nRate', value: '$rate%',
            color: rate >= 80 ? AppColors.successGreen : rate >= 60 ? AppColors.warningAmber : AppColors.errorRed,
            icon: AppIcons.trendingUpRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Present\nDays', value: '$present',
            color: AppColors.successGreen, icon: AppIcons.checkCircleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Late\nDays', value: '$late',
            color: AppColors.warningAmber, icon: AppIcons.scheduleRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Absent\nDays', value: '$absent',
            color: AppColors.errorRed, icon: AppIcons.cancelRounded),
        const SizedBox(width: 8),
        _StatTile(label: 'Working\nDays', value: '$workDays',
            color: AppColors.primaryBlue, icon: AppIcons.calendarMonthRounded),
      ]),
      const SizedBox(height: 16),
      // Attendance charts
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 4,
          child: _DonutChart(
            title: 'Attendance Breakdown',
            segments: [
              ('On Time', present - late, AppColors.successGreen),
              ('Late', late, AppColors.warningAmber),
              ('Absent', absent, AppColors.errorRed),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: _TrendBarChart(
            title: 'Daily Attendance Rate — $monthLabel',
            days: trendDays,
          ),
        ),
      ]),
      if (leaveByType.isNotEmpty) ...[
        const SizedBox(height: 16),
        _HorizBars(
          title: 'Leave Taken by Type (Approved Days)',
          unit: 'days',
          items: leaveByType.entries.map((e) => (
            typeLabels[e.key] ?? e.key,
            e.value.toDouble(),
            maxLeave,
            AppColors.primaryBlue,
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
            const AppIcon(AppIcons.paymentsRounded, color: AppColors.successGreen, size: 16),
            const SizedBox(width: 8),
            Text('Payroll processed: ',
                style: TextStyle(fontSize: 13, color: context.appSubtext)),
            Text('RWF ${NumberFormat('#,###').format(totalGross.round())}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
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
              const SizedBox(width: 10),
              _DailyPdfButton(
                date: _date,
                branchId: _branchId,
                aiReport: state.report ??
                    (savedDoc.isNotEmpty ? savedDoc['report'] as String? : null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AiSummaryPanel(
            loading: state.loading,
            error: state.error,
            freshReport: state.report,
            savedDoc: savedDoc.isNotEmpty ? savedDoc : null,
            periodLabel: dateFmt.format(_date),
            onGenerate: () => notifier.generateDaily(date: _fmt.format(_date), branchId: _branchId),
          ),
          const SizedBox(height: 20),
          // Live attendance data
          _DailyLiveSection(date: _date, branchId: _branchId),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
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
          const AppIcon(AppIcons.warningAmberRounded, color: AppColors.warningAmber, size: 16),
          const SizedBox(width: 6),
          Text('AI Anomaly Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
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
          const AppIcon(AppIcons.autoAwesomeRounded, color: AppColors.warningAmber, size: 14),
          const SizedBox(width: 6),
          const Text('Anomaly Alert', style: TextStyle(color: AppColors.warningAmber, fontSize: 13, fontWeight: FontWeight.w500)),
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
                      icon: const AppIcon(AppIcons.chevronLeftRounded, size: 18),
                      onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        periodLabel,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.chevronRightRounded, size: 18),
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
              const SizedBox(width: 10),
              _WeeklyPdfButton(
                weekStart: _weekStart,
                branchId: _branchId,
                periodLabel: periodLabel,
                fileKey: weekStartStr.replaceAll('-', ''),
                aiReport: state.report ??
                    (savedDoc.isNotEmpty ? savedDoc['report'] as String? : null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AiSummaryPanel(
            loading: state.loading,
            error: state.error,
            freshReport: state.report,
            savedDoc: savedDoc.isNotEmpty ? savedDoc : null,
            periodLabel: periodLabel,
            onGenerate: () => notifier.generateWeekly(startDate: weekStartStr, branchId: _branchId),
          ),
          const SizedBox(height: 20),
          // Live weekly breakdown
          _WeeklyLiveSection(weekStart: _weekStart, branchId: _branchId),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
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
                      icon: const AppIcon(AppIcons.chevronLeftRounded, size: 18),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        DateFormat('MMMM yyyy').format(_month),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.chevronRightRounded, size: 18),
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
              const SizedBox(width: 10),
              _MonthlyPdfButton(
                month: _month,
                branchId: _branchId,
                aiReport: state.report,
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          // Live monthly overview
          _MonthlyLiveSection(month: _month, branchId: _branchId),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
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
  bool _pdfDownloading = false;

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('group'));
    final notifier = ref.read(reportNotifierProvider('group').notifier);
    final docs     = ref.watch(reportsStreamProvider('group_daily')).valueOrNull ?? [];

    // Live data
    final attAsync      = ref.watch(attendanceByDateProvider(_date));
    final attendance    = attAsync.valueOrNull ?? [];
    final allEmployees  = (ref.watch(employeesProvider).valueOrNull ?? [])
        .where((e) => e.isActive).toList();
    final branches      = ref.watch(branchesStreamProvider).valueOrNull ?? [];

    final branchNames   = {for (final b in branches) b.id: b.name};

    // Employees per branch
    final empPerBranch = <String, int>{};
    for (final e in allEmployees) {
      final k = e.branchId ?? 'unassigned';
      empPerBranch[k] = (empPerBranch[k] ?? 0) + 1;
    }

    // Attendance per branch
    final attPerBranch = <String, List<AttendanceModel>>{};
    for (final a in attendance) {
      final k = a.branchId ?? 'unassigned';
      (attPerBranch[k] ??= []).add(a);
    }

    // Build sorted branch stats
    final branchStats = empPerBranch.entries.map((entry) {
      final bid    = entry.key;
      final total  = entry.value;
      final recs   = attPerBranch[bid] ?? [];
      final present  = recs.where((r) => !r.isAbsent && !r.isOnLeave && r.checkInTime != null).length;
      final late     = recs.where((r) => r.isLate && !r.isAbsent && !r.isOnLeave).length;
      final onLeave  = recs.where((r) => r.isOnLeave).length;
      final absent   = recs.where((r) => r.isAbsent).length;
      return _BranchStat(
        branchId: bid, branchName: branchNames[bid] ?? bid,
        total: total, present: present, late: late,
        onLeave: onLeave, absent: absent,
        rate: total > 0 ? present / total * 100 : 0.0,
      );
    }).toList()..sort((a, b) => b.rate.compareTo(a.rate));

    // Group totals
    final totalActive  = allEmployees.length;
    final totalPresent = attendance.where((r) => !r.isAbsent && !r.isOnLeave && r.checkInTime != null).length;
    final totalLate    = attendance.where((r) => r.isLate && !r.isAbsent && !r.isOnLeave).length;
    final totalOnLeave = attendance.where((r) => r.isOnLeave).length;
    final totalAbsent  = attendance.where((r) => r.isAbsent).length;
    final overallRate  = totalActive > 0 ? totalPresent / totalActive * 100 : 0.0;

    final isToday  = _fmt.format(_date) == _fmt.format(DateTime.now());
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(_date);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Controls ─────────────────────────────────────────────────────────
        Row(children: [
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
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: (attAsync.isLoading || _pdfDownloading) ? null : () async {
              setState(() => _pdfDownloading = true);
              try {
                await GroupReportPdfService.download(
                  companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
                  date: _fmt.format(_date),
                  totalEmployees: totalActive,
                  totalPresent: totalPresent,
                  totalLate: totalLate,
                  totalOnLeave: totalOnLeave,
                  totalAbsent: totalAbsent,
                  overallRate: overallRate,
                  branchStats: branchStats.map((s) => GroupBranchStat(
                    branchName: s.branchName,
                    total: s.total, present: s.present, late: s.late,
                    onLeave: s.onLeave, absent: s.absent, rate: s.rate,
                  )).toList(),
                  aiReport: state.report,
                );
              } finally {
                if (mounted) setState(() => _pdfDownloading = false);
              }
            },
            icon: _pdfDownloading
                ? const SizedBox(width: 15, height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const AppIcon(AppIcons.downloadRounded, size: 17),
            label: const Text('Download PDF',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 12),
        _AiSummaryPanel(
          loading: state.loading,
          error: state.error,
          freshReport: state.report,
          savedDoc: docs.isNotEmpty ? docs.firstWhere(
            (d) => (d['date'] as String?) == _fmt.format(_date),
            orElse: () => docs.first,
          ) : null,
          periodLabel: DateFormat('d MMMM yyyy').format(_date),
          onGenerate: () => notifier.generateGroupDaily(date: _fmt.format(_date)),
        ),

        // ── Live KPI cards ────────────────────────────────────────────────────
        const SizedBox(height: 20),
        _SectionLabel('Live Group Summary — $dateLabel'),
        const SizedBox(height: 12),
        if (attAsync.isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          ))
        else ...[
          Row(children: [
            _StatTile(
              icon: AppIcons.corporateFareRounded,
              label: 'Total Employees',
              value: '$totalActive',
              sub: '${branches.length} branches',
              color: AppColors.primaryBlue,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: AppIcons.checkCircleOutlineRounded,
              label: isToday ? 'Present Today' : 'Present',
              value: '$totalPresent',
              sub: '${overallRate.toStringAsFixed(1)}% of workforce',
              color: AppColors.successGreen,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: AppIcons.accessTimeRounded,
              label: 'Arrived Late',
              value: '$totalLate',
              sub: totalPresent > 0
                  ? '${(totalLate / totalPresent * 100).toStringAsFixed(0)}% of present'
                  : 'No check-ins yet',
              color: AppColors.warningAmber,
            ),
            const SizedBox(width: 12),
            _StatTile(
              icon: AppIcons.beachAccessRounded,
              label: 'On Leave',
              value: '$totalOnLeave',
              sub: '$totalAbsent absent (unexcused)',
              color: const Color(0xFF9B59B6),
            ),
          ]),

          // ── Charts row ─────────────────────────────────────────────────────
          if (branchStats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 6,
                child: _GroupBarChart(stats: branchStats),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: context.cardDeco(),
                  child: _DonutChart(
                    title: 'Attendance Breakdown',
                    segments: [
                      ('Present', totalPresent - totalLate, AppColors.successGreen),
                      ('Late',    totalLate,    AppColors.warningAmber),
                      ('On Leave', totalOnLeave, const Color(0xFF9B59B6)),
                      ('Absent',  totalAbsent,  AppColors.errorRed),
                    ],
                  ),
                ),
              ),
            ]),

            // ── Branch breakdown table ────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel('Branch Breakdown'),
            const SizedBox(height: 10),
            _GroupBranchTable(stats: branchStats),

            // ── Best / worst highlight ────────────────────────────────────────
            if (branchStats.length >= 2) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _GroupHighlightCard(stat: branchStats.first, isTop: true)),
                const SizedBox(width: 12),
                Expanded(child: _GroupHighlightCard(stat: branchStats.last, isTop: false)),
              ]),
            ],
          ] else
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(36),
              decoration: context.cardDeco(),
              child: Center(child: Column(children: [
                AppIcon(AppIcons.barChartRounded, size: 44, color: context.appSubtext.withAlpha(120)),
                const SizedBox(height: 12),
                Text(
                  isToday
                      ? 'No attendance recorded yet for today'
                      : 'No attendance data for this date',
                  style: TextStyle(color: context.appSubtext, fontSize: 14),
                ),
              ])),
            ),
        ],

        // ── Previous reports ──────────────────────────────────────────────────
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel('Previous Group Reports'),
          const SizedBox(height: 10),
          ...docs.take(5).map((d) => _ReportCard(doc: d)),
        ],
      ]),
    );
  }
}

// ── Branch stat data class ────────────────────────────────────────────────────
class _BranchStat {
  const _BranchStat({
    required this.branchId, required this.branchName,
    required this.total, required this.present, required this.late,
    required this.onLeave, required this.absent, required this.rate,
  });
  final String branchId, branchName;
  final int total, present, late, onLeave, absent;
  final double rate;
}

// ── Branch attendance bar chart ───────────────────────────────────────────────
class _GroupBarChart extends StatelessWidget {
  const _GroupBarChart({required this.stats});
  final List<_BranchStat> stats;

  @override
  Widget build(BuildContext context) {
    final visible = stats.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Branch Attendance Rate',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(color: context.appBorder, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                      style: TextStyle(color: context.appSubtext, fontSize: 11)),
                )),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= visible.length) return const SizedBox.shrink();
                    final name = visible[i].branchName;
                    final short = name.length > 10 ? '${name.substring(0, 9)}…' : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(short,
                          style: TextStyle(color: context.appSubtext, fontSize: 9),
                          textAlign: TextAlign.center),
                    );
                  },
                )),
              ),
              barGroups: visible.asMap().entries.map((e) {
                final rate = e.value.rate;
                final color = rate >= 90
                    ? AppColors.successGreen
                    : rate >= 70
                        ? AppColors.warningAmber
                        : AppColors.errorRed;
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: rate,
                    color: color,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: context.appBorder.withAlpha(60),
                    ),
                  ),
                ]);
              }).toList(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => context.appCard,
                  getTooltipItem: (group, _, rod, __) {
                    final s = visible[group.x];
                    return BarTooltipItem(
                      '${s.branchName}\n${s.present}/${s.total} · ${rod.toY.toStringAsFixed(1)}%',
                      TextStyle(color: context.appText, fontSize: 12, fontWeight: FontWeight.w500),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Branch breakdown table ─────────────────────────────────────────────────────
class _GroupBranchTable extends StatelessWidget {
  const _GroupBranchTable({required this.stats});
  final List<_BranchStat> stats;

  static Color _rateColor(double r) =>
      r >= 90 ? AppColors.successGreen : r >= 70 ? AppColors.warningAmber : AppColors.errorRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.cardDeco(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.appTint,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            _TH('Branch',     flex: 4),
            _TH('Employees',  flex: 2),
            _TH('Present',    flex: 2),
            _TH('Late',       flex: 2),
            _TH('On Leave',   flex: 2),
            _TH('Absent',     flex: 2),
            _TH('Rate',       flex: 2),
          ]),
        ),
        ...stats.asMap().entries.map((entry) {
          final s = entry.value;
          final rc = _rateColor(s.rate);
          return Container(
            decoration: BoxDecoration(
              color: entry.key.isEven ? Colors.transparent : context.appBg.withAlpha(80),
              border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(flex: 4, child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: rc, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.branchName,
                    style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
              ])),
              Expanded(flex: 2, child: Text('${s.total}',
                  style: TextStyle(color: context.appText, fontSize: 13))),
              Expanded(flex: 2, child: Text('${s.present}',
                  style: const TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w500))),
              Expanded(flex: 2, child: Text('${s.late}',
                  style: TextStyle(
                      color: s.late > 0 ? AppColors.warningAmber : context.appSubtext,
                      fontSize: 13,
                      fontWeight: s.late > 0 ? FontWeight.w500 : FontWeight.normal))),
              Expanded(flex: 2, child: Text('${s.onLeave}',
                  style: TextStyle(
                      color: s.onLeave > 0 ? const Color(0xFF9B59B6) : context.appSubtext,
                      fontSize: 13))),
              Expanded(flex: 2, child: Text('${s.absent}',
                  style: TextStyle(
                      color: s.absent > 0 ? AppColors.errorRed : context.appSubtext,
                      fontSize: 13,
                      fontWeight: s.absent > 0 ? FontWeight.w500 : FontWeight.normal))),
              Expanded(flex: 2, child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: rc.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: Text('${s.rate.toStringAsFixed(1)}%',
                      style: TextStyle(color: rc, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Best / worst branch highlight card ────────────────────────────────────────
class _GroupHighlightCard extends StatelessWidget {
  const _GroupHighlightCard({required this.stat, required this.isTop});
  final _BranchStat stat;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final color = isTop ? AppColors.successGreen : AppColors.errorRed;
    final icon  = isTop ? AppIcons.emojiEventsRounded : AppIcons.trendingDownRounded;
    final label = isTop ? 'Best Performing Branch' : 'Needs Attention';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(11)),
          child: AppIcon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: context.appSubtext, fontSize: 12, fontWeight: FontWeight.w400)),
          const SizedBox(height: 2),
          Text(stat.branchName,
              style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${stat.present}/${stat.total} present · ${stat.rate.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }
}

// ── Daily PDF download button ─────────────────────────────────────────────────
class _DailyPdfButton extends ConsumerStatefulWidget {
  final DateTime date;
  final String? branchId;
  final String? aiReport;
  const _DailyPdfButton({required this.date, this.branchId, this.aiReport});
  @override
  ConsumerState<_DailyPdfButton> createState() => _DailyPdfButtonState();
}

class _DailyPdfButtonState extends ConsumerState<_DailyPdfButton> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(attendanceByDateProvider(widget.date));
    final empsAsync    = ref.watch(employeesProvider);
    final onLeaveIds   = ref.watch(
        approvedLeavesByDateProvider(leaveDateKey(widget.date))).valueOrNull
        ?? const <String>{};
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    final emps = (empsAsync.valueOrNull ?? [])
        .where((e) => e.isActive && (widget.branchId == null || e.branchId == widget.branchId))
        .toList();
    final recs = widget.branchId != null
        ? (recordsAsync.valueOrNull ?? []).where((r) => r.branchId == widget.branchId).toList()
        : (recordsAsync.valueOrNull ?? []);
    final present  = recs.where((r) => _wasPresent(r, wet)).length;
    final late     = recs.where((r) => r.isLate && _wasPresent(r, wet)).length;
    final onLeave  = widget.branchId != null
        ? emps.where((e) => onLeaveIds.contains(e.id)).length
        : onLeaveIds.length;
    final absent   = (emps.length - present - onLeave).clamp(0, emps.length);
    final rate     = emps.isNotEmpty ? ((present / emps.length) * 100).round() : 0;

    final fmt = DateFormat('yyyy-MM-dd');
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _downloading ? null : () async {
        setState(() => _downloading = true);
        try {
          String? branchName;
          if (widget.branchId != null) {
            final branches = ref.read(branchesStreamProvider).valueOrNull ?? [];
            branchName = branches.firstWhere((b) => b.id == widget.branchId,
                orElse: () => branches.first).name;
          }
          await DailyReportPdfService.download(
            companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
            dateLabel: DateFormat('d MMMM yyyy').format(widget.date),
            dateKey: fmt.format(widget.date),
            totalActive: emps.length,
            present: present, late: late, absent: absent, onLeave: onLeave, rate: rate,
            aiReport: widget.aiReport,
            branchName: branchName,
          );
        } finally {
          if (mounted) setState(() => _downloading = false);
        }
      },
      icon: _downloading
          ? const SizedBox(width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const AppIcon(AppIcons.downloadRounded, size: 17),
      label: const Text('Download PDF',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ── Weekly PDF download button ────────────────────────────────────────────────
class _WeeklyPdfButton extends ConsumerStatefulWidget {
  final DateTime weekStart;
  final String? branchId;
  final String periodLabel;
  final String fileKey;
  final String? aiReport;
  const _WeeklyPdfButton({
    required this.weekStart, this.branchId,
    required this.periodLabel, required this.fileKey, this.aiReport,
  });
  @override
  ConsumerState<_WeeklyPdfButton> createState() => _WeeklyPdfButtonState();
}

class _WeeklyPdfButtonState extends ConsumerState<_WeeklyPdfButton> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final empsAsync   = ref.watch(employeesProvider);
    final monthAsync  = ref.watch(
        attendanceByMonthProvider((year: widget.weekStart.year, month: widget.weekStart.month)));
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    final emps = (empsAsync.valueOrNull ?? [])
        .where((e) => e.isActive && (widget.branchId == null || e.branchId == widget.branchId))
        .toList();
    final weekEnd  = widget.weekStart.add(const Duration(days: 6));
    final weekDays = List.generate(5, (i) => widget.weekStart.add(Duration(days: i)));
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final allRecs = monthAsync.valueOrNull ?? [];
    final weekRecs = allRecs.where((r) {
      final d = r.date;
      return !d.isBefore(widget.weekStart) && !d.isAfter(weekEnd) &&
          (widget.branchId == null || r.branchId == widget.branchId);
    }).toList();

    int totalPresent = 0, totalLate = 0;
    final dayStatMap = <int, (int, int)>{};
    for (final r in weekRecs) {
      if (_wasPresent(r, wet)) {
        totalPresent++;
        if (r.isLate) totalLate++;
        final wd  = r.date.weekday;
        final prev = dayStatMap[wd] ?? (0, 0);
        dayStatMap[wd] = (prev.$1 + 1, prev.$2 + (r.isLate ? 1 : 0));
      }
    }
    final maxPossible = 5 * (emps.isEmpty ? 1 : emps.length);
    final avgRate = maxPossible > 0 ? ((totalPresent / maxPossible) * 100).round() : 0;
    final dayStats = List.generate(5, (i) {
      final present = dayStatMap[weekDays[i].weekday]?.$1 ?? 0;
      return (dayLabels[i], present, emps.isEmpty ? 1 : emps.length);
    });

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _downloading ? null : () async {
        setState(() => _downloading = true);
        try {
          String? branchName;
          if (widget.branchId != null) {
            final branches = ref.read(branchesStreamProvider).valueOrNull ?? [];
            branchName = branches.firstWhere((b) => b.id == widget.branchId,
                orElse: () => branches.first).name;
          }
          await WeeklyReportPdfService.download(
            companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
            period: widget.periodLabel,
            fileKey: widget.fileKey,
            totalActive: emps.length,
            totalPresent: totalPresent,
            totalLate: totalLate,
            avgRate: avgRate,
            dayStats: dayStats,
            aiReport: widget.aiReport,
            branchName: branchName,
          );
        } finally {
          if (mounted) setState(() => _downloading = false);
        }
      },
      icon: _downloading
          ? const SizedBox(width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const AppIcon(AppIcons.downloadRounded, size: 17),
      label: const Text('Download PDF',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ── Monthly PDF download button ───────────────────────────────────────────────
class _MonthlyPdfButton extends ConsumerStatefulWidget {
  final DateTime month;
  final String? branchId;
  final String? aiReport;
  const _MonthlyPdfButton({required this.month, this.branchId, this.aiReport});
  @override
  ConsumerState<_MonthlyPdfButton> createState() => _MonthlyPdfButtonState();
}

class _MonthlyPdfButtonState extends ConsumerState<_MonthlyPdfButton> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final monthKey   = DateFormat('yyyy-MM').format(widget.month);
    final attAsync   = ref.watch(
        attendanceByMonthProvider((year: widget.month.year, month: widget.month.month)));
    final leavesAsync  = ref.watch(allLeaveRequestsProvider);
    final payrollAsync = ref.watch(payrollRunByMonthProvider(monthKey));
    final empsAsync    = ref.watch(employeesProvider);
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    final totalActive = (empsAsync.valueOrNull ?? [])
        .where((e) => e.isActive && (widget.branchId == null || e.branchId == widget.branchId))
        .length;
    final allRecords = attAsync.valueOrNull ?? [];
    final records    = widget.branchId != null
        ? allRecords.where((r) => r.branchId == widget.branchId).toList()
        : allRecords;
    final present = records.where((r) => _wasPresent(r, wet)).length;
    final late    = records.where((r) => r.isLate && _wasPresent(r, wet)).length;

    final now    = DateTime.now();
    final lastDay = (widget.month.year == now.year && widget.month.month == now.month)
        ? now.day
        : DateUtils.getDaysInMonth(widget.month.year, widget.month.month);
    int workDays = 0;
    for (int d = 1; d <= lastDay; d++) {
      if (DateTime(widget.month.year, widget.month.month, d).weekday <= 5) workDays++;
    }
    final maxPossible = workDays * (totalActive == 0 ? 1 : totalActive);
    final rate = maxPossible > 0 ? ((present / maxPossible) * 100).round() : 0;
    final absent = (workDays * totalActive - present).clamp(0, workDays * totalActive);

    final allLeaves = (leavesAsync.valueOrNull ?? []).where((l) =>
        l.status == 'approved' &&
        l.startDate.year == widget.month.year &&
        l.startDate.month == widget.month.month).toList();
    final leaveByType = <String, int>{};
    for (final l in allLeaves) {
      leaveByType[l.leaveType] = (leaveByType[l.leaveType] ?? 0) + l.totalDays;
    }

    final payrollRun  = payrollAsync.valueOrNull;
    final totalGross  = payrollRun?.totalGross ?? 0.0;
    final payrollCount = payrollRun?.employeeCount ?? 0;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _downloading ? null : () async {
        setState(() => _downloading = true);
        try {
          String? branchName;
          if (widget.branchId != null) {
            final branches = ref.read(branchesStreamProvider).valueOrNull ?? [];
            branchName = branches.firstWhere((b) => b.id == widget.branchId,
                orElse: () => branches.first).name;
          }
          await MonthlyReportPdfService.download(
            companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
            month: monthKey,
            totalActive: totalActive,
            present: present, late: late,
            absent: absent, workDays: workDays, rate: rate,
            leaveByType: leaveByType,
            totalGross: totalGross,
            payrollCount: payrollCount,
            aiReport: widget.aiReport,
            branchName: branchName,
          );
        } finally {
          if (mounted) setState(() => _downloading = false);
        }
      },
      icon: _downloading
          ? const SizedBox(width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const AppIcon(AppIcons.downloadRounded, size: 17),
      label: const Text('Download PDF',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
            AppIcon(AppIcons.calendarTodayRounded, size: 14, color: context.appSubtext),
            const SizedBox(width: 6),
            Text(
              isToday ? 'Today' : DateFormat('d MMM yyyy').format(date),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText),
            ),
            const SizedBox(width: 4),
            AppIcon(AppIcons.expandMoreRounded, size: 14, color: context.appSubtext),
          ],
        ),
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
          const AppIcon(AppIcons.errorOutlineRounded, color: AppColors.errorRed, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(clean.isNotEmpty ? clean : 'Something went wrong.', style: const TextStyle(fontSize: 12, color: AppColors.errorRed))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE REPORT TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _AttendanceReportTab extends ConsumerStatefulWidget {
  const _AttendanceReportTab();
  @override
  ConsumerState<_AttendanceReportTab> createState() => _AttendanceReportTabState();
}

class _AttendanceReportTabState extends ConsumerState<_AttendanceReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _branchId;
  bool _downloading = false;

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final attAsync = ref.watch(
        attendanceByMonthProvider((year: _month.year, month: _month.month)));
    final empsAsync = ref.watch(employeesProvider);
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    final monthKey = DateFormat('yyyy-MM').format(_month);
    final attAiState = ref.watch(reportNotifierProvider('attendance'));
    final attAiNotifier = ref.read(reportNotifierProvider('attendance').notifier);
    final monthlyDocs = ref.watch(reportsStreamProvider('monthly')).valueOrNull ?? [];

    final allEmps = empsAsync.valueOrNull ?? [];
    final emps = allEmps
        .where((e) => e.isActive && (_branchId == null || e.branchId == _branchId))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final allRecords = attAsync.valueOrNull ?? [];
    final records = _branchId != null
        ? allRecords.where((r) => r.branchId == _branchId).toList()
        : allRecords;

    bool isPresent(AttendanceModel r) =>
        r.checkInTime != null && r.checkInTime!.isBefore(_endOfWorkDt(r.date, wet));

    final totalDays = records.isNotEmpty ? records.map((r) => r.date).toSet().length : 0;
    final presentCount = records.where((r) => isPresent(r)).length;
    final lateCount = records.where((r) => r.isLate && isPresent(r)).length;
    final absentCount = (totalDays * emps.length - presentCount).clamp(0, totalDays * emps.length);
    final rate = (totalDays * emps.length) > 0
        ? ((presentCount / (totalDays * emps.length)) * 100).round()
        : 0;

    // Per-employee summary
    final byEmp = <String, List<AttendanceModel>>{};
    for (final r in records) {
      byEmp.putIfAbsent(r.employeeId, () => []).add(r);
    }

    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('d MMM');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Controls ──────────────────────────────────────────────────────
          Row(children: [
            if (_showBranchFilter) ...[
              _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
              const SizedBox(width: 10),
            ],
            _MonthNav(
              month: _month,
              onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: _month.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                  : null,
            ),
            const Spacer(),
            _GenButton(
              loading: attAiState.loading,
              onTap: () => attAiNotifier.generateAttendance(month: monthKey, branchId: _branchId),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (attAsync.isLoading || empsAsync.isLoading || _downloading)
                  ? null
                  : () async {
                      setState(() => _downloading = true);
                      try {
                        final branches = ref.read(branchesStreamProvider).valueOrNull ?? [];
                        final branchName = _branchId != null
                            ? branches.firstWhere((b) => b.id == _branchId,
                                    orElse: () => branches.first).name
                            : null;
                        await AttendancePdfService.download(
                          companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
                          period: monthLabel,
                          employees: emps,
                          records: records,
                          workEndTime: wet,
                          branchName: branchName,
                        );
                      } finally {
                        if (mounted) setState(() => _downloading = false);
                      }
                    },
              icon: _downloading
                  ? const SizedBox(width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const AppIcon(AppIcons.downloadRounded, size: 17),
              label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),

          const SizedBox(height: 12),
          Builder(builder: (_) {
            final sd = monthlyDocs.firstWhere(
              (d) => (d['month'] as String?) == monthKey,
              orElse: () => monthlyDocs.isNotEmpty ? monthlyDocs.first : <String, dynamic>{},
            );
            return _AiSummaryPanel(
              loading: attAiState.loading,
              error: attAiState.error,
              freshReport: attAiState.report,
              savedDoc: sd.isNotEmpty ? sd : null,
              periodLabel: monthLabel,
              onGenerate: () => attAiNotifier.generateAttendance(month: monthKey, branchId: _branchId),
            );
          }),

          const SizedBox(height: 20),

          // ── Summary stat cards ─────────────────────────────────────────────
          if (attAsync.isLoading || empsAsync.isLoading)
            const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primaryBlue)))
          else ...[
            _SectionLabel('Summary — $monthLabel'),
            const SizedBox(height: 10),
            Row(children: [
              _StatTile(label: 'Employees', value: '${emps.length}',
                  color: AppColors.primaryBlue, icon: AppIcons.peopleRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Working Days', value: '$totalDays',
                  color: const Color(0xFF8B5CF6), icon: AppIcons.calendarMonthRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Att. Rate', value: '$rate%',
                  color: rate >= 80 ? AppColors.successGreen : rate >= 60 ? AppColors.warningAmber : AppColors.errorRed,
                  icon: AppIcons.trendingUpRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Present', value: '$presentCount',
                  color: AppColors.successGreen, icon: AppIcons.checkCircleRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Late', value: '$lateCount',
                  color: AppColors.warningAmber, icon: AppIcons.scheduleRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Absent', value: '$absentCount',
                  color: AppColors.errorRed, icon: AppIcons.cancelRounded),
            ]),

            const SizedBox(height: 16),

            // ── Analysis charts ────────────────────────────────────────────
            Builder(builder: (_) {
              // Build per-day data for trend chart
              final byDay = <int, (int, int)>{};
              for (final r in records) {
                final d = r.date.day;
                final prev = byDay[d] ?? (0, 0);
                byDay[d] = (
                  prev.$1 + (isPresent(r) ? 1 : 0),
                  prev.$2 + 1,
                );
              }
              final sortedDays = byDay.keys.toList()..sort();
              final trendDays = sortedDays.map((d) =>
                ('$d', byDay[d]!.$1, emps.isEmpty ? 1 : emps.length)).toList();

              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 4,
                  child: _DonutChart(
                    title: 'Status Breakdown',
                    segments: [
                      ('On Time', presentCount - lateCount, AppColors.successGreen),
                      ('Late', lateCount, AppColors.warningAmber),
                      ('Absent', absentCount, AppColors.errorRed),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: _TrendBarChart(
                    title: 'Daily Attendance Rate — $monthLabel',
                    days: trendDays,
                  ),
                ),
              ]);
            }),

            const SizedBox(height: 24),

            // ── Employee breakdown table ────────────────────────────────────
            _SectionLabel('Employee Attendance Breakdown'),
            const SizedBox(height: 10),
            Container(
              decoration: context.cardDeco(),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    _TH('Employee', flex: 3),
                    _TH('Department', flex: 2),
                    _TH('Present', flex: 1),
                    _TH('Late', flex: 1),
                    _TH('Absent', flex: 1),
                    _TH('Rate', flex: 1),
                    _TH('Avg Check-in', flex: 2),
                  ]),
                ),
                if (emps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No employee data for this period.',
                        style: TextStyle(color: context.appSubtext, fontSize: 13)),
                  )
                else
                  ...emps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final emp = entry.value;
                    final recs = byEmp[emp.id] ?? [];
                    final pres = recs.where((r) => isPresent(r)).length;
                    final late = recs.where((r) => r.isLate && isPresent(r)).length;
                    final absent = (totalDays - pres).clamp(0, totalDays);
                    final empRate = totalDays > 0 ? ((pres / totalDays) * 100).round() : 0;
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
                    final rateColor = empRate >= 80
                        ? AppColors.successGreen
                        : empRate >= 60
                            ? AppColors.warningAmber
                            : AppColors.errorRed;
                    return Container(
                      decoration: BoxDecoration(
                        color: i.isEven ? Colors.transparent : context.appBg.withAlpha(80),
                        border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(emp.fullName,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText))),
                        Expanded(flex: 2, child: Text(emp.department,
                            style: TextStyle(fontSize: 12, color: context.appSubtext))),
                        Expanded(flex: 1, child: Text('$pres',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.successGreen))),
                        Expanded(flex: 1, child: Text('$late',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.warningAmber))),
                        Expanded(flex: 1, child: Text('$absent',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                color: absent > 0 ? AppColors.errorRed : context.appSubtext))),
                        Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: rateColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$empRate%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: rateColor)),
                        ))),
                        Expanded(flex: 2, child: Text(avgCheckIn,
                            style: TextStyle(fontSize: 12, color: context.appSubtext))),
                      ]),
                    );
                  }),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Daily log ──────────────────────────────────────────────────
            _SectionLabel('Daily Attendance Log'),
            const SizedBox(height: 10),
            Container(
              decoration: context.cardDeco(),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    _TH('Employee', flex: 3),
                    _TH('Date', flex: 2),
                    _TH('Status', flex: 2),
                    _TH('Check-In', flex: 2),
                    _TH('Check-Out', flex: 2),
                  ]),
                ),
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No attendance records for this period.',
                        style: TextStyle(color: context.appSubtext, fontSize: 13)),
                  )
                else
                  ...(() {
                    final sorted = List<AttendanceModel>.from(records)
                      ..sort((a, b) {
                        final eA = emps.firstWhere((e) => e.id == a.employeeId,
                            orElse: () => emps.first);
                        final eB = emps.firstWhere((e) => e.id == b.employeeId,
                            orElse: () => emps.first);
                        final c = eA.fullName.compareTo(eB.fullName);
                        return c != 0 ? c : a.date.compareTo(b.date);
                      });
                    return sorted.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      final emp = emps.firstWhere((e) => e.id == r.employeeId,
                          orElse: () => emps.first);
                      final present = isPresent(r);
                      String status;
                      Color statusColor;
                      if (r.isOnLeave) {
                        status = 'On Leave';
                        statusColor = AppColors.primaryBlue;
                      } else if (present && r.isLate) {
                        status = 'Late';
                        statusColor = AppColors.warningAmber;
                      } else if (present) {
                        status = 'Present';
                        statusColor = AppColors.successGreen;
                      } else {
                        status = 'Absent';
                        statusColor = AppColors.errorRed;
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: i.isEven ? Colors.transparent : context.appBg.withAlpha(80),
                          border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(emp.fullName,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.appText))),
                          Expanded(flex: 2, child: Text(dateFmt.format(r.date),
                              style: TextStyle(fontSize: 12, color: context.appSubtext))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(18),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(status,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
                          ))),
                          Expanded(flex: 2, child: Text(
                              r.checkInTime != null ? timeFmt.format(r.checkInTime!) : '—',
                              style: TextStyle(fontSize: 12, color: context.appSubtext))),
                          Expanded(flex: 2, child: Text(
                              r.checkOutTime != null ? timeFmt.format(r.checkOutTime!) : '—',
                              style: TextStyle(fontSize: 12, color: context.appSubtext))),
                        ]),
                      );
                    });
                  })(),
              ]),
            ),

          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE REPORT TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _PerformanceReportTab extends ConsumerStatefulWidget {
  const _PerformanceReportTab();
  @override
  ConsumerState<_PerformanceReportTab> createState() => _PerformanceReportTabState();
}

class _PerformanceReportTabState extends ConsumerState<_PerformanceReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _branchId;
  bool _downloading = false;

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = DateFormat('yyyy-MM').format(_month);
    final perfAsync = ref.watch(performanceByMonthProvider(monthKey));
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    final perfAiState = ref.watch(reportNotifierProvider('performance'));
    final perfAiNotifier = ref.read(reportNotifierProvider('performance').notifier);
    final perfDocs = ref.watch(reportsStreamProvider('performance')).valueOrNull ?? [];

    final allRecords = perfAsync.valueOrNull ?? [];
    final records = _branchId != null
        ? allRecords.where((r) => r.branchId == _branchId).toList()
        : allRecords;

    final sorted = List<PerformanceModel>.from(records)
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));

    final avg = records.isEmpty
        ? 0.0
        : records.fold(0.0, (s, r) => s + r.overallScore) / records.length;

    final excellent = records.where((r) => r.overallScore >= 4.5).length;
    final good = records.where((r) => r.overallScore >= 3.0 && r.overallScore < 4.5).length;
    final poor = records.where((r) => r.overallScore < 3.0).length;

    // All criteria
    final allCriteria = <String>{};
    for (final r in records) { allCriteria.addAll(r.scores.keys); }
    final criteriaList = allCriteria.toList()..sort();

    // Criteria auto-computed by system (shown with "Auto" badge)
    final autoKeys = <String>{};
    for (final r in records) { autoKeys.addAll(r.systemScoredKeys); }

    Color scoreColor(double s) {
      if (s >= 4.0) return AppColors.successGreen;
      if (s >= 3.0) return AppColors.warningAmber;
      return AppColors.errorRed;
    }

    String ratingLabel(double s) {
      if (s >= 4.5) return 'Excellent';
      if (s >= 4.0) return 'Very Good';
      if (s >= 3.0) return 'Good';
      if (s >= 2.0) return 'Needs Improvement';
      return 'Poor';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls
          Row(children: [
            if (_showBranchFilter) ...[
              _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
              const SizedBox(width: 10),
            ],
            _MonthNav(
              month: _month,
              onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: _month.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                  : null,
            ),
            const Spacer(),
            _GenButton(
              loading: perfAiState.loading,
              onTap: () => perfAiNotifier.generatePerformance(month: monthKey, branchId: _branchId),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (perfAsync.isLoading || _downloading || records.isEmpty)
                  ? null
                  : () async {
                      setState(() => _downloading = true);
                      try {
                        final branches = ref.read(branchesStreamProvider).valueOrNull ?? [];
                        final branchName = _branchId != null
                            ? branches.firstWhere((b) => b.id == _branchId,
                                    orElse: () => branches.first).name
                            : null;
                        await PerformanceReportPdfService.download(
                          companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
                          month: monthKey,
                          records: records,
                          branchName: branchName,
                        );
                      } finally {
                        if (mounted) setState(() => _downloading = false);
                      }
                    },
              icon: _downloading
                  ? const SizedBox(width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const AppIcon(AppIcons.downloadRounded, size: 17),
              label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),

          const SizedBox(height: 12),
          Builder(builder: (_) {
            final sd = perfDocs.firstWhere(
              (d) => (d['month'] as String?) == monthKey,
              orElse: () => perfDocs.isNotEmpty ? perfDocs.first : <String, dynamic>{},
            );
            return _AiSummaryPanel(
              loading: perfAiState.loading,
              error: perfAiState.error,
              freshReport: perfAiState.report,
              savedDoc: sd.isNotEmpty ? sd : null,
              periodLabel: monthLabel,
              onGenerate: () => perfAiNotifier.generatePerformance(month: monthKey, branchId: _branchId),
            );
          }),

          const SizedBox(height: 20),

          if (perfAsync.isLoading)
            const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primaryBlue)))
          else if (records.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: Column(children: [
                  AppIcon(AppIcons.leaderboardRounded, size: 48, color: context.appSubtext),
                  const SizedBox(height: 12),
                  Text('No performance reviews for $monthLabel',
                      style: TextStyle(fontSize: 14, color: context.appSubtext)),
                ]),
              ),
            )
          else ...[
            // Summary cards
            _SectionLabel('Performance Summary — $monthLabel'),
            const SizedBox(height: 10),
            Row(children: [
              _StatTile(label: 'Reviewed', value: '${records.length}',
                  color: AppColors.primaryBlue, icon: AppIcons.peopleRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Avg Score', value: avg.toStringAsFixed(1),
                  color: scoreColor(avg), icon: AppIcons.starRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Excellent ≥4.5', value: '$excellent',
                  color: AppColors.successGreen, icon: AppIcons.emojiEventsRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Good 3–4.5', value: '$good',
                  color: AppColors.warningAmber, icon: AppIcons.thumbUpRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Needs Work <3', value: '$poor',
                  color: AppColors.errorRed, icon: AppIcons.trendingDownRounded),
            ]),

            const SizedBox(height: 16),

            // ── Analysis charts ────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 4,
                child: _DonutChart(
                  title: 'Rating Distribution',
                  segments: [
                    ('Excellent (≥4.5)', excellent, AppColors.successGreen),
                    ('Good (3–4.5)', good, AppColors.warningAmber),
                    ('Needs Work (<3)', poor, AppColors.errorRed),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _HorizBars(
                  title: 'Top Performers — Overall Score',
                  items: sorted.take(8).map((r) {
                    final c = scoreColor(r.overallScore);
                    return (r.employeeName, r.overallScore, 5.0, c);
                  }).toList(),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // Scores table
            _SectionLabel('Employee Performance Scores — Ranked'),
            const SizedBox(height: 10),
            Container(
              decoration: context.cardDeco(),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    _TH('#', flex: 1),
                    _TH('Employee', flex: 3),
                    _TH('Department', flex: 2),
                    _TH('Score', flex: 1),
                    _TH('Rating', flex: 2),
                    ...criteriaList.map((c) => autoKeys.contains(c)
                        ? Expanded(
                            flex: 2,
                            child: Row(children: [
                              Flexible(child: Text(c,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.appSubtext),
                                  overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Auto',
                                    style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          )
                        : _TH(c, flex: 2)),
                  ]),
                ),
                ...sorted.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final r = entry.value;
                  final color = scoreColor(r.overallScore);
                  final isMedal = rank <= 3;
                  final medalColors = [
                    const Color(0xFFFFD700), // gold
                    const Color(0xFFC0C0C0), // silver
                    const Color(0xFFCD7F32), // bronze
                  ];
                  return Container(
                    decoration: BoxDecoration(
                      color: entry.key.isEven ? Colors.transparent : context.appBg.withAlpha(80),
                      border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 1, child: isMedal
                          ? AppIcon(AppIcons.emojiEventsRounded, color: medalColors[rank - 1], size: 16)
                          : Text('$rank', style: TextStyle(fontSize: 12, color: context.appSubtext))),
                      Expanded(flex: 3, child: Text(r.employeeName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText))),
                      Expanded(flex: 2, child: Text(r.department,
                          style: TextStyle(fontSize: 12, color: context.appSubtext))),
                      Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(r.overallScore.toStringAsFixed(1),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                      ))),
                      Expanded(flex: 2, child: Text(ratingLabel(r.overallScore),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color))),
                      ...criteriaList.map((c) {
                        final score = r.scores[c];
                        return Expanded(flex: 2, child: score != null
                            ? Text(score.toStringAsFixed(1),
                                style: TextStyle(fontSize: 12, color: scoreColor(score),
                                    fontWeight: FontWeight.w500))
                            : Text('—', style: TextStyle(fontSize: 12, color: context.appSubtext)));
                      }),
                    ]),
                  );
                }),
              ]),
            ),

            // AI Reviews
            if (sorted.any((r) => r.aiReview != null && r.aiReview!.isNotEmpty)) ...[
              const SizedBox(height: 24),
              _SectionLabel('AI Performance Reviews'),
              const SizedBox(height: 10),
              ...sorted
                  .where((r) => r.aiReview != null && r.aiReview!.isNotEmpty)
                  .map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: context.cardDeco(),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(r.employeeName,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: context.appText)),
                            ),
                            Text(r.department,
                                style: TextStyle(fontSize: 11, color: context.appSubtext)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scoreColor(r.overallScore).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                  '${r.overallScore.toStringAsFixed(1)} · ${ratingLabel(r.overallScore)}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: scoreColor(r.overallScore))),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(r.aiReview!,
                              style: TextStyle(fontSize: 13, color: context.appText, height: 1.6)),
                          if (r.managerNotes != null && r.managerNotes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const AppIcon(AppIcons.commentRounded, size: 13, color: AppColors.primaryBlue),
                                const SizedBox(width: 6),
                                Expanded(child: Text('Manager: ${r.managerNotes}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue))),
                              ]),
                            ),
                          ],
                        ]),
                      )),
            ],
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRANCHES REPORT TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _BranchesReportTab extends ConsumerStatefulWidget {
  const _BranchesReportTab();
  @override
  ConsumerState<_BranchesReportTab> createState() => _BranchesReportTabState();
}

class _BranchesReportTabState extends ConsumerState<_BranchesReportTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final attAsync = ref.watch(
        attendanceByMonthProvider((year: _month.year, month: _month.month)));
    final empsAsync = ref.watch(employeesProvider);
    final branchesAsync = ref.watch(branchesStreamProvider);
    final wet = ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    final monthKey = DateFormat('yyyy-MM').format(_month);
    final payrollAsync = ref.watch(payrollRunByMonthProvider(monthKey));
    final branchAiState = ref.watch(reportNotifierProvider('branches'));
    final branchAiNotifier = ref.read(reportNotifierProvider('branches').notifier);
    final branchDocs = ref.watch(reportsStreamProvider('monthly')).valueOrNull ?? [];

    final branches = (branchesAsync.valueOrNull ?? [])
        .where((b) => b.isActive)
        .toList();
    final allEmps = empsAsync.valueOrNull ?? [];
    final allRecords = attAsync.valueOrNull ?? [];

    bool isPresent(AttendanceModel r) =>
        r.checkInTime != null && r.checkInTime!.isBefore(_endOfWorkDt(r.date, wet));

    final totalDays = allRecords.isNotEmpty
        ? allRecords.map((r) => r.date).toSet().length
        : 0;

    // Per-branch stats
    final rwfFmt = NumberFormat('#,###');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls
          Row(children: [
            _MonthNav(
              month: _month,
              onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: _month.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                  : null,
            ),
            const Spacer(),
            _GenButton(
              loading: branchAiState.loading,
              onTap: () => branchAiNotifier.generateBranches(month: monthKey),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (attAsync.isLoading || empsAsync.isLoading || branchesAsync.isLoading || _downloading)
                  ? null
                  : () async {
                      setState(() => _downloading = true);
                      try {
                        final payrollRun = payrollAsync.valueOrNull;
                        // Distribute payroll proportionally by employee count per branch
                        final totalEmpCount = allEmps.where((e) => e.isActive).length;
                        final payrollByBranch = <String, double>{};
                        if (payrollRun != null && totalEmpCount > 0) {
                          for (final b in branches) {
                            final cnt = allEmps.where((e) => e.isActive && e.branchId == b.id).length;
                            payrollByBranch[b.id] = (cnt / totalEmpCount) * payrollRun.totalGross;
                          }
                        }
                        await BranchesReportPdfService.download(
                          companyName: ref.read(companySettingsProvider).value?.companyName ?? 'HRNovva',
                          period: monthLabel,
                          branches: branches,
                          employees: allEmps,
                          records: allRecords,
                          workEndTime: wet,
                          payrollByBranch: payrollByBranch,
                        );
                      } finally {
                        if (mounted) setState(() => _downloading = false);
                      }
                    },
              icon: _downloading
                  ? const SizedBox(width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const AppIcon(AppIcons.downloadRounded, size: 17),
              label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),

          const SizedBox(height: 12),
          Builder(builder: (_) {
            final sd = branchDocs.firstWhere(
              (d) => (d['month'] as String?) == monthKey,
              orElse: () => branchDocs.isNotEmpty ? branchDocs.first : <String, dynamic>{},
            );
            return _AiSummaryPanel(
              loading: branchAiState.loading,
              error: branchAiState.error,
              freshReport: branchAiState.report,
              savedDoc: sd.isNotEmpty ? sd : null,
              periodLabel: monthLabel,
              onGenerate: () => branchAiNotifier.generateBranches(month: monthKey),
            );
          }),

          const SizedBox(height: 20),

          if (attAsync.isLoading || empsAsync.isLoading || branchesAsync.isLoading)
            const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primaryBlue)))
          else if (branches.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: Column(children: [
                  AppIcon(AppIcons.accountTreeRounded, size: 48, color: context.appSubtext),
                  const SizedBox(height: 12),
                  Text('No branches found.',
                      style: TextStyle(fontSize: 14, color: context.appSubtext)),
                ]),
              ),
            )
          else ...[
            // Company overview stats
            _SectionLabel('Company Overview — $monthLabel'),
            const SizedBox(height: 10),
            Row(children: [
              _StatTile(label: 'Branches', value: '${branches.length}',
                  color: AppColors.primaryBlue, icon: AppIcons.accountTreeRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Active\nEmployees', value: '${allEmps.where((e) => e.isActive).length}',
                  color: const Color(0xFF8B5CF6), icon: AppIcons.peopleRounded),
              const SizedBox(width: 8),
              _StatTile(label: 'Working\nDays', value: '$totalDays',
                  color: const Color(0xFF06B6D4), icon: AppIcons.calendarMonthRounded),
              const SizedBox(width: 8),
              _StatTile(
                  label: 'Total\nPresent',
                  value: '${allRecords.where((r) => isPresent(r)).length}',
                  color: AppColors.successGreen,
                  icon: AppIcons.checkCircleRounded),
              if (payrollAsync.valueOrNull != null) ...[
                const SizedBox(width: 8),
                _StatTile(
                    label: 'Payroll\nTotal',
                    value: 'RWF\n${rwfFmt.format(payrollAsync.valueOrNull!.totalGross.round())}',
                    color: AppColors.warningAmber,
                    icon: AppIcons.paymentsRounded),
              ],
            ]),

            const SizedBox(height: 24),

            // ── Branch charts ──────────────────────────────────────────────
            Builder(builder: (_) {
              final branchItems = branches.map((b) {
                final empCount = allEmps.where((e) => e.isActive && e.branchId == b.id).length;
                final brRecs = allRecords.where((r) => r.branchId == b.id).toList();
                final pres = brRecs.where((r) => isPresent(r)).length;
                final maxP = totalDays * (empCount == 0 ? 1 : empCount);
                final rate = maxP > 0 ? (pres / maxP * 100).roundToDouble() : 0.0;
                final c = rate >= 80 ? AppColors.successGreen : rate >= 60 ? AppColors.warningAmber : AppColors.errorRed;
                return (b.name, rate, 100.0, c);
              }).toList();

              final empItems = branches.map((b) {
                final cnt = allEmps.where((e) => e.isActive && e.branchId == b.id).length.toDouble();
                final totalActive = allEmps.where((e) => e.isActive).length;
                return (b.name, cnt, totalActive == 0 ? 1.0 : totalActive.toDouble(), AppColors.primaryBlue);
              }).toList();

              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _HorizBars(
                    title: 'Attendance Rate by Branch',
                    items: branchItems,
                    unit: '%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HorizBars(
                    title: 'Employee Count by Branch',
                    items: empItems,
                  ),
                ),
              ]);
            }),

            const SizedBox(height: 20),

            // Branch comparison table
            _SectionLabel('Branch Performance Comparison'),
            const SizedBox(height: 10),
            Container(
              decoration: context.cardDeco(),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    _TH('Branch', flex: 3),
                    _TH('Employees', flex: 2),
                    _TH('Present', flex: 1),
                    _TH('Late', flex: 1),
                    _TH('Absent', flex: 1),
                    _TH('Att. Rate', flex: 2),
                    _TH('Location', flex: 2),
                  ]),
                ),
                ...branches.asMap().entries.map((entry) {
                  final i = entry.key;
                  final b = entry.value;
                  final empCount = allEmps.where((e) => e.isActive && e.branchId == b.id).length;
                  final brRecs = allRecords.where((r) => r.branchId == b.id).toList();
                  final present = brRecs.where((r) => isPresent(r)).length;
                  final late = brRecs.where((r) => r.isLate && isPresent(r)).length;
                  final maxP = totalDays * (empCount == 0 ? 1 : empCount);
                  final absent = (maxP - present).clamp(0, maxP);
                  final rate = maxP > 0 ? ((present / maxP) * 100).round() : 0;
                  final rateColor = rate >= 80
                      ? AppColors.successGreen
                      : rate >= 60
                          ? AppColors.warningAmber
                          : AppColors.errorRed;

                  return Container(
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.transparent : context.appBg.withAlpha(80),
                      border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(b.name,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText))),
                      Expanded(flex: 2, child: Text('$empCount',
                          style: TextStyle(fontSize: 13, color: context.appSubtext))),
                      Expanded(flex: 1, child: Text('$present',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.successGreen))),
                      Expanded(flex: 1, child: Text('$late',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.warningAmber))),
                      Expanded(flex: 1, child: Text('$absent',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                              color: absent > 0 ? AppColors.errorRed : context.appSubtext))),
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: rateColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$rate%',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rateColor)),
                      ))),
                      Expanded(flex: 2, child: Text(b.location.isNotEmpty ? b.location : '—',
                          style: TextStyle(fontSize: 11, color: context.appSubtext))),
                    ]),
                  );
                }),
                // Totals footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    border: Border(top: BorderSide(color: context.appBorder, width: 1)),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('TOTAL',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.appText))),
                    Expanded(flex: 2, child: Text('${allEmps.where((e) => e.isActive).length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appText))),
                    Expanded(flex: 1, child: Text('${allRecords.where((r) => isPresent(r)).length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successGreen))),
                    Expanded(flex: 1, child: Text('${allRecords.where((r) => r.isLate && isPresent(r)).length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningAmber))),
                    Expanded(flex: 1, child: Text('—', style: TextStyle(fontSize: 12, color: context.appSubtext))),
                    Expanded(flex: 2, child: const SizedBox()),
                    Expanded(flex: 2, child: const SizedBox()),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // Per-branch employee roster
            _SectionLabel('Employee Roster by Branch'),
            const SizedBox(height: 10),
            ...branches.map((b) {
              final branchEmps = allEmps
                  .where((e) => e.isActive && e.branchId == b.id)
                  .toList()
                ..sort((a, c) => a.fullName.compareTo(c.fullName));
              if (branchEmps.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                    ),
                    child: Row(children: [
                      const AppIcon(AppIcons.businessRounded, color: AppColors.primaryBlue, size: 14),
                      const SizedBox(width: 8),
                      Text(b.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue)),
                      const SizedBox(width: 8),
                      Text('${branchEmps.length} employees',
                          style: TextStyle(fontSize: 12, color: context.appSubtext)),
                      if (b.location.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('• ${b.location}',
                            style: TextStyle(fontSize: 11, color: context.appSubtext)),
                      ],
                    ]),
                  ),
                  Container(
                    decoration: context.cardDeco(),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.appTint,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Row(children: [
                          _TH('#', flex: 1),
                          _TH('Name', flex: 3),
                          _TH('Department', flex: 2),
                          _TH('Job Title', flex: 2),
                          _TH('Salary Type', flex: 2),
                          _TH('Contract', flex: 2),
                        ]),
                      ),
                      ...branchEmps.asMap().entries.map((entry) {
                        final i = entry.key;
                        final emp = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: i.isEven ? Colors.transparent : context.appBg.withAlpha(80),
                            border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
                          ),
                          child: Row(children: [
                            Expanded(flex: 1, child: Text('${i + 1}',
                                style: TextStyle(fontSize: 11, color: context.appSubtext))),
                            Expanded(flex: 3, child: Text(emp.fullName,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.appText))),
                            Expanded(flex: 2, child: Text(emp.department,
                                style: TextStyle(fontSize: 11, color: context.appSubtext))),
                            Expanded(flex: 2, child: Text(emp.jobTitle,
                                style: TextStyle(fontSize: 11, color: context.appSubtext))),
                            Expanded(flex: 2, child: Text(_salaryTypeLabel(emp.salaryType),
                                style: TextStyle(fontSize: 11, color: context.appSubtext))),
                            Expanded(flex: 2, child: Text(_contractLabel(emp.contractType),
                                style: TextStyle(fontSize: 11, color: context.appSubtext))),
                          ]),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHART WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Donut pie chart with legend. segments = (label, value, color)
class _DonutChart extends StatelessWidget {
  final List<(String, int, Color)> segments;
  final String title;
  const _DonutChart({required this.segments, required this.title});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0, (s, e) => s + e.$2);
    return Container(
      decoration: context.cardDeco(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText)),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: total == 0
              ? Center(child: Text('No data', style: TextStyle(color: context.appSubtext, fontSize: 13)))
              : Row(children: [
                  Expanded(
                    flex: 5,
                    child: PieChart(
                      PieChartData(
                        sections: segments.map((s) => PieChartSectionData(
                          value: s.$2.toDouble(),
                          color: s.$3,
                          radius: 46,
                          title: '',
                          showTitle: false,
                        )).toList(),
                        centerSpaceRadius: 38,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: segments.map((s) {
                        final pct = total > 0 ? (s.$2 / total * 100).round() : 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Container(width: 10, height: 10,
                                decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(5))),
                            const SizedBox(width: 7),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.$1, style: TextStyle(fontSize: 10, color: context.appSubtext)),
                                Text('${s.$2}  ($pct%)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                        color: context.appText)),
                              ],
                            )),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }
}

/// Vertical bar chart — days: (label, present, total)
class _TrendBarChart extends StatelessWidget {
  final List<(String, int, int)> days;
  final String title;
  final Color barColor;
  const _TrendBarChart({required this.days, required this.title, this.barColor = AppColors.primaryBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.cardDeco(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: days.isEmpty
              ? Center(child: Text('No data', style: TextStyle(color: context.appSubtext, fontSize: 13)))
              : BarChart(BarChartData(
                  maxY: 100,
                  minY: 0,
                  barGroups: days.asMap().entries.map((e) {
                    final rate = e.value.$3 > 0 ? (e.value.$2 / e.value.$3 * 100) : 0.0;
                    final c = rate >= 80 ? AppColors.successGreen
                        : rate >= 60 ? AppColors.warningAmber
                        : AppColors.errorRed;
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(
                        toY: rate,
                        color: c.withAlpha(220),
                        width: days.length > 20 ? 7 : 13,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true, toY: 100,
                          color: context.appBorder.withAlpha(60),
                        ),
                      ),
                    ]);
                  }).toList(),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true, drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: context.appBorder, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 18,
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        if (days.length > 10 && i % 4 != 0) return const SizedBox.shrink();
                        return Text(days[i].$1,
                            style: TextStyle(fontSize: 9, color: context.appSubtext));
                      },
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 28,
                      getTitlesWidget: (val, _) {
                        if (val == 0 || val == 50 || val == 100) {
                          return Text('${val.toInt()}%',
                              style: TextStyle(fontSize: 9, color: context.appSubtext));
                        }
                        return const SizedBox.shrink();
                      },
                    )),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                )),
        ),
      ]),
    );
  }
}

/// Horizontal score bars for performance/branches
class _HorizBars extends StatelessWidget {
  final List<(String, double, double, Color)> items; // (label, value, max, color)
  final String title;
  final String? unit;
  const _HorizBars({required this.items, required this.title, this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: context.cardDeco(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText)),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Center(child: Text('No data', style: TextStyle(color: context.appSubtext, fontSize: 13)))
        else
          ...items.take(8).map((item) {
            final pct = item.$3 > 0 ? (item.$1 == '' ? 0.0 : item.$2 / item.$3).clamp(0.0, 1.0) : 0.0;
            final valStr = item.$3 == 100 ? '${item.$2.toInt()}%' : item.$2.toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(item.$1,
                      style: TextStyle(fontSize: 12, color: context.appText, fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis)),
                  Text(unit != null ? '$valStr$unit' : valStr,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.$4)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: context.appBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(item.$4),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Shared UI helpers for new tabs ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final int flex;
  const _TH(this.text, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: context.appSubtext, letterSpacing: 0.4)),
    );
  }
}

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  const _MonthNav({required this.month, required this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const AppIcon(AppIcons.chevronLeftRounded, size: 18),
          onPressed: onPrev,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(DateFormat('MMMM yyyy').format(month),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText)),
        ),
        IconButton(
          icon: const AppIcon(AppIcons.chevronRightRounded, size: 18),
          onPressed: onNext,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

String _salaryTypeLabel(String t) => switch (t) {
      'fixed_monthly' => 'Fixed Monthly',
      'daily_rate' => 'Daily Rate',
      'hourly_rate' => 'Hourly Rate',
      _ => t,
    };

String _contractLabel(String t) => switch (t) {
      'full_time' => 'Full Time',
      'part_time' => 'Part Time',
      'contract' => 'Contract',
      'intern' => 'Intern',
      _ => t,
    };
