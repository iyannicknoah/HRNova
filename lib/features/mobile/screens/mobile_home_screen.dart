import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../employees/models/employee_model.dart';
import '../../employees/providers/employees_provider.dart';
import '../../leave/models/leave_request_model.dart';
import '../../leave/providers/leave_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: employeeAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue)),
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
              _BottomNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
            ]);
          },
        ),
      ),
    );
  }
}

// ─── Colours ─────────────────────────────────────────────────────────────────
const _bg       = Color(0xFF070E1C);
const _card     = Color(0xFF0D1628);
// ignore: unused_element — reserved for nested card variant
// const _cardAlt  = Color(0xFF111E35);
const _border   = Color(0xFF1A2E4A);
const _sub      = AppColors.textSecondary;
const _blue     = AppColors.primaryBlue;

// ─── Bottom Nav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.beach_access_rounded, Icons.beach_access_outlined, 'Leave'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border.withAlpha(120), width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8, top: 8),
      child: Row(
        children: List.generate(_items.length, (i) {
          final active = current == i;
          final item = _items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? _blue.withAlpha(25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      active ? item.$1 : item.$2,
                      size: 22,
                      color: active ? _blue : _sub,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(item.$3,
                      style: TextStyle(
                          color: active ? _blue : _sub,
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── HOME TAB ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.employee});
  final EmployeeModel employee;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Transparent top bar ──────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting,
                    style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 13,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 2),
                Text(employee.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            _Av(name: employee.fullName, photoUrl: employee.profilePhotoUrl, size: 42),
          ]),
        ),

        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Role card ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_blue.withAlpha(200), const Color(0xFF6B5FE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.work_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(employee.jobTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(employee.department,
                      style: TextStyle(
                          color: Colors.white.withAlpha(180), fontSize: 13)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('Active',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Leave balance ───────────────────────────────────────────
            const Text('Leave Balance',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _LeaveBalanceTile(
                  label: 'Annual',
                  days: employee.leaveBalances['annual'] ?? 18,
                  total: AppConstants.annualLeaveDaysPerYear,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LeaveBalanceTile(
                  label: 'Sick',
                  days: employee.leaveBalances['sick'] ?? 10,
                  total: 10,
                  color: AppColors.successGreen,
                ),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Quick Info ──────────────────────────────────────────────
            const Text('My Info',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                _InfoRow(icon: Icons.badge_outlined, label: 'Employee ID',
                    value: employee.id.length >= 8
                        ? employee.id.substring(0, 8).toUpperCase()
                        : employee.id.toUpperCase()),
                Divider(height: 1, color: _border),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: employee.email),
                if (employee.phone.isNotEmpty) ...[
                  Divider(height: 1, color: _border),
                  _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: employee.phone),
                ],
              ]),
            ),

            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

class _LeaveBalanceTile extends StatelessWidget {
  const _LeaveBalanceTile({
    required this.label, required this.days,
    required this.total, required this.color,
  });
  final String label;
  final int days, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (days / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('$days',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1)),
        Text('of $total days',
            style: const TextStyle(color: _sub, fontSize: 11)),
        const SizedBox(height: 10),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 18, color: _blue),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(color: _sub, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }
}

// ─── LEAVE TAB ────────────────────────────────────────────────────────────────
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
    final top = MediaQuery.of(context).padding.top;
    final requestsAsync =
        ref.watch(employeeLeaveRequestsProvider(widget.employee.id));

    return Stack(children: [
      CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 20, 20, 0),
              child: const Text('Leave',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                      backgroundColor: _blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
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
                child: Center(child: CircularProgressIndicator(color: _blue))),
            error: (e, _) => SliverFillRemaining(
                child: Center(
                    child: Text('$e',
                        style: const TextStyle(color: _sub)))),
            data: (requests) => requests.isEmpty
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: const Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inbox_rounded, size: 36, color: _sub),
                          SizedBox(height: 8),
                          Text('No leave requests yet',
                              style: TextStyle(color: _sub, fontSize: 13)),
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

// ─── Boarding Pass Cards ──────────────────────────────────────────────────────
class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({
    required this.type, required this.icon,
    required this.days, required this.total, required this.gradient,
  });
  final String type;
  final IconData icon;
  final int days, total;
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 14, color: Colors.white.withAlpha(200)),
                const SizedBox(width: 6),
                Text(type.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 8),
              Text('$days',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              Text('days remaining',
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withAlpha(40),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 4,
                ),
              ),
            ]),
          ),
        ),
        SizedBox(
          width: 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(8, (_) => Container(
              width: 5, height: 5,
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50), shape: BoxShape.circle),
            )),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text('$total days', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('USED', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text('$used days', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SmallPassCard extends StatelessWidget {
  const _SmallPassCard({
    required this.type, required this.icon,
    required this.days, required this.total, required this.color,
  });
  final String type;
  final IconData icon;
  final int days, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text('$days', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800, height: 1)),
        Text('days left', style: TextStyle(color: color.withAlpha(180), fontSize: 11)),
        const SizedBox(height: 4),
        Text(type, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        Text('of $total days', style: const TextStyle(color: _sub, fontSize: 11)),
      ]),
    );
  }
}

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
      'annual' => _blue,
      'sick' => AppColors.successGreen,
      'maternity' => const Color(0xFF9C27B0),
      'paternity' => const Color(0xFF00897B),
      _ => _sub,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
              '${request.leaveType[0].toUpperCase()}${request.leaveType.substring(1)} Leave',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bgCol, borderRadius: BorderRadius.circular(100)),
            child: Text(
                '${request.status[0].toUpperCase()}${request.status.substring(1)}',
                style: TextStyle(color: fgCol, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 12, color: _sub),
          const SizedBox(width: 6),
          Text('${dateF.format(request.startDate)} – ${dateF.format(request.endDate)}',
              style: const TextStyle(color: _sub, fontSize: 12)),
          const SizedBox(width: 12),
          const Icon(Icons.schedule_rounded, size: 12, color: _sub),
          const SizedBox(width: 4),
          Text('${request.totalDays} day${request.totalDays != 1 ? "s" : ""}',
              style: const TextStyle(color: _sub, fontSize: 12)),
        ]),
        if (request.status == 'rejected' && request.rejectedReason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pillRedBg.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.errorRed.withAlpha(60)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.errorRed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(request.rejectedReason!,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 11)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Leave Request Sheet ──────────────────────────────────────────────────────
class _LeaveRequestSheet extends ConsumerStatefulWidget {
  const _LeaveRequestSheet({required this.employee, required this.onClose});
  final EmployeeModel employee;
  final VoidCallback onClose;
  @override
  ConsumerState<_LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends ConsumerState<_LeaveRequestSheet> {
  String _leaveType = 'annual';
  DateTime? _startDate, _endDate;
  final _reasonCtrl = TextEditingController();
  bool _saving = false;
  final _dateF = DateFormat('MMM d, yyyy');

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _pickStart() async {
    final d = await showDatePicker(context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null && mounted) setState(() { _startDate = d; if (_endDate?.isBefore(d) == true) _endDate = null; });
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(context: context,
        initialDate: _startDate ?? DateTime.now().add(const Duration(days: 1)),
        firstDate: _startDate ?? DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null && mounted) setState(() => _endDate = d);
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select start and end dates'))); return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a reason'))); return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(leaveNotifierProvider.notifier).submitLeaveRequest(
        employeeId: widget.employee.id, employeeName: widget.employee.fullName,
        leaveType: _leaveType, startDate: _startDate!, endDate: _endDate!,
        reason: _reasonCtrl.text.trim(), branchId: widget.employee.branchId, source: 'mobile_app');
      if (mounted) { widget.onClose(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted!'), backgroundColor: AppColors.successGreen)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const types = [('annual', 'Annual'), ('sick', 'Sick'), ('maternity', 'Maternity'), ('paternity', 'Paternity'), ('unpaid', 'Unpaid'), ('emergency', 'Emergency')];
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withAlpha(140),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(2)))),
                  const Text('Request Leave', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const Text('Leave Type', style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: types.map((t) {
                    final sel = _leaveType == t.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _leaveType = t.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? _blue : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: sel ? _blue : Colors.white.withAlpha(25)),
                        ),
                        child: Text(t.$2, style: TextStyle(color: sel ? Colors.white : _sub, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _datePicker('Start Date', _startDate != null ? _dateF.format(_startDate!) : 'Select', _pickStart)),
                    const SizedBox(width: 12),
                    Expanded(child: _datePicker('End Date', _endDate != null ? _dateF.format(_endDate!) : 'Select', _pickEnd)),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Reason', style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonCtrl, maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Describe the reason for your leave…',
                      hintStyle: const TextStyle(color: _sub, fontSize: 12),
                      filled: true, fillColor: Colors.white.withAlpha(10),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withAlpha(40)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _datePicker(String label, String value, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: _sub),
              const SizedBox(width: 8),
              Text(value, style: TextStyle(color: value == 'Select' ? _sub : Colors.white, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

// ─── PROFILE TAB ──────────────────────────────────────────────────────────────
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.of(context).padding.top;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Transparent top bar ────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
          child: const Text('Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ),

        const SizedBox(height: 28),

        // ── Avatar + name ──────────────────────────────────────────────
        Center(
          child: Column(children: [
            _Av(name: employee.fullName, photoUrl: employee.profilePhotoUrl, size: 80),
            const SizedBox(height: 14),
            Text(employee.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _blue.withAlpha(25),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(employee.jobTitle,
                  style: const TextStyle(
                      color: _blue, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            if (employee.email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(employee.email,
                  style: const TextStyle(color: _sub, fontSize: 13)),
            ],
          ]),
        ),

        const SizedBox(height: 32),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Account section ────────────────────────────────────────
            const _SectionLabel('Account'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Edit Profile',
                  onTap: () {},
                ),
                Divider(height: 1, color: _border),
                _SettingsRow(
                  icon: Icons.email_outlined,
                  label: 'Change Email',
                  onTap: () => _showChangeEmailDialog(context),
                ),
                Divider(height: 1, color: _border),
                _SettingsRow(
                  icon: Icons.lock_reset_rounded,
                  label: 'Reset Password',
                  subtitle: 'Send reset link to your email',
                  onTap: () => _resetPassword(context, employee.email),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── App section ────────────────────────────────────────────
            const _SectionLabel('App'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Version',
                  subtitle: '1.0.0',
                  showChevron: false,
                  onTap: () {},
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Sign out ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  side: BorderSide(color: AppColors.errorRed.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),

            const SizedBox(height: 32),
          ]),
        ),
      ]),
    );
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    if (email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  void _showChangeEmailDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter your new email address.',
              style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'new@email.com',
              hintStyle: const TextStyle(color: _sub),
              filled: true, fillColor: Colors.white.withAlpha(10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _sub)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final newEmail = ctrl.text.trim();
              if (newEmail.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(newEmail);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Verification sent to $newEmail. Confirm it to complete the change.'),
                    backgroundColor: AppColors.successGreen,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.errorRed,
                  ));
                }
              }
            },
            child: const Text('Send Verification'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _sub))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) context.go('/login');
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _sub,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.showChevron = true,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    const color = Colors.white;
    const iconColor = _blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: const TextStyle(color: _sub, fontSize: 12)),
              ],
            ]),
          ),
          if (showChevron)
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withAlpha(60)),
        ]),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class _Av extends StatelessWidget {
  const _Av({required this.name, this.photoUrl, required this.size});
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _initials()),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final colors = AppColors.gradientForName(name);
    final parts = name.split(' ');
    final ini = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(ini, style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w700)),
    );
  }
}
