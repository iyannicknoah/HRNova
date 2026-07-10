import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_table.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main screen
// ─────────────────────────────────────────────────────────────────────────────
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _search = '';
  String _deptFilter = 'all';
  String _contractFilter = 'all';
  String _statusFilter = 'all';
  String? _branchFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAdd() => context.push('/employees/new');
  void _openEdit(EmployeeModel e) => context.push('/employees/new?editId=${e.id}');

  List<EmployeeModel> _filter(List<EmployeeModel> all) {
    return all.where((e) {
      final q = _search.toLowerCase();
      if (q.isNotEmpty) {
        final match = e.fullName.toLowerCase().contains(q) ||
            e.nationalId.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_deptFilter != 'all' && e.department != _deptFilter) return false;
      if (_contractFilter != 'all' && e.contractType != _contractFilter) return false;
      if (_statusFilter != 'all' && e.status != _statusFilter) return false;
      if (_branchFilter != null && e.branchId != _branchFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(companySettingsProvider);
    final departments = settingsAsync.value?.departments ?? const [];
    final limitAsync = ref.watch(companyEmployeeLimitProvider);
    final limit = limitAsync.value ?? (current: 0, max: 0);
    final atLimit = limit.max > 0 && limit.current >= limit.max;
    final role = ref.watch(currentUserRoleProvider);
    final companyType = ref.watch(companyTypeProvider).valueOrNull ?? AppConstants.companySingle;
    final isMultiBranch = companyType == AppConstants.companyMultiBranch;
    final showBranchFilter = isMultiBranch &&
        (role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin);
    final branches = showBranchFilter ? (ref.watch(branchesStreamProvider).value ?? []) : [];

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            count: limit.current,
            max: limit.max,
            atLimit: atLimit,
            onAdd: (role == AppConstants.roleManager || atLimit) ? null : _openAdd,
            showAdd: role != AppConstants.roleManager,
          ),
          _FilterBar(
            searchCtrl: _searchCtrl,
            onSearch: (v) => setState(() => _search = v),
            departments: departments,
            deptFilter: _deptFilter,
            onDept: (v) => setState(() => _deptFilter = v ?? 'all'),
            contractFilter: _contractFilter,
            onContract: (v) => setState(() => _contractFilter = v ?? 'all'),
            statusFilter: _statusFilter,
            onStatus: (v) => setState(() => _statusFilter = v ?? 'all'),
            showBranchFilter: showBranchFilter,
            branches: branches,
            branchFilter: _branchFilter,
            onBranch: (v) => setState(() => _branchFilter = v),
          ),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.errorRed))),
              data: (employees) {
                final filtered = _filter(employees);
                if (filtered.isEmpty) {
                  final isSearching = _search.isNotEmpty || _deptFilter != 'all' || _contractFilter != 'all' || _statusFilter != 'all';
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AppIcon(AppIcons.peopleOutline, size: 64, color: context.appSubtext),
                      const SizedBox(height: 12),
                      Text(
                        isSearching ? 'No employees match your filters' : 'No employees yet',
                        style: TextStyle(color: context.appSubtext, fontSize: 16),
                      ),
                      if (!isSearching) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Get started by adding your first employee',
                          style: TextStyle(color: context.appSubtext, fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        HRNovaButton(
                          label: 'Add First Employee',
                          onPressed: _openAdd,
                          icon: AppIcons.addRounded,
                          isFullWidth: false,
                        ),
                      ],
                    ]),
                  );
                }
                return _EmployeeTable(
                  employees: filtered,
                  onView: (e) => context.push('/employees/${e.id}'),
                  onEdit: _openEdit,
                  onDeactivate: (e) => _confirmDeactivate(context, e),
                  onDelete: (e) => _confirmDelete(context, e),
                  canEdit: role != AppConstants.roleManager,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, EmployeeModel e) {
    AppDialogShell.show<void>(
      context: context,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deactivate Employee?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: context.appText)),
            const SizedBox(height: 12),
            Text('${e.fullName} will be marked inactive. This does not delete their data.', style: TextStyle(color: context.appSubtext)),
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
                  label: 'Deactivate',
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await ref.read(employeesNotifierProvider.notifier).deactivate(e.id);
                    } catch (err) {
                      if (mounted) _showErr(err.toString());
                    }
                  },
                  textColor: AppColors.errorRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, EmployeeModel e) {
    AppDialogShell.show<void>(
      context: context,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.errorRed.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                child: const AppIcon(AppIcons.deleteOutlineRounded, color: AppColors.errorRed, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Delete Employee?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: context.appText)),
              ),
            ]),
            const SizedBox(height: 15),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${e.fullName}', style: TextStyle(fontWeight: FontWeight.w600, color: context.appText)),
              TextSpan(text: ' will be permanently removed from the employee list.', style: TextStyle(color: context.appSubtext)),
            ])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.errorRed.withAlpha(40)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppIcon(AppIcons.warningAmberRounded, size: 15, color: AppColors.errorRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('This action cannot be undone. Attendance and leave records are preserved.',
                      style: TextStyle(fontSize: 14, color: context.appText)),
                ),
              ]),
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
                  label: 'Delete',
                  onPressed: () async {
                    Navigator.pop(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(employeesNotifierProvider.notifier).deleteEmployee(e.id, email: e.email.isNotEmpty ? e.email : null);
                      if (mounted) messenger.showSnackBar(
                        SnackBar(content: Text('${e.fullName} deleted'), backgroundColor: AppColors.successGreen),
                      );
                    } catch (err) {
                      if (mounted) _showErr(err.toString());
                    }
                  },
                  textColor: AppColors.errorRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.errorRed, content: Text(msg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.max,
    required this.atLimit,
    required this.onAdd,
    this.showAdd = true,
  });
  final int count;
  final int max;
  final bool atLimit;
  final VoidCallback? onAdd;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final hasLimit = max > 0;
    final pct = hasLimit ? (count / max).clamp(0.0, 1.0) : 0.0;
    final barColor = atLimit
        ? AppColors.errorRed
        : pct >= 0.8
            ? AppColors.warningAmber
            : AppColors.primaryBlue;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Employees',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.appText)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: atLimit
                        ? context.pillRedBg
                        : context.pillBlueBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    hasLimit ? '$count / $max' : '$count Active',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: atLimit
                            ? AppColors.errorRed
                            : AppColors.primaryBlue)),
              ),
              const Spacer(),
              if (showAdd) ...[
                if (atLimit)
                  Tooltip(
                    message: 'Employee limit reached. Contact your administrator.',
                    child: FilledButton.icon(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.errorRed.withAlpha(30),
                        foregroundColor: AppColors.errorRed,
                        disabledBackgroundColor: AppColors.errorRed.withAlpha(30),
                        disabledForegroundColor: AppColors.errorRed,
                      ),
                      icon: const AppIcon(AppIcons.blockRounded, size: 16),
                      label: const Text('Limit Reached',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  )
                else
                  HRNovaButton(
                    label: 'Add Employee',
                    onPressed: onAdd ?? () {},
                    icon: AppIcons.addRounded,
                    isFullWidth: false,
                  ),
              ],
            ],
          ),
          if (hasLimit) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: context.appBorder,
                    valueColor: AlwaysStoppedAnimation(barColor),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                atLimit
                    ? 'Limit reached'
                    : '${max - count} slot${max - count == 1 ? '' : 's'} remaining',
                style: TextStyle(
                    fontSize: 13,
                    color: atLimit ? AppColors.errorRed : context.appSubtext,
                    fontWeight:
                        atLimit ? FontWeight.w500 : FontWeight.normal),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl, required this.onSearch,
    required this.departments, required this.deptFilter, required this.onDept,
    required this.contractFilter, required this.onContract,
    required this.statusFilter, required this.onStatus,
    required this.showBranchFilter,
    required this.branches,
    required this.branchFilter,
    required this.onBranch,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final List<String> departments;
  final String deptFilter;
  final ValueChanged<String?> onDept;
  final String contractFilter;
  final ValueChanged<String?> onContract;
  final String statusFilter;
  final ValueChanged<String?> onStatus;
  final bool showBranchFilter;
  final List<dynamic> branches;
  final String? branchFilter;
  final ValueChanged<String?> onBranch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 0, 24, 16),
      child: Wrap(
        spacing: 10, runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260, height: 40,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search name, ID or email…',
                hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
                prefixIcon: AppIcon(AppIcons.search, size: 18, color: context.appSubtext),
                filled: true, fillColor: context.appCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.alternate)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.alternate)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.tertiary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
          _DropFilter(
            value: deptFilter,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Departments')),
              ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
            ],
            onChanged: onDept,
          ),
          _DropFilter(
            value: contractFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Contracts')),
              DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
              DropdownMenuItem(value: 'fixed_term', child: Text('Fixed Term')),
              DropdownMenuItem(value: 'probation', child: Text('Probation')),
              DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
            ],
            onChanged: onContract,
          ),
          _DropFilter(
            value: statusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: onStatus,
          ),
          if (showBranchFilter)
            _DropFilter(
              value: branchFilter ?? 'all',
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Branches')),
                ...branches.map((b) => DropdownMenuItem(value: b.id as String, child: Text(b.name as String))),
              ],
              onChanged: (v) => onBranch(v == 'all' ? null : v),
            ),
        ],
      ),
    );
  }
}

class _DropFilter extends StatelessWidget {
  const _DropFilter({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 160),
      decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.alternate)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, items: items, onChanged: onChanged,
          dropdownColor: context.appCard,
          style: TextStyle(color: context.appText, fontSize: 15),
          icon: AppIcon(AppIcons.keyboardArrowDown, size: 18, color: context.appSubtext),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Employee Table
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({required this.employees, required this.onView, required this.onEdit, required this.onDeactivate, required this.onDelete, this.canEdit = true});
  final List<EmployeeModel> employees;
  final ValueChanged<EmployeeModel> onView;
  final ValueChanged<EmployeeModel> onEdit;
  final ValueChanged<EmployeeModel> onDeactivate;
  final ValueChanged<EmployeeModel> onDelete;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: context.cardDeco(12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppTableHeader(
              columns: [
                'EMPLOYEE', 'DEPARTMENT', 'JOB TITLE', 'CONTRACT',
                if (canEdit) 'SALARY',
                'STATUS', 'ACTIONS',
              ],
              flex: [30, 18, 18, 15, if (canEdit) 17, 12, 14],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: context.alternate),
              itemBuilder: (context, i) {
                final e = employees[i];
                return InkWell(
                  onTap: () => onView(e),
                  hoverColor: context.appTint,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(children: [
                      Expanded(flex: 30, child: Row(children: [
                        _Avatar(name: e.fullName, photoUrl: e.profilePhotoUrl, size: 34),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.fullName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: context.appText), overflow: TextOverflow.ellipsis)),
                      ])),
                      Expanded(flex: 18, child: Text(e.department, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: context.appText))),
                      Expanded(flex: 18, child: Text(e.jobTitle.isEmpty ? '—' : e.jobTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: context.appText), overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 15, child: Align(alignment: Alignment.centerLeft, child: _Chip(_ctLabel(e.contractType), context.pillBlueBg, context.pillBlueText))),
                      if (canEdit) Expanded(flex: 17, child: Text(_salaryStr(e), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.appText))),
                      Expanded(flex: 12, child: Align(alignment: Alignment.centerLeft, child: StatusBadge.fromString(e.status))),
                      Expanded(flex: 14, child: Row(children: [
                        _ActionBtn(AppIcons.visibilityOutlined, 'View Profile', () => onView(e)),
                        if (canEdit) _ActionBtn(AppIcons.editOutlined, 'Edit', () => onEdit(e)),
                        if (canEdit && e.isActive) _ActionBtn(AppIcons.blockOutlined, 'Deactivate', () => onDeactivate(e), color: AppColors.warningAmber),
                        if (canEdit) _ActionBtn(AppIcons.deleteOutlineRounded, 'Delete', () => onDelete(e), color: AppColors.errorRed),
                      ])),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _ctLabel(String c) => switch (c) {
    'fixed_term' => 'Fixed Term', 'probation' => 'Probation', 'part_time' => 'Part Time', _ => 'Permanent',
  };

  static String _salaryStr(EmployeeModel e) {
    final v = switch (e.salaryType) { 'daily_rate' => e.dailyRate, 'hourly_rate' => e.hourlyRate, _ => e.salaryAmount };
    if (v == 0) return '—';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer('RWF ');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return switch (e.salaryType) { 'daily_rate' => '${buf.toString()}/day', 'hourly_rate' => '${buf.toString()}/hr', _ => buf.toString() };
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.bg, this.fg);
  final String label; final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg)),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(this.icon, this.tip, this.onTap, {this.color});
  final IconRef icon; final String tip; final VoidCallback onTap; final Color? color;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.all(5), child: AppIcon(icon, size: 17, color: color ?? context.appSubtext))),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl, this.size = 36});
  final String name; final String? photoUrl; final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(child: Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initials()));
    }
    return _initials();
  }

  Widget _initials() {
    final colors = AppColors.gradientForName(name);
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase()
        : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w600)),
    );
  }
}

