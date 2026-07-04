import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';

class EmployeeAddScreen extends ConsumerStatefulWidget {
  const EmployeeAddScreen({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<EmployeeAddScreen> createState() => _EmployeeAddScreenState();
}

class _EmployeeAddScreenState extends ConsumerState<EmployeeAddScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _initialized = false;
  Uint8List? _photoBytes;
  String? _existingPhotoUrl;

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _nationalId;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _dob;
  late final TextEditingController _emergency;
  late final TextEditingController _jobTitle;
  late final TextEditingController _rssb;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _salaryAmt;
  late final TextEditingController _dailyRate;
  late final TextEditingController _hourlyRate;
  late final TextEditingController _transport;
  late final TextEditingController _housing;
  late final TextEditingController _bank;
  late final TextEditingController _notes;

  String _dept = '';
  String _contract = AppConstants.contractTypePermanent;
  String _salaryType = AppConstants.salaryTypeFixedMonthly;
  String _role = AppConstants.roleEmployee;
  String? _branchId;

  bool get isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _firstName  = TextEditingController();
    _lastName   = TextEditingController();
    _nationalId = TextEditingController();
    _phone      = TextEditingController();
    _email      = TextEditingController();
    _dob        = TextEditingController();
    _emergency  = TextEditingController();
    _jobTitle   = TextEditingController();
    _rssb       = TextEditingController();
    _startDate  = TextEditingController();
    _endDate    = TextEditingController();
    _salaryAmt  = TextEditingController();
    _dailyRate  = TextEditingController();
    _hourlyRate = TextEditingController();
    _transport  = TextEditingController();
    _housing    = TextEditingController();
    _bank       = TextEditingController();
    _notes      = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _nationalId, _phone, _email, _dob,
      _emergency, _jobTitle, _rssb, _startDate, _endDate, _salaryAmt,
      _dailyRate, _hourlyRate, _transport, _housing, _bank, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFromEmployee(EmployeeModel e) {
    if (_initialized) return;
    _initialized = true;
    _firstName.text  = e.firstName;
    _lastName.text   = e.lastName;
    _nationalId.text = e.nationalId;
    _phone.text      = e.phone;
    _email.text      = e.email;
    _dob.text        = e.dateOfBirth != null ? EmployeeModel.fmtDate(e.dateOfBirth) : '';
    _emergency.text  = e.emergencyContact;
    _jobTitle.text   = e.jobTitle;
    _rssb.text       = e.rssbNumber;
    _startDate.text  = EmployeeModel.fmtDate(e.startDate);
    _endDate.text    = e.endDate != null ? EmployeeModel.fmtDate(e.endDate) : '';
    _salaryAmt.text  = e.salaryAmount != 0 ? e.salaryAmount.toStringAsFixed(0) : '';
    _dailyRate.text  = e.dailyRate != 0 ? e.dailyRate.toStringAsFixed(0) : '';
    _hourlyRate.text = e.hourlyRate != 0 ? e.hourlyRate.toStringAsFixed(0) : '';
    _transport.text  = e.transportAllowance != 0 ? e.transportAllowance.toStringAsFixed(0) : '';
    _housing.text    = e.housingAllowance != 0 ? e.housingAllowance.toStringAsFixed(0) : '';
    _bank.text       = e.bankAccount;
    _notes.text      = e.notes ?? '';
    _dept            = e.department;
    _contract        = e.contractType;
    _salaryType      = e.salaryType;
    _role            = e.role;
    _branchId        = e.branchId;
    _existingPhotoUrl = e.profilePhotoUrl;
  }

  void _initForAdd(List<String> departments) {
    if (_initialized) return;
    _initialized = true;
    if (departments.isNotEmpty) _dept = departments.first;
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickPhoto();
    if (bytes != null && mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.errorRed, content: Text('Please select a department. Add departments in Settings first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'nationalId': _nationalId.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'emergencyContact': _emergency.text.trim(),
        'department': _dept,
        'jobTitle': _jobTitle.text.trim(),
        'contractType': _contract,
        'startDate': _startDate.text.trim(),
        'rssbNumber': _rssb.text.trim(),
        'salaryType': _salaryType,
        'salaryAmount': double.tryParse(_salaryAmt.text.trim()) ?? 0,
        'dailyRate': double.tryParse(_dailyRate.text.trim()) ?? 0,
        'hourlyRate': double.tryParse(_hourlyRate.text.trim()) ?? 0,
        'transportAllowance': double.tryParse(_transport.text.trim()) ?? 0,
        'housingAllowance': double.tryParse(_housing.text.trim()) ?? 0,
        'bankAccount': _bank.text.trim(),
        'role': _role,
      };
      if (_branchId != null) data['branchId'] = _branchId;
      if (_dob.text.isNotEmpty) data['dateOfBirth'] = _dob.text.trim();
      if (_emergency.text.isNotEmpty) data['emergencyContact'] = _emergency.text.trim();
      if (_contract == 'fixed_term' && _endDate.text.isNotEmpty) data['endDate'] = _endDate.text.trim();
      if (_notes.text.trim().isNotEmpty) data['notes'] = _notes.text.trim();

      final notifier = ref.read(employeesNotifierProvider.notifier);
      if (isEdit) {
        await notifier.updateEmployee(widget.editId!, data, photoBytes: _photoBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Employee updated successfully'),
            backgroundColor: AppColors.successGreen,
          ));
          context.pop();
        }
      } else {
        final (_, tempPassword) = await notifier.addEmployee(data: data, photoBytes: _photoBytes);
        if (mounted) {
          final email = (data['email'] as String?) ?? '';
          if (tempPassword != null && email.isNotEmpty) {
            await _showCredentialsDialog(email, tempPassword);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Employee added successfully'),
              backgroundColor: AppColors.successGreen,
            ));
          }
          if (mounted) context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.errorRed,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCredentialsDialog(String email, String tempPassword) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.successGreen.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.successGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Employee Added', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ctx.appText)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share these login credentials with the employee.',
              style: TextStyle(fontSize: 15, color: ctx.appSubtext)),
          const SizedBox(height: 16),
          _CredRow(label: 'Email', value: email, ctx: ctx),
          const SizedBox(height: 10),
          _CredRow(label: 'Password', value: tempPassword, ctx: ctx),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warningAmber.withAlpha(60)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warningAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The employee must change this password after their first login.',
                  style: TextStyle(fontSize: 14, color: ctx.appText),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);
    final departments = settingsAsync.value?.departments ?? const [];
    final branchesAsync = ref.watch(branchesStreamProvider);
    final isMultiBranch = ref.watch(currentCompanyTypeProvider) == AppConstants.companyMultiBranch;

    // Load employee for edit mode
    if (isEdit) {
      final empAsync = ref.watch(employeeByIdProvider(widget.editId!));
      if (empAsync.isLoading && !_initialized) {
        return Scaffold(
          backgroundColor: context.appBg,
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      empAsync.whenData((e) { if (e != null) _initFromEmployee(e); });
    } else {
      _initForAdd(departments);
    }

    return Scaffold(
      backgroundColor: context.appBg,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Personal Information', [
                      _row2(
                        _field('First Name', _firstName, required: true),
                        _field('Last Name', _lastName, required: true),
                      ),
                      _row2(
                        _field('National ID', _nationalId),
                        _field('Phone (+250)', _phone),
                      ),
                      _field('Email Address', _email, hint: 'employee@company.com'),
                      _row2(
                        _datefield('Date of Birth', _dob),
                        _field('Emergency Contact', _emergency, hint: 'Name & phone'),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Employment Details', [
                      _row2(
                        _dropField('Department', _dept, [
                          if (departments.isEmpty) const DropdownMenuItem(value: '', child: Text('No departments — add in Settings')),
                          ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                        ], (v) => setState(() => _dept = v ?? '')),
                        _field('Job Title', _jobTitle, required: true),
                      ),
                      if (isMultiBranch)
                        _dropFieldN('Branch', _branchId, [
                          const DropdownMenuItem(value: null, child: Text('Select branch…')),
                          ...?branchesAsync.value?.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                        ], (v) => setState(() => _branchId = v)),
                      _row2(
                        _dropField('Contract Type', _contract,
                          AppConstants.contractTypes.map((c) => DropdownMenuItem(value: c, child: Text(_ctLabel(c)))).toList(),
                          (v) => setState(() => _contract = v ?? _contract)),
                        _datefield('Start Date', _startDate, required: true),
                      ),
                      if (_contract == 'fixed_term') _datefield('End Date', _endDate),
                      _field('RSSB Number', _rssb),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Profile Photo', [
                      Row(children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.appField,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _photoBytes != null
                              ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                              : _existingPhotoUrl != null
                                  ? Image.network(_existingPhotoUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.person_outline, size: 32, color: context.appSubtext))
                                  : Icon(Icons.person_outline, size: 32, color: context.appSubtext),
                        ),
                        const SizedBox(width: 16),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primaryBlue),
                              foregroundColor: AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.upload_outlined, size: 16),
                            label: const Text('Upload Photo'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _photoBytes != null ? 'Photo ready to upload' : 'JPEG or PNG, max 5 MB',
                            style: TextStyle(fontSize: 14, color: context.appSubtext),
                          ),
                        ]),
                      ]),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Salary & Allowances', [
                      _dropField('Salary Type', _salaryType,
                        AppConstants.salaryTypes.map((s) => DropdownMenuItem(value: s, child: Text(_stLabel(s)))).toList(),
                        (v) => setState(() => _salaryType = v ?? _salaryType)),
                      if (_salaryType == AppConstants.salaryTypeFixedMonthly)
                        _field('Monthly Salary (RWF)', _salaryAmt, hint: '0', keyboard: TextInputType.number),
                      if (_salaryType == AppConstants.salaryTypeDailyRate)
                        _field('Daily Rate (RWF)', _dailyRate, hint: '0', keyboard: TextInputType.number),
                      if (_salaryType == AppConstants.salaryTypeHourlyRate)
                        _field('Hourly Rate (RWF)', _hourlyRate, hint: '0', keyboard: TextInputType.number),
                      _row2(
                        _field('Transport Allowance (RWF)', _transport, hint: '0', keyboard: TextInputType.number),
                        _field('Housing Allowance (RWF)', _housing, hint: '0', keyboard: TextInputType.number),
                      ),
                      _field('Bank Account Number', _bank),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('System Access', [
                      _dropField('Role', _role, const [
                        DropdownMenuItem(value: 'employee', child: Text('Employee')),
                        DropdownMenuItem(value: 'guard', child: Text('Guard (QR scanner)')),
                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                        DropdownMenuItem(value: 'hr_admin', child: Text('HR Admin')),
                        DropdownMenuItem(value: 'branch_hr_admin', child: Text('Branch HR Admin')),
                        DropdownMenuItem(value: 'director', child: Text('Director')),
                        DropdownMenuItem(value: 'finance_manager', child: Text('Finance Manager')),
                      ], (v) => setState(() => _role = v ?? _role)),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(10)),
                        child: const Row(children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'If an email is provided, a temporary password is auto-generated so the employee can log in to the app.',
                            style: TextStyle(fontSize: 14, color: AppColors.primaryBlue),
                          )),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection('Notes', [
                      _field('Additional Notes', _notes, hint: 'Any additional information…', maxLines: 3),
                    ]),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 24, 16),
      decoration: BoxDecoration(
        color: context.appCard,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.appField,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 18, color: context.appText),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Employee' : 'Add New Employee',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.appText),
              ),
              Text(
                isEdit ? 'Update employee information' : 'Fill in the details to create a new employee record',
                style: TextStyle(fontSize: 15, color: context.appSubtext),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
      decoration: BoxDecoration(
        color: context.appCard,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _saving ? null : () => context.pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: context.appField,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Cancel', style: TextStyle(color: context.appText, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: _saving ? AppColors.primaryBlue.withAlpha(140) : AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(100),
                boxShadow: _saving ? null : [BoxShadow(color: AppColors.primaryBlue.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isEdit ? 'Save Changes' : 'Add Employee',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> fields) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appText)),
          const SizedBox(height: 4),
          Divider(color: context.appBorder),
          const SizedBox(height: 12),
          ...fields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 14), child: f)),
        ],
      ),
    );
  }

  Widget _row2(Widget left, Widget right) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Expanded(child: left), const SizedBox(width: 16), Expanded(child: right)],
  );

  Widget _field(String label, TextEditingController ctrl, {
    String? hint,
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText),
        children: required ? [TextSpan(text: ' *', style: const TextStyle(color: AppColors.errorRed))] : [],
      )),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
          filled: true, fillColor: context.appField,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    ]);
  }

  Widget _datefield(String label, TextEditingController ctrl, {bool required = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText),
        children: required ? [TextSpan(text: ' *', style: const TextStyle(color: AppColors.errorRed))] : [],
      )),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        readOnly: true,
        style: const TextStyle(fontSize: 15),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (picked != null) ctrl.text = EmployeeModel.fmtDate(picked);
        },
        decoration: InputDecoration(
          hintText: 'Select date',
          hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 16, color: context.appSubtext),
          filled: true, fillColor: context.appField,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      ),
    ]);
  }

  Widget _dropField(String label, String value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    final validValue = items.any((i) => i.value == value) ? value : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: context.appField,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: validValue,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            style: TextStyle(fontSize: 15, color: context.appText),
            icon: Icon(Icons.keyboard_arrow_down, size: 18, color: context.appSubtext),
          ),
        ),
      ),
    ]);
  }

  Widget _dropFieldN(String label, String? value, List<DropdownMenuItem<String?>> items, ValueChanged<String?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: context.appField,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            style: TextStyle(fontSize: 15, color: context.appText),
            icon: Icon(Icons.keyboard_arrow_down, size: 18, color: context.appSubtext),
          ),
        ),
      ),
    ]);
  }

  String _ctLabel(String c) => switch (c) {
    'fixed_term' => 'Fixed Term', 'probation' => 'Probation', 'part_time' => 'Part Time', _ => 'Permanent',
  };

  String _stLabel(String s) => switch (s) {
    'daily_rate' => 'Daily Rate', 'hourly_rate' => 'Hourly Rate', _ => 'Fixed Monthly',
  };
}

class _CredRow extends StatefulWidget {
  const _CredRow({required this.label, required this.value, required this.ctx});
  final String label, value;
  final BuildContext ctx;

  @override
  State<_CredRow> createState() => _CredRowState();
}

class _CredRowState extends State<_CredRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.ctx.appField,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label,
              style: TextStyle(fontSize: 13, color: widget.ctx.appSubtext, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(widget.value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.ctx.appText,
                  fontFamily: 'monospace')),
        ])),
        GestureDetector(
          onTap: _copy,
          child: Icon(
            _copied ? Icons.check_rounded : Icons.copy_rounded,
            size: 16,
            color: _copied ? AppColors.successGreen : widget.ctx.appSubtext,
          ),
        ),
      ]),
    );
  }
}
