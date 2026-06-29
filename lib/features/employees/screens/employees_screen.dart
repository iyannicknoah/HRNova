import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/hrnova_button.dart';
import '../../../../shared/widgets/hrnova_text_field.dart';
import '../../../../shared/widgets/hrnova_sidebar.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  // Navigation & state variables
  Employee? _selectedEmployee; // If not null, render the detailed profile view
  int _profileTab = 0; // 0: Profile, 1: QR Code, 2: Leave Balances

  // Slide-out panel state variables
  bool _isPanelOpen = false;
  Employee? _editingEmployee; // If not null, we are editing this employee

  // Search & Filter state variables
  final _searchController = TextEditingController();
  String _selectedDepartmentFilter = 'All';
  bool _showInactive = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController(text: '+250');
  final _emailController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _salaryAmountController = TextEditingController();
  final _dailyRateController = TextEditingController();
  final _passwordController = TextEditingController(); // Temp password for new manager

  String _selectedDepartment = '';
  String _selectedContractType = 'permanent';
  String _selectedSalaryType = 'fixed_monthly';
  String _selectedRole = 'employee';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Enforce +250 prefix lock
    _phoneController.addListener(() {
      if (!_phoneController.text.startsWith('+250')) {
        _phoneController.value = TextEditingValue(
          text: '+250',
          selection: const TextSelection.collapsed(offset: 4),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _salaryAmountController.dispose();
    _dailyRateController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openAddPanel(List<String> departments) {
    setState(() {
      _isPanelOpen = true;
      _editingEmployee = null;
      _firstNameController.clear();
      _lastNameController.clear();
      _nationalIdController.clear();
      _phoneController.text = '+250';
      _emailController.clear();
      _jobTitleController.clear();
      _salaryAmountController.clear();
      _dailyRateController.clear();
      _passwordController.clear();
      _selectedDepartment = departments.isNotEmpty ? departments.first : 'Other';
      _selectedContractType = 'permanent';
      _selectedSalaryType = 'fixed_monthly';
      _selectedRole = 'employee';
      _startDate = DateTime.now();
      _endDate = null;
    });
  }

  void _openEditPanel(Employee emp, List<String> departments) {
    setState(() {
      _isPanelOpen = true;
      _editingEmployee = emp;
      _firstNameController.text = emp.firstName;
      _lastNameController.text = emp.lastName;
      _nationalIdController.text = emp.nationalId;
      
      final phone = emp.phone;
      _phoneController.text = phone.startsWith('+250') ? phone : (phone.isEmpty ? '+250' : '+250$phone');
      
      _emailController.text = emp.email;
      _jobTitleController.text = emp.jobTitle;
      _salaryAmountController.text = emp.salaryAmount > 0 ? emp.salaryAmount.toInt().toString() : '';
      _dailyRateController.text = emp.dailyRate > 0 ? emp.dailyRate.toInt().toString() : '';
      _passwordController.clear();
      
      _selectedDepartment = departments.contains(emp.department)
          ? emp.department
          : (departments.isNotEmpty ? departments.first : 'Other');
      _selectedContractType = emp.contractType;
      _selectedSalaryType = emp.salaryType;
      _selectedRole = emp.role;
      _startDate = emp.startDate;
      _endDate = emp.endDate;
    });
  }

  void _closePanel() {
    setState(() {
      _isPanelOpen = false;
      _editingEmployee = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : (_endDate ?? DateTime.now().add(const Duration(days: 30)));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
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

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
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

  Future<void> _handleSave() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final nationalId = _nationalIdController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final jobTitle = _jobTitleController.text.trim();
    final salaryType = _selectedSalaryType;
    final role = _selectedRole;

    if (firstName.isEmpty) {
      _showError('First Name is required.');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Last Name is required.');
      return;
    }
    if (phone.isEmpty) {
      _showError('Phone Number is required.');
      return;
    }
    if (email.isEmpty) {
      _showError('Email Address is required.');
      return;
    }
    if (jobTitle.isEmpty) {
      _showError('Job Title is required.');
      return;
    }

    final phoneRegex = RegExp(r'^\+2507[2389]\d{7}$');
    if (!phoneRegex.hasMatch(phone)) {
      _showError('Phone number must be a valid Rwanda mobile (e.g., +250788123456).');
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    if (_selectedContractType == 'fixed_term' && _endDate == null) {
      _showError('End Date is required for fixed term contracts.');
      return;
    }

    double salaryAmount = 0.0;
    double dailyRate = 0.0;

    if (salaryType == 'fixed_monthly') {
      final amount = double.tryParse(_salaryAmountController.text);
      if (amount == null || amount <= 0) {
        _showError('Please enter a valid monthly salary.');
        return;
      }
      salaryAmount = amount;
    } else if (salaryType == 'daily_rate' || salaryType == 'hourly_rate') {
      final rate = double.tryParse(_dailyRateController.text);
      if (rate == null || rate <= 0) {
        _showError('Please enter a valid daily/hourly rate.');
        return;
      }
      dailyRate = rate;
    }

    String? tempPassword;
    if (_editingEmployee == null && role == 'manager') {
      tempPassword = _passwordController.text;
      if (tempPassword.length < 6) {
        _showError('Temporary password for manager must be at least 6 characters.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final id = _editingEmployee?.id;
      final docId = await ref.read(employeesNotifierProvider.notifier).saveEmployee(
            id: id,
            firstName: firstName,
            lastName: lastName,
            nationalId: nationalId,
            phone: phone,
            email: email,
            department: _selectedDepartment,
            jobTitle: jobTitle,
            contractType: _selectedContractType,
            startDate: _startDate,
            endDate: _selectedContractType == 'fixed_term' ? _endDate : null,
            salaryType: salaryType,
            salaryAmount: salaryAmount,
            dailyRate: dailyRate,
            role: role,
            managerTempPassword: tempPassword,
          );

      _closePanel();
      _showSuccess(id == null ? 'Employee added successfully!' : 'Employee updated successfully!');

      if (id == null && docId != null) {
        // Show success registration details Dialog with QR code
        final companyId = ref.read(companyIdProvider) ?? '';
        final qrData = '${companyId}_$docId';
        _showCredentialsDialog(firstName, lastName, email, tempPassword, qrData);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showCredentialsDialog(
    String firstName,
    String lastName,
    String email,
    String? password,
    String qrData,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Container(
            width: 360,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppColors.primaryGreen, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Employee Registered Successfully',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: $firstName $lastName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('Email: $email', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (password != null) ...[
                        const SizedBox(height: 6),
                        Text('Temp Password: $password',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Generated QR ID Card:',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
                const SizedBox(height: 24),
                HRNovaButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeactivateDialog(Employee emp) {
    showDialog(
      context: context,
      builder: (context) {
        final isActive = emp.status == 'active';
        return AlertDialog(
          backgroundColor: AppColors.cardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isActive ? 'Deactivate Employee' : 'Activate Employee',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            isActive
                ? 'Are you sure you want to deactivate ${emp.fullName}? They will be hidden from the active list but their records will be preserved.'
                : 'Are you sure you want to reactivate ${emp.fullName}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? AppColors.errorRed : AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final newStatus = isActive ? 'inactive' : 'active';
                try {
                  await ref.read(employeesNotifierProvider.notifier).setStatus(emp.id, newStatus);
                  _showSuccess('${emp.fullName} status updated to $newStatus.');
                  // If we are currently viewing the deactivated employee, update their state/view
                  if (_selectedEmployee?.id == emp.id) {
                    setState(() {
                      _selectedEmployee = _selectedEmployee!.copyWith(status: newStatus);
                    });
                  }
                } catch (e) {
                  _showError('Failed to update status: $e');
                }
              },
              child: Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAdjustLeaveDialog(Employee emp, String leaveType, int currentBalance) {
    final adjustmentController = TextEditingController(text: currentBalance.toString());
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Adjust ${leaveType.toUpperCase()} Leave',
            style: const TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HRNovaTextField(
                  label: 'New Balance (Days)',
                  controller: adjustmentController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                HRNovaTextField(
                  label: 'Adjustment Reason',
                  hint: 'e.g. Leave adjustments for performance reward',
                  controller: reasonController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newBalance = int.tryParse(adjustmentController.text);
                final reason = reasonController.text.trim();

                if (newBalance == null || newBalance < 0) {
                  _showError('Please enter a valid balance.');
                  return;
                }
                if (reason.isEmpty) {
                  _showError('Reason is required to log balance adjustments.');
                  return;
                }

                Navigator.pop(context);
                try {
                  await ref.read(employeesNotifierProvider.notifier).updateLeaveBalance(emp.id, leaveType, newBalance);
                  _showSuccess('Leave adjusted successfully.');
                  // Refresh view state
                  if (_selectedEmployee?.id == emp.id) {
                    setState(() {
                      final updatedBalances = Map<String, int>.from(_selectedEmployee!.leaveBalances);
                      updatedBalances[leaveType] = newBalance;
                      _selectedEmployee = _selectedEmployee!.copyWith(leaveBalances: updatedBalances);
                    });
                  }
                } catch (e) {
                  _showError('Failed to adjust balance: $e');
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // QR Code download PNG function
  Future<void> _downloadQrCode(Employee emp) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: emp.qrCode,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );
      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );
        final picData = await painter.toImageData(300);
        if (picData != null) {
          final bytes = picData.buffer.asUint8List();
          
          if (kIsWeb) {
            final blob = html.Blob([bytes]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            // ignore: unused_local_variable
            final anchor = html.AnchorElement(href: url)
              ..setAttribute("download", "QR_${emp.firstName}_${emp.lastName}.png")
              ..click();
            html.Url.revokeObjectUrl(url);
            _showSuccess('QR code downloaded successfully.');
          }
        }
      }
    } catch (e) {
      _showError('Download failed: $e');
    }
  }

  // QR printing function
  Future<void> _printQrCode(Employee emp) async {
    try {
      final doc = pw.Document();

      final qrValidationResult = QrValidator.validate(
        data: emp.qrCode,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );
        final picData = await painter.toImageData(300);
        if (picData != null) {
          final qrImage = pw.MemoryImage(picData.buffer.asUint8List());

          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(24),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey, width: 2),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                    ),
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('HRNova ID CARD', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 12),
                        pw.Image(qrImage, width: 150, height: 150),
                        pw.SizedBox(height: 12),
                        pw.Text(emp.fullName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(emp.jobTitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                        pw.SizedBox(height: 4),
                        pw.Text('ID: ${emp.qrCode}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );

          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => doc.save(),
          );
        }
      }
    } catch (e) {
      _showError('Printing failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final userClaimsAsync = ref.watch(userClaimsProvider);

    final departments = settingsAsync.maybeWhen(
      data: (settings) => settings?.departments ?? <String>[],
      orElse: () => <String>[],
    );

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
      body: Stack(
        children: [
          Row(
            children: [
              HRNovaSidebar(
                currentRoute: '/employees',
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
                child: _selectedEmployee != null
                    ? _buildProfileView(_selectedEmployee!, departments)
                    : _buildListView(employeesAsync, departments),
              ),
            ],
          ),
          
          // Slide-out panel overlay
          if (_isPanelOpen)
            GestureDetector(
              onTap: _closePanel,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Slide-out panel container (480px width)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isPanelOpen ? 0 : -480,
            top: 0,
            bottom: 0,
            child: _buildSidePanel(departments),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(AsyncValue<List<Employee>> employeesAsync, List<String> departments) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              employeesAsync.when(
                loading: () => const Text('Employees', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                error: (err, stack) => const Text('Employees', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                data: (list) {
                  final activeCount = list.where((e) => e.status == 'active').length;
                  return Row(
                    children: [
                      const Text(
                        'Employees',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(
                        text: '$activeCount Active',
                        type: 'active',
                      ),
                    ],
                  );
                },
              ),
              HRNovaButton(
                label: '+ Add Employee',
                onPressed: () => _openAddPanel(departments),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Search and Filters Bar
          Row(
            children: [
              // Search input
              Expanded(
                child: HRNovaTextField(
                  label: '',
                  hint: 'Search by employee name or job title...',
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              // Department Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardNavy,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: AppColors.cardNavy,
                    value: _selectedDepartmentFilter,
                    icon: const Icon(Icons.filter_list, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedDepartmentFilter = val;
                        });
                      }
                    },
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Departments')),
                      ...departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Show Inactive Toggle
              FilterChip(
                backgroundColor: AppColors.cardNavy,
                selectedColor: AppColors.primaryGreen.withOpacity(0.15),
                checkmarkColor: AppColors.primaryGreen,
                label: const Text('Show Inactive', style: TextStyle(color: Colors.white, fontSize: 13)),
                selected: _showInactive,
                onSelected: (val) {
                  setState(() {
                    _showInactive = val;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: _showInactive ? AppColors.primaryGreen : const Color(0x1AFFFFFF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Employees table / grid
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x13FFFFFF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: employeesAsync.when(
                loading: () => const Center(child: LoadingWidget(message: 'Retrieving employees list...')),
                error: (err, stack) => Center(child: Text('Error loading employees: $err', style: const TextStyle(color: AppColors.errorRed))),
                data: (list) {
                  final search = _searchController.text.trim().toLowerCase();
                  final filtered = list.where((emp) {
                    final matchesStatus = _showInactive ? true : (emp.status == 'active');
                    final matchesSearch = emp.fullName.toLowerCase().contains(search) ||
                        emp.jobTitle.toLowerCase().contains(search) ||
                        emp.department.toLowerCase().contains(search);
                    final matchesDept = _selectedDepartmentFilter == 'All' || emp.department == _selectedDepartmentFilter;

                    return matchesStatus && matchesSearch && matchesDept;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No employees found matching filter criteria.',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: 32.0,
                              dataRowMinHeight: 64,
                              dataRowMaxHeight: 64,
                              headingTextStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
                              columns: const [
                                DataColumn(label: Text('EMPLOYEE')),
                                DataColumn(label: Text('DEPARTMENT')),
                                DataColumn(label: Text('JOB TITLE')),
                                DataColumn(label: Text('CONTRACT')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: filtered.map((emp) {
                                final isEmpActive = emp.status == 'active';
                                final initials = emp.firstName.isNotEmpty && emp.lastName.isNotEmpty
                                    ? '${emp.firstName[0]}${emp.lastName[0]}'.toUpperCase()
                                    : 'EE';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedEmployee = emp;
                                            _profileTab = 0;
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                                              child: Text(initials, style: const TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(emp.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                const SizedBox(height: 2),
                                                Text(emp.email, style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(emp.department, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                    DataCell(Text(emp.jobTitle, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                    DataCell(Text(
                                      emp.contractType == 'fixed_term' ? 'Fixed Term' : (emp.contractType == 'probation' ? 'Probation' : 'Permanent'),
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    )),
                                    DataCell(
                                      StatusBadge(
                                        text: isEmpActive ? 'Active' : 'Inactive',
                                        type: isEmpActive ? 'active' : 'suspended',
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, color: Colors.white54, size: 18),
                                            tooltip: 'View Profile',
                                            onPressed: () {
                                              setState(() {
                                                _selectedEmployee = emp;
                                                _profileTab = 0;
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                                            tooltip: 'Edit Details',
                                            onPressed: () => _openEditPanel(emp, departments),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isEmpActive ? Icons.lock_open_outlined : Icons.lock_outline,
                                              color: isEmpActive ? AppColors.errorRed.withOpacity(0.7) : AppColors.primaryGreen,
                                              size: 18,
                                            ),
                                            tooltip: isEmpActive ? 'Deactivate' : 'Activate',
                                            onPressed: () => _showDeactivateDialog(emp),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView(Employee emp, List<String> departments) {
    final initials = emp.firstName.isNotEmpty && emp.lastName.isNotEmpty
        ? '${emp.firstName[0]}${emp.lastName[0]}'.toUpperCase()
        : 'EE';
    final isActive = emp.status == 'active';

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          TextButton.icon(
            icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 16),
            label: const Text('Back to Employees', style: TextStyle(color: Colors.white70)),
            onPressed: () {
              setState(() {
                _selectedEmployee = null;
              });
            },
          ),
          const SizedBox(height: 16),

          // Profile Header card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardNavy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x13FFFFFF)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                  child: Text(initials, style: const TextStyle(color: AppColors.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emp.fullName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          StatusBadge(
                            text: isActive ? 'Active' : 'Inactive',
                            type: isActive ? 'active' : 'suspended',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${emp.jobTitle} • ${emp.department}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
                HRNovaButton(
                  label: 'Edit Profile',
                  onPressed: () => _openEditPanel(emp, departments),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Profile navigation Tabs
          Row(
            children: [
              _buildTabButton(0, 'Profile Info', Icons.person_outline),
              const SizedBox(width: 12),
              _buildTabButton(1, 'QR Code ID', Icons.qr_code_2),
              const SizedBox(width: 12),
              _buildTabButton(2, 'Leave Balances', Icons.beach_access_outlined),
            ],
          ),
          const SizedBox(height: 20),

          // Tab content area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.cardNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x13FFFFFF)),
              ),
              child: _profileTab == 0
                  ? _buildProfileTab(emp)
                  : (_profileTab == 1 ? _buildQrTab(emp) : _buildLeaveTab(emp)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final active = _profileTab == index;
    return InkWell(
      onTap: () => setState(() => _profileTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGreen.withOpacity(0.15) : AppColors.cardNavy,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primaryGreen : const Color(0x1AFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.primaryGreen : Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(Employee emp) {
    final df = DateFormat('dd MMMM yyyy');
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Details', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoColumn('Email Address', emp.email),
              _buildInfoColumn('Phone Number', emp.phone),
              _buildInfoColumn('National ID', emp.nationalId.isNotEmpty ? emp.nationalId : 'Not Configured'),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(color: Color(0x13FFFFFF)),
          const SizedBox(height: 24),
          const Text('Employment Details', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoColumn('System Access Role', emp.role.toUpperCase()),
              _buildInfoColumn('Contract Type', emp.contractType == 'fixed_term' ? 'Fixed Term' : (emp.contractType == 'probation' ? 'Probation' : 'Permanent')),
              _buildInfoColumn('Job Start Date', df.format(emp.startDate)),
            ],
          ),
          if (emp.contractType == 'fixed_term' && emp.endDate != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoColumn('Contract End Date', df.format(emp.endDate!)),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const Divider(color: Color(0x13FFFFFF)),
          const SizedBox(height: 24),
          const Text('Salary Information', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoColumn('Salary Structure', emp.salaryType == 'fixed_monthly' ? 'Fixed Monthly' : (emp.salaryType == 'daily_rate' ? 'Daily Rate' : 'Hourly Rate')),
              if (emp.salaryType == 'fixed_monthly')
                _buildInfoColumn('Monthly Salary', '${NumberFormat('#,###').format(emp.salaryAmount)} RWF')
              else
                _buildInfoColumn('Wage Rate', '${NumberFormat('#,###').format(emp.dailyRate)} RWF'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQrTab(Employee emp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('HRNova Client', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                QrImageView(
                  data: emp.qrCode,
                  version: QrVersions.auto,
                  size: 160.0,
                ),
                const SizedBox(height: 12),
                Text(emp.fullName, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('ID: ${emp.qrCode}', style: const TextStyle(color: Colors.black38, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.download, color: Colors.white, size: 18),
                label: const Text('Download QR (PNG)', style: TextStyle(color: Colors.white, fontSize: 13)),
                onPressed: () => _downloadQrCode(emp),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.print, color: Colors.white, size: 18),
                label: const Text('Print Badge', style: TextStyle(color: Colors.white, fontSize: 13)),
                onPressed: () => _printQrCode(emp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTab(Employee emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Leave Balances (Current Year)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildLeaveCard(emp, 'annual', emp.leaveBalances['annual'] ?? 0, 'Annual Leave'),
              _buildLeaveCard(emp, 'sick', emp.leaveBalances['sick'] ?? 0, 'Sick Leave'),
              _buildLeaveCard(emp, 'maternity', emp.leaveBalances['maternity'] ?? 84, 'Maternity (Rwanda Law)'),
              _buildLeaveCard(emp, 'paternity', emp.leaveBalances['paternity'] ?? 4, 'Paternity (Rwanda Law)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveCard(Employee emp, String leaveType, int count, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leaveType.toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit, color: AppColors.primaryGreen, size: 16),
                onPressed: () => _showAdjustLeaveDialog(emp, leaveType, count),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count Days', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(List<String> departments) {
    final isNew = _editingEmployee == null;

    return Container(
      width: 480,
      color: AppColors.cardNavy,
      padding: const EdgeInsets.all(28.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isNew ? 'Add Employee' : 'Edit Employee Details',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: _closePanel,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0x13FFFFFF), height: 1),
            const SizedBox(height: 20),

            // Scrollable forms
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PERSONAL INFO
                    const Text('1. Personal Information', style: TextStyle(color: AppColors.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: HRNovaTextField(
                            label: 'First Name',
                            controller: _firstNameController,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: HRNovaTextField(
                            label: 'Last Name',
                            controller: _lastNameController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HRNovaTextField(
                      label: 'National ID Number',
                      controller: _nationalIdController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    HRNovaTextField(
                      label: 'Phone Number',
                      hint: 'e.g. +250788123456',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    HRNovaTextField(
                      label: 'Email Address',
                      hint: 'name@company.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    // Department Dropdown
                    const Text('Department', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
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
                          value: departments.contains(_selectedDepartment)
                              ? _selectedDepartment
                              : (departments.isNotEmpty ? departments.first : 'Other'),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedDepartment = val;
                              });
                            }
                          },
                          items: [
                            if (departments.isEmpty)
                              const DropdownMenuItem(value: 'Other', child: Text('Other'))
                            else
                              ...departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    HRNovaTextField(
                      label: 'Job Title',
                      controller: _jobTitleController,
                    ),
                    const SizedBox(height: 16),
                    // Contract Type Dropdown
                    const Text('Contract Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
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
                          value: _selectedContractType,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedContractType = val;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                            DropdownMenuItem(value: 'fixed_term', child: Text('Fixed Term')),
                            DropdownMenuItem(value: 'probation', child: Text('Probation')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_startDate),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedContractType == 'fixed_term') ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                child: Text(
                                  _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'Choose Date',
                                  style: TextStyle(color: _endDate != null ? Colors.white : Colors.white30, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),

                    // SALARY DETAILS
                    const Text('2. Salary Details', style: TextStyle(color: AppColors.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Salary Payment Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
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
                          value: _selectedSalaryType,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedSalaryType = val;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'fixed_monthly', child: Text('Fixed Monthly')),
                            DropdownMenuItem(value: 'daily_rate', child: Text('Daily Rate')),
                            DropdownMenuItem(value: 'hourly_rate', child: Text('Hourly Rate')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedSalaryType == 'fixed_monthly')
                      HRNovaTextField(
                        label: 'Monthly Salary (RWF)',
                        controller: _salaryAmountController,
                        keyboardType: TextInputType.number,
                      )
                    else if (_selectedSalaryType == 'daily_rate')
                      HRNovaTextField(
                        label: 'Daily Rate (RWF)',
                        controller: _dailyRateController,
                        keyboardType: TextInputType.number,
                      )
                    else if (_selectedSalaryType == 'hourly_rate')
                      HRNovaTextField(
                        label: 'Hourly Rate (RWF)',
                        controller: _dailyRateController, // reuse same controller for simplicity
                        keyboardType: TextInputType.number,
                      ),
                    const SizedBox(height: 28),

                    // SYSTEM ACCESS
                    const Text('3. System Access', style: TextStyle(color: AppColors.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('System Role', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
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
                          value: _selectedRole,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedRole = val;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'employee', child: Text('Employee')),
                            DropdownMenuItem(value: 'manager', child: Text('Manager')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isNew && _selectedRole == 'manager') ...[
                      HRNovaTextField(
                        label: 'Temporary Login Password',
                        hint: 'Min 6 characters',
                        controller: _passwordController,
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: This manager account will be provisioned. Make sure to note down and share the password with the manager.',
                        style: TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Buttons
            HRNovaButton(
              label: 'Save Employee',
              onPressed: _handleSave,
              isLoading: _isSaving,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
