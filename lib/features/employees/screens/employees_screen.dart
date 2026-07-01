import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';

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
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(companySettingsProvider);
    final departments = settingsAsync.value?.departments ?? const [];

    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            count: employeesAsync.value?.where((e) => e.isActive).length ?? 0,
            onAdd: _openAdd,
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
                      Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        isSearching ? 'No employees match your filters' : 'No employees yet',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      if (!isSearching) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Get started by adding your first employee',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        _PillBtn(label: 'Add First Employee', onTap: _openAdd),
                      ],
                    ]),
                  );
                }
                return _EmployeeTable(
                  employees: filtered,
                  onView: (e) => context.push('/employees/${e.id}'),
                  onEdit: _openEdit,
                  onDeactivate: (e) => _confirmDeactivate(context, e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, EmployeeModel e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Deactivate Employee?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('${e.fullName} will be marked inactive. This does not delete their data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(employeesNotifierProvider.notifier).deactivate(e.id);
              } catch (err) {
                if (mounted) _showErr(err.toString());
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
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
  const _Header({required this.count, required this.onAdd});
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 16),
      child: Row(
        children: [
          const Text('Employees', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(20)),
            child: Text('$count Active', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
          ),
          const Spacer(),
          _PillBtn(label: 'Add Employee', onTap: onAdd),
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
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryBlue)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, items: items, onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Employee Table
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({required this.employees, required this.onView, required this.onEdit, required this.onDeactivate});
  final List<EmployeeModel> employees;
  final ValueChanged<EmployeeModel> onView;
  final ValueChanged<EmployeeModel> onEdit;
  final ValueChanged<EmployeeModel> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue50,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(children: const [
              Expanded(flex: 30, child: Text('EMPLOYEE', style: _hStyle)),
              Expanded(flex: 18, child: Text('DEPARTMENT', style: _hStyle)),
              Expanded(flex: 18, child: Text('JOB TITLE', style: _hStyle)),
              Expanded(flex: 15, child: Text('CONTRACT', style: _hStyle)),
              Expanded(flex: 17, child: Text('SALARY', style: _hStyle)),
              Expanded(flex: 12, child: Text('STATUS', style: _hStyle)),
              Expanded(flex: 14, child: Text('ACTIONS', style: _hStyle)),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.cardBorder),
              itemBuilder: (context, i) {
                final e = employees[i];
                return InkWell(
                  onTap: () => onView(e),
                  hoverColor: AppColors.lightBlue50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Expanded(flex: 30, child: Row(children: [
                        _Avatar(name: e.fullName, photoUrl: e.profilePhotoUrl, size: 34),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text(e.email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                        ])),
                      ])),
                      Expanded(flex: 18, child: Text(e.department, style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 18, child: Text(e.jobTitle.isEmpty ? '—' : e.jobTitle, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 15, child: _Chip(_ctLabel(e.contractType), AppColors.pillBlueBg, AppColors.pillBlueText)),
                      Expanded(flex: 17, child: Text(_salaryStr(e), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 12, child: _StatusBadge(e.status)),
                      Expanded(flex: 14, child: Row(children: [
                        _ActionBtn(Icons.visibility_outlined, 'View Profile', () => onView(e)),
                        _ActionBtn(Icons.edit_outlined, 'Edit', () => onEdit(e)),
                        if (e.isActive) _ActionBtn(Icons.block_outlined, 'Deactivate', () => onDeactivate(e), color: AppColors.errorRed),
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

  static const _hStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5);

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
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'active'   => ('Active', AppColors.pillGreenBg, AppColors.pillGreenText),
      'inactive' => ('Inactive', AppColors.pillRedBg, AppColors.pillRedText),
      _          => (status, AppColors.pillNavyBg, AppColors.pillNavyText),
    };
    return _Chip(label, bg, fg);
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(this.icon, this.tip, this.onTap, {this.color = AppColors.textSecondary});
  final IconData icon; final String tip; final VoidCallback onTap; final Color color;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 17, color: color))),
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
      child: Text(initials, style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom pill button — bypasses M3 ElevatedButton theming entirely
// ─────────────────────────────────────────────────────────────────────────────
class _PillBtn extends StatelessWidget {
  const _PillBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(70), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
