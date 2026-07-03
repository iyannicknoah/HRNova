import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../employees/models/employee_model.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/models/leave_request_model.dart';
import '../../leave/providers/leave_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class MobileHomeScreen extends ConsumerStatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  ConsumerState<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends ConsumerState<MobileHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final employeeAsync = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070E1C),
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (employee) {
          if (employee == null) {
            return const Center(
              child: Text('Employee profile not found.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return Column(children: [
            _MobileTopBar(employee: employee),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _HomeTab(employee: employee),
                  _LeaveTab(employee: employee),
                  _ProfileTab(employee: employee),
                ],
              ),
            ),
            _BottomNav(
              current: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 16),
      color: const Color(0xFF0D1628),
      child: Row(children: [
        _Av(name: employee.fullName, photoUrl: employee.profilePhotoUrl, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good ${_greeting()}!',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Text(employee.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            children: [
              TextSpan(text: 'HR', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Nova',
                  style: TextStyle(color: AppColors.primaryBlue)),
            ],
          ),
        ),
      ]),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      color: const Color(0xFF0D1628),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Home',
              active: current == 0, onTap: () => onTap(0)),
          _NavItem(icon: Icons.beach_access_rounded, label: 'Leave',
              active: current == 1, onTap: () => onTap(1)),
          _NavItem(icon: Icons.person_rounded, label: 'Profile',
              active: current == 2, onTap: () => onTap(2)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppColors.primaryBlue : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active
                      ? FontWeight.w600
                      : FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ── HOME TAB ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(today,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Your Dashboard',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        // Department + position card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1628),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.work_rounded,
                  color: AppColors.primaryBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.jobTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(employee.department,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.pillGreenBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text('Active',
                  style: TextStyle(
                      color: AppColors.pillGreenText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Leave Balance',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _MiniBalanceCard(
              label: 'Annual',
              days: employee.leaveBalances['annual'] ?? 18,
              total: AppConstants.annualLeaveDaysPerYear,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniBalanceCard(
              label: 'Sick',
              days: employee.leaveBalances['sick'] ?? 10,
              total: 10,
              color: AppColors.successGreen,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _MiniBalanceCard extends StatelessWidget {
  const _MiniBalanceCard(
      {required this.label,
      required this.days,
      required this.total,
      required this.color});
  final String label;
  final int days;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (days / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('$days',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1)),
        Text('of $total days',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withAlpha(18),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }
}

// ── LEAVE TAB ─────────────────────────────────────────────────────────────────

class _LeaveTab extends ConsumerStatefulWidget {
  const _LeaveTab({required this.employee});
  final EmployeeModel employee;

  @override
  ConsumerState<_LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends ConsumerState<_LeaveTab> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final requestsAsync =
        ref.watch(employeeLeaveRequestsProvider(widget.employee.id));

    return Stack(children: [
      CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text('Leave Balances',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _BoardingPassCard(
                  type: 'Annual Leave',
                  icon: Icons.flight_takeoff_rounded,
                  days: widget.employee.leaveBalances['annual'] ?? 18,
                  total: AppConstants.annualLeaveDaysPerYear,
                  gradient: const [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                ),
                const SizedBox(height: 10),
                _BoardingPassCard(
                  type: 'Sick Leave',
                  icon: Icons.local_hospital_rounded,
                  days: widget.employee.leaveBalances['sick'] ?? 10,
                  total: 10,
                  gradient: const [Color(0xFF065F46), Color(0xFF10B981)],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _SmallPassCard(
                      type: 'Maternity',
                      icon: Icons.child_care_rounded,
                      days: widget.employee.leaveBalances['maternity'] ?? 84,
                      total: AppConstants.maternityLeaveDays,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallPassCard(
                      type: 'Paternity',
                      icon: Icons.family_restroom_rounded,
                      days: widget.employee.leaveBalances['paternity'] ?? 4,
                      total: AppConstants.paternityLeaveDays,
                      color: const Color(0xFF00897B),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _showForm = true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Request Leave',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('My Requests',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
              ]),
            ),
          ),
          requestsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(
                    child: Text('$e',
                        style: const TextStyle(
                            color: AppColors.textSecondary)))),
            data: (requests) => requests.isEmpty
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1628),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withAlpha(15)),
                        ),
                        child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 36,
                                  color: AppColors.textSecondary),
                              SizedBox(height: 8),
                              Text('No leave requests yet',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ]),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RequestCard(request: requests[i]),
                        ),
                        childCount: requests.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      if (_showForm)
        _LeaveRequestSheet(
          employee: widget.employee,
          onClose: () => setState(() => _showForm = false),
        ),
    ]);
  }
}

// ── Boarding Pass Cards ───────────────────────────────────────────────────────

class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({
    required this.type,
    required this.icon,
    required this.days,
    required this.total,
    required this.gradient,
  });
  final String type;
  final IconData icon;
  final int days;
  final int total;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final used = (total - days).clamp(0, total);
    final pct = total > 0 ? (days / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 16,
                        color: Colors.white.withAlpha(200)),
                    const SizedBox(width: 6),
                    Text(type.toUpperCase(),
                        style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ]),
                  const SizedBox(height: 8),
                  Text('$days',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          height: 1)),
                  Text('days remaining',
                      style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white.withAlpha(40),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 4,
                    ),
                  ),
                ]),
          ),
        ),
        SizedBox(
          width: 18,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              8,
              (_) => Container(
                width: 6, height: 6,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 18, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('TOTAL',
                      style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text('$total days',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text('USED',
                      style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text('$used days',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ]),
          ),
        ),
      ]),
    );
  }
}

class _SmallPassCard extends StatelessWidget {
  const _SmallPassCard({
    required this.type,
    required this.icon,
    required this.days,
    required this.total,
    required this.color,
  });
  final String type;
  final IconData icon;
  final int days;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text('$days',
            style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1)),
        Text('days left',
            style: TextStyle(
                color: color.withAlpha(180), fontSize: 11)),
        const SizedBox(height: 4),
        Text(type,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        Text('of $total days',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final LeaveRequestModel request;

  @override
  Widget build(BuildContext context) {
    final dateF = DateFormat('MMM d');
    final (bgCol, fgCol) = switch (request.status) {
      'approved' => (AppColors.pillGreenBg, AppColors.pillGreenText),
      'rejected' => (AppColors.pillRedBg, AppColors.pillRedText),
      _ => (AppColors.pillAmberBg, AppColors.pillAmberText),
    };
    final dotColor = switch (request.leaveType) {
      'annual' => AppColors.primaryBlue,
      'sick' => AppColors.successGreen,
      'maternity' => const Color(0xFF9C27B0),
      'paternity' => const Color(0xFF00897B),
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
              '${request.leaveType[0].toUpperCase()}${request.leaveType.substring(1)} Leave',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: bgCol,
                borderRadius: BorderRadius.circular(100)),
            child: Text(
                '${request.status[0].toUpperCase()}${request.status.substring(1)}',
                style: TextStyle(
                    color: fgCol,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
              '${dateF.format(request.startDate)} – ${dateF.format(request.endDate)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          const Icon(Icons.schedule_rounded,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
              '${request.totalDays} day${request.totalDays != 1 ? "s" : ""}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ]),
        if (request.status == 'rejected' &&
            request.rejectedReason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pillRedBg.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.errorRed.withAlpha(60)),
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.errorRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(request.rejectedReason!,
                        style: const TextStyle(
                            color: AppColors.errorRed, fontSize: 11)),
                  ),
                ]),
          ),
        ],
      ]),
    );
  }
}

// ── Leave Request Sheet ───────────────────────────────────────────────────────

class _LeaveRequestSheet extends ConsumerStatefulWidget {
  const _LeaveRequestSheet(
      {required this.employee, required this.onClose});
  final EmployeeModel employee;
  final VoidCallback onClose;

  @override
  ConsumerState<_LeaveRequestSheet> createState() =>
      _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends ConsumerState<_LeaveRequestSheet> {
  String _leaveType = 'annual';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _saving = false;
  final _dateF = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      setState(() {
        _startDate = d;
        if (_endDate != null && _endDate!.isBefore(d)) _endDate = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) setState(() => _endDate = d);
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please select start and end dates')));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reason')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(leaveNotifierProvider.notifier).submitLeaveRequest(
            employeeId: widget.employee.id,
            employeeName: widget.employee.fullName,
            leaveType: _leaveType,
            startDate: _startDate!,
            endDate: _endDate!,
            reason: _reasonCtrl.text.trim(),
            branchId: widget.employee.branchId,
            source: 'mobile_app',
          );
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Leave request submitted!'),
            backgroundColor: AppColors.successGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const types = [
      ('annual', 'Annual Leave'),
      ('sick', 'Sick Leave'),
      ('maternity', 'Maternity Leave'),
      ('paternity', 'Paternity Leave'),
      ('unpaid', 'Unpaid Leave'),
      ('emergency', 'Emergency Leave'),
    ];

    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withAlpha(120),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1628),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const Text('Request Leave',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      const Text('Leave Type',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: types.map((t) {
                          final sel = _leaveType == t.$1;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _leaveType = t.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primaryBlue
                                    : Colors.white.withAlpha(10),
                                borderRadius:
                                    BorderRadius.circular(100),
                                border: Border.all(
                                    color: sel
                                        ? AppColors.primaryBlue
                                        : Colors.white.withAlpha(25)),
                              ),
                              child: Text(t.$2,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: _datePicker(
                            label: 'Start Date',
                            value: _startDate != null
                                ? _dateF.format(_startDate!)
                                : 'Select date',
                            onTap: _pickStart,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _datePicker(
                            label: 'End Date',
                            value: _endDate != null
                                ? _dateF.format(_endDate!)
                                : 'Select date',
                            onTap: _pickEnd,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      const Text('Reason',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 3,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText:
                              'Briefly describe the reason for your leave…',
                          hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withAlpha(10),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color:
                                      Colors.white.withAlpha(25))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color:
                                      Colors.white.withAlpha(25))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onClose,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Colors.white.withAlpha(40)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(100)),
                            ),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(100)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('Submit Request',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _datePicker(
          {required String label,
          required String value,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withAlpha(25)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(value,
                      style: TextStyle(
                          color: value == 'Select date'
                              ? AppColors.textSecondary
                              : Colors.white,
                          fontSize: 13)),
                ]),
              ),
            ]),
      );
}

// ── PROFILE TAB ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('My Profile',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Center(
          child: Column(children: [
            _Av(name: employee.fullName,
                photoUrl: employee.profilePhotoUrl, size: 72),
            const SizedBox(height: 12),
            Text(employee.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(employee.jobTitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1628),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Column(children: [
            _pRow('Department', employee.department),
            _pRow('Position', employee.jobTitle),
            _pRow('Employee ID',
                employee.id.length >= 8
                    ? employee.id.substring(0, 8).toUpperCase()
                    : employee.id.toUpperCase()),
            if (employee.email.isNotEmpty) _pRow('Email', employee.email),
            if (employee.phone.isNotEmpty)
              _pRow('Phone', employee.phone),
          ]),
        ),
      ]),
    );
  }

  Widget _pRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

// ── Avatar ────────────────────────────────────────────────────────────────────

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
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials()),
      );
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
      width: size, height: size,
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
