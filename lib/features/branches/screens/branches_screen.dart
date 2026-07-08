import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/providers/leave_provider.dart';
import '../models/branch_model.dart';
import '../providers/branches_provider.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  String _search = '';

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddBranchDialog(
      notifier: ref.read(branchesNotifierProvider.notifier),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesStreamProvider);
    final companyType = ref.watch(companyTypeProvider).valueOrNull ?? 'single';
    final isSingle = companyType == 'single';

    return Scaffold(
      backgroundColor: context.appBg,
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.errorRed))),
        data: (branches) {
          final filtered = _search.isEmpty
              ? branches
              : branches.where((b) {
                  final q = _search.toLowerCase();
                  return b.name.toLowerCase().contains(q) ||
                      b.location.toLowerCase().contains(q) ||
                      b.branchCode.toLowerCase().contains(q);
                }).toList();

          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Branches', style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Manage your company branches', style: TextStyle(color: context.appSubtext, fontSize: 15)),
                    ]),
                    const Spacer(),
                    if (!isSingle)
                      FilledButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Branch'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isSingle) ...[
                  Expanded(child: _SingleCompanyEmptyState()),
                ] else ...[
                  // Branch count
                  Text('${branches.length} ${branches.length == 1 ? 'branch' : 'branches'}',
                      style: TextStyle(fontSize: 14, color: context.appSubtext)),
                  const SizedBox(height: 16),
                  // Search
                  Container(
                    decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: TextStyle(color: context.appText, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search branches...',
                        hintStyle: TextStyle(color: context.appSubtext),
                        prefixIcon: Icon(Icons.search_rounded, color: context.appSubtext, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Grid
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.business_outlined, size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text(
                                branches.isEmpty ? 'No branches yet — add one to get started' : 'No branches match your search',
                                style: TextStyle(color: context.appSubtext, fontSize: 16),
                              ),
                            ]),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 380, childAspectRatio: 1.5,
                              crossAxisSpacing: 14, mainAxisSpacing: 14,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _BranchCard(
                              branch: filtered[i],
                              onToggleActive: (active) async {
                                await ref.read(branchesNotifierProvider.notifier)
                                    .setActive(filtered[i].id, isActive: active);
                              },
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => _BranchDetailDialog(branch: filtered[i]),
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Single company placeholder ────────────────────────────────────────────────
class _SingleCompanyEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(30),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.business_outlined, size: 40, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),
          Text(
            'Single Location Company',
            style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'This company is set up as a single location.\nBranch management is not available.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appSubtext, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 18),
            const SizedBox(width: 10),
            Text(
              'Contact us to upgrade for Multi-Branch',
              style: TextStyle(color: AppColors.primaryBlue, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Branch card ───────────────────────────────────────────────────────────────
class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.onToggleActive, this.onTap});
  final BranchModel branch;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _BranchCardContent(branch: branch, onToggleActive: onToggleActive),
    );
  }
}

class _BranchCardContent extends StatelessWidget {
  const _BranchCardContent({required this.branch, required this.onToggleActive});
  final BranchModel branch;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.gradientForName(branch.name), begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(branch.name[0], style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(branch.name, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                if (branch.branchCode.isNotEmpty)
                  Text(branch.branchCode, style: TextStyle(color: context.appSubtext, fontSize: 13)),
              ])),
              GestureDetector(
                onTap: () => onToggleActive(!branch.isActive),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: branch.isActive ? AppColors.pillGreenBg : AppColors.pillRedBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    branch.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: branch.isActive ? AppColors.pillGreenText : AppColors.pillRedText, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: 10),
          _row(Icons.location_on_rounded, branch.location.isEmpty ? 'No location set' : branch.location),
          const SizedBox(height: 6),
          _row(Icons.people_rounded, '${branch.employeeCount} employees'),
          const SizedBox(height: 6),
          _row(Icons.email_outlined, branch.branchHrAdminEmail ?? 'No HR Admin assigned'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Builder(builder: (context) => Row(children: [
    Icon(icon, size: 14, color: context.appSubtext),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: TextStyle(color: context.appSubtext, fontSize: 14), overflow: TextOverflow.ellipsis)),
  ]));
}

// ── Branch detail dialog ──────────────────────────────────────────────────────
class _BranchDetailDialog extends ConsumerWidget {
  const _BranchDetailDialog({required this.branch});
  final BranchModel branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final allEmployees = ref.watch(employeesProvider).value ?? [];
    final branchEmployees = allEmployees.where((e) => e.branchId == branch.id).toList();
    final activeCount   = branchEmployees.where((e) => e.isActive).length;
    final inactiveCount = branchEmployees.length - activeCount;

    final records = ref.watch(attendanceByDateProvider(today)).value ?? [];
    final branchRecords = records.where((r) => r.branchId == branch.id).toList();
    final presentCount  = branchRecords.where((r) => r.checkInTime != null && !r.isAbsent && !r.isLate).length;
    final lateCount     = branchRecords.where((r) => r.isLate).length;
    final absentCount   = activeCount - presentCount - lateCount;

    final allLeaves = ref.watch(allLeaveRequestsProvider).value ?? [];
    final branchLeaves = allLeaves.where((l) => l.branchId == branch.id).toList();
    final pendingLeaves  = branchLeaves.where((l) => l.status == 'pending').length;
    final approvedLeaves = branchLeaves.where((l) => l.status == 'approved').length;

    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.gradientForName(branch.name), begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(branch.name[0], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(branch.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.appText)),
                if (branch.location.isNotEmpty)
                  Text(branch.location, style: TextStyle(fontSize: 14, color: context.appSubtext)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: branch.isActive ? AppColors.pillGreenBg : AppColors.pillRedBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(branch.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: branch.isActive ? AppColors.pillGreenText : AppColors.pillRedText)),
              ),
              const SizedBox(width: 10),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: context.appSubtext)),
            ]),
            const SizedBox(height: 8),
            if (branch.branchCode.isNotEmpty)
              Text('Code: ${branch.branchCode}', style: TextStyle(fontSize: 13, color: context.appSubtext)),
            if (branch.branchHrAdminEmail != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.email_outlined, size: 13, color: context.appSubtext),
                const SizedBox(width: 6),
                Text(branch.branchHrAdminEmail!, style: TextStyle(fontSize: 13, color: context.appSubtext)),
              ]),
            ],
            Divider(color: context.appBorder, height: 28),
            // Employee stats
            Text('Employees', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            Row(children: [
              _DetailStat('Total', '${branchEmployees.length}', AppColors.primaryBlue),
              const SizedBox(width: 10),
              _DetailStat('Active', '$activeCount', AppColors.successGreen),
              const SizedBox(width: 10),
              _DetailStat('Inactive', '$inactiveCount', AppColors.warningAmber),
            ]),
            const SizedBox(height: 20),
            // Today's attendance
            Text("Today's Attendance", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            Row(children: [
              _DetailStat('Present', '$presentCount', AppColors.successGreen),
              const SizedBox(width: 10),
              _DetailStat('Late', '$lateCount', AppColors.warningAmber),
              const SizedBox(width: 10),
              _DetailStat('Absent', '${absentCount.clamp(0, activeCount)}', AppColors.errorRed),
            ]),
            const SizedBox(height: 20),
            // Leave summary
            Text('Leave Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            Row(children: [
              _DetailStat('Pending', '$pendingLeaves', AppColors.warningAmber),
              const SizedBox(width: 10),
              _DetailStat('Approved (all time)', '$approvedLeaves', AppColors.successGreen),
            ]),
            const SizedBox(height: 24),
            // Attendance rate progress
            if (activeCount > 0) ...[
              Row(children: [
                Text('Attendance Rate Today', style: TextStyle(fontSize: 14, color: context.appSubtext)),
                const Spacer(),
                Text('${(((presentCount + lateCount) / activeCount) * 100).round()}%',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((presentCount + lateCount) / activeCount).clamp(0.0, 1.0),
                  backgroundColor: context.appBorder,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primaryBlue),
                  minHeight: 8,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: context.appSubtext)),
      ]),
    ),
  );
}

// ── Add Branch dialog (two-step) ──────────────────────────────────────────────
class _AddBranchDialog extends ConsumerStatefulWidget {
  const _AddBranchDialog({required this.notifier});
  final BranchesNotifier notifier;

  @override
  ConsumerState<_AddBranchDialog> createState() => _AddBranchDialogState();
}

class _AddBranchDialogState extends ConsumerState<_AddBranchDialog> {
  // Step 1 controllers
  final _nameCtrl = TextEditingController();
  final _locCtrl  = TextEditingController();
  final _codeCtrl = TextEditingController();

  // Step 2 — new HR controllers
  final _hrFirstCtrl  = TextEditingController();
  final _hrLastCtrl   = TextEditingController();
  final _hrEmailCtrl  = TextEditingController();
  final _hrPassCtrl   = TextEditingController();

  int _step = 1;           // 1 = branch info, 2 = HR assignment
  String? _createdBranchId;
  String? _createdBranchName;

  bool _useExisting = true; // true = select existing HR, false = add new
  String? _selectedEmployeeId;
  bool _obscure  = true;
  bool _saving   = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _locCtrl.dispose(); _codeCtrl.dispose();
    _hrFirstCtrl.dispose(); _hrLastCtrl.dispose();
    _hrEmailCtrl.dispose(); _hrPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _createBranch() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Branch name is required');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final branchId = await widget.notifier.addBranch(
        name: _nameCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        branchCode: _codeCtrl.text.trim(),
      );
      setState(() {
        _createdBranchId   = branchId;
        _createdBranchName = _nameCtrl.text.trim();
        _step   = 2;
        _saving = false;
      });
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Future<void> _assignHr() async {
    setState(() { _saving = true; _error = null; });
    try {
      if (_useExisting) {
        if (_selectedEmployeeId == null) {
          setState(() { _saving = false; _error = 'Please select an HR admin.'; });
          return;
        }
        final allEmps = ref.read(employeesProvider).value ?? [];
        final emp = allEmps.firstWhere((e) => e.id == _selectedEmployeeId,
            orElse: () => throw Exception('Employee not found'));
        await widget.notifier.assignExistingHrToBranch(
          _createdBranchId!,
          employeeId: emp.id,
          employeeEmail: emp.email,
          existingBranchId: emp.branchId,
        );
      } else {
        if (_hrFirstCtrl.text.trim().isEmpty || _hrEmailCtrl.text.trim().isEmpty || _hrPassCtrl.text.trim().isEmpty) {
          setState(() { _saving = false; _error = 'First name, email and password are required.'; });
          return;
        }
        await widget.notifier.addNewHrToBranch(
          _createdBranchId!,
          firstName: _hrFirstCtrl.text.trim(),
          lastName: _hrLastCtrl.text.trim(),
          email: _hrEmailCtrl.text.trim(),
          password: _hrPassCtrl.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$_createdBranchName" branch set up successfully'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _skip() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"$_createdBranchName" branch created. Assign an HR admin later.'),
      backgroundColor: AppColors.warningAmber,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: _step == 1 ? _buildStep1(context) : _buildStep2(context),
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _dialogHeader(context, 'Add New Branch', 'Step 1 of 2 — Branch Details'),
      const SizedBox(height: 24),
      _dlgField('Branch Name *', _nameCtrl, hint: 'e.g. Musanze Branch'),
      const SizedBox(height: 14),
      _dlgField('Location', _locCtrl, hint: 'e.g. Musanze District'),
      const SizedBox(height: 14),
      _dlgField('Branch Code', _codeCtrl, hint: 'e.g. MSZ-001'),
      _errorBox(),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _outlinedBtn('Cancel', () => Navigator.pop(context))),
        const SizedBox(width: 12),
        Expanded(child: _filledBtn('Next: Assign HR →', _saving ? null : _createBranch, loading: _saving)),
      ]),
    ]);
  }

  Widget _buildStep2(BuildContext context) {
    final allEmps = ref.watch(employeesProvider).value ?? [];
    // Only show branch_hr_admin employees not yet assigned to any branch
    final unassignedHrs = allEmps.where((e) =>
        e.role == 'branch_hr_admin' && (e.branchId == null || e.branchId!.isEmpty)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _dialogHeader(context, 'Assign HR Admin', 'Step 2 of 2 — "$_createdBranchName"'),
      const SizedBox(height: 20),

      // Toggle: existing or new
      Container(
        decoration: BoxDecoration(color: context.appField, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          _tab('Select Existing HR', _useExisting, () => setState(() { _useExisting = true; _error = null; })),
          _tab('Add New HR', !_useExisting, () => setState(() { _useExisting = false; _error = null; })),
        ]),
      ),
      const SizedBox(height: 20),

      if (_useExisting) ...[
        Text('Choose an HR admin to assign to this branch:',
            style: TextStyle(fontSize: 14, color: context.appSubtext)),
        const SizedBox(height: 10),
        if (unassignedHrs.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appField,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: context.appSubtext),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'No unassigned HR admins found. Use "Add New HR" or skip and assign later.',
                style: TextStyle(fontSize: 14, color: context.appSubtext),
              )),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.appField,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedEmployeeId,
                hint: Text('Select HR admin…', style: TextStyle(color: context.appSubtext, fontSize: 15)),
                style: TextStyle(fontSize: 15, color: context.appText),
                icon: Icon(Icons.keyboard_arrow_down, color: context.appSubtext, size: 18),
                items: unassignedHrs.map((e) => DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.fullName} · ${e.email}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: context.appText)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedEmployeeId = v),
              ),
            ),
          ),
      ] else ...[
        _dlgField('First Name *', _hrFirstCtrl, hint: 'First name'),
        const SizedBox(height: 12),
        _dlgField('Last Name', _hrLastCtrl, hint: 'Last name'),
        const SizedBox(height: 12),
        _dlgField('Email *', _hrEmailCtrl, hint: 'hr@company.rw', type: TextInputType.emailAddress),
        const SizedBox(height: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Password *', style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _hrPassCtrl,
            obscureText: _obscure,
            style: TextStyle(color: context.appText, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Min 6 characters',
              hintStyle: TextStyle(color: context.appSubtext),
              filled: true, fillColor: context.appField,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: context.appSubtext),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
            ),
          ),
        ]),
      ],

      _errorBox(),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _outlinedBtn('Skip for now', _saving ? null : _skip)),
        const SizedBox(width: 12),
        Expanded(child: _filledBtn('Assign HR', _saving ? null : _assignHr, loading: _saving)),
      ]),
    ]);
  }

  Widget _dialogHeader(BuildContext context, String title, String subtitle) {
    return Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add_business_rounded, color: AppColors.primaryBlue, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w700)),
        Text(subtitle, style: TextStyle(color: context.appSubtext, fontSize: 13)),
      ])),
      IconButton(onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: context.appSubtext)),
    ]);
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: active ? Colors.white : context.appSubtext,
        )),
      ),
    ));
  }

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.pillRedBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 14))),
        ]),
      ),
    );
  }

  Widget _outlinedBtn(String label, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: context.appBorder),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      child: Text(label, style: TextStyle(color: context.appText, fontWeight: FontWeight.w600)),
    );
  }

  Widget _filledBtn(String label, VoidCallback? onTap, {bool loading = false}) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        disabledBackgroundColor: AppColors.primaryBlue.withAlpha(100),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      child: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _dlgField(String label, TextEditingController ctrl, {String? hint, TextInputType? type}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type,
          style: TextStyle(color: context.appText, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.appSubtext),
            filled: true, fillColor: context.appField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
        ),
      ]);
}
