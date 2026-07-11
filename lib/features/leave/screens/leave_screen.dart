import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/working_days_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_table.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/models/branch_model.dart';
import '../../branches/providers/branches_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/leave_request_model.dart';
import '../providers/leave_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/month_nav.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

Color _leaveColor(String t) => switch (t) {
      'annual' => AppColors.primaryBlue,
      'sick' => AppColors.successGreen,
      'maternity' => const Color(0xFF9C27B0),
      'paternity' => const Color(0xFF00897B),
      'unpaid' => AppColors.textSecondary,
      'emergency' => AppColors.errorRed,
      'compassionate' => const Color(0xFFFF9800),
      _ => AppColors.textSecondary,
    };

String _typeLabel(String t) => switch (t) {
      'annual' => 'Annual',
      'sick' => 'Sick',
      'maternity' => 'Maternity',
      'paternity' => 'Paternity',
      'unpaid' => 'Unpaid',
      'emergency' => 'Emergency',
      'compassionate' => 'Compassionate',
      _ => t,
    };

String _srcLabel(String s) => switch (s) {
      'mobile_app' => 'Mobile',
      'whatsapp_portal' => 'WhatsApp',
      'web_dashboard' => 'Web',
      'hr_manual' => 'HR Manual',
      _ => s,
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late bool _isTopHr;

  @override
  void initState() {
    super.initState();
    final role = ref.read(currentUserRoleProvider) ?? '';
    _isTopHr = role == AppConstants.roleHrAdmin || role == AppConstants.roleGroupHrAdmin;
    // Leave Roster tab added for all roles; top HR: 4 tabs, others: 5 tabs
    _tabs = TabController(length: _isTopHr ? 4 : 5, vsync: this);
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
          _LeaveHeader(),
          _LeaveTabBar(controller: _tabs, isTopHr: _isTopHr),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _isTopHr
                  ? const [
                      _LeaveRosterTab(),
                      _AllRequestsTab(showBranchFilter: true),
                      _ExpiredTab(),
                      _CalendarTab(),
                    ]
                  : const [
                      _LeaveRosterTab(),
                      _PendingTab(),
                      _AllRequestsTab(showBranchFilter: false),
                      _ExpiredTab(),
                      _CalendarTab(),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _LeaveHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 16),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Leave Management',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text('Review, approve and track employee leave',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),
      ]),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _LeaveTabBar extends StatelessWidget {
  const _LeaveTabBar({required this.controller, required this.isTopHr});
  final TabController controller;
  final bool isTopHr;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.appCard),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: context.appSubtext,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 15),
        indicatorColor: AppColors.primaryBlue,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        tabs: isTopHr
            ? const [Tab(text: 'Leave Roster'), Tab(text: 'All Requests'), Tab(text: 'Expired'), Tab(text: 'Calendar')]
            : const [Tab(text: 'Leave Roster'), Tab(text: 'Pending'), Tab(text: 'All Requests'), Tab(text: 'Expired'), Tab(text: 'Calendar')],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'pending' =>
        ('Pending', context.pillAmberBg, context.pillAmberText),
      'approved' =>
        ('Approved', context.pillGreenBg, context.pillGreenText),
      'rejected' =>
        ('Rejected', context.pillRedBg, context.pillRedText),
      _ => ('—', context.pillNavyBg, context.pillNavyText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _leaveColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(100)),
      child: Text(_typeLabel(type),
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.gradientForName(name);
    final parts = name.split(' ');
    final ini =
        parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
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
              fontSize: size * 0.36,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── LEAVE ROSTER TAB ─────────────────────────────────────────────────────────

class _LeaveRosterTab extends ConsumerWidget {
  const _LeaveRosterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(activeLeaveRosterProvider);
    final role = ref.watch(currentUserRoleProvider) ?? '';
    final canMarkLeave = role == AppConstants.roleHrAdmin ||
        role == AppConstants.roleGroupHrAdmin ||
        role == AppConstants.roleBranchHrAdmin;
    final today = DateTime.now();
    final dateF = DateFormat('MMM d, yyyy');

    return rosterAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: context.appSubtext))),
      data: (roster) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            decoration: BoxDecoration(
              color: context.appCard,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(28),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${roster.length} employee${roster.length == 1 ? '' : 's'} away',
                            style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'As of ${DateFormat('EEEE, d MMMM y').format(today)}',
                      style: TextStyle(color: context.appSubtext, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                if (canMarkLeave)
                  ElevatedButton.icon(
                    onPressed: () => AppDialogShell.show(
                      context: context,
                      alignment: Alignment.center,
                      maxWidth: 520,
                      child: const _MarkOnLeaveDialog(),
                    ),
                    icon: const AppIcon(AppIcons.beachAccessRounded, size: 16),
                    label: const Text('Mark on Leave'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
              ],
            ),
          ),

          // Roster list
          Expanded(
            child: roster.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AppIcon(AppIcons.peopleOutlineRounded,
                          size: 56, color: context.appSubtext.withAlpha(120)),
                      const SizedBox(height: 12),
                      Text('No one is on leave today',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 17,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('All employees are present.',
                          style: TextStyle(color: context.appSubtext, fontSize: 15)),
                    ]),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: roster
                          .map((r) => SizedBox(
                                width: 400,
                                child: _RosterCard(req: r, today: today, dateF: dateF),
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.req, required this.today, required this.dateF});
  final LeaveRequestModel req;
  final DateTime today;
  final DateFormat dateF;

  @override
  Widget build(BuildContext context) {
    final daysLeft = req.endDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    final isLastDay = daysLeft == 0;
    final leaveColor = _leaveColor(req.leaveType);
    final isHrManual = req.source == 'hr_manual';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 40 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InitialsAvatar(name: req.employeeName, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.employeeName,
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _TypeBadge(req.leaveType),
                        const SizedBox(width: 6),
                        if (isHrManual)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningAmber.withAlpha(28),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('HR Manual',
                                style: TextStyle(
                                    color: AppColors.warningAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLastDay
                      ? AppColors.warningAmber.withAlpha(28)
                      : AppColors.successGreen.withAlpha(22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      isLastDay ? 'Last day' : '$daysLeft',
                      style: TextStyle(
                        color: isLastDay ? AppColors.warningAmber : AppColors.successGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isLastDay)
                      Text('days left',
                          style: TextStyle(
                              color: isLastDay ? AppColors.warningAmber : AppColors.successGreen,
                              fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.appBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                AppIcon(AppIcons.dateRangeRounded, size: 14, color: context.appSubtext),
                const SizedBox(width: 6),
                Text(
                  '${dateF.format(req.startDate)}  →  ${dateF.format(req.endDate)}',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                const Spacer(),
                Text('${req.totalDays} day${req.totalDays == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${req.reason}"',
              style: TextStyle(
                  color: context.appSubtext,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mark on Leave Dialog ──────────────────────────────────────────────────────

class _MarkOnLeaveDialog extends ConsumerStatefulWidget {
  const _MarkOnLeaveDialog();

  @override
  ConsumerState<_MarkOnLeaveDialog> createState() => _MarkOnLeaveDialogState();
}

class _MarkOnLeaveDialogState extends ConsumerState<_MarkOnLeaveDialog> {
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedBranchId;
  String _leaveType = 'annual';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _reasonCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _submitting = false;
  String _employeeSearch = '';

  static const _types = [
    ('annual', 'Annual Leave'),
    ('sick', 'Sick Leave'),
    ('maternity', 'Maternity Leave'),
    ('paternity', 'Paternity Leave'),
    ('unpaid', 'Unpaid Leave'),
    ('emergency', 'Emergency Leave'),
    ('compassionate', 'Compassionate Leave'),
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select an employee')));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a reason')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(leaveNotifierProvider.notifier).hrMarkOnLeave(
            employeeId: _selectedEmployeeId!,
            employeeName: _selectedEmployeeName!,
            leaveType: _leaveType,
            startDate: _startDate,
            endDate: _endDate,
            reason: _reasonCtrl.text.trim(),
            branchId: _selectedBranchId,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Employee marked on leave successfully'),
              backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.valueOrNull ?? [];
    final filtered = employees
        .where((e) =>
            e.status == 'active' &&
            (_employeeSearch.isEmpty ||
                e.fullName.toLowerCase().contains(_employeeSearch.toLowerCase())))
        .toList();

    final settings = ref.watch(companySettingsProvider).value;
    final workingDays = settings?.workingDays ??
        const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    final days = WorkingDaysService.calculate(_startDate, _endDate, workingDays);
    final dateF = DateFormat('MMM d, yyyy');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const AppIcon(AppIcons.beachAccessRounded,
                        color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Mark Employee on Leave',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: AppIcon(AppIcons.closeRounded, color: context.appSubtext),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Employee search + select
              Text('Employee',
                  style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              // Show selected or search
              if (_selectedEmployeeId != null)
                InkWell(
                  onTap: () => setState(() {
                    _selectedEmployeeId = null;
                    _selectedEmployeeName = null;
                    _searchCtrl.clear();
                    _employeeSearch = '';
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        _InitialsAvatar(name: _selectedEmployeeName!, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_selectedEmployeeName!,
                              style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        AppIcon(AppIcons.closeRounded,
                            color: AppColors.primaryBlue, size: 16),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _employeeSearch = v),
                  style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w400),
                  decoration: InputDecoration(
                    hintText: 'Search employee by name...',
                    hintStyle: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w300),
                    prefixIcon: AppIcon(AppIcons.searchRounded, color: context.appSubtext, size: 18),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.appBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.appBorder)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                  ),
                ),
                if (_employeeSearch.isNotEmpty && filtered.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: context.appCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.appBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length.clamp(0, 8),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        return InkWell(
                          onTap: () => setState(() {
                            _selectedEmployeeId = e.id;
                            _selectedEmployeeName = e.fullName;
                            _selectedBranchId = e.branchId;
                            _searchCtrl.clear();
                            _employeeSearch = '';
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                _InitialsAvatar(name: e.fullName, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.fullName,
                                          style: TextStyle(
                                              color: context.appText,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400)),
                                      Text(e.jobTitle,
                                          style: TextStyle(
                                              color: context.appSubtext,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),

              // Leave type
              Text('Leave Type',
                  style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _leaveType,
                    dropdownColor: context.appCard,
                    style: TextStyle(color: context.appText, fontSize: 14),
                    icon: AppIcon(AppIcons.expandMoreRounded, color: context.appSubtext),
                    isExpanded: true,
                    onChanged: (v) => setState(() => _leaveType = v!),
                    items: _types
                        .map((t) => DropdownMenuItem(
                              value: t.$1,
                              child: Text(t.$2),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Date',
                            style: TextStyle(
                                color: context.appSubtext,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        _DateButton(
                          label: dateF.format(_startDate),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) {
                              setState(() {
                                _startDate = d;
                                if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Date',
                            style: TextStyle(
                                color: context.appSubtext,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        _DateButton(
                          label: dateF.format(_endDate),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                ),
                child: Row(children: [
                  const AppIcon(AppIcons.infoOutlineRounded,
                      color: AppColors.primaryBlue, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    '$days working day${days == 1 ? '' : 's'} will be deducted',
                    style: const TextStyle(color: AppColors.primaryBlue, fontSize: 13),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Reason
              Text('Reason / Notes',
                  style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 2,
                style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: 'E.g. Employee came in person to request leave...',
                  hintStyle: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w300),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.appBorder)),
                  focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: HRNovaButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                      backgroundColor: context.isDark ? AppColors.darkCard : AppColors.backgroundBlue,
                      textColor: context.appText,
                      height: 45,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HRNovaButton(
                      label: 'Mark on Leave',
                      onPressed: _submitting ? null : _submit,
                      isLoading: _submitting,
                      height: 45,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.calendarTodayRounded,
                size: 14, color: context.appSubtext),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: context.appText, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── PENDING TAB ───────────────────────────────────────────────────────────────

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingLeaveRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: context.appSubtext))),
      data: (requests) => requests.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppIcon(AppIcons.checkCircleOutlineRounded,
                    size: 56,
                    color: AppColors.successGreen.withAlpha(180)),
                const SizedBox(height: 12),
                Text('No pending requests',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 17,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('All leave requests have been processed.',
                    style: TextStyle(
                        color: context.appSubtext, fontSize: 15)),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: requests
                    .map((r) => SizedBox(
                          width: 400,
                          child: _PendingCard(request: r),
                        ))
                    .toList(),
              ),
            ),
    );
  }
}

// ── Pending Card ──────────────────────────────────────────────────────────────

class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.request});
  final LeaveRequestModel request;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _loading = false;
  final _dateF = DateFormat('MMM d, yyyy');

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final conflict = await ref
          .read(leaveNotifierProvider.notifier)
          .approveLeaveGuarded(widget.request);
      if (mounted) {
        if (conflict != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Already handled by $conflict'),
            backgroundColor: AppColors.warningAmber,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Leave approved for ${widget.request.employeeName}'),
            backgroundColor: AppColors.successGreen,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRejectDialog() {
    AppDialogShell.show(
      context: context,
      alignment: Alignment.center,
      child: _RejectDialog(request: widget.request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Container(
      decoration: context.cardDeco(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _InitialsAvatar(name: req.employeeName, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.employeeName,
                              style: TextStyle(
                                  color: context.appText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _TypeBadge(req.leaveType),
                            const SizedBox(width: 8),
                            Text(() {
                                  final d = req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1;
                                  return '$d day${d != 1 ? "s" : ""}';
                                }(),
                                style: TextStyle(
                                    color: context.appSubtext, fontSize: 14)),
                            const SizedBox(width: 6),
                            Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: context.appSubtext,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(_srcLabel(req.source),
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 14)),
                          ]),
                        ]),
                  ),
                  Text(_dateF.format(req.requestedAt),
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 14)),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FROM',
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(_dateF.format(req.startDate),
                                style: TextStyle(
                                    color: context.appText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                    AppIcon(AppIcons.arrowForwardRounded,
                        size: 16, color: context.appSubtext),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('TO',
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(_dateF.format(req.endDate),
                                style: TextStyle(
                                    color: context.appText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                  ]),
                ),
                if (req.isExtension || (req.leaveType == 'sick' && req.totalDays >= 3)) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: [
                    if (req.isExtension)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(20), borderRadius: BorderRadius.circular(100)),
                        child: const Text('Extension', style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    if (req.leaveType == 'sick' && req.totalDays >= 3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty) ? context.pillGreenBg : context.pillAmberBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty) ? "Doctor's note attached" : "No doctor's note",
                          style: TextStyle(
                            color: (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty) ? context.pillGreenText : context.pillAmberText,
                            fontSize: 12, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ]),
                ],
                if (req.reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Reason: ${req.reason}',
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: _loading ? null : _showRejectDialog,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.errorRed.withAlpha(180)),
                      foregroundColor: AppColors.errorRed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      minimumSize: const Size(90, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _loading ? null : _approve,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      minimumSize: const Size(90, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
                  ),
                ]),
              ]),
        ),
      ]),
    );
  }
}

// ── Reject Dialog ─────────────────────────────────────────────────────────────

class _RejectDialog extends ConsumerStatefulWidget {
  const _RejectDialog({required this.request});
  final LeaveRequestModel request;

  @override
  ConsumerState<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends ConsumerState<_RejectDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a reason')));
      return;
    }
    setState(() => _loading = true);
    try {
      final conflict = await ref
          .read(leaveNotifierProvider.notifier)
          .rejectLeaveGuarded(widget.request, reason);
      if (mounted) {
        Navigator.pop(context);
        if (conflict != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Already handled by $conflict'),
            backgroundColor: AppColors.warningAmber,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Leave request declined')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: context.pillRedBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: const AppIcon(AppIcons.cancelRounded,
                        color: AppColors.errorRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Decline Leave Request',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: AppIcon(AppIcons.closeRounded,
                        color: context.appSubtext),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                    'Declining ${widget.request.employeeName}\'s ${_typeLabel(widget.request.leaveType)} leave request.',
                    style: TextStyle(
                        color: context.appSubtext, fontSize: 15)),
                const SizedBox(height: 16),
                Text('Reason for declining *',
                    style: TextStyle(
                        color: context.appSubtext,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  autofocus: true,
                  style: TextStyle(color: context.appText, fontSize: 15),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Critical deadline, insufficient notice…',
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
                            color: AppColors.errorRed, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: HRNovaButton.text(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      textColor: context.appSubtext,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HRNovaButton(
                      label: 'Decline',
                      onPressed: _loading ? null : _reject,
                      isLoading: _loading,
                      backgroundColor: AppColors.errorRed,
                      height: 44,
                    ),
                  ),
                ]),
              ]),
    );
  }
}

// ── ALL REQUESTS TAB ──────────────────────────────────────────────────────────

class _AllRequestsTab extends ConsumerStatefulWidget {
  const _AllRequestsTab({this.showBranchFilter = false});
  final bool showBranchFilter;

  @override
  ConsumerState<_AllRequestsTab> createState() => _AllRequestsTabState();
}

class _AllRequestsTabState extends ConsumerState<_AllRequestsTab> {
  String _search = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  String? _branchFilter;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allLeaveRequestsProvider);
    final all = requestsAsync.value ?? [];
    final branches = widget.showBranchFilter
        ? (ref.watch(branchesStreamProvider).valueOrNull ?? <BranchModel>[])
        : <BranchModel>[];

    final filtered = all.where((r) {
      final q = _search.toLowerCase();
      final nameOk = q.isEmpty || r.employeeName.toLowerCase().contains(q);
      final typeOk = _typeFilter == 'All' || r.leaveType == _typeFilter;
      final statusOk = _statusFilter == 'All' || r.status == _statusFilter;
      final branchOk = _branchFilter == null || r.branchId == _branchFilter;
      return nameOk && typeOk && statusOk && branchOk;
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: context.appText, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
                  prefixIcon: AppIcon(AppIcons.searchRounded, size: 16, color: context.appSubtext),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (widget.showBranchFilter && branches.isNotEmpty) ...[
            _FilterDrop(
              value: _branchFilter ?? 'all',
              items: ['all', ...branches.map((b) => b.id)],
              labels: ['All Branches', ...branches.map((b) => b.name)],
              onChanged: (v) => setState(() => _branchFilter = v == 'all' ? null : v),
            ),
            const SizedBox(width: 10),
          ],
          _FilterDrop(
            value: _typeFilter,
            items: const [
              'All', 'annual', 'sick', 'maternity', 'paternity', 'unpaid', 'emergency', 'compassionate'
            ],
            labels: const [
              'All Types', 'Annual', 'Sick', 'Maternity', 'Paternity', 'Unpaid', 'Emergency', 'Compassionate'
            ],
            onChanged: (v) => setState(() => _typeFilter = v),
          ),
          const SizedBox(width: 10),
          _FilterDrop(
            value: _statusFilter,
            items: const ['All', 'pending', 'approved', 'rejected'],
            labels: const ['All Status', 'Pending', 'Approved', 'Rejected'],
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(width: 10),
          Text('${filtered.length} result${filtered.length != 1 ? "s" : ""}',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: context.cardDeco(18),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppTableHeader(
                columns: const ['EMPLOYEE', 'TYPE', 'FROM', 'TO', 'DAYS', 'STATUS', 'SOURCE'],
                flex: const [24, 12, 12, 12, 7, 10, 7],
              ),
            ),
            Expanded(
              child: requestsAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text('No requests found',
                              style: TextStyle(
                                  color: context.appSubtext,
                                  fontSize: 15)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: context.appBorder),
                          itemBuilder: (_, i) =>
                              _RequestRow(request: filtered[i]),
                        ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _RequestRow extends ConsumerStatefulWidget {
  const _RequestRow({required this.request});
  final LeaveRequestModel request;

  @override
  ConsumerState<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends ConsumerState<_RequestRow> {
  bool _expanded = false;
  bool _overrideLoading = false;
  final _dateF = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        hoverColor: context.appTint,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: Row(children: [
            Expanded(
              flex: 24,
              child: Row(children: [
                _InitialsAvatar(name: req.employeeName, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(req.employeeName,
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            Expanded(flex: 12, child: Align(alignment: Alignment.centerLeft, child: _TypeBadge(req.leaveType))),
            Expanded(
              flex: 12,
              child: Text(_dateF.format(req.startDate),
                  style: TextStyle(
                      color: context.appText, fontSize: 14)),
            ),
            Expanded(
              flex: 12,
              child: Text(_dateF.format(req.endDate),
                  style: TextStyle(
                      color: context.appText, fontSize: 14)),
            ),
            Expanded(
              flex: 7,
              child: Text(() {
                  final d = req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1;
                  return '${d}d';
                }(),
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(flex: 10, child: Align(alignment: Alignment.centerLeft, child: _StatusBadge(req.status))),
            Expanded(
              flex: 7,
              child: Text(_srcLabel(req.source),
                  style: TextStyle(
                      color: context.appSubtext, fontSize: 14)),
            ),
          ]),
        ),
      ),
      if (_expanded) ...[
        Divider(height: 1, color: context.appBorder),
        Container(
          color: context.appTint,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Extension badge
            if (req.isExtension) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(20), borderRadius: BorderRadius.circular(100)),
                child: const Text('Leave Extension', style: TextStyle(color: Color(0xFF1565C0), fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
            // Doctor's note badge for sick leave >= 3 days
            if (req.leaveType == 'sick' && req.totalDays >= 3) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty)
                      ? context.pillGreenBg
                      : context.pillAmberBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty)
                      ? "Doctor's note attached"
                      : "No doctor's note",
                  style: TextStyle(
                    color: (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty)
                        ? context.pillGreenText
                        : context.pillAmberText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (req.reason.isNotEmpty)
              _detail('Reason', req.reason, context),
            if (req.rejectedReason != null)
              _detail('Decline Reason', req.rejectedReason!, context,
                  color: AppColors.errorRed),
            _detail('Submitted',
                DateFormat('MMM d, yyyy HH:mm').format(req.requestedAt),
                context),
            if (req.approvedAt != null)
              _detail('Approved',
                  DateFormat('MMM d, yyyy HH:mm').format(req.approvedAt!),
                  context),
            // HR Admin override button for decided requests
            Builder(builder: (ctx) {
              final role = ref.watch(currentUserRoleProvider);
              final isTopHr = role == AppConstants.roleHrAdmin || role == AppConstants.roleGroupHrAdmin;
              if (!isTopHr || req.status == 'pending') return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _overrideLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : OutlinedButton.icon(
                        onPressed: () => _showOverrideDialog(ctx, req),
                        icon: const AppIcon(AppIcons.syncRounded, size: 16),
                        label: Text(req.status == 'approved' ? 'Override: Reject' : 'Override: Approve',
                            style: const TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningAmber,
                          side: BorderSide(color: AppColors.warningAmber.withAlpha(80)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
              );
            }),
          ]),
        ),
      ],
    ]);
  }

  void _showOverrideDialog(BuildContext ctx, LeaveRequestModel req) {
    final newStatus = req.status == 'approved' ? 'rejected' : 'approved';
    final ctrl = TextEditingController();
    AppDialogShell.show(
      context: ctx,
      alignment: Alignment.center,
      maxWidth: 420,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Override to ${newStatus == 'approved' ? 'Approved' : 'Rejected'}',
                style: TextStyle(color: ctx.appText, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: ctx.appText),
              decoration: InputDecoration(
                hintText: 'Reason for override',
                hintStyle: TextStyle(color: ctx.appSubtext),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.appBorder)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primaryBlue)),
                filled: true, fillColor: ctx.appField,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HRNovaButton.text(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx),
                  textColor: ctx.appSubtext,
                ),
                HRNovaButton.text(
                  label: 'Confirm Override',
                  onPressed: () async {
                    final reason = ctrl.text.trim();
                    if (reason.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => _overrideLoading = true);
                    try {
                      await ref.read(leaveNotifierProvider.notifier).overrideLeaveDecision(
                        req: req, newStatus: newStatus, reason: reason,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Decision overridden to $newStatus'), backgroundColor: AppColors.warningAmber),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
                      }
                    } finally {
                      if (mounted) setState(() => _overrideLoading = false);
                    }
                  },
                  textColor: AppColors.warningAmber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value, BuildContext context,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    color: context.appSubtext,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
          ),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: color ?? context.appText,
                      fontSize: 14))),
        ]),
      );
}

class _FilterDrop extends StatelessWidget {
  const _FilterDrop({
    required this.value,
    required this.items,
    required this.labels,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safe,
          isDense: true,
          dropdownColor: context.appCard,
          style: TextStyle(color: context.appText, fontSize: 14),
          icon: AppIcon(AppIcons.keyboardArrowDownRounded,
              size: 14, color: context.appSubtext),
          items: items
              .asMap()
              .entries
              .map((e) => DropdownMenuItem(
                    value: e.value,
                    child: Text(labels[e.key],
                        style: TextStyle(
                            color: context.appText, fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// ── EXPIRED TAB ───────────────────────────────────────────────────────────────

class _ExpiredTab extends ConsumerWidget {
  const _ExpiredTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiredAsync = ref.watch(expiredLeaveRequestsProvider);

    return expiredAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.appSubtext))),
      data: (expired) {
        if (expired.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppIcon(AppIcons.eventAvailableRounded, size: 56, color: AppColors.successGreen.withAlpha(180)),
              const SizedBox(height: 12),
              Text('No expired requests',
                  style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('All pending leave requests are still within their period.',
                  style: TextStyle(color: context.appSubtext, fontSize: 15)),
            ]),
          );
        }

        final s = TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(children: [
              Text('${expired.length} expired request${expired.length != 1 ? "s" : ""}',
                  style: TextStyle(color: context.appSubtext, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.pillAmberBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppIcon(AppIcons.infoOutlineRounded, size: 14, color: context.pillAmberText),
                  const SizedBox(width: 6),
                  Text('Pending requests whose leave period has already ended',
                      style: TextStyle(color: context.pillAmberText, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 24, child: Text('EMPLOYEE', style: s)),
                    Expanded(flex: 12, child: Text('TYPE', style: s)),
                    Expanded(flex: 12, child: Text('FROM', style: s)),
                    Expanded(flex: 12, child: Text('TO', style: s)),
                    Expanded(flex: 7, child: Text('DAYS', style: s)),
                    Expanded(flex: 12, child: Text('EXPIRED', style: s)),
                    Expanded(flex: 8, child: Text('SOURCE', style: s)),
                  ]),
                ),
                Divider(height: 1, color: context.appBorder),
                Expanded(
                  child: ListView.separated(
                    itemCount: expired.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: context.appBorder),
                    itemBuilder: (_, i) => _ExpiredRow(request: expired[i]),
                  ),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _ExpiredRow extends StatelessWidget {
  const _ExpiredRow({required this.request});
  final LeaveRequestModel request;

  String _agoText(DateTime endDate) {
    final diff = DateTime.now().difference(endDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 30) return '$diff days ago';
    final months = (diff / 30).floor();
    return '$months month${months != 1 ? "s" : ""} ago';
  }

  @override
  Widget build(BuildContext context) {
    final req = request;
    final dateF = DateFormat('MMM d, yyyy');
    final days = req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1;
    final ago = _agoText(req.endDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(children: [
        Expanded(
          flex: 24,
          child: Row(children: [
            _InitialsAvatar(name: req.employeeName, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(req.employeeName,
                  style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w400),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        Expanded(flex: 12, child: Align(alignment: Alignment.centerLeft, child: _TypeBadge(req.leaveType))),
        Expanded(
          flex: 12,
          child: Text(dateF.format(req.startDate),
              style: TextStyle(color: context.appText, fontSize: 14)),
        ),
        Expanded(
          flex: 12,
          child: Text(dateF.format(req.endDate),
              style: TextStyle(color: context.appText, fontSize: 14)),
        ),
        Expanded(
          flex: 7,
          child: Text('${days}d',
              style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 12,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: context.pillAmberBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(ago,
                  style: TextStyle(color: context.pillAmberText, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
        Expanded(
          flex: 8,
          child: Text(_srcLabel(req.source),
              style: TextStyle(color: context.appSubtext, fontSize: 14)),
        ),
      ]),
    );
  }
}

// ── CALENDAR TAB ──────────────────────────────────────────────────────────────

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = DateTime.now();

  static const _weekDays = [
    'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
  ];

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final calAsync = ref.watch(leavesCalendarByMonthProvider(
        (year: _month.year, month: _month.month)));
    final calEntries = calAsync.value ?? [];

    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final entry in calEntries) {
      final date = entry['date'] as String? ?? '';
      if (date.isNotEmpty) byDate.putIfAbsent(date, () => []).add(entry);
    }

    final firstDay = DateTime(_month.year, _month.month, 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + lastDay.day;
    final selectedEntries = byDate[_dateKey(_selected)] ?? [];

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          MonthNav(
            label: DateFormat('MMMM yyyy').format(_month),
            onPrev: () => setState(() =>
                _month = DateTime(_month.year, _month.month - 1)),
            onNext: () => setState(() =>
                _month = DateTime(_month.year, _month.month + 1)),
          ),
          const Spacer(),
          ...[
            ('Annual', AppColors.primaryBlue),
            ('Sick', AppColors.successGreen),
            ('Maternity', const Color(0xFF9C27B0)),
            ('Paternity', const Color(0xFF00897B)),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: item.$2, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(item.$1,
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 13)),
                ]),
              )),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  decoration: context.cardDeco(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Container(
                      color: context.appTint,
                      child: Row(
                        children: _weekDays
                            .map((d) => Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(d,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: context.appSubtext,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(6),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1.15,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: totalCells,
                        itemBuilder: (_, index) {
                          if (index < startOffset) return const SizedBox.shrink();
                          final day = index - startOffset + 1;
                          final date = DateTime(_month.year, _month.month, day);
                          final entries = byDate[_dateKey(date)] ?? [];
                          final now = DateTime.now();
                          final isToday = now.year == date.year &&
                              now.month == date.month &&
                              now.day == date.day;
                          final isSelected = _selected.year == date.year &&
                              _selected.month == date.month &&
                              _selected.day == date.day;

                          return _CalendarCell(
                            day: day,
                            entries: entries,
                            isToday: isToday,
                            isSelected: isSelected,
                            onTap: () => setState(() => _selected = date),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 280,
                child: _OnLeavePanel(date: _selected, entries: selectedEntries),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.entries,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });
  final int day;
  final List<Map<String, dynamic>> entries;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dots = <String>{};
    for (final e in entries) {
      dots.add(e['leaveType'] as String? ?? '');
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? AppColors.primaryBlue.withAlpha(18) : null,
          border: isSelected ? Border.all(color: AppColors.primaryBlue, width: 1.5) : null,
        ),
        padding: const EdgeInsets.all(6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.primaryBlue, shape: BoxShape.circle)
                : null,
            child: Center(
              child: Text('$day',
                  style: TextStyle(
                      color: isToday ? Colors.white : context.appText,
                      fontSize: 13,
                      fontWeight:
                          isToday ? FontWeight.w600 : FontWeight.w400)),
            ),
          ),
          if (entries.isNotEmpty) ...[
            const Spacer(),
            Row(children: [
              ...dots.take(4).map((type) => Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(color: _leaveColor(type), shape: BoxShape.circle),
                  )),
            ]),
            const SizedBox(height: 3),
            Text('${entries.length} on leave',
                style: TextStyle(color: context.appSubtext, fontSize: 9.5, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}

// ── On-leave side panel ────────────────────────────────────────────────────────
class _OnLeavePanel extends StatelessWidget {
  const _OnLeavePanel({required this.date, required this.entries});
  final DateTime date;
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Container(
      decoration: context.cardDeco(16),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppIcon(AppIcons.beachAccessRounded, size: 15, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text('On Leave', style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            Text(
              isToday ? 'Today · ${DateFormat('MMM d').format(date)}' : DateFormat('EEEE, MMM d').format(date),
              style: TextStyle(color: context.appSubtext, fontSize: 13),
            ),
          ]),
        ),
        Divider(height: 1, color: context.appBorder),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AppIcon(AppIcons.checkCircleOutlineRounded, size: 32, color: context.appSubtext.withAlpha(120)),
                      const SizedBox(height: 8),
                      Text('Nobody on leave this day',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.appSubtext, fontSize: 13)),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: context.appBorder),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final name = e['employeeName'] as String? ?? 'Unknown';
                    final type = e['leaveType'] as String? ?? '';
                    final color = _leaveColor(type);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(children: [
                        _InitialsAvatar(name: name, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(100)),
                          child: Text(_leaveTypeLabel(type),
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  String _leaveTypeLabel(String t) => switch (t) {
    'annual' => 'Annual', 'sick' => 'Sick', 'maternity' => 'Maternity',
    'paternity' => 'Paternity', 'unpaid' => 'Unpaid', 'emergency' => 'Emergency',
    'compassionate' => 'Compassionate', _ => t.isEmpty ? '—' : t,
  };
}
