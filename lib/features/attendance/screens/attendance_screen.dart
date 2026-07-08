import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/download_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/models/branch_model.dart';
import '../../branches/providers/branches_provider.dart';
import '../../employees/models/employee_model.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/providers/leave_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/attendance_model.dart';
import '../providers/attendance_provider.dart';

// ── Joined display row ────────────────────────────────────────────────────────
typedef _JR = ({
  String employeeId,
  String name,
  String dept,
  String? photoUrl,
  String? checkIn,
  String? checkOut,
  String status,
  bool isManual,
  bool stillIn,
  int lateMinutes,
});

String _fmt(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// Returns the DateTime representing end of work on the same day as [day]
DateTime _endOfWorkDt(DateTime day, String workEndTime) {
  final parts = workEndTime.split(':');
  return DateTime(day.year, day.month, day.day,
      int.parse(parts[0]), parts.length > 1 ? int.parse(parts[1]) : 0);
}

// Present = checked in before work ended (includes late arrivals)
bool _wasPresent(AttendanceModel r, String workEndTime) =>
    r.checkInTime != null &&
    r.checkInTime!.isBefore(_endOfWorkDt(r.date, workEndTime));

String _statusFromRecord(AttendanceModel? r, String workEndTime) {
  if (r == null) return 'absent';
  if (r.isOnLeave) return 'on_leave';
  if (r.isAbsent) return 'absent';
  // Checked in at or after work ended → absent
  if (r.checkInTime != null && !_wasPresent(r, workEndTime)) return 'absent';
  if (r.isLate) return 'late';
  if (r.checkInTime != null) return 'on_time';
  return 'absent';
}

List<_JR> _buildRows(
    List<EmployeeModel> employees,
    List<AttendanceModel> records,
    Set<String> onLeaveIds,
    String workEndTime) {
  final recMap = {for (final r in records) r.employeeId: r};
  final rows = <_JR>[];
  for (final emp in employees.where((e) => e.isActive)) {
    final r = recMap[emp.id];
    final String status;
    if (r == null && onLeaveIds.contains(emp.id)) {
      status = 'on_leave';
    } else {
      status = _statusFromRecord(r, workEndTime);
    }
    rows.add((
      employeeId: emp.id,
      name: emp.fullName,
      dept: emp.department,
      photoUrl: emp.profilePhotoUrl,
      checkIn: r?.checkInTime != null ? _fmt(r!.checkInTime!) : null,
      checkOut: r?.checkOutTime != null ? _fmt(r!.checkOutTime!) : null,
      status: status,
      isManual: r?.verificationType == 'manual',
      stillIn: r?.checkInTime != null && r?.checkOutTime == null,
      lateMinutes: r?.lateMinutes ?? 0,
    ));
  }
  // Sort: on_time → late → on_leave → absent
  const order = {'on_time': 0, 'late': 1, 'on_leave': 2, 'absent': 3};
  rows.sort((a, b) =>
      (order[a.status] ?? 4).compareTo(order[b.status] ?? 4));
  return rows;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _selectedDate = DateTime.now();
  String _deptFilter = 'All';
  String _statusFilter = 'All';
  String? _branchFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) setState(() => _selectedDate = d);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final companyType = ref.watch(companyTypeProvider).valueOrNull ?? AppConstants.companySingle;
    final isMultiBranch = companyType == AppConstants.companyMultiBranch;
    final isTopHr = role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
    final showBranchFilter = isMultiBranch && isTopHr;
    final branches = showBranchFilter ? (ref.watch(branchesStreamProvider).value ?? <BranchModel>[]) : <BranchModel>[];
    final workEndTime =
        ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    final employeesAsync = ref.watch(employeesProvider);
    final recordsAsync = ref.watch(attendanceByDateProvider(_selectedDate));
    final dateKey = leaveDateKey(_selectedDate);
    final onLeaveIds =
        ref.watch(approvedLeavesByDateProvider(dateKey)).value ??
            const <String>{};

    // Build joined rows — filter employees by branch for top HR when branch selected
    final allRows = employeesAsync.when(
      data: (allEmps) {
        final employees = (_branchFilter == null || !showBranchFilter)
            ? allEmps
            : allEmps.where((e) => e.branchId == _branchFilter).toList();
        return recordsAsync.when(
          data: (records) => _buildRows(employees, records, onLeaveIds, workEndTime),
          loading: () => _buildRows(employees, [], onLeaveIds, workEndTime),
          error: (_, __) => _buildRows(employees, [], onLeaveIds, workEndTime),
        );
      },
      loading: () => <_JR>[],
      error: (_, __) => <_JR>[],
    );

    // Summary counts — present includes late (late is a subset of present)
    final present = allRows.where((r) => r.status == 'on_time' || r.status == 'late').length;
    final late    = allRows.where((r) => r.status == 'late').length;
    final absent  = allRows.where((r) => r.status == 'absent').length;
    final onLeave = allRows.where((r) => r.status == 'on_leave').length;

    // Available departments for filter
    final deptSet = {for (final r in allRows) r.dept}.toList()..sort();
    final depts = ['All', ...deptSet];

    // Apply filters
    final filtered = allRows.where((r) {
      final deptOk = _deptFilter == 'All' || r.dept == _deptFilter;
      final statusOk = _statusFilter == 'All' || r.status == _statusFilter;
      return deptOk && statusOk;
    }).toList();

    final selectedBranch = _branchFilter == null
        ? null
        : branches.where((b) => b.id == _branchFilter).firstOrNull;

    return Scaffold(
      backgroundColor: context.appBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualEntry(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Manual Entry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            date: _selectedDate,
            onDatePick: _pickDate,
            showBranchFilter: showBranchFilter,
            branches: branches,
            selectedBranchName: selectedBranch?.name,
            onBranchPick: (id) => setState(() => _branchFilter = id),
          ),
          _SummaryRow(
              present: present, late: late, absent: absent, onLeave: onLeave),
          _AttTabBar(controller: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TodayTab(
                  rows: filtered,
                  depts: depts,
                  deptFilter: _deptFilter,
                  statusFilter: _statusFilter,
                  loading: employeesAsync.isLoading || recordsAsync.isLoading,
                  onDept: (v) => setState(() => _deptFilter = v),
                  onStatus: (v) => setState(() => _statusFilter = v),
                ),
                _HistoryTab(
                  date: _selectedDate,
                  onDatePick: _pickDate,
                ),
                _SummaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntry(BuildContext context) {
    showDialog(
        context: context, builder: (_) => const _ManualEntryDialog());
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onDatePick,
    this.showBranchFilter = false,
    this.branches = const [],
    this.selectedBranchName,
    this.onBranchPick,
  });
  final DateTime date;
  final VoidCallback onDatePick;
  final bool showBranchFilter;
  final List<BranchModel> branches;
  final String? selectedBranchName;
  final ValueChanged<String?>? onBranchPick;

  void _showBranchMenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size   = renderBox.size;

    final items = <PopupMenuEntry<String?>>[
      const PopupMenuItem(value: null, child: Text('All Branches')),
      const PopupMenuDivider(),
      ...branches.map((b) => PopupMenuItem(value: b.id, child: Text(b.name))),
    ];

    final result = await showMenu<String?>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx, offset.dy + size.height + 4,
        offset.dx + size.width, offset.dy + size.height + 300,
      ),
      items: items,
      color: context.appCard,
    );
    onBranchPick?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 16),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Attendance',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text('Real-time employee attendance tracking',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),
        const Spacer(),
        _HeaderBtn(
          icon: Icons.calendar_today_rounded,
          label: DateFormat('MMM d, yyyy').format(date),
          onTap: onDatePick,
        ),
        if (showBranchFilter) ...[
          const SizedBox(width: 10),
          Builder(builder: (ctx) => _HeaderBtn(
            icon: Icons.business_rounded,
            label: selectedBranchName ?? 'All Branches',
            trailing: Icons.keyboard_arrow_down_rounded,
            onTap: () => _showBranchMenu(ctx),
          )),
        ],
      ]),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn(
      {required this.icon, required this.label, this.trailing, this.onTap});
  final IconData icon;
  final String label;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: context.appSubtext),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            Icon(trailing, size: 15, color: context.appSubtext),
          ],
        ]),
      ),
    );
  }
}

// ── Summary cards ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.present,
      required this.late,
      required this.absent,
      required this.onLeave});
  final int present, late, absent, onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: Row(children: [
        Expanded(child: _SCard('Present', present, Icons.check_circle_rounded,
            AppColors.successGreen, AppColors.pillGreenBg)),
        const SizedBox(width: 12),
        Expanded(child: _SCard('Late', late, Icons.schedule_rounded,
            AppColors.warningAmber, AppColors.pillAmberBg)),
        const SizedBox(width: 12),
        Expanded(child: _SCard('Absent', absent, Icons.cancel_rounded,
            AppColors.errorRed, AppColors.pillRedBg)),
        const SizedBox(width: 12),
        Expanded(child: _SCard('On Leave', onLeave, Icons.beach_access_rounded,
            AppColors.primaryBlue, AppColors.pillBlueBg)),
      ]),
    );
  }
}

class _SCard extends StatelessWidget {
  const _SCard(this.label, this.count, this.icon, this.color, this.bg);
  final String label;
  final int count;
  final IconData icon;
  final Color color, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1)),
                const SizedBox(height: 2),
                Text(label,
                    style:
                        TextStyle(color: context.appSubtext, fontSize: 14)),
              ]),
        ),
      ]),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────
class _AttTabBar extends StatelessWidget {
  const _AttTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCard,
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: context.appSubtext,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        indicatorColor: AppColors.primaryBlue,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'History'),
          Tab(text: 'Summary'),
        ],
      ),
    );
  }
}

// ── TODAY TAB ─────────────────────────────────────────────────────────────────
class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.rows,
    required this.depts,
    required this.deptFilter,
    required this.statusFilter,
    required this.loading,
    required this.onDept,
    required this.onStatus,
  });
  final List<_JR> rows;
  final List<String> depts;
  final String deptFilter, statusFilter;
  final bool loading;
  final ValueChanged<String> onDept, onStatus;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter bar
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          const Spacer(),
          _DropFilter(
            value: deptFilter,
            items: depts,
            prefix: 'Dept:',
            onChanged: onDept,
          ),
          const SizedBox(width: 10),
          _DropFilter(
            value: statusFilter,
            items: const ['All', 'on_time', 'late', 'absent', 'on_leave'],
            labels: const ['All', 'On Time', 'Late', 'Absent', 'On Leave'],
            prefix: 'Status:',
            onChanged: onStatus,
          ),
        ]),
      ),
      // Table
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: context.appTint,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: _tableHeader(context),
            ),
            Divider(color: context.appBorder, height: 1),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              Icon(Icons.people_outline,
                                  size: 48, color: context.appSubtext),
                              const SizedBox(height: 10),
                              Text('No employees found',
                                  style: TextStyle(
                                      color: context.appSubtext,
                                      fontSize: 16)),
                            ]))
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: context.appBorder),
                          itemBuilder: (_, i) =>
                              _AttRow(row: rows[i]),
                        ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _tableHeader(BuildContext context) {
    final s = TextStyle(
        color: context.appSubtext,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5);
    return Row(children: [
      Expanded(flex: 28, child: Text('EMPLOYEE', style: s)),
      Expanded(flex: 10, child: Text('CHECK IN', style: s)),
      Expanded(flex: 10, child: Text('CHECK OUT', style: s)),
      Expanded(flex: 12, child: Text('STATUS', style: s)),
      Expanded(flex: 6, child: Text('TYPE', style: s)),
    ]);
  }
}

class _DropFilter extends StatelessWidget {
  const _DropFilter({
    required this.value,
    required this.items,
    this.labels,
    required this.prefix,
    required this.onChanged,
  });
  final String value, prefix;
  final List<String> items;
  final List<String>? labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(prefix,
            style: TextStyle(color: context.appSubtext, fontSize: 14)),
        const SizedBox(width: 6),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: safeValue,
            isDense: true,
            dropdownColor: context.appCard,
            style: TextStyle(color: context.appText, fontSize: 14),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: context.appSubtext),
            items: items
                .asMap()
                .entries
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(
                          labels != null && e.key < labels!.length
                              ? labels![e.key]
                              : e.value,
                          style: TextStyle(
                              color: context.appText, fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ),
      ]),
    );
  }
}

// ── Attendance row ────────────────────────────────────────────────────────────
class _AttRow extends StatelessWidget {
  const _AttRow({required this.row});
  final _JR row;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: context.appTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          // Employee
          Expanded(
            flex: 28,
            child: Row(children: [
              _Av(name: row.name, photoUrl: row.photoUrl, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.name,
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 1),
                      Text(row.dept,
                          style: TextStyle(
                              color: context.appSubtext, fontSize: 13)),
                    ]),
              ),
            ]),
          ),
          // Check In
          Expanded(
            flex: 10,
            child: Text(
              row.checkIn ?? '—',
              style: TextStyle(
                  color: row.checkIn != null
                      ? context.appText
                      : context.appSubtext,
                  fontSize: 15),
            ),
          ),
          // Check Out
          Expanded(
            flex: 10,
            child: row.checkOut != null
                ? Text(row.checkOut!,
                    style:
                        TextStyle(color: context.appText, fontSize: 15))
                : row.stillIn
                    ? Row(children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: AppColors.warningAmber,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        const Text('Still in',
                            style: TextStyle(
                                color: AppColors.warningAmber,
                                fontSize: 14)),
                      ])
                    : Text('—',
                        style: TextStyle(
                            color: context.appSubtext, fontSize: 15)),
          ),
          // Status badge
          Expanded(
            flex: 12,
            child: Align(
                alignment: Alignment.centerLeft,
                child: _SBadge(row.status)),
          ),
          // Type icons
          Expanded(
            flex: 6,
            child: Row(children: [
              if (row.isManual) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Manual Entry',
                  child: Icon(Icons.edit_rounded,
                      size: 14, color: context.appSubtext),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SBadge extends StatelessWidget {
  const _SBadge(this.status);
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
              TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _Av extends StatelessWidget {
  const _Av({required this.name, this.photoUrl, required this.size});
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
          child: Image.network(photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials()));
    }
    return _initials();
  }

  Widget _initials() {
    final colors = AppColors.gradientForName(name);
    final parts = name.split(' ');
    final ini = parts
        .take(2)
        .map((p) => p.isNotEmpty ? p[0] : '')
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(ini,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ── HISTORY TAB ───────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.date, required this.onDatePick});
  final DateTime date;
  final VoidCallback onDatePick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final recordsAsync = ref.watch(attendanceByDateProvider(date));
    final dateKey = leaveDateKey(date);
    final onLeaveIds =
        ref.watch(approvedLeavesByDateProvider(dateKey)).value ?? const <String>{};

    final workEndTime =
        ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';
    final rows = employeesAsync.when(
      data: (employees) => recordsAsync.when(
        data: (records) => _buildRows(employees, records, onLeaveIds, workEndTime),
        loading: () => _buildRows(employees, [], onLeaveIds, workEndTime),
        error: (_, __) => <_JR>[],
      ),
      loading: () => <_JR>[],
      error: (_, __) => <_JR>[],
    );

    final loading =
        employeesAsync.isLoading || recordsAsync.isLoading;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          GestureDetector(
            onTap: onDatePick,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: context.appSubtext),
                const SizedBox(width: 8),
                Text(DateFormat('EEEE, MMM d, yyyy').format(date),
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 14, color: context.appSubtext),
              ]),
            ),
          ),
          const Spacer(),
          Text('${rows.length} employees',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                  color: context.appTint,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12))),
              child: Row(children: [
                Expanded(flex: 28, child: _hTxt('EMPLOYEE', context)),
                Expanded(flex: 10, child: _hTxt('CHECK IN', context)),
                Expanded(flex: 10, child: _hTxt('CHECK OUT', context)),
                Expanded(flex: 12, child: _hTxt('STATUS', context)),
                Expanded(flex: 6, child: _hTxt('TYPE', context)),
              ]),
            ),
            Divider(height: 1, color: context.appBorder),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: context.appBorder),
                      itemBuilder: (_, i) => _AttRow(row: rows[i]),
                    ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Text _hTxt(String t, BuildContext ctx) => Text(t,
      style: TextStyle(
          color: ctx.appSubtext,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));
}

// ── SUMMARY TAB ───────────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _exporting = false;

  Future<void> _exportPdf(List<_SRow> rows) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Generating PDF…'),
      duration: Duration(seconds: 60),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final monthLabel = DateFormat('MMMM yyyy').format(_month);
      final font = await PdfGoogleFonts.interRegular();
      final bold = await PdfGoogleFonts.interBold();

      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('Attendance Summary — $monthLabel',
              style: pw.TextStyle(font: bold, fontSize: 18)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Employee', 'Department', 'Present', 'Late', 'Absent', 'On Leave', 'Hours'],
            headerStyle: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A6FD4)),
            cellStyle: pw.TextStyle(font: font, fontSize: 12),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F7FA)),
            data: rows.map((r) => [
              r.name,
              r.dept,
              '${r.present}',
              '${r.late}',
              '${r.absent}',
              '${r.onLeave}',
              '${r.hours.toStringAsFixed(1)}h',
            ]).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Generated by HRNova · ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        ],
      ));

      final bytes = await doc.save();
      downloadBytes(bytes, 'Attendance_Summary_${DateFormat('yyyy-MM').format(_month)}.pdf', 'application/pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF downloaded successfully ✓'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(attendanceByMonthProvider(
        (year: _month.year, month: _month.month)));
    final employeesAsync = ref.watch(employeesProvider);
    final workEndTime =
        ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    // Build per-employee summary
    final summaryRows = employeesAsync.when(
      data: (employees) => recordsAsync.when(
        data: (records) => _buildSummary(employees, records, workEndTime),
        loading: () => <_SRow>[],
        error: (_, __) => <_SRow>[],
      ),
      loading: () => <_SRow>[],
      error: (_, __) => <_SRow>[],
    );

    final loading =
        employeesAsync.isLoading || recordsAsync.isLoading;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          _navBtn(Icons.chevron_left_rounded,
              () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              context),
          const SizedBox(width: 12),
          Text(DateFormat('MMMM yyyy').format(_month),
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _navBtn(Icons.chevron_right_rounded,
              () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              context),
          const Spacer(),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _exporting ? context.appBorder : AppColors.primaryBlue),
              foregroundColor:
                  _exporting ? context.appSubtext : AppColors.primaryBlue,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
            ),
            onPressed: _exporting || summaryRows.isEmpty
                ? null
                : () => _exportPdf(summaryRows),
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryBlue))
                : const Icon(Icons.download_rounded, size: 16),
            label: Text(_exporting ? 'Generating…' : 'Export PDF'),
          ),
        ]),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                  color: context.appTint,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12))),
              child: Row(children: [
                Expanded(flex: 24, child: _h('EMPLOYEE', context)),
                Expanded(flex: 10, child: _h('DEPT', context)),
                Expanded(flex: 8, child: _h('PRESENT', context)),
                Expanded(flex: 6, child: _h('LATE', context)),
                Expanded(flex: 6, child: _h('ABSENT', context)),
                Expanded(flex: 6, child: _h('LEAVE', context)),
                Expanded(flex: 8, child: _h('HOURS', context)),
              ]),
            ),
            Divider(height: 1, color: context.appBorder),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : summaryRows.isEmpty
                      ? Center(
                          child: Text('No records for this month',
                              style: TextStyle(
                                  color: context.appSubtext, fontSize: 15)))
                      : ListView.separated(
                          itemCount: summaryRows.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: context.appBorder),
                          itemBuilder: (_, i) =>
                              _SummaryRow2(row: summaryRows[i]),
                        ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _navBtn(
          IconData icon, VoidCallback onTap, BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: BorderRadius.circular(8)),
          child:
              Icon(icon, color: context.appText, size: 18),
        ),
      );

  Widget _h(String t, BuildContext ctx) => Text(t,
      style: TextStyle(
          color: ctx.appSubtext,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));

  List<_SRow> _buildSummary(
      List<EmployeeModel> employees, List<AttendanceModel> records, String workEndTime) {
    final byEmp = <String, List<AttendanceModel>>{};
    for (final r in records) {
      byEmp.putIfAbsent(r.employeeId, () => []).add(r);
    }
    final result = <_SRow>[];
    for (final emp in employees.where((e) => e.isActive)) {
      final recs = byEmp[emp.id] ?? [];
      if (recs.isEmpty) continue;
      // Present = checked in before work ended (includes late arrivals)
      final present = recs.where((r) => _wasPresent(r, workEndTime)).length;
      final late = recs.where((r) => r.isLate && _wasPresent(r, workEndTime)).length;
      // Absent = explicit isAbsent flag OR checked in after work ended
      final absent = recs.where((r) =>
          r.isAbsent || (r.checkInTime != null && !_wasPresent(r, workEndTime))).length;
      final onLeave = recs.where((r) => r.isOnLeave).length;
      final totalHours = recs.fold<double>(0, (s, r) => s + (r.workingHours ?? 0));
      result.add((
        employeeId: emp.id,
        name: emp.fullName,
        dept: emp.department,
        photoUrl: emp.profilePhotoUrl,
        present: present,
        late: late,
        absent: absent,
        onLeave: onLeave,
        hours: totalHours,
      ));
    }
    return result;
  }
}

typedef _SRow = ({
  String employeeId,
  String name,
  String dept,
  String? photoUrl,
  int present,
  int late,
  int absent,
  int onLeave,
  double hours,
});

class _SummaryRow2 extends StatelessWidget {
  const _SummaryRow2({required this.row});
  final _SRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(
          flex: 24,
          child: Row(children: [
            _Av(name: row.name, photoUrl: row.photoUrl, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(row.name,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        Expanded(
            flex: 10,
            child: Text(row.dept,
                style:
                    TextStyle(color: context.appSubtext, fontSize: 14))),
        Expanded(flex: 8, child: _num('${row.present}', AppColors.successGreen)),
        Expanded(flex: 6, child: _num('${row.late}', AppColors.warningAmber)),
        Expanded(flex: 6, child: _num('${row.absent}', AppColors.errorRed)),
        Expanded(flex: 6, child: _num('${row.onLeave}', AppColors.primaryBlue)),
        Expanded(
            flex: 8,
            child: Text('${row.hours.toStringAsFixed(1)}h',
                style: TextStyle(
                    color: context.appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _num(String v, Color color) => Text(v,
      style:
          TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700));
}

// ── Manual Entry Dialog ───────────────────────────────────────────────────────
class _ManualEntryDialog extends ConsumerStatefulWidget {
  const _ManualEntryDialog();

  @override
  ConsumerState<_ManualEntryDialog> createState() =>
      _ManualEntryDialogState();
}

class _ManualEntryDialogState extends ConsumerState<_ManualEntryDialog> {
  EmployeeModel? _selectedEmployee;
  DateTime _date = DateTime.now();
  TimeOfDay _checkIn = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _checkOut;
  final _reasonCtrl = TextEditingController();
  bool _hasCheckOut = false;
  bool _saving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2024),
        lastDate: DateTime.now());
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _pickCheckIn() async {
    final t = await showTimePicker(context: context, initialTime: _checkIn);
    if (t != null && mounted) setState(() => _checkIn = t);
  }

  Future<void> _pickCheckOut() async {
    final t = await showTimePicker(
        context: context,
        initialTime: _checkOut ?? const TimeOfDay(hour: 17, minute: 0));
    if (t != null && mounted) setState(() => _checkOut = t);
  }

  Future<void> _save() async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an employee')));
      return;
    }
    setState(() => _saving = true);
    try {
      final checkInDt = DateTime(
          _date.year, _date.month, _date.day, _checkIn.hour, _checkIn.minute);
      DateTime? checkOutDt;
      if (_hasCheckOut && _checkOut != null) {
        checkOutDt = DateTime(_date.year, _date.month, _date.day,
            _checkOut!.hour, _checkOut!.minute);
      }
      await ref.read(attendanceNotifierProvider.notifier).addManualEntry(
            employeeId: _selectedEmployee!.id,
            branchId: _selectedEmployee!.branchId,
            date: _date,
            checkInTime: checkInDt,
            checkOutTime: checkOutDt,
            notes: _reasonCtrl.text.trim().isNotEmpty
                ? _reasonCtrl.text.trim()
                : null,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Attendance recorded successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(activeEmployeesProvider);
    final employees = employeesAsync.value ?? [];

    return Dialog(
      backgroundColor: context.appCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.pillBlueBg,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Manual Attendance Entry',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:
                      Icon(Icons.close_rounded, color: context.appSubtext),
                ),
              ]),
              const SizedBox(height: 22),
              // Employee picker
              _dlgLabel('Employee *', context),
              const SizedBox(height: 6),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.appField,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EmployeeModel>(
                    value: _selectedEmployee,
                    hint: Text('Select employee',
                        style: TextStyle(
                            color: context.appSubtext, fontSize: 15)),
                    dropdownColor: context.appCard,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: context.appSubtext),
                    items: employees
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.fullName,
                                  style: TextStyle(
                                      color: context.appText,
                                      fontSize: 15)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedEmployee = v),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Date
              _dlgLabel('Date *', context),
              const SizedBox(height: 6),
              _timePicker(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('MMM d, yyyy').format(_date),
                  onTap: _pickDate,
                  context: context),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dlgLabel('Check-In Time *', context),
                        const SizedBox(height: 6),
                        _timePicker(
                            icon: Icons.access_time_rounded,
                            label: _checkIn.format(context),
                            onTap: _pickCheckIn,
                            context: context),
                      ]),
                ),
                if (_hasCheckOut) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dlgLabel('Check-Out Time', context),
                          const SizedBox(height: 6),
                          _timePicker(
                              icon: Icons.access_time_rounded,
                              label: _checkOut != null
                                  ? _checkOut!.format(context)
                                  : 'Pick time',
                              labelColor: _checkOut != null
                                  ? context.appText
                                  : context.appSubtext,
                              onTap: _pickCheckOut,
                              context: context),
                        ]),
                  ),
                ],
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () =>
                    setState(() => _hasCheckOut = !_hasCheckOut),
                child: Row(children: [
                  Icon(
                    _hasCheckOut
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: _hasCheckOut
                        ? AppColors.primaryBlue
                        : context.appSubtext,
                  ),
                  const SizedBox(width: 8),
                  Text('Add check-out time',
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 14),
              _dlgLabel('Reason / Notes', context),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: context.appText, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. System was down, forgot to scan...',
                  hintStyle: TextStyle(color: context.appSubtext),
                  filled: true,
                  fillColor: context.appField,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appBorder),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(color: context.appText)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Save Entry',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePicker({
    required IconData icon,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
    required BuildContext context,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.appField,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: context.appSubtext),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: labelColor ?? context.appText, fontSize: 15)),
          ]),
        ),
      );

  Widget _dlgLabel(String t, BuildContext ctx) => Text(t,
      style: TextStyle(
          color: ctx.appSubtext,
          fontSize: 14,
          fontWeight: FontWeight.w500));
}
