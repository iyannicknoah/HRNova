import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hrnova/core/theme/app_colors.dart';
import 'package:hrnova/shared/widgets/hrnova_sidebar.dart';
import 'package:hrnova/shared/widgets/loading_widget.dart';
import 'package:hrnova/shared/widgets/status_badge.dart';
import 'package:hrnova/features/auth/providers/auth_provider.dart';
import 'package:hrnova/features/employees/models/employee_model.dart';
import 'package:hrnova/features/employees/providers/employees_provider.dart';
import 'package:hrnova/features/settings/models/company_settings_model.dart';
import 'package:hrnova/features/settings/providers/settings_provider.dart';

// ─── Attendance Model ────────────────────────────────────────────────────────
class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String date;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
  final int lateMinutes;
  final double? totalHoursWorked;
  final bool isManualEntry;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
    required this.lateMinutes,
    this.totalHoursWorked,
    required this.isManualEntry,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceRecord(
      id: doc.id,
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      date: data['date'] as String? ?? '',
      status: data['status'] as String? ?? 'absent',
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
      checkInPhotoUrl: data['checkInPhotoUrl'] as String?,
      checkOutPhotoUrl: data['checkOutPhotoUrl'] as String?,
      lateMinutes: data['lateMinutes'] as int? ?? 0,
      totalHoursWorked: (data['totalHoursWorked'] as num?)?.toDouble(),
      isManualEntry: data['isManualEntry'] as bool? ?? false,
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _departmentFilter = 'All';
  String _statusFilter = 'All';

  FirebaseFirestore get _firestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _selectedDateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  // ── Color helpers ─────────────────────────────────────────────────────
  Color _initColor(String name) {
    final colors = [
      AppColors.lightGreen, AppColors.infoBlue, AppColors.warningAmber,
      const Color(0xFFEC4899), const Color(0xFF8B5CF6), const Color(0xFFF59E0B),
    ];
    int hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '??';
  }

  // ── Manual Entry Dialog ────────────────────────────────────────────────
  Future<void> _showManualEntryDialog(List<Employee> employees, String companyId) async {
    Employee? selectedEmp;
    DateTime date = DateTime.now();
    TimeOfDay? checkInTime;
    TimeOfDay? checkOutTime;
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: AppColors.cardNavy,
          title: const Text('Manual Attendance Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employee', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Employee>(
                    dropdownColor: AppColors.cardNavy,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.darkNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    hint: const Text('Select employee', style: TextStyle(color: Colors.white38)),
                    value: selectedEmp,
                    items: employees.map<DropdownMenuItem<Employee>>((e) => DropdownMenuItem<Employee>(
                      value: e,
                      child: Text(e.fullName, style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (e) => setDS(() => selectedEmp = e),
                  ),
                  const SizedBox(height: 16),
                  const Text('Date', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDS(() => date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.darkNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Check-In', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                              if (t != null) setDS(() => checkInTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(color: AppColors.darkNavy, borderRadius: BorderRadius.circular(8)),
                              child: Text(checkInTime?.format(ctx) ?? 'Select', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Check-Out (opt.)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                              if (t != null) setDS(() => checkOutTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(color: AppColors.darkNavy, borderRadius: BorderRadius.circular(8)),
                              child: Text(checkOutTime?.format(ctx) ?? 'Select', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Reason', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Reason for manual entry...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppColors.darkNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              onPressed: () async {
                if (selectedEmp == null || checkInTime == null) return;
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final docId = '${dateStr}_${selectedEmp!.id}';
                final checkInDt = DateTime(date.year, date.month, date.day, checkInTime!.hour, checkInTime!.minute);
                DateTime? checkOutDt;
                double? totalHours;
                if (checkOutTime != null) {
                  checkOutDt = DateTime(date.year, date.month, date.day, checkOutTime!.hour, checkOutTime!.minute);
                  totalHours = checkOutDt.difference(checkInDt).inMinutes / 60.0;
                }

                // Calculate status
                final settings = ref.read(settingsProvider).valueOrNull;
                final startParts = (settings?.workStartTime ?? '08:00').split(':');
                final startH = int.tryParse(startParts[0]) ?? 8;
                final startM = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
                final grace = settings?.gracePeriodMinutes ?? 10;
                final deadline = DateTime(date.year, date.month, date.day, startH, startM).add(Duration(minutes: grace));
                final status = checkInDt.isBefore(deadline) ? 'on_time' : 'late';
                final lateMin = status == 'late' ? checkInDt.difference(deadline).inMinutes : 0;

                await _firestore
                    .collection('companies')
                    .doc(companyId)
                    .collection('attendance')
                    .doc(docId)
                    .set({
                  'employeeId': selectedEmp!.id,
                  'employeeName': selectedEmp!.fullName,
                  'department': selectedEmp!.department,
                  'date': dateStr,
                  'month': DateFormat('yyyy-MM').format(date),
                  'checkInTime': Timestamp.fromDate(checkInDt),
                  'checkOutTime': checkOutDt != null ? Timestamp.fromDate(checkOutDt) : null,
                  'status': status,
                  'lateMinutes': lateMin,
                  'totalHoursWorked': totalHours,
                  'isManualEntry': true,
                  'manualEntryReason': reasonCtrl.text,
                  'isApprovedLeave': false,
                  'checkInPhotoUrl': null,
                  'checkOutPhotoUrl': null,
                }, SetOptions(merge: true));

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Entry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
  }

  // ── Photo Dialog ───────────────────────────────────────────────────────
  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(companyIdProvider);
    final userClaimsAsync = ref.watch(userClaimsProvider);
    final companyName = ref.watch(companyNameProvider).maybeWhen(data: (n) => n, orElse: () => 'HRNova');
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;
    final employeesAsync = ref.watch(employeesProvider);

    final userName = userClaimsAsync.maybeWhen(data: (c) => c?['name']?.toString() ?? 'HR Admin', orElse: () => 'HR Admin');
    final userRole = userClaimsAsync.maybeWhen(data: (c) => c?['role']?.toString() ?? 'hr_admin', orElse: () => 'hr_admin');

    if (companyId == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkNavy,
        body: Center(child: LoadingWidget(message: 'Loading...')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Row(
        children: [
          HRNovaSidebar(
            currentRoute: '/attendance',
            companyName: companyName,
            userName: userName,
            userRole: userRole,
            onItemTapped: (route) async {
              if (route == 'sign_out_action') {
                await ref.read(authNotifierProvider.notifier).signOut();
              } else {
                if (mounted) context.go(route);
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                // ── Top Bar ──
                _buildTopBar(companyId, employees: employeesAsync.valueOrNull ?? [], settings: settings),
                // ── Summary Cards ──
                _buildSummaryCards(companyId),
                // ── Filter Bar + Tab Bar ──
                _buildFilterBar(settings),
                // ── Tab Content ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAttendanceList(companyId, _todayStr),
                      _buildHistoryTab(companyId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────
  Widget _buildTopBar(String companyId, {required List<Employee> employees, CompanySettings? settings}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attendance', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
          Row(
            children: [
              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      // Switch to history tab if not today
                      if (DateFormat('yyyy-MM-dd').format(picked) != _todayStr) {
                        _tabController.animateTo(1);
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardNavy,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x20FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Manual Entry Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Manual Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final emps = ref.read(employeesProvider).valueOrNull ?? [];
                  _showManualEntryDialog(emps, companyId);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────
  Widget _buildSummaryCards(String companyId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          // Present Today
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('companies').doc(companyId).collection('attendance')
                  .where('date', isEqualTo: _todayStr)
                  .snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                final present = docs.where((d) {
                  final s = (d.data() as Map)['status'] as String? ?? '';
                  return s == 'on_time' || s == 'late';
                }).length;
                return _summaryCard('Present Today', '$present', Icons.people_outline, AppColors.lightGreen);
              },
            ),
          ),
          const SizedBox(width: 16),
          // Late
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('companies').doc(companyId).collection('attendance')
                  .where('date', isEqualTo: _todayStr)
                  .where('status', isEqualTo: 'late')
                  .snapshots(),
              builder: (ctx, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _summaryCard('Late Today', '$count', Icons.alarm, AppColors.warningAmber);
              },
            ),
          ),
          const SizedBox(width: 16),
          // Absent (totalActive - present - onLeave)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('companies').doc(companyId).collection('attendance')
                  .where('date', isEqualTo: _todayStr)
                  .snapshots(),
              builder: (ctx, snap) {
                final empAsync = ref.watch(employeesProvider);
                final totalActive = empAsync.valueOrNull?.where((e) => e.status == 'active').length ?? 0;
                final presentCount = snap.data?.docs.where((d) {
                  final s = (d.data() as Map)['status'] as String? ?? '';
                  return s == 'on_time' || s == 'late';
                }).length ?? 0;
                final absent = (totalActive - presentCount).clamp(0, totalActive);
                return _summaryCard('Absent Today', '$absent', Icons.person_off_outlined, AppColors.errorRed);
              },
            ),
          ),
          const SizedBox(width: 16),
          // On Leave
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('companies').doc(companyId).collection('leaves_calendar')
                  .where('date', isEqualTo: _todayStr)
                  .snapshots(),
              builder: (ctx, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _summaryCard('On Leave', '$count', Icons.beach_access, AppColors.infoBlue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x13FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────
  Widget _buildFilterBar(CompanySettings? settings) {
    final List<String> departments = ['All', ...?(settings?.departments)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Department Filter
              _filterDropdown(
                value: _departmentFilter,
                items: departments.cast<String>(),
                onChanged: (v) => setState(() => _departmentFilter = v ?? 'All'),
                label: 'Department',
              ),
              const SizedBox(width: 12),
              // Status Filter
              _filterDropdown(
                value: _statusFilter,
                items: const ['All', 'On Time', 'Late', 'Absent'],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
                label: 'Status',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.lightGreen,
            unselectedLabelColor: Colors.white54,
            indicatorColor: AppColors.lightGreen,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [Tab(text: 'Today'), Tab(text: 'History')],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x20FFFFFF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppColors.cardNavy,
          value: items.contains(value) ? value : items.first,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Attendance List ────────────────────────────────────────────────────
  Widget _buildAttendanceList(String companyId, String dateStr) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('companies')
          .doc(companyId)
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .orderBy('checkInTime', descending: false)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget(message: 'Loading attendance...'));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.errorRed)));
        }

        var records = snap.data?.docs
            .map((d) => AttendanceRecord.fromFirestore(d))
            .toList() ?? [];

        // Apply filters
        if (_departmentFilter != 'All') {
          records = records.where((r) => r.department == _departmentFilter).toList();
        }
        if (_statusFilter != 'All') {
          final filterMap = {'On Time': 'on_time', 'Late': 'late', 'Absent': 'absent'};
          final filterVal = filterMap[_statusFilter] ?? _statusFilter.toLowerCase();
          records = records.where((r) => r.status == filterVal).toList();
        }

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No attendance records for ${DateFormat('d MMMM yyyy').format(DateTime.tryParse(dateStr) ?? DateTime.now())}',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          itemCount: records.length,
          itemBuilder: (ctx, i) => _buildAttendanceRow(records[i]),
        );
      },
    );
  }

  Widget _buildAttendanceRow(AttendanceRecord r) {
    final initials = _initials(r.employeeName);
    final color = _initColor(r.employeeName);
    final checkInStr = r.checkInTime != null ? DateFormat('HH:mm').format(r.checkInTime!) : '—';
    final checkOutStr = r.checkOutTime != null ? DateFormat('HH:mm').format(r.checkOutTime!) : null;

    String statusType;
    String statusLabel;
    switch (r.status) {
      case 'on_time':
        statusType = 'ontime';
        statusLabel = 'On Time';
        break;
      case 'late':
        statusType = 'late';
        statusLabel = 'Late';
        break;
      default:
        statusType = 'absent';
        statusLabel = 'Absent';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.15),
            child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 14),
          // Name & Dept
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.employeeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(r.department, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          // Check-in
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Check-In', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(checkInStr, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          // Check-out
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Check-Out', style: TextStyle(color: Colors.white38, fontSize: 10)),
                checkOutStr != null
                    ? Text(checkOutStr, style: const TextStyle(color: Colors.white, fontSize: 13))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warningAmber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('In Office', style: TextStyle(color: AppColors.warningAmber, fontSize: 11)),
                      ),
              ],
            ),
          ),
          // Status badge
          StatusBadge(text: statusLabel, type: statusType),
          const SizedBox(width: 14),
          // Photo thumbnail
          if (r.checkInPhotoUrl != null)
            GestureDetector(
              onTap: () => _showPhotoDialog(r.checkInPhotoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  r.checkInPhotoUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: AppColors.darkNavy,
                    child: const Icon(Icons.person, color: Colors.white24, size: 24),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.darkNavy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.person, color: Colors.white24, size: 24),
            ),
          if (r.isManualEntry) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: 'Manual Entry',
              child: Icon(Icons.edit_note, color: Colors.white30, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  // ── History Tab ────────────────────────────────────────────────────────
  Widget _buildHistoryTab(String companyId) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              const Text('Viewing: ', style: TextStyle(color: Colors.white54)),
              Text(
                DateFormat('dd MMMM yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14, color: AppColors.lightGreen),
                label: const Text('Change Date', style: TextStyle(color: AppColors.lightGreen, fontSize: 13)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
            ],
          ),
        ),
        Expanded(child: _buildAttendanceList(companyId, _selectedDateStr)),
      ],
    );
  }
}


