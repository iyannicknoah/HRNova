import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/company_settings_model.dart';
import '../../../../shared/widgets/hrnova_button.dart';
import '../../../../shared/widgets/hrnova_text_field.dart';
import '../../../../shared/widgets/hrnova_sidebar.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _initialized = false;
  CompanySettings? _currentSettings;

  // Controllers
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _gracePeriodController = TextEditingController();
  final List<String> _workingDays = [];

  final _annualLeaveController = TextEditingController();
  final _sickLeaveController = TextEditingController();

  final _departmentController = TextEditingController();
  final List<String> _departments = [];

  final _managerPhoneController = TextEditingController();
  final _hrPhoneController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _hrEmailController = TextEditingController();
  String _notificationMethod = 'both';

  // Section saving states
  bool _isSavingSchedule = false;
  bool _isSavingLeave = false;
  bool _isSavingDepartments = false;
  bool _isSavingNotifications = false;

  @override
  void initState() {
    super.initState();
    _managerPhoneController.text = '+250';
    _hrPhoneController.text = '+250';

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

  void _initializeFields(CompanySettings settings) {
    if (_initialized) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentSettings = settings;

        _startTimeController.text = settings.workStartTime;
        _endTimeController.text = settings.workEndTime;
        _gracePeriodController.text = settings.gracePeriodMinutes.toString();
        
        _workingDays.clear();
        _workingDays.addAll(settings.workingDays);

        _annualLeaveController.text = settings.annualLeaveDays.toString();
        _sickLeaveController.text = settings.sickLeaveDays.toString();

        _departments.clear();
        _departments.addAll(settings.departments);

        final managerPhone = settings.managerPhone;
        _managerPhoneController.text = managerPhone.startsWith('+250') ? managerPhone : (managerPhone.isEmpty ? '+250' : '+250$managerPhone');
        final hrPhone = settings.hrAdminPhone;
        _hrPhoneController.text = hrPhone.startsWith('+250') ? hrPhone : (hrPhone.isEmpty ? '+250' : '+250$hrPhone');
        _managerEmailController.text = settings.managerEmail;
        _hrEmailController.text = settings.hrAdminEmail;
        _notificationMethod = settings.notificationMethod;

        _initialized = true;
      });
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
      setState(() {
        controller.text = '$hourStr:$minStr';
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryGreen),
    );
  }

  Future<void> _saveSchedule() async {
    final grace = int.tryParse(_gracePeriodController.text);
    if (grace == null || grace < 0) {
      _showError('Please enter a valid grace period.');
      return;
    }
    if (_workingDays.isEmpty) {
      _showError('Please select at least one working day.');
      return;
    }

    setState(() {
      _isSavingSchedule = true;
    });

    try {
      final updated = (_currentSettings ?? const CompanySettings()).copyWith(
        workStartTime: _startTimeController.text,
        workEndTime: _endTimeController.text,
        gracePeriodMinutes: grace,
        workingDays: _workingDays,
      );
      await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
      _currentSettings = updated;
      _showSuccess('Schedule settings saved successfully.');
    } catch (e) {
      _showError('Failed to save schedule settings: $e');
    } finally {
      setState(() {
        _isSavingSchedule = false;
      });
    }
  }

  Future<void> _saveLeave() async {
    final annual = int.tryParse(_annualLeaveController.text);
    final sick = int.tryParse(_sickLeaveController.text);
    if (annual == null || annual < 0 || sick == null || sick < 0) {
      _showError('Please enter valid leave days.');
      return;
    }

    setState(() {
      _isSavingLeave = true;
    });

    try {
      final updated = (_currentSettings ?? const CompanySettings()).copyWith(
        annualLeaveDays: annual,
        sickLeaveDays: sick,
      );
      await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
      _currentSettings = updated;
      _showSuccess('Leave policies saved successfully.');
    } catch (e) {
      _showError('Failed to save leave policies: $e');
    } finally {
      setState(() {
        _isSavingLeave = false;
      });
    }
  }

  Future<void> _saveDepartments() async {
    if (_departments.isEmpty) {
      _showError('Please configure at least one department.');
      return;
    }

    setState(() {
      _isSavingDepartments = true;
    });

    try {
      final updated = (_currentSettings ?? const CompanySettings()).copyWith(
        departments: _departments,
      );
      await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
      _currentSettings = updated;
      _showSuccess('Departments saved successfully.');
    } catch (e) {
      _showError('Failed to save departments: $e');
    } finally {
      setState(() {
        _isSavingDepartments = false;
      });
    }
  }

  Future<void> _saveNotifications() async {
    final managerPhone = _managerPhoneController.text.trim();
    final hrPhone = _hrPhoneController.text.trim();
    final managerEmail = _managerEmailController.text.trim();
    final hrEmail = _hrEmailController.text.trim();

    final phoneRegex = RegExp(r'^\+2507[2389]\d{7}$');
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (managerPhone.isNotEmpty && !phoneRegex.hasMatch(managerPhone)) {
      _showError('Manager phone must be in +250 format (e.g. +250788123456)');
      return;
    }
    if (hrPhone.isNotEmpty && !phoneRegex.hasMatch(hrPhone)) {
      _showError('HR Admin phone must be in +250 format (e.g. +250788123456)');
      return;
    }
    if (managerEmail.isNotEmpty && !emailRegex.hasMatch(managerEmail)) {
      _showError('Manager email is invalid.');
      return;
    }
    if (hrEmail.isNotEmpty && !emailRegex.hasMatch(hrEmail)) {
      _showError('HR Admin email is invalid.');
      return;
    }
    if (managerPhone.isEmpty && hrPhone.isEmpty && managerEmail.isEmpty && hrEmail.isEmpty) {
      _showError('Please configure at least one notification contact.');
      return;
    }

    setState(() {
      _isSavingNotifications = true;
    });

    try {
      final updated = (_currentSettings ?? const CompanySettings()).copyWith(
        managerPhone: managerPhone,
        hrAdminPhone: hrPhone,
        managerEmail: managerEmail,
        hrAdminEmail: hrEmail,
        notificationMethod: _notificationMethod,
      );
      await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
      _currentSettings = updated;
      _showSuccess('Notification contacts saved successfully.');
    } catch (e) {
      _showError('Failed to save notifications: $e');
    } finally {
      setState(() {
        _isSavingNotifications = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final userClaimsAsync = ref.watch(userClaimsProvider);

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

    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Row(
        children: [
          HRNovaSidebar(
            currentRoute: '/settings',
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
            child: settingsAsync.when(
              loading: () => const Center(child: LoadingWidget(message: 'Loading System Settings...')),
              error: (err, stack) => Center(child: Text('Error loading configuration: $err', style: const TextStyle(color: AppColors.errorRed))),
              data: (settings) {
                if (settings != null) {
                  _initializeFields(settings);
                }

                return Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Settings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildScheduleSection(),
                              const SizedBox(height: 24),
                              _buildLeaveSection(),
                              const SizedBox(height: 24),
                              _buildDepartmentsSection(),
                              const SizedBox(height: 24),
                              _buildNotificationsSection(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children, required Widget saveButton}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x13FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.lightGreen, size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0x13FFFFFF)),
          const SizedBox(height: 20),
          ...children,
          const SizedBox(height: 20),
          const Divider(color: Color(0x13FFFFFF)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: saveButton,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return _buildSectionCard(
      title: 'Work Schedule',
      icon: Icons.schedule_outlined,
      saveButton: HRNovaButton(
        label: 'Save Schedule',
        onPressed: _saveSchedule,
        isLoading: _isSavingSchedule,
      ),
      children: [
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
        const SizedBox(height: 18),
        HRNovaTextField(
          label: 'Grace Period (Minutes)',
          hint: '10',
          controller: _gracePeriodController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
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

  Widget _buildLeaveSection() {
    return _buildSectionCard(
      title: 'Leave Policy',
      icon: Icons.card_travel_outlined,
      saveButton: HRNovaButton(
        label: 'Save Policies',
        onPressed: _saveLeave,
        isLoading: _isSavingLeave,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: HRNovaTextField(
                label: 'Annual Leave Days per Year',
                hint: '18',
                controller: _annualLeaveController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HRNovaTextField(
                label: 'Sick Leave Days per Year',
                hint: '10',
                controller: _sickLeaveController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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

  Widget _buildDepartmentsSection() {
    return _buildSectionCard(
      title: 'Company Departments',
      icon: Icons.lan_outlined,
      saveButton: HRNovaButton(
        label: 'Save Departments',
        onPressed: _saveDepartments,
        isLoading: _isSavingDepartments,
      ),
      children: [
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
                onPressed: () {
                  final dept = _departmentController.text.trim();
                  if (dept.isNotEmpty && !_departments.contains(dept)) {
                    setState(() {
                      _departments.add(dept);
                      _departmentController.clear();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Configured Departments:',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _departments.map((dept) {
            return Chip(
              backgroundColor: AppColors.darkNavy,
              label: Text(dept, style: const TextStyle(color: Colors.white, fontSize: 12)),
              deleteIcon: const Icon(Icons.cancel, color: AppColors.errorRed, size: 16),
              onDeleted: () {
                setState(() {
                  _departments.remove(dept);
                });
              },
              side: const BorderSide(color: Color(0x13FFFFFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _buildSectionCard(
      title: 'Notifications & Contacts',
      icon: Icons.chat_bubble_outline_rounded,
      saveButton: HRNovaButton(
        label: 'Save Contacts',
        onPressed: _saveNotifications,
        isLoading: _isSavingNotifications,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: HRNovaTextField(
                label: 'HR Admin WhatsApp Number',
                hint: 'e.g. +250788123456',
                controller: _hrPhoneController,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HRNovaTextField(
                label: 'HR Admin Email',
                hint: 'e.g. hr@company.rw',
                controller: _hrEmailController,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: HRNovaTextField(
                label: 'Department Manager WhatsApp Number',
                hint: 'e.g. +250788123456',
                controller: _managerPhoneController,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HRNovaTextField(
                label: 'Department Manager Email',
                hint: 'e.g. manager@company.rw',
                controller: _managerEmailController,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
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
