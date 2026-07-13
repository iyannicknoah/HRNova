import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../features/attendance/models/attendance_model.dart';
import '../../../features/attendance/providers/attendance_provider.dart';
import '../../../features/employees/models/employee_model.dart';
import '../../../features/employees/providers/employees_provider.dart';
import '../../../features/leave/models/leave_request_model.dart';
import '../../../features/leave/providers/leave_provider.dart';
import '../../../features/payroll/models/payroll_model.dart';
import '../../../features/payroll/providers/payroll_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/working_days_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_dropdown.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/month_nav.dart';

// Mobile-only notification providers filtered by employeeId
final _mobileNotifsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  final emp = ref.watch(currentEmployeeProvider).valueOrNull;
  if (companyId == null || emp == null) return Stream.value([]);
  return FirebaseService.notificationsRef(companyId)
      .where('employeeId', isEqualTo: emp.id)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList());
});

final _mobileUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider);
  final emp = ref.watch(currentEmployeeProvider).valueOrNull;
  if (companyId == null || emp == null) return Stream.value(0);
  return FirebaseService.notificationsRef(companyId)
      .where('employeeId', isEqualTo: emp.id)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);
});

// Accent colors — theme-independent semantic palette
const _blue = Color(0xFF4A9EFF);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFE5534B);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFFA855F7);
const _teal = Color(0xFF14B8A6);

DateTime _endOfWorkDt(DateTime day, String workEndTime) {
  final parts = workEndTime.split(':');
  return DateTime(day.year, day.month, day.day,
      int.parse(parts[0]), parts.length > 1 ? int.parse(parts[1]) : 0);
}

bool _wasPresent(AttendanceModel r, String workEndTime) =>
    r.checkInTime != null &&
    r.checkInTime!.isBefore(_endOfWorkDt(r.date, workEndTime));

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
      backgroundColor: context.appBg,
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? _blue : context.appSubtext,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? _blue : context.appSubtext,
                size: 22,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: context.appCard,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          height: 64,
          destinations: const [
            NavigationDestination(
              icon: AppIcon(AppIcons.homeOutlined),
              selectedIcon: AppIcon(AppIcons.homeRounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: AppIcon(AppIcons.calendarMonthOutlined),
              selectedIcon: AppIcon(AppIcons.calendarMonthRounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: AppIcon(AppIcons.beachAccessOutlined),
              selectedIcon: AppIcon(AppIcons.beachAccessRounded),
              label: 'Leave',
            ),
            NavigationDestination(
              icon: AppIcon(AppIcons.receiptLongOutlined),
              selectedIcon: AppIcon(AppIcons.receiptLongRounded),
              label: 'Payslip',
            ),
            NavigationDestination(
              icon: AppIcon(AppIcons.personOutlineRounded),
              selectedIcon: AppIcon(AppIcons.personRounded),
              label: 'Profile',
            ),
          ],
        ),
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
          return Center(
              child: Text('Profile not found',
                  style: TextStyle(color: context.appSubtext)));
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

    final workEndTime =
        ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';
    final presentCount =
        records.where((a) => _wasPresent(a, workEndTime)).length;
    final lateCount = records
        .where((a) => a.isLate && _wasPresent(a, workEndTime))
        .length;
    final usedAnnual = leaves
        .where((l) =>
            l.status == 'approved' &&
            l.leaveType == AppConstants.leaveTypeAnnual)
        .fold(0, (s, l) => s + (l.totalDays > 0 ? l.totalDays : l.endDate.difference(l.startDate).inDays + 1));
    final annualBalance =
        (AppConstants.annualLeaveDaysPerYear - usedAnnual)
            .clamp(0, AppConstants.annualLeaveDaysPerYear);
    final pendingLeaves = leaves.where((l) => l.status == 'pending').length;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context, emp, greeting),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTodayCard(today, now),
                const SizedBox(height: 20),
                _buildStatsGrid(context, presentCount, lateCount, annualBalance, pendingLeaves),
                const SizedBox(height: 24),
                Text('Recent Attendance',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 17,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  _emptyHint('No attendance records this month')
                else
                  ...records.take(5).map((a) => _AttendanceRow(att: a)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, EmployeeModel emp, String greeting) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: context.appCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: logo + notification bell
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  context.isDark
                      ? 'assets/icon/icon_dark.png'
                      : 'assets/icon/icon_light.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 7),
              Text('HRNovva',
                  style: TextStyle(
                      color: context.appText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              const _MobileNotificationBell(),
            ],
          ),
          const SizedBox(height: 18),
          // Greeting
          Text(greeting,
              style: TextStyle(color: context.appSubtext, fontSize: 14)),
          const SizedBox(height: 2),
          Text('${emp.firstName} ${emp.lastName}',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 22,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTodayCard(AttendanceModel? today, DateTime now) {
    final fmt = DateFormat('hh:mm a');
    String status;
    String sub;
    IconRef icon;
    Color accentColor;

    if (today == null) {
      status = 'Not checked in';
      sub = DateFormat('EEEE, d MMMM y').format(now);
      icon = AppIcons.loginRounded;
      accentColor = _blue;
    } else if (today.isOnLeave) {
      status = 'On Approved Leave';
      sub = 'Have a great rest!';
      icon = AppIcons.beachAccessRounded;
      accentColor = _blue;
    } else if (today.checkInTime != null) {
      status = today.isLate ? 'Checked in (Late)' : 'Checked in';
      final out = today.checkOutTime != null
          ? ' · Out ${fmt.format(today.checkOutTime!)}'
          : '';
      sub = 'In ${fmt.format(today.checkInTime!)}$out';
      icon = AppIcons.checkCircleRounded;
      accentColor = today.isLate ? _amber : _green;
    } else {
      status = 'Absent';
      sub = DateFormat('EEEE, d MMMM y').format(now);
      icon = AppIcons.cancelRounded;
      accentColor = _red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.32),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppIcon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sub,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
      BuildContext context, int present, int late, int annualLeft, int pending) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: [
        _StatCard(
            value: '$present',
            label: 'Present\nThis Month'),
        _StatCard(
            value: '$late',
            label: 'Late\nThis Month'),
        _StatCard(
            value: '$annualLeft',
            label: 'Annual Leave\nBalance'),
        _StatCard(
            value: '$pending',
            label: 'Pending\nRequests'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value,
      required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: context.cardDeco(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: context.appText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          Text(label,
              style: TextStyle(
                  color: context.appSubtext, fontSize: 11, height: 1.3)),
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
      dot = context.appSubtext;
      statusLabel = 'No record';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: context.cardDeco(),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt.format(att.date),
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w400)),
                if (att.checkInTime != null)
                  Text(
                    att.checkOutTime != null
                        ? 'In ${timeFmt.format(att.checkInTime!)} · Out ${timeFmt.format(att.checkOutTime!)}'
                        : 'In ${timeFmt.format(att.checkInTime!)}',
                    style: TextStyle(color: context.appSubtext, fontSize: 13),
                  ),
                if (att.workingHours != null && att.workingHours! > 0)
                  Text(
                    '${att.workingHours!.toStringAsFixed(1)}h worked',
                    style: TextStyle(
                        color: context.appSubtext.withOpacity(0.65),
                        fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dot.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: dot, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
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
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    final param = (employeeId: emp.id, year: _month.year, month: _month.month);
    final attAsync = ref.watch(employeeAttendanceByMonthProvider(param));
    final leaveMonthAsync = ref.watch(
        leavesCalendarByMonthProvider((year: _month.year, month: _month.month)));
    final leaveDayNums = (leaveMonthAsync.value ?? [])
        .where((e) => e['employeeId'] == emp.id)
        .map((e) {
          final parts = ((e['date'] as String?) ?? '').split('-');
          return parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
        })
        .toSet();
    final workEndTime =
        ref.watch(companySettingsProvider).value?.workEndTime ?? '17:00';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthSelector(context),
          attAsync.when(
            loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator(color: _blue))),
            error: (e, _) => Expanded(
                child: Center(
                    child: Text('$e', style: const TextStyle(color: _red)))),
            data: (records) =>
                Expanded(child: _attContent(context, records, leaveDayNums, workEndTime)),
          ),
        ],
      ),
    );
  }

  Widget _monthSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: context.appCard,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          Text('Attendance',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
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

  Widget _attContent(BuildContext context,
      List<AttendanceModel> records, Set<int> leaveDayNums, String workEndTime) {
    final present = records.where((a) => _wasPresent(a, workEndTime)).length;
    final late =
        records.where((a) => a.isLate && _wasPresent(a, workEndTime)).length;

    final now = DateTime.now();
    final lastDay = (_month.year == now.year && _month.month == now.month)
        ? now.day
        : DateUtils.getDaysInMonth(_month.year, _month.month);
    int elapsedWorking = 0;
    for (int d = 1; d <= lastDay; d++) {
      if (DateTime(_month.year, _month.month, d).weekday <= 5) {
        elapsedWorking++;
      }
    }
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final workingLeaveDays = leaveDayNums
        .where((d) =>
            d >= 1 &&
            d <= daysInMonth &&
            DateTime(_month.year, _month.month, d).weekday <= 5)
        .length;
    final absent =
        (elapsedWorking - present - workingLeaveDays).clamp(0, elapsedWorking);

    final Map<int, AttendanceModel> dayMap = {
      for (final a in records) a.date.day: a
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _summaryRow(present, late, absent),
        const SizedBox(height: 20),
        _calendar(context, dayMap, leaveDayNums),
        const SizedBox(height: 20),
        Text('Details',
            style: TextStyle(
                color: context.appText,
                fontSize: 17,
                fontWeight: FontWeight.w500)),
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

  Widget _calendar(BuildContext context, Map<int, AttendanceModel> dayMap, Set<int> leaveDayNums) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final today = DateTime.now();
    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDeco(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdays
                .map((d) => SizedBox(
                    width: 36,
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.appSubtext,
                            fontSize: 13,
                            fontWeight: FontWeight.w500))))
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
              final date = DateTime(_month.year, _month.month, dayNum);
              final isWeekend = date.weekday >= 6;
              final isFuture = date.isAfter(DateTime.now());
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              Color? dotColor;
              if (!isFuture) {
                if (att != null) {
                  if (att.isOnLeave) dotColor = _blue;
                  else if (att.isAbsent) dotColor = _red;
                  else if (att.isLate) dotColor = _amber;
                  else dotColor = _green;
                } else if (leaveDayNums.contains(dayNum)) {
                  dotColor = _blue;
                } else if (!isWeekend) {
                  // No attendance record at all for a past working day means
                  // the employee never checked in — still absent, even
                  // though no AttendanceModel doc exists to carry that flag.
                  dotColor = _red;
                }
              }

              return Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isToday
                        ? (dotColor != null ? dotColor.withOpacity(0.18) : _blue.withOpacity(0.12))
                        : (dotColor != null ? dotColor.withOpacity(0.15) : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday
                          ? (dotColor ?? _blue)
                          : (dotColor != null ? dotColor.withOpacity(0.6) : Colors.transparent),
                      width: isToday ? 2 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        color: isFuture
                            ? context.appSubtext.withOpacity(0.35)
                            : isToday
                                ? (dotColor ?? _blue)
                                : (dotColor != null
                                    ? dotColor
                                    : (isWeekend ? context.appSubtext : context.appText)),
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _calendarLegend(context),
        ],
      ),
    );
  }

  Widget _calendarLegend(BuildContext context) {
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 12)),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: context.appSubtext, fontSize: 12)),
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
          return Center(
              child: Text('Profile not found',
                  style: TextStyle(color: context.appSubtext)));
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
    final leaves = leaveAsync.valueOrNull ?? [];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Text('Leave',
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              HRNovaButton(
                label: 'Request',
                icon: AppIcons.add,
                isFullWidth: false,
                height: 38,
                onPressed: () => _showRequestSheet(context, emp),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Leave Balances',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            int usedOf(String type) => leaves
                .where((l) => l.status == 'approved' && l.leaveType == type)
                .fold(0, (s, l) => s + (l.totalDays > 0 ? l.totalDays : l.endDate.difference(l.startDate).inDays + 1));
            final annualUsed = usedOf(AppConstants.leaveTypeAnnual);
            final sickUsed = usedOf(AppConstants.leaveTypeSick);
            final maternityUsed = usedOf(AppConstants.leaveTypeMaternity);
            final paternityUsed = usedOf(AppConstants.leaveTypePaternity);
            return Column(
              children: [
                _BalanceCard(
                    label: 'Annual Leave',
                    icon: AppIcons.flightTakeoffRounded,
                    used: annualUsed,
                    total: AppConstants.annualLeaveDaysPerYear,
                    color: _blue),
                const SizedBox(height: 10),
                _BalanceCard(
                    label: 'Sick Leave',
                    icon: AppIcons.localHospitalRounded,
                    used: sickUsed,
                    total: AppConstants.sickLeaveDays,
                    color: _green),
                const SizedBox(height: 10),
                _BalanceCard(
                    label: 'Maternity Leave',
                    icon: AppIcons.childFriendlyRounded,
                    used: maternityUsed,
                    total: AppConstants.maternityLeaveDays,
                    color: _purple),
                const SizedBox(height: 10),
                _BalanceCard(
                    label: 'Paternity Leave',
                    icon: AppIcons.familyRestroomRounded,
                    used: paternityUsed,
                    total: AppConstants.paternityLeaveDays,
                    color: _teal),
              ],
            );
          }),
          const SizedBox(height: 24),
          Text('My Requests',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (leaves.isEmpty)
            _emptyHint('No leave requests yet')
          else
            ...leaves.take(20).map((l) => _LeaveRequestCard(req: l, emp: emp)),
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
    required this.icon,
    required this.used,
    required this.total,
    required this.color,
  });

  final String label;
  final IconRef icon;
  final int used;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final remaining = (total - used).clamp(0, total);
    final ratio = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text('$remaining days remaining',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('of $total',
                  style: TextStyle(color: context.appSubtext, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestCard extends StatefulWidget {
  const _LeaveRequestCard({required this.req, required this.emp});
  final LeaveRequestModel req;
  final EmployeeModel emp;

  @override
  State<_LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends State<_LeaveRequestCard> {
  bool _expanded = false;

  bool get _canExtend {
    if (widget.req.status != 'approved') return false;
    final now = DateTime.now();
    return widget.req.endDate.isAfter(now.subtract(const Duration(days: 3))) &&
        widget.req.endDate.isBefore(now.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
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
    final days = req.totalDays > 0
        ? req.totalDays
        : req.endDate.difference(req.startDate).inDays + 1;
    final isRejected = req.status == 'rejected';

    return GestureDetector(
      onTap: isRejected ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: context.cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeLabel,
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                          '${fmt.format(req.startDate)} → ${fmt.format(req.endDate)}  ·  $days day${days == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: context.appSubtext, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
                if (isRejected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: AppIcon(
                      _expanded
                          ? AppIcons.keyboardArrowUpRounded
                          : AppIcons.keyboardArrowDownRounded,
                      size: 18,
                      color: context.appSubtext,
                    ),
                  ),
              ],
            ),
            // Rejection reason (expanded)
            if (isRejected && _expanded && req.rejectedReason != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _red.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIcon(AppIcons.infoOutlineRounded,
                        color: _red, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${req.rejectedReason}',
                        style: const TextStyle(
                            color: _red, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_canExtend) ...[
              const SizedBox(height: 10),
              HRNovaButton(
                label: 'Extend Leave',
                icon: AppIcons.eventRepeatRounded,
                outlined: true,
                height: 40,
                onPressed: () => _showExtendSheet(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExtendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LeaveRequestSheet(emp: widget.emp, extensionOf: widget.req),
    );
  }
}

// Leave request bottom sheet
class _LeaveRequestSheet extends ConsumerStatefulWidget {
  const _LeaveRequestSheet({required this.emp, this.extensionOf});
  final EmployeeModel emp;
  final LeaveRequestModel? extensionOf;

  @override
  ConsumerState<_LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends ConsumerState<_LeaveRequestSheet> {
  late String _leaveType;
  late DateTime _startDate;
  late DateTime _endDate;
  late TextEditingController _reasonCtrl;
  bool _submitting = false;
  bool _doctorNoteUploaded = false;
  String? _doctorNoteUrl;

  bool get _isExtension => widget.extensionOf != null;

  @override
  void initState() {
    super.initState();
    if (_isExtension) {
      final orig = widget.extensionOf!;
      _leaveType = orig.leaveType;
      _startDate = orig.endDate.add(const Duration(days: 1));
      _endDate = _startDate;
      _reasonCtrl = TextEditingController(text: 'Extension of leave');
    } else {
      _leaveType = 'annual';
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _reasonCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDoctorNote() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      setState(() {
        _doctorNoteUploaded = true;
        _doctorNoteUrl = file.path;
      });
    } catch (_) {
      setState(() => _doctorNoteUploaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, y');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (ctx, controller) => Container(
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(_isExtension ? 'Extend Leave' : 'Request Leave',
                style: TextStyle(
                    color: context.appText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            if (_isExtension) ...[
              const SizedBox(height: 6),
              Text(
                'Extending: ${DateFormat('MMM d').format(widget.extensionOf!.startDate)} → ${DateFormat('MMM d').format(widget.extensionOf!.endDate)}',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            _typeDropdown(context),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, 'Start Date'),
                      const SizedBox(height: 8),
                      _dateTile(context, fmt.format(_startDate), () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
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
                      _label(context, 'End Date'),
                      const SizedBox(height: 8),
                      _dateTile(context, fmt.format(_endDate), () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
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
                  color: _blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const AppIcon(AppIcons.infoOutlineRounded, color: _blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$days working day${days == 1 ? '' : 's'} will be deducted from your balance',
                      style: const TextStyle(color: _blue, fontSize: 13),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 16),
            HRNovaTextField(
              label: 'Reason',
              controller: _reasonCtrl,
              maxLines: 3,
              hint: 'Describe the reason...',
            ),
            Builder(builder: (context) {
              final days = WorkingDaysService.calculate(
                _startDate, _endDate,
                const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
              );
              if (_leaveType != 'sick' || days < 3) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withOpacity(0.35)),
                  ),
                  child: const Row(children: [
                    AppIcon(AppIcons.infoOutlineRounded, color: _amber, size: 14),
                    SizedBox(width: 8),
                    Expanded(child: Text("Sick leave of 3+ days requires a doctor's note.", style: TextStyle(fontSize: 12, color: _amber))),
                  ]),
                ),
                const SizedBox(height: 8),
                HRNovaButton(
                  label: _doctorNoteUploaded ? "Doctor's note attached" : "Upload Doctor's Note (optional)",
                  icon: AppIcons.uploadFileRounded,
                  outlined: true,
                  height: 44,
                  backgroundColor: _doctorNoteUploaded ? _green : context.appSubtext,
                  onPressed: _pickDoctorNote,
                ),
              ]);
            }),
            const SizedBox(height: 28),
            HRNovaButton(
              label: 'Submit Request',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(text,
      style: TextStyle(
          color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w400));

  Widget _typeDropdown(BuildContext context) {
    const types = [
      ('annual', 'Annual Leave'),
      ('sick', 'Sick Leave'),
      ('maternity', 'Maternity Leave'),
      ('paternity', 'Paternity Leave'),
    ];
    return HRNovaDropdown<String>(
      label: 'Leave Type',
      value: _leaveType,
      enabled: !_isExtension,
      onChanged: (v) => setState(() => _leaveType = v!),
      items: types
          .map((t) => DropdownMenuItem(
                value: t.$1,
                child: Text(t.$2),
              ))
          .toList(),
    );
  }

  Widget _dateTile(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.calendarTodayRounded, color: context.appSubtext, size: 15),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: TextStyle(color: context.appText, fontSize: 14)),
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
            employeeName: '${widget.emp.firstName} ${widget.emp.lastName}',
            leaveType: _leaveType,
            startDate: _startDate,
            endDate: _endDate,
            reason: _reasonCtrl.text.trim(),
            branchId: widget.emp.branchId,
            attachmentUrl: _doctorNoteUrl,
            isExtension: _isExtension,
            originalRequestId: widget.extensionOf?.id,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text('Payslips',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
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
                  Text('Payslips',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
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
              _earningsSection(context, slip),
              const SizedBox(height: 12),
              _deductionsSection(context, slip),
              const SizedBox(height: 20),
              HRNovaButton(
                label: 'Download Payslip PDF',
                icon: AppIcons.downloadRounded,
                onPressed: () => _downloadPdf(context, slip),
              ),
              const SizedBox(height: 24),
              Text('Previous Months',
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              ...slips.map((s) => _SlipHistoryTile(
                    slip: s,
                    isSelected: s.payrollMonth == selected,
                    onTap: () => setState(() => _selectedMonth = s.payrollMonth),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.32),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fmtMonth(slip.payrollMonth),
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text('Net Salary',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'RWF ${fmt.format(slip.netSalary)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${slip.firstName} ${slip.lastName}  ·  ${slip.position}',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _earningsSection(BuildContext context, PayslipModel slip) {
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

  Widget _deductionsSection(BuildContext context, PayslipModel slip) {
    final fmt = NumberFormat('#,##0', 'en');
    return _CollapsibleSection(
      title: 'Deductions',
      total: 'RWF ${fmt.format(slip.totalDeductions)}',
      color: _red,
      children: [
        _SlipRow('PAYE Tax', fmt.format(slip.paye)),
        _SlipRow('RSSB Pension (6%)', fmt.format(slip.pensionEmployee)),
        _SlipRow('Maternity Levy (0.3%)', fmt.format(slip.maternityEmployee)),
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
          pw.Text('HRNovva Payslip',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('${slip.payrollMonth}  ·  ${slip.firstName} ${slip.lastName}'),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Net Salary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('RWF ${fmt.format(slip.netSalary)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 17)),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Earnings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Basic Salary'), pw.Text(fmt.format(slip.baseSalary))]),
          if (slip.transportAllowance > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Transport'), pw.Text(fmt.format(slip.transportAllowance))]),
          if (slip.housingAllowance > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Housing'), pw.Text(fmt.format(slip.housingAllowance))]),
          pw.SizedBox(height: 12),
          pw.Text('Deductions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('PAYE Tax'), pw.Text(fmt.format(slip.paye))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Employee RSSB'), pw.Text(fmt.format(slip.totalEmployeeRssb))]),
          if (slip.loanDeductions > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Loan Repayment'), pw.Text(fmt.format(slip.loanDeductions))]),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('NET SALARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
      decoration: context.cardDeco(),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
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
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                  Text(widget.total,
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  AppIcon(
                    _expanded ? AppIcons.expandLessRounded : AppIcons.expandMoreRounded,
                    color: context.appSubtext,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: context.appSubtext, fontSize: 14))),
          Text('RWF $value',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400)),
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
          color: isSelected ? _blue.withOpacity(0.1) : context.appCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _blue.withOpacity(0.4) : context.appBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _fmtMonth(slip.payrollMonth),
                style: TextStyle(
                    color: isSelected ? _blue : context.appText,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400),
              ),
            ),
            Text('RWF ${fmt.format(slip.netSalary)}',
                style: TextStyle(
                    color: context.appText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
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
        color: context.appCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          dropdownColor: context.appCard,
          style: TextStyle(color: context.appText, fontSize: 14),
          icon: AppIcon(AppIcons.expandMoreRounded, color: context.appSubtext, size: 18),
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
          return Center(
              child: Text('Profile not found',
                  style: TextStyle(color: context.appSubtext)));
        }
        return _ProfileContent(emp: emp);
      },
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.emp});
  final EmployeeModel emp;

  void _showQrSheet(BuildContext context) {
    final qrData = emp.qrCode ?? '${emp.companyId}_${emp.id}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: ctx.appCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ctx.appBorder, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text('My QR Code',
                  style: TextStyle(
                      color: ctx.appText, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_blue, Color(0xFF2979E0)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('HRNovva',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square, color: AppColors.darkNavy),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.darkNavy),
                    ),
                    const SizedBox(height: 16),
                    Text('${emp.firstName} ${emp.lastName}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        '${emp.department} · ${emp.jobTitle.isEmpty ? "Employee" : emp.jobTitle}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              HRNovaButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joinDate = DateFormat('MMMM y').format(emp.startDate);
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          // Top bar: logo + QR action
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  context.isDark
                      ? 'assets/icon/icon_dark.png'
                      : 'assets/icon/icon_light.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 7),
              Text('HRNovva',
                  style: TextStyle(
                      color: context.appText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showQrSheet(context),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: AppIcon(AppIcons.qrCodeScannerRounded,
                        size: 20, color: context.appText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_blue, Color(0xFF2979E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _blue.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.white24, shape: BoxShape.circle),
                  child: _Avatar(emp: emp, radius: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${emp.firstName} ${emp.lastName}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          emp.jobTitle.isEmpty
                              ? emp.department
                              : '${emp.jobTitle} · ${emp.department}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85), fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showQrSheet(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppIcon(AppIcons.qrCodeScannerRounded,
                        color: Colors.white, size: 19),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Member since $joinDate',
                style: TextStyle(color: context.appSubtext, fontSize: 12)),
          ),
          const SizedBox(height: 24),

          // Account
          Text('Account',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _LinkRow(
              icon: AppIcons.qrCodeScannerRounded,
              label: 'My QR Code',
              onTap: () => _showQrSheet(context)),
          const SizedBox(height: 24),

          // Personal Info
          Text('Personal Info',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (emp.nationalId.isNotEmpty)
            _InfoRow(
                icon: AppIcons.badgeRounded,
                label: 'National ID',
                value: emp.nationalId),
          if (emp.phone.isNotEmpty)
            _InfoRow(
                icon: AppIcons.phoneRounded, label: 'Phone', value: emp.phone),
          if (emp.email.isNotEmpty)
            _InfoRow(
                icon: AppIcons.emailRounded, label: 'Email', value: emp.email),
          _InfoRow(
              icon: AppIcons.workRounded,
              label: 'Contract',
              value: emp.contractType),
          const SizedBox(height: 24),

          // Theme toggle
          Text('Appearance',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: context.cardDeco(),
            child: Row(
              children: [
                AppIcon(
                  isDark ? AppIcons.darkModeRounded : AppIcons.lightModeRounded,
                  color: context.appText,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDark ? 'Dark Mode' : 'Light Mode',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w400),
                      ),
                      Text(
                        isDark ? 'Tap to switch to light' : 'Tap to switch to dark',
                        style: TextStyle(color: context.appSubtext, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: (v) {
                    ref.read(themeNotifierProvider.notifier).setMode(
                        v ? ThemeMode.dark : ThemeMode.light);
                  },
                  activeThumbColor: _blue,
                  activeTrackColor: _blue.withOpacity(0.3),
                  inactiveThumbColor: _amber,
                  inactiveTrackColor: _amber.withOpacity(0.25),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign out
          HRNovaButton(
            label: 'Sign Out',
            icon: AppIcons.logoutRounded,
            outlined: true,
            backgroundColor: _red,
            borderWidth: 1,
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/mobile-onboarding');
            },
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
  final IconRef icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: context.cardDeco(),
      child: Row(
        children: [
          AppIcon(icon, color: context.appText, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: context.appSubtext, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(
      {required this.icon, required this.label, required this.onTap});
  final IconRef icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: context.cardDeco(),
        child: Row(
          children: [
            AppIcon(icon, color: context.appText, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w400)),
            ),
            AppIcon(AppIcons.chevronRightRounded,
                size: 18, color: context.appSubtext),
          ],
        ),
      ),
    );
  }
}

class _MobileNotificationBell extends ConsumerWidget {
  const _MobileNotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_mobileUnreadCountProvider).value ?? 0;

    return GestureDetector(
      onTap: () => _showSheet(context, ref),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appTint,
              shape: BoxShape.circle,
            ),
            child: AppIcon(AppIcons.notificationsRounded,
                size: 20, color: context.appText),
          ),
          if (count > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 17,
                height: 17,
                decoration: const BoxDecoration(
                    color: _red, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final items = ref.watch(_mobileNotifsProvider).value ?? [];
          return _NotificationSheet(
            items: items,
            onRead: (id) =>
                ref.read(leaveNotifierProvider.notifier).markNotificationRead(id),
            onReadAll: () =>
                ref.read(leaveNotifierProvider.notifier).markAllRead(),
          );
        },
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.items,
    required this.onRead,
    required this.onReadAll,
  });
  final List<Map<String, dynamic>> items;
  final ValueChanged<String> onRead;
  final VoidCallback onReadAll;

  @override
  Widget build(BuildContext context) {
    final hasUnread = items.any((n) => n['isRead'] != true);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, controller) => Container(
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: context.appBorder,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      Text('Notifications',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (hasUnread)
                        TextButton(
                          onPressed: onReadAll,
                          child: const Text('Mark all read',
                              style: TextStyle(
                                  color: _blue, fontSize: 13)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.appBorder),
            // List
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(AppIcons.notificationsNoneRounded,
                              size: 48,
                              color: context.appSubtext.withOpacity(0.4)),
                          const SizedBox(height: 10),
                          Text('No notifications',
                              style: TextStyle(
                                  color: context.appSubtext, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: context.appBorder),
                      itemBuilder: (_, i) {
                        final n = items[i];
                        final id = n['id'] as String? ?? '';
                        final isUnread = n['isRead'] != true;
                        final type = n['type'] as String? ?? '';
                        return InkWell(
                          onTap: isUnread ? () => onRead(id) : null,
                          child: Container(
                            color: isUnread ? _blue.withOpacity(0.06) : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _iconBg(type),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: AppIcon(_iconFor(type),
                                      size: 17, color: _iconColor(type)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(n['title'] as String? ?? '',
                                          style: TextStyle(
                                              color: context.appText,
                                              fontSize: 14,
                                              fontWeight: isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.w400)),
                                      const SizedBox(height: 3),
                                      Text(n['body'] as String? ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: context.appSubtext,
                                              fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Text(_timeAgo(n['createdAt']),
                                          style: TextStyle(
                                              color: context.appSubtext
                                                  .withOpacity(0.65),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin:
                                        const EdgeInsets.only(top: 4, left: 8),
                                    decoration: const BoxDecoration(
                                        color: _blue, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconRef _iconFor(String type) => switch (type) {
        'leave_approved' => AppIcons.checkCircleRounded,
        'leave_rejected' => AppIcons.cancelRounded,
        _ => AppIcons.notificationsRounded,
      };

  Color _iconBg(String type) => switch (type) {
        'leave_approved' => _green.withOpacity(0.12),
        'leave_rejected' => _red.withOpacity(0.12),
        _ => _blue.withOpacity(0.12),
      };

  Color _iconColor(String type) => switch (type) {
        'leave_approved' => _green,
        'leave_rejected' => _red,
        _ => _blue,
      };

  String _timeAgo(dynamic ts) {
    DateTime? dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is String) {
      dt = DateTime.tryParse(ts);
    }
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
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
        backgroundColor: context.appCard,
      );
    }

    final gradColors = AppColors.gradientForName(emp.firstName);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.65,
            fontWeight: FontWeight.w600,
          ),
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
    final canGoNext =
        !DateTime(month.year, month.month + 1).isAfter(DateTime.now());
    return MonthNav(
      label: DateFormat('MMM yyyy').format(month),
      onPrev: onPrev,
      onNext: canGoNext ? onNext : null,
    );
  }
}

Widget _emptyHint(String msg) => Builder(
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.inboxRounded, color: context.appSubtext.withOpacity(0.4), size: 48),
              const SizedBox(height: 10),
              Text(msg,
                  style: TextStyle(color: context.appSubtext, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
