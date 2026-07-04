import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../features/attendance/models/attendance_model.dart';
import '../../../features/attendance/providers/attendance_provider.dart';
import '../../../features/employees/models/employee_model.dart';
import '../../../features/employees/providers/employees_provider.dart';
import '../../../features/leave/models/leave_request_model.dart';
import '../../../features/leave/providers/leave_provider.dart';
import '../../../features/payroll/models/payroll_model.dart';
import '../../../features/payroll/providers/payroll_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/working_days_service.dart';
import '../../../features/auth/providers/auth_provider.dart';

const _bg = Color(0xFF070E1C);
const _card = Color(0xFF0D1628);
const _border = Color(0xFF1A2E4A);
const _blue = Color(0xFF4A9EFF);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFE5534B);
const _amber = Color(0xFFF59E0B);
const _textSec = Color(0xFF6B7A99);

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
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
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          _AttendanceTab(),
          _LeaveTab(),
          _PayslipTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: _card,
        selectedItemColor: _blue,
        unselectedItemColor: _textSec,
        selectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded), label: 'Attendance'),
          BottomNavigationBarItem(
              icon: Icon(Icons.beach_access_rounded), label: 'Leave'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Payslip'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(currentEmployeeProvider);
    return empAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _blue)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (emp) {
        if (emp == null) {
          return const Center(
              child: Text('Profile not found',
                  style: TextStyle(color: _textSec)));
        }
        return _HomeContent(emp: emp, greeting: _greeting());
      },
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.emp, required this.greeting});

  final EmployeeModel emp;
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthParam = (employeeId: emp.id, year: now.year, month: now.month);
    final attAsync = ref.watch(employeeAttendanceByMonthProvider(monthParam));
    final leaveAsync = ref.watch(employeeLeaveRequestsProvider(emp.id));

    final records = attAsync.value ?? [];
    final leaves = leaveAsync.value ?? [];

    final today = attAsync.value?.where((a) {
      final d = a.date;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).firstOrNull;

    final presentCount =
        records.where((a) => !a.isAbsent && !a.isOnLeave).length;
    final lateCount = records.where((a) => a.isLate).length;
    final annualBalance =
        (emp.leaveBalances['annual'] as num?)?.toInt() ?? AppConstants.annualLeaveDaysPerYear;
    final pendingLeaves = leaves.where((l) => l.status == 'pending').length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(emp, greeting),
          const SizedBox(height: 20),
          _buildTodayCard(today, now),
          const SizedBox(height: 20),
          _buildStatsGrid(presentCount, lateCount, annualBalance, pendingLeaves),
          const SizedBox(height: 24),
          const Text('Recent Attendance',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (records.isEmpty)
            _emptyHint('No attendance records this month')
          else
            ...records.take(5).map((a) => _AttendanceRow(att: a)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(EmployeeModel emp, String greeting) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: const TextStyle(color: _textSec, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${emp.firstName} ${emp.lastName}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text(emp.jobTitle,
                  style: const TextStyle(color: _textSec, fontSize: 15)),
            ],
          ),
        ),
        _Avatar(emp: emp, radius: 24),
      ],
    );
  }

  Widget _buildTodayCard(AttendanceModel? today, DateTime now) {
    final fmt = DateFormat('hh:mm a');
    String status;
    String sub;
    IconData icon;

    if (today == null) {
      status = 'Not checked in';
      sub = DateFormat('EEEE, d MMMM y').format(now);
      icon = Icons.login_rounded;
    } else if (today.isOnLeave) {
      status = 'On Approved Leave';
      sub = 'Have a great rest!';
      icon = Icons.beach_access_rounded;
    } else if (today.checkInTime != null) {
      status = today.isLate ? 'Checked in (Late)' : 'Checked in';
      final out = today.checkOutTime != null
          ? ' · Out ${fmt.format(today.checkOutTime!)}'
          : '';
      sub = 'In ${fmt.format(today.checkInTime!)}$out';
      icon = Icons.check_circle_rounded;
    } else {
      status = 'Absent';
      sub = DateFormat('EEEE, d MMMM y').format(now);
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(sub,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
      int present, int late, int annualLeft, int pending) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
            icon: Icons.check_circle_rounded,
            value: '$present',
            label: 'Present\nThis Month',
            color: _green),
        _StatCard(
            icon: Icons.schedule_rounded,
            value: '$late',
            label: 'Late\nThis Month',
            color: _amber),
        _StatCard(
            icon: Icons.event_available_rounded,
            value: '$annualLeft',
            label: 'Annual Leave\nBalance',
            color: _blue),
        _StatCard(
            icon: Icons.hourglass_top_rounded,
            value: '$pending',
            label: 'Pending\nRequests',
            color: const Color(0xFFA855F7)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(
                        color: _textSec, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.att});
  final AttendanceModel att;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d');
    final timeFmt = DateFormat('hh:mm a');
    Color dot;
    String statusLabel;

    if (att.isOnLeave) {
      dot = _blue;
      statusLabel = 'On Leave';
    } else if (att.isAbsent) {
      dot = _red;
      statusLabel = 'Absent';
    } else if (att.isLate) {
      dot = _amber;
      statusLabel = 'Late';
    } else if (att.checkInTime != null) {
      dot = _green;
      statusLabel = 'Present';
    } else {
      dot = _textSec;
      statusLabel = 'No record';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt.format(att.date),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                if (att.checkInTime != null)
                  Text(timeFmt.format(att.checkInTime!),
                      style:
                          const TextStyle(color: _textSec, fontSize: 14)),
              ],
            ),
          ),
          Text(statusLabel,
              style: TextStyle(
                  color: dot, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab();

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final empAsync = ref.watch(currentEmployeeProvider);
    final emp = empAsync.value;
    if (emp == null) {
      return const Center(
          child: CircularProgressIndicator(color: _blue));
    }

    final param =
        (employeeId: emp.id, year: _month.year, month: _month.month);
    final attAsync = ref.watch(employeeAttendanceByMonthProvider(param));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthSelector(),
          attAsync.when(
            loading: () => const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: _blue))),
            error: (e, _) => Expanded(
                child: Center(
                    child: Text('$e',
                        style: const TextStyle(color: _red)))),
            data: (records) => Expanded(child: _attContent(records)),
          ),
        ],
      ),
    );
  }

  Widget _monthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          const Text('Attendance',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          _MonthNav(
            month: _month,
            onPrev: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
            onNext: () {
              final next = DateTime(_month.year, _month.month + 1);
              if (!next.isAfter(DateTime.now())) {
                setState(() => _month = next);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _attContent(List<AttendanceModel> records) {
    final present = records.where((a) => !a.isAbsent && !a.isOnLeave && a.checkInTime != null).length;
    final late = records.where((a) => a.isLate).length;
    final absent = records.where((a) => a.isAbsent).length;

    // Build day → record map
    final Map<int, AttendanceModel> dayMap = {
      for (final a in records) a.date.day: a
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _summaryRow(present, late, absent),
        const SizedBox(height: 20),
        _calendar(dayMap),
        const SizedBox(height: 20),
        const Text('Details',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (records.isEmpty)
          _emptyHint('No records for this month')
        else
          ...records.map((a) => _AttendanceRow(att: a)),
      ],
    );
  }

  Widget _summaryRow(int present, int late, int absent) {
    return Row(
      children: [
        _SummaryChip(label: 'Present', value: present, color: _green),
        const SizedBox(width: 10),
        _SummaryChip(label: 'Late', value: late, color: _amber),
        const SizedBox(width: 10),
        _SummaryChip(label: 'Absent', value: absent, color: _red),
      ],
    );
  }

  Widget _calendar(Map<int, AttendanceModel> dayMap) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday; // Mon=1

    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdays
                .map((d) => SizedBox(
                    width: 36,
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _textSec,
                            fontSize: 14,
                            fontWeight: FontWeight.w600))))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: (firstWeekday - 1) + daysInMonth,
            itemBuilder: (context, i) {
              final dayNum = i - (firstWeekday - 1) + 1;
              if (dayNum < 1) return const SizedBox();

              final att = dayMap[dayNum];
              final date =
                  DateTime(_month.year, _month.month, dayNum);
              final isWeekend = date.weekday >= 6;
              final isFuture = date.isAfter(DateTime.now());

              Color dotColor;
              if (isFuture || att == null) {
                dotColor = isWeekend
                    ? const Color(0xFF1A2E4A)
                    : Colors.transparent;
              } else if (att.isOnLeave) {
                dotColor = _blue;
              } else if (att.isAbsent) {
                dotColor = _red;
              } else if (att.isLate) {
                dotColor = _amber;
              } else {
                dotColor = _green;
              }

              return Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: (dotColor != Colors.transparent && !isFuture)
                        ? dotColor.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: (dotColor != Colors.transparent && !isFuture)
                        ? Border.all(color: dotColor, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        color: isFuture
                            ? _textSec.withOpacity(0.4)
                            : (isWeekend && att == null)
                                ? _textSec
                                : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _calendarLegend(),
        ],
      ),
    );
  }

  Widget _calendarLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendDot(color: _green, label: 'On time'),
        _LegendDot(color: _amber, label: 'Late'),
        _LegendDot(color: _red, label: 'Absent'),
        _LegendDot(color: _blue, label: 'Leave'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: _textSec, fontSize: 13)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAVE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _LeaveTab extends ConsumerWidget {
  const _LeaveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(currentEmployeeProvider);
    return empAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _blue)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (emp) {
        if (emp == null) {
          return const Center(
              child:
                  Text('Profile not found', style: TextStyle(color: _textSec)));
        }
        return _LeaveContent(emp: emp);
      },
    );
  }
}

class _LeaveContent extends ConsumerWidget {
  const _LeaveContent({required this.emp});
  final EmployeeModel emp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveAsync = ref.watch(employeeLeaveRequestsProvider(emp.id));
    final leaves = leaveAsync.value ?? [];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Text('Leave',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showRequestSheet(context, emp),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Request'),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Leave Balances',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _BalanceCard(
              label: 'Annual Leave',
              days: (emp.leaveBalances['annual'] as num?)?.toInt() ??
                  AppConstants.annualLeaveDaysPerYear,
              total: AppConstants.annualLeaveDaysPerYear,
              borderColor: _blue),
          const SizedBox(height: 10),
          _BalanceCard(
              label: 'Sick Leave',
              days: (emp.leaveBalances['sick'] as num?)?.toInt() ?? 10,
              total: 10,
              borderColor: _green),
          const SizedBox(height: 10),
          _BalanceCard(
              label: 'Maternity Leave',
              days: (emp.leaveBalances['maternity'] as num?)?.toInt() ??
                  AppConstants.maternityLeaveDays,
              total: AppConstants.maternityLeaveDays,
              borderColor: const Color(0xFFA855F7)),
          const SizedBox(height: 10),
          _BalanceCard(
              label: 'Paternity Leave',
              days: (emp.leaveBalances['paternity'] as num?)?.toInt() ??
                  AppConstants.paternityLeaveDays,
              total: AppConstants.paternityLeaveDays,
              borderColor: const Color(0xFF14B8A6)),
          const SizedBox(height: 24),
          const Text('My Requests',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (leaves.isEmpty)
            _emptyHint('No leave requests yet')
          else
            ...leaves.take(20).map((l) => _LeaveRequestCard(req: l)),
        ],
      ),
    );
  }

  void _showRequestSheet(BuildContext context, EmployeeModel emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveRequestSheet(emp: emp),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.days,
    required this.total,
    required this.borderColor,
  });

  final String label;
  final int days;
  final int total;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(55), blurRadius: 14, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: borderColor.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.beach_access_rounded, color: borderColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: _textSec, fontSize: 14)),
                const SizedBox(height: 2),
                Text('$days days remaining',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text('of $total',
              style: const TextStyle(color: _textSec, fontSize: 14)),
        ],
      ),
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({required this.req});
  final LeaveRequestModel req;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d');
    final Color statusColor = switch (req.status) {
      'approved' => _green,
      'rejected' => _red,
      _ => _amber,
    };
    final String statusLabel = switch (req.status) {
      'approved' => 'Approved',
      'rejected' => 'Declined',
      _ => 'Pending',
    };
    final String typeLabel = switch (req.leaveType) {
      'annual' => 'Annual',
      'sick' => 'Sick',
      'maternity' => 'Maternity',
      'paternity' => 'Paternity',
      _ => req.leaveType,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    '${fmt.format(req.startDate)} → ${fmt.format(req.endDate)}  ·  ${req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1} day${(req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1) == 1 ? '' : 's'}',
                    style: const TextStyle(color: _textSec, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// Leave request bottom sheet
class _LeaveRequestSheet extends ConsumerStatefulWidget {
  const _LeaveRequestSheet({required this.emp});
  final EmployeeModel emp;

  @override
  ConsumerState<_LeaveRequestSheet> createState() =>
      _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends ConsumerState<_LeaveRequestSheet> {
  String _leaveType = 'annual';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, y');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Request Leave',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _label('Leave Type'),
            const SizedBox(height: 8),
            _typeDropdown(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Start Date'),
                      const SizedBox(height: 8),
                      _dateTile(fmt.format(_startDate), () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 30)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) {
                              _endDate = _startDate;
                            }
                          });
                        }
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('End Date'),
                      const SizedBox(height: 8),
                      _dateTile(fmt.format(_endDate), () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _endDate = d);
                      }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(builder: (_) {
              final days = WorkingDaysService.calculate(
                _startDate, _endDate,
                const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
              );
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withAlpha(60)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: _blue, size: 17),
                  const SizedBox(width: 8),
                  Text(
                    '$days working day${days == 1 ? '' : 's'} will be deducted from your balance',
                    style: const TextStyle(color: _blue, fontSize: 13),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 16),
            _label('Reason'),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the reason...',
                hintStyle: const TextStyle(color: _textSec),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: _textSec, fontSize: 15, fontWeight: FontWeight.w500));

  Widget _typeDropdown() {
    const types = [
      ('annual', 'Annual Leave'),
      ('sick', 'Sick Leave'),
      ('maternity', 'Maternity Leave'),
      ('paternity', 'Paternity Leave'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _leaveType,
          dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: (v) => setState(() => _leaveType = v!),
          items: types
              .map((t) => DropdownMenuItem(
                    value: t.$1,
                    child: Text(t.$2),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _dateTile(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: _textSec, size: 15),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reason')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(leaveNotifierProvider.notifier).submitLeaveRequest(
            employeeId: widget.emp.id,
            employeeName:
                '${widget.emp.firstName} ${widget.emp.lastName}',
            leaveType: _leaveType,
            startDate: _startDate,
            endDate: _endDate,
            reason: _reasonCtrl.text.trim(),
            branchId: widget.emp.branchId,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYSLIP TAB
// ─────────────────────────────────────────────────────────────────────────────

class _PayslipTab extends ConsumerStatefulWidget {
  const _PayslipTab();

  @override
  ConsumerState<_PayslipTab> createState() => _PayslipTabState();
}

class _PayslipTabState extends ConsumerState<_PayslipTab> {
  String? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final empAsync = ref.watch(currentEmployeeProvider);
    final emp = empAsync.value;
    if (emp == null) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    final slipsAsync = ref.watch(employeePayslipsProvider(emp.id));

    return slipsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _blue)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (slips) {
        if (slips.isEmpty) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text('Payslips',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
                _emptyHint('No payslips yet. Contact HR.'),
              ],
            ),
          );
        }

        final selected = _selectedMonth ?? slips.first.payrollMonth;
        final slip = slips.firstWhere(
          (s) => s.payrollMonth == selected,
          orElse: () => slips.first,
        );

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Text('Payslips',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _MonthDropdown(
                    months: slips.map((s) => s.payrollMonth).toList(),
                    selected: selected,
                    onChanged: (m) => setState(() => _selectedMonth = m),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _netSalaryCard(slip),
              const SizedBox(height: 16),
              _earningsSection(slip),
              const SizedBox(height: 12),
              _deductionsSection(slip),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _downloadPdf(context, slip),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Payslip PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Previous Months',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...slips.map((s) => _SlipHistoryTile(
                    slip: s,
                    isSelected: s.payrollMonth == selected,
                    onTap: () =>
                        setState(() => _selectedMonth = s.payrollMonth),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _netSalaryCard(PayslipModel slip) {
    final fmt = NumberFormat('#,##0', 'en');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fmtMonth(slip.payrollMonth),
            style:
                TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text('Net Salary',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'RWF ${fmt.format(slip.netSalary)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${slip.firstName} ${slip.lastName}  ·  ${slip.position}',
            style:
                TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _earningsSection(PayslipModel slip) {
    final fmt = NumberFormat('#,##0', 'en');
    return _CollapsibleSection(
      title: 'Earnings',
      total: 'RWF ${fmt.format(slip.totalEarnings)}',
      color: _green,
      children: [
        _SlipRow('Basic Salary', fmt.format(slip.baseSalary)),
        if (slip.transportAllowance > 0)
          _SlipRow('Transport', fmt.format(slip.transportAllowance)),
        if (slip.housingAllowance > 0)
          _SlipRow('Housing', fmt.format(slip.housingAllowance)),
        if (slip.bonuses > 0) _SlipRow('Bonus', fmt.format(slip.bonuses)),
      ],
    );
  }

  Widget _deductionsSection(PayslipModel slip) {
    final fmt = NumberFormat('#,##0', 'en');
    return _CollapsibleSection(
      title: 'Deductions',
      total: 'RWF ${fmt.format(slip.totalDeductions)}',
      color: _red,
      children: [
        _SlipRow('PAYE Tax', fmt.format(slip.paye)),
        _SlipRow('Employee RSSB', fmt.format(slip.totalEmployeeRssb)),
        if (slip.absentDeduction > 0)
          _SlipRow('Absent (${slip.absentDays}d)', fmt.format(slip.absentDeduction)),
        if (slip.lateDeduction > 0)
          _SlipRow('Late penalties', fmt.format(slip.lateDeduction)),
        if (slip.loanDeductions > 0)
          _SlipRow('Loan repayment', fmt.format(slip.loanDeductions)),
        if (slip.extraDeductions > 0)
          _SlipRow(slip.extraDeductionsDescription ?? 'Other', fmt.format(slip.extraDeductions)),
      ],
    );
  }

  Future<void> _downloadPdf(BuildContext ctx, PayslipModel slip) async {
    final fmt = NumberFormat('#,##0', 'en');
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('HRNova Payslip',
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('${slip.payrollMonth}  ·  ${slip.firstName} ${slip.lastName}'),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Net Salary',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('RWF ${fmt.format(slip.netSalary)}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 17)),
              ]),
          pw.SizedBox(height: 16),
          pw.Text('Earnings',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Basic Salary'),
                pw.Text(fmt.format(slip.baseSalary))
              ]),
          if (slip.transportAllowance > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Transport'),
                  pw.Text(fmt.format(slip.transportAllowance))
                ]),
          if (slip.housingAllowance > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Housing'),
                  pw.Text(fmt.format(slip.housingAllowance))
                ]),
          pw.SizedBox(height: 12),
          pw.Text('Deductions',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PAYE Tax'),
                pw.Text(fmt.format(slip.paye))
              ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Employee RSSB'),
                pw.Text(fmt.format(slip.totalEmployeeRssb))
              ]),
          if (slip.loanDeductions > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Loan Repayment'),
                  pw.Text(fmt.format(slip.loanDeductions))
                ]),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NET SALARY',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('RWF ${fmt.format(slip.netSalary)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'payslip_${slip.payrollMonth}.pdf',
    );
  }

  String _fmtMonth(String ym) {
    try {
      final d = DateFormat('yyyy-MM').parse(ym);
      return DateFormat('MMMM yyyy').format(d);
    } catch (_) {
      return ym;
    }
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.total,
    required this.color,
    required this.children,
  });

  final String title;
  final String total;
  final Color color;
  final List<Widget> children;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(widget.total,
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _textSec,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(children: widget.children),
            ),
        ],
      ),
    );
  }
}

class _SlipRow extends StatelessWidget {
  const _SlipRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: _textSec, fontSize: 15))),
          Text('RWF $value',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SlipHistoryTile extends StatelessWidget {
  const _SlipHistoryTile({
    required this.slip,
    required this.isSelected,
    required this.onTap,
  });
  final PayslipModel slip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _blue.withAlpha(25) : _card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _fmtMonth(slip.payrollMonth),
                style: TextStyle(
                    color: isSelected ? _blue : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text('RWF ${fmt.format(slip.netSalary)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _fmtMonth(String ym) {
    try {
      final d = DateFormat('yyyy-MM').parse(ym);
      return DateFormat('MMMM yyyy').format(d);
    } catch (_) {
      return ym;
    }
  }
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({
    required this.months,
    required this.selected,
    required this.onChanged,
  });
  final List<String> months;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          icon: const Icon(Icons.expand_more_rounded, color: _textSec, size: 18),
          onChanged: (v) => onChanged(v!),
          items: months
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(_fmtMonth(m)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _fmtMonth(String ym) {
    try {
      final d = DateFormat('yyyy-MM').parse(ym);
      return DateFormat('MMM yyyy').format(d);
    } catch (_) {
      return ym;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(currentEmployeeProvider);
    return empAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _blue)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: _red))),
      data: (emp) {
        if (emp == null) {
          return const Center(
              child: Text('Profile not found',
                  style: TextStyle(color: _textSec)));
        }
        return _ProfileContent(emp: emp);
      },
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.emp});
  final EmployeeModel emp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joinDate = DateFormat('MMMM y').format(emp.startDate);
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Center(child: _Avatar(emp: emp, radius: 44)),
          const SizedBox(height: 16),
          Center(
            child: Text('${emp.firstName} ${emp.lastName}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Center(
              child: Text(emp.jobTitle,
                  style: const TextStyle(color: _textSec, fontSize: 15))),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _blue.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(emp.department,
                  style: const TextStyle(
                      color: _blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
              child: Text('Member since $joinDate',
                  style: const TextStyle(color: _textSec, fontSize: 14))),
          const SizedBox(height: 28),
          const Text('Personal Info',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (emp.nationalId.isNotEmpty)
            _InfoRow(
                icon: Icons.badge_rounded,
                label: 'National ID',
                value: emp.nationalId),
          if (emp.phone.isNotEmpty)
            _InfoRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: emp.phone),
          if (emp.email.isNotEmpty)
            _InfoRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: emp.email),
          _InfoRow(
              icon: Icons.work_rounded,
              label: 'Contract',
              value: emp.contractType),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? _blue : _amber,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: (v) {
                    ref.read(themeNotifierProvider.notifier).setMode(
                        v ? ThemeMode.dark : ThemeMode.light);
                  },
                  activeThumbColor: _blue,
                  activeTrackColor: _blue.withAlpha(80),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/mobile-onboarding');
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              side: const BorderSide(color: _red),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _textSec, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: _textSec, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.emp, required this.radius});
  final EmployeeModel emp;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials =
        '${emp.firstName.isNotEmpty ? emp.firstName[0] : ''}${emp.lastName.isNotEmpty ? emp.lastName[0] : ''}'
            .toUpperCase();

    if (emp.profilePhotoUrl != null && emp.profilePhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(emp.profilePhotoUrl!),
        backgroundColor: _card,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _blue.withOpacity(0.2),
      child: Text(
        initials,
        style: TextStyle(
          color: _blue,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMM yyyy').format(month);
    final canGoNext = !DateTime(month.year, month.month + 1)
        .isAfter(DateTime.now());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded, color: _textSec),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: Icon(Icons.chevron_right_rounded,
              color: canGoNext ? _textSec : _border),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

Widget _emptyHint(String msg) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(msg,
            style: const TextStyle(color: _textSec, fontSize: 15)),
      ),
    );
