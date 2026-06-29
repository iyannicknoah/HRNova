import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/company_settings_model.dart';
import '../../../../shared/widgets/hrnova_button.dart';
import '../../../../shared/widgets/hrnova_text_field.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/hrnova_sidebar.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentStep = 1; // 1 to 4

  // Step 1: Schedule Controllers
  final _startTimeController = TextEditingController(text: '08:00');
  final _endTimeController = TextEditingController(text: '17:00');
  final _gracePeriodController = TextEditingController(text: '10');
  final List<String> _workingDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

  // Step 2: Leave Policy Controllers
  final _annualLeaveController = TextEditingController(text: '18');
  final _sickLeaveController = TextEditingController(text: '10');

  // Step 3: Department Controllers
  final _departmentController = TextEditingController();
  final List<String> _departments = [];

  // Step 4: Notification Controllers
  final _managerPhoneController = TextEditingController(text: '+250');
  final _hrPhoneController = TextEditingController(text: '+250');
  final _managerEmailController = TextEditingController();
  final _hrEmailController = TextEditingController();
  String _notificationMethod = 'both';

  bool _isSavingOnboarding = false;

  @override
  void initState() {
    super.initState();
    _managerPhoneController.addListener(() {
      if (!_managerPhoneController.text.startsWith('+250')) {
        _managerPhoneController.value = TextEditingValue(
          text: '+250',
          selection: const TextSelection.collapsed(offset: 4),
        );
      }
    });
    _hrPhoneController.addListener(() {
      if (!_hrPhoneController.text.startsWith('+250')) {
        _hrPhoneController.value = TextEditingValue(
          text: '+250',
          selection: const TextSelection.collapsed(offset: 4),
        );
      }
    });
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _gracePeriodController.dispose();
    _annualLeaveController.dispose();
    _sickLeaveController.dispose();
    _departmentController.dispose();
    _managerPhoneController.dispose();
    _hrPhoneController.dispose();
    _managerEmailController.dispose();
    _hrEmailController.dispose();
    super.dispose();
  }

  void _addDepartment() {
    final dept = _departmentController.text.trim();
    if (dept.isNotEmpty && !_departments.contains(dept)) {
      setState(() {
        _departments.add(dept);
        _departmentController.clear();
      });
    }
  }

  void _removeDepartment(String dept) {
    setState(() {
      _departments.remove(dept);
    });
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final initialTime = TimeOfDay(
      hour: int.tryParse(controller.text.split(':')[0]) ?? 8,
      minute: int.tryParse(controller.text.split(':')[1]) ?? 0,
    );
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: AppColors.cardNavy,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      final hourStr = pickedTime.hour.toString().padLeft(2, '0');
      final minStr = pickedTime.minute.toString().padLeft(2, '0');
      controller.text = '$hourStr:$minStr';
    }
  }

  bool _validateStep() {
    if (_currentStep == 1) {
      final grace = int.tryParse(_gracePeriodController.text);
      if (grace == null || grace < 0) {
        _showErrorSnackBar('Please enter a valid grace period.');
        return false;
      }
      if (_workingDays.isEmpty) {
        _showErrorSnackBar('Please select at least one working day.');
        return false;
      }
    } else if (_currentStep == 2) {
      final annual = int.tryParse(_annualLeaveController.text);
      final sick = int.tryParse(_sickLeaveController.text);
      if (annual == null || annual < 0 || sick == null || sick < 0) {
        _showErrorSnackBar('Please enter valid leave days.');
        return false;
      }
    } else if (_currentStep == 3) {
      if (_departments.isEmpty) {
        _showErrorSnackBar('Please add at least one department to proceed.');
        return false;
      }
    } else if (_currentStep == 4) {
      final managerPhone = _managerPhoneController.text.trim();
      final hrPhone = _hrPhoneController.text.trim();
      final managerEmail = _managerEmailController.text.trim();
      final hrEmail = _hrEmailController.text.trim();

      final phoneRegex = RegExp(r'^\+2507[2389]\d{7}$');
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

      if (managerPhone.isNotEmpty && !phoneRegex.hasMatch(managerPhone)) {
        _showErrorSnackBar('Manager phone must be in +250 format (e.g. +250788123456)');
        return false;
      }
      if (hrPhone.isNotEmpty && !phoneRegex.hasMatch(hrPhone)) {
        _showErrorSnackBar('HR Admin phone must be in +250 format (e.g. +250788123456)');
        return false;
      }
      if (managerEmail.isNotEmpty && !emailRegex.hasMatch(managerEmail)) {
        _showErrorSnackBar('Manager email address is invalid.');
        return false;
      }
      if (hrEmail.isNotEmpty && !emailRegex.hasMatch(hrEmail)) {
        _showErrorSnackBar('HR Admin email address is invalid.');
        return false;
      }
      if (managerPhone.isEmpty && hrPhone.isEmpty && managerEmail.isEmpty && hrEmail.isEmpty) {
        _showErrorSnackBar('Please configure at least one notification contact.');
        return false;
      }
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  Future<void> _saveOnboarding() async {
    if (!_validateStep()) return;

    setState(() {
      _isSavingOnboarding = true;
    });

    final settings = CompanySettings(
      workStartTime: _startTimeController.text,
      workEndTime: _endTimeController.text,
      gracePeriodMinutes: int.parse(_gracePeriodController.text),
      annualLeaveDays: int.parse(_annualLeaveController.text),
      sickLeaveDays: int.parse(_sickLeaveController.text),
      lateDeductionPerHourRwf: 500, // standard default
      maxLateBeforeWarning: 3,      // standard default
      notificationMethod: _notificationMethod,
      isOnboardingComplete: true,
      workingDays: _workingDays,
      departments: _departments,
      managerPhone: _managerPhoneController.text.trim(),
      hrAdminPhone: _hrPhoneController.text.trim(),
      managerEmail: _managerEmailController.text.trim(),
      hrAdminEmail: _hrEmailController.text.trim(),
    );

    try {
      await ref.read(settingsNotifierProvider.notifier).updateSettings(settings);
    } catch (e) {
      _showErrorSnackBar('Failed to complete onboarding: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOnboarding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final userClaimsAsync = ref.watch(userClaimsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.darkNavy,
        body: Center(child: LoadingWidget(message: 'Initializing Workspace...')),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.darkNavy,
        body: Center(
          child: Text(
            'Failed to load settings: $err',
            style: const TextStyle(color: AppColors.errorRed),
          ),
        ),
      ),
      data: (settings) {
        // If settings doc doesn't show onboarding complete, render the wizard
        if (settings == null || settings.isOnboardingComplete == false) {
          return _buildOnboardingWizard();
        }

        // Otherwise, render the main dashboard
        final userName = userClaimsAsync.maybeWhen(
          data: (claims) => claims?['name']?.toString() ?? 'HR Admin',
          orElse: () => 'HR Admin',
        );
        final userRole = userClaimsAsync.maybeWhen(
          data: (claims) => claims?['role']?.toString() ?? 'hr_admin',
          orElse: () => 'hr_admin',
        );

        final companyName = ref.watch(companyNameProvider).maybeWhen(
          data: (name) => name,
          orElse: () => 'HRNova',
        );

        final companyId = ref.watch(companyIdProvider);

        return Scaffold(
          backgroundColor: AppColors.darkNavy,
          body: Row(
            children: [
              HRNovaSidebar(
                currentRoute: '/dashboard',
                companyName: companyName,
                userName: userName,
                userRole: userRole,
                onItemTapped: (route) async {
                  if (route == 'sign_out_action') {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  } else {
                    context.go(route);
                  }
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Muraho, $userName',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 24),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── Metrics Cards Grid ──
                      _buildRealMetricsRow(context, companyId),
                      const SizedBox(height: 36),

                      // Activity list & quick links
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left pane: Recent Attendance
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.cardNavy,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x13FFFFFF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Recent Attendance',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _buildRecentAttendance(companyId),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Right pane: Quick Actions
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.cardNavy,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x13FFFFFF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quick Actions',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildQuickActionButton(
                                      context,
                                      label: 'Add Employee',
                                      icon: Icons.person_add_alt_1_outlined,
                                      route: '/employees?action=add',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildQuickActionButton(
                                      context,
                                      label: 'View Attendance',
                                      icon: Icons.calendar_today_outlined,
                                      route: '/attendance',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildQuickActionButton(
                                      context,
                                      label: 'Approve Leave',
                                      icon: Icons.check_circle_outline,
                                      route: '/leave',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Real Metrics Row ────────────────────────────────────────────────────
  Widget _buildRealMetricsRow(BuildContext context, String? companyId) {
    if (companyId == null) {
      return Row(children: [
        _buildMetricCard('Present Today', '—', Icons.people_outline, AppColors.lightGreen),
        const SizedBox(width: 20),
        _buildMetricCard('Late Arrivals', '—', Icons.alarm, AppColors.warningAmber),
        const SizedBox(width: 20),
        _buildMetricCard('On Leave', '—', Icons.beach_access, AppColors.infoBlue),
        const SizedBox(width: 20),
        _buildMetricCard('Pending Leaves', '—', Icons.pending_actions, AppColors.errorRed),
      ]);
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

    return StreamBuilder<List<QuerySnapshot>>(
      stream: Stream.fromFuture(Future.wait([
        firestore.collection('companies').doc(companyId).collection('attendance')
            .where('date', isEqualTo: today).get(),
        firestore.collection('companies').doc(companyId).collection('leaves_calendar')
            .where('date', isEqualTo: today).get(),
        firestore.collection('companies').doc(companyId).collection('leave_requests')
            .where('status', isEqualTo: 'pending').get(),
      ])),
      builder: (ctx, snap) {
        final attendanceDocs = snap.data?[0].docs ?? [];
        final presentCount = attendanceDocs.where((d) {
          final s = (d.data() as Map)['status'] as String? ?? '';
          return s == 'on_time' || s == 'late';
        }).length;
        final lateCount = attendanceDocs.where((d) {
          return (d.data() as Map)['status'] == 'late';
        }).length;
        final onLeaveCount = snap.data?[1].docs.length ?? 0;
        final pendingLeaves = snap.data?[2].docs.length ?? 0;

        return Row(children: [
          _buildMetricCard('Present Today', '$presentCount', Icons.people_outline, AppColors.lightGreen),
          const SizedBox(width: 20),
          _buildMetricCard('Late Arrivals', '$lateCount', Icons.alarm, AppColors.warningAmber),
          const SizedBox(width: 20),
          _buildMetricCard('On Leave', '$onLeaveCount', Icons.beach_access, AppColors.infoBlue),
          const SizedBox(width: 20),
          _buildMetricCard('Pending Leaves', '$pendingLeaves', Icons.pending_actions, AppColors.errorRed),
        ]);
      },
    );
  }

  // ── Recent Attendance ────────────────────────────────────────────────────
  Widget _buildRecentAttendance(String? companyId) {
    if (companyId == null) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white38)));
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('companies').doc(companyId).collection('attendance')
          .where('date', isEqualTo: today)
          .orderBy('checkInTime', descending: true)
          .limit(5)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.lightGreen, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('No attendance recorded today', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0x10FFFFFF), height: 1),
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final name = data['employeeName'] as String? ?? 'Unknown';
            final status = data['status'] as String? ?? 'absent';
            final checkInTs = data['checkInTime'] as Timestamp?;
            final timeStr = checkInTs != null ? DateFormat('HH:mm').format(checkInTs.toDate()) : '—';

            Color statusColor;
            String statusLabel;
            switch (status) {
              case 'on_time':
                statusColor = AppColors.lightGreen;
                statusLabel = 'On Time';
                break;
              case 'late':
                statusColor = AppColors.warningAmber;
                statusLabel = 'Late';
                break;
              default:
                statusColor = AppColors.errorRed;
                statusLabel = 'Absent';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardNavy,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(BuildContext context, {required String label, required IconData icon, required String route}) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkNavy,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x0EFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.lightGreen, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingWizard() {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardNavy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1AFFFFFF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and step text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Setup Workspace',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Step $_currentStep of 4',
                      style: const TextStyle(color: AppColors.lightGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentStep / 4.0,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lightGreen),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 32),

                // Wizard Steps Render
                if (_currentStep == 1) _buildStep1()
                else if (_currentStep == 2) _buildStep2()
                else if (_currentStep == 3) _buildStep3()
                else if (_currentStep == 4) _buildStep4(),

                const SizedBox(height: 36),
                const Divider(color: Color(0x13FFFFFF)),
                const SizedBox(height: 20),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 1)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        child: const Text('Back', style: TextStyle(color: Colors.white70)),
                      )
                    else
                      const SizedBox.shrink(),
                    HRNovaButton(
                      label: _currentStep == 4 ? 'Finish Setup' : 'Next',
                      onPressed: () {
                        if (_currentStep == 4) {
                          _saveOnboarding();
                        } else {
                          if (_validateStep()) {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        }
                      },
                      isLoading: _currentStep == 4 ? _isSavingOnboarding : false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Work Schedule',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context, _startTimeController),
                child: IgnorePointer(
                  child: HRNovaTextField(
                    label: 'Shift Start Time',
                    hint: '08:00',
                    controller: _startTimeController,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context, _endTimeController),
                child: IgnorePointer(
                  child: HRNovaTextField(
                    label: 'Shift End Time',
                    hint: '17:00',
                    controller: _endTimeController,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        HRNovaTextField(
          label: 'Grace Period (Minutes)',
          hint: '10',
          controller: _gracePeriodController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        const Text(
          'Working Days',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildDayCheckbox('Mon', 'monday'),
            _buildDayCheckbox('Tue', 'tuesday'),
            _buildDayCheckbox('Wed', 'wednesday'),
            _buildDayCheckbox('Thu', 'thursday'),
            _buildDayCheckbox('Fri', 'friday'),
            _buildDayCheckbox('Sat', 'saturday'),
          ],
        ),
      ],
    );
  }

  Widget _buildDayCheckbox(String label, String value) {
    final isSelected = _workingDays.contains(value);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _workingDays.remove(value);
          } else {
            _workingDays.add(value);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : const Color(0x1AFFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.lightGreen : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Leave Policy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        HRNovaTextField(
          label: 'Annual Leave Days per Year',
          hint: '18',
          controller: _annualLeaveController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        HRNovaTextField(
          label: 'Sick Leave Days per Year',
          hint: '10',
          controller: _sickLeaveController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.infoBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.infoBlue, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Note: Maternity leave (84 days) and Paternity leave (4 days) are fixed by Rwandan Labor Law and configured automatically.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Company Departments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: HRNovaTextField(
                label: 'Add Department',
                hint: 'e.g. Operations, IT, Finance',
                controller: _departmentController,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: HRNovaButton(
                label: 'Add',
                onPressed: _addDepartment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Configured Departments:',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        if (_departments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No departments added yet. Add at least one department.',
              style: TextStyle(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _departments.map((dept) {
              return Chip(
                backgroundColor: AppColors.darkNavy,
                label: Text(dept, style: const TextStyle(color: Colors.white, fontSize: 12)),
                deleteIcon: const Icon(Icons.cancel, color: AppColors.errorRed, size: 16),
                onDeleted: () => _removeDepartment(dept),
                side: const BorderSide(color: Color(0x13FFFFFF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Notifications & Contacts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        HRNovaTextField(
          label: 'HR Admin WhatsApp Number',
          hint: 'e.g. +250788123456',
          controller: _hrPhoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        HRNovaTextField(
          label: 'HR Admin Email',
          hint: 'e.g. hr@company.rw',
          controller: _hrEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0x13FFFFFF)),
        const SizedBox(height: 16),
        HRNovaTextField(
          label: 'Department Manager WhatsApp Number',
          hint: 'e.g. +250788123456',
          controller: _managerPhoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        HRNovaTextField(
          label: 'Department Manager Email',
          hint: 'e.g. manager@company.rw',
          controller: _managerEmailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        const Text(
          'Preferred Notification Method',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.darkNavy,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: AppColors.cardNavy,
              value: _notificationMethod,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _notificationMethod = val;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'both', child: Text('WhatsApp & Email')),
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Only')),
                DropdownMenuItem(value: 'email', child: Text('Email Only')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
