import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

class EmployeeFormPanel extends ConsumerStatefulWidget {
  const EmployeeFormPanel({
    super.key,
    this.initial,
    required this.departments,
    required this.onClose,
    required this.onSaved,
  });

  final EmployeeModel? initial;
  final List<String> departments;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  ConsumerState<EmployeeFormPanel> createState() => _EmployeeFormPanelState();
}

class _EmployeeFormPanelState extends ConsumerState<EmployeeFormPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  Uint8List? _photoBytes;

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

  String _dept = '';
  String _contract = AppConstants.contractTypePermanent;
  String _salaryType = AppConstants.salaryTypeFixedMonthly;
  String _role = AppConstants.roleEmployee;
  String? _branchId;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _firstName  = TextEditingController(text: e?.firstName ?? '');
    _lastName   = TextEditingController(text: e?.lastName ?? '');
    _nationalId = TextEditingController(text: e?.nationalId ?? '');
    _phone      = TextEditingController(text: e?.phone ?? '');
    _email      = TextEditingController(text: e?.email ?? '');
    _dob        = TextEditingController(text: e?.dateOfBirth != null ? EmployeeModel.fmtDate(e!.dateOfBirth) : '');
    _emergency  = TextEditingController(text: e?.emergencyContact ?? '');
    _jobTitle   = TextEditingController(text: e?.jobTitle ?? '');
    _rssb       = TextEditingController(text: e?.rssbNumber ?? '');
    _startDate  = TextEditingController(text: e?.startDate != null ? EmployeeModel.fmtDate(e!.startDate) : '');
    _endDate    = TextEditingController(text: e?.endDate != null ? EmployeeModel.fmtDate(e!.endDate) : '');
    _salaryAmt  = TextEditingController(text: e?.salaryAmount != 0 ? e!.salaryAmount.toStringAsFixed(0) : '');
    _dailyRate  = TextEditingController(text: e?.dailyRate != 0 ? e!.dailyRate.toStringAsFixed(0) : '');
    _hourlyRate = TextEditingController(text: e?.hourlyRate != 0 ? e!.hourlyRate.toStringAsFixed(0) : '');
    _transport  = TextEditingController(text: e?.transportAllowance != 0 ? e!.transportAllowance.toStringAsFixed(0) : '');
    _housing    = TextEditingController(text: e?.housingAllowance != 0 ? e!.housingAllowance.toStringAsFixed(0) : '');
    _bank       = TextEditingController(text: e?.bankAccount ?? '');
    _dept       = e?.department ?? (widget.departments.isNotEmpty ? widget.departments.first : '');
    _contract   = e?.contractType ?? AppConstants.contractTypePermanent;
    _salaryType = e?.salaryType ?? AppConstants.salaryTypeFixedMonthly;
    _role       = e?.role ?? AppConstants.roleEmployee;
    _branchId   = e?.branchId;
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _nationalId, _phone, _email, _dob,
        _emergency, _jobTitle, _rssb, _startDate, _endDate, _salaryAmt,
        _dailyRate, _hourlyRate, _transport, _housing, _bank]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickPhoto();
    if (bytes != null && mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'nationalId': _nationalId.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'emergencyContact': _emergency.text.trim(),
        'department': _dept,
        'jobTitle': _jobTitle.text.trim(),
        if (_branchId != null) 'branchId': _branchId,
        'contractType': _contract,
        'startDate': _startDate.text.trim(),
        if (_contract == 'fixed_term' && _endDate.text.isNotEmpty) 'endDate': _endDate.text.trim(),
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
      final notifier = ref.read(employeesNotifierProvider.notifier);
      if (widget.initial == null) {
        await notifier.addEmployee(data: data, photoBytes: _photoBytes);
      } else {
        await notifier.updateEmployee(widget.initial!.id, data, photoBytes: _photoBytes);
      }
      if (mounted) widget.onSaved();
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final branchesAsync = ref.watch(branchesStreamProvider);
    final isMultiBranch = ref.watch(currentCompanyTypeProvider) == AppConstants.companyMultiBranch;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 40,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 14, 16),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue50,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(children: [
              Expanded(child: Text(
                isEdit ? 'Edit Employee' : 'Add New Employee',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              )),
              IconButton(onPressed: widget.onClose, icon: const AppIcon(AppIcons.close, size: 22), color: AppColors.textSecondary),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Personal Info
                _SecTitle('Personal Information'),
                const SizedBox(height: 12),
                _Row2(
                  left: _PField('First Name', _firstName, required: true),
                  right: _PField('Last Name', _lastName, required: true),
                ),
                const SizedBox(height: 12),
                _Row2(
                  left: _PField('National ID', _nationalId),
                  right: _PField('Phone (+250)', _phone),
                ),
                const SizedBox(height: 12),
                _PField('Email Address', _email, hint: 'employee@company.com'),
                const SizedBox(height: 12),
                _Row2(
                  left: _DatePField('Date of Birth', _dob),
                  right: _PField('Emergency Contact', _emergency, hint: 'Name & phone'),
                ),
                const SizedBox(height: 20),

                // Employment
                _SecTitle('Employment Details'),
                const SizedBox(height: 12),
                _Row2(
                  left: _DropPField('Department', _dept, [
                    if (widget.departments.isEmpty) const DropdownMenuItem(value: '', child: Text('No departments')),
                    ...widget.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                  ], (v) => setState(() => _dept = v ?? '')),
                  right: _PField('Job Title', _jobTitle, required: true),
                ),
                const SizedBox(height: 12),
                if (isMultiBranch) ...[
                  _DropPField('Branch', _branchId, [
                    const DropdownMenuItem(value: null, child: Text('Select branch…')),
                    ...?branchesAsync.value?.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                  ], (v) => setState(() => _branchId = v)),
                  const SizedBox(height: 12),
                ],
                _Row2(
                  left: _DropPField('Contract Type', _contract,
                    AppConstants.contractTypes.map((c) => DropdownMenuItem(value: c, child: Text(_ctLabel(c)))).toList(),
                    (v) => setState(() => _contract = v ?? _contract)),
                  right: _DatePField('Start Date', _startDate, required: true),
                ),
                if (_contract == 'fixed_term') ...[
                  const SizedBox(height: 12),
                  _DatePField('End Date', _endDate),
                ],
                const SizedBox(height: 12),
                _PField('RSSB Number', _rssb),
                const SizedBox(height: 20),

                // Photo
                _SecTitle('Profile Photo'),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lightBlue50,
                      border: Border.all(color: AppColors.cardBorder, width: 2)),
                    clipBehavior: Clip.antiAlias,
                    child: _photoBytes != null
                        ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                        : widget.initial?.profilePhotoUrl != null
                            ? Image.network(widget.initial!.profilePhotoUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const AppIcon(AppIcons.personOutline, size: 32, color: AppColors.textSecondary))
                            : const AppIcon(AppIcons.personOutline, size: 32, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primaryBlue), foregroundColor: AppColors.primaryBlue),
                      onPressed: _pickPhoto,
                      icon: const AppIcon(AppIcons.uploadOutlined, size: 16),
                      label: const Text('Upload Photo'),
                    ),
                    const SizedBox(height: 4),
                    Text(_photoBytes != null ? 'Photo selected' : 'JPEG or PNG, max 5 MB',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Salary
                _SecTitle('Salary & Allowances'),
                const SizedBox(height: 12),
                _DropPField('Salary Type', _salaryType,
                  AppConstants.salaryTypes.map((s) => DropdownMenuItem(value: s, child: Text(_stLabel(s)))).toList(),
                  (v) => setState(() => _salaryType = v ?? _salaryType)),
                const SizedBox(height: 12),
                if (_salaryType == AppConstants.salaryTypeFixedMonthly)
                  _PField('Monthly Salary (RWF)', _salaryAmt, keyboardType: TextInputType.number),
                if (_salaryType == AppConstants.salaryTypeDailyRate)
                  _PField('Daily Rate (RWF)', _dailyRate, keyboardType: TextInputType.number),
                if (_salaryType == AppConstants.salaryTypeHourlyRate)
                  _PField('Hourly Rate (RWF)', _hourlyRate, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _Row2(
                  left: _PField('Transport Allowance (RWF)', _transport, keyboardType: TextInputType.number),
                  right: _PField('Housing Allowance (RWF)', _housing, keyboardType: TextInputType.number),
                ),
                const SizedBox(height: 12),
                _PField('Bank Account Number', _bank),
                const SizedBox(height: 20),

                // System Access
                _SecTitle('System Access'),
                const SizedBox(height: 12),
                _DropPField('Role', _role, const [
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager (gets app login)')),
                ], (v) => setState(() => _role = v ?? _role)),
                if (_role == 'manager') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: context.pillBlueBg, borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [
                      AppIcon(AppIcons.infoOutline, size: 16, color: AppColors.primaryBlue),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'A temporary password will be auto-generated and sent to the employee email.',
                        style: TextStyle(fontSize: 14, color: AppColors.primaryBlue),
                      )),
                    ]),
                  ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
            child: Row(children: [
              Expanded(child: HRNovaButton(
                label: 'Cancel',
                outlined: true,
                onPressed: widget.onClose,
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: HRNovaButton(
                label: isEdit ? 'Save Changes' : 'Add Employee',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  String _ctLabel(String c) => switch (c) {
    'fixed_term' => 'Fixed Term', 'probation' => 'Probation', 'part_time' => 'Part Time', _ => 'Permanent',
  };
  String _stLabel(String s) => switch (s) {
    'daily_rate' => 'Daily Rate', 'hourly_rate' => 'Hourly Rate', _ => 'Fixed Monthly',
  };
}

// ─── Reusable form sub-widgets ────────────────────────────────────────────────
class _SecTitle extends StatelessWidget {
  const _SecTitle(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
    const SizedBox(height: 6),
    const Divider(color: AppColors.cardBorder, height: 1),
  ]);
}

class _Row2 extends StatelessWidget {
  const _Row2({required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: left), const SizedBox(width: 12), Expanded(child: right),
  ]);
}

class _PField extends StatelessWidget {
  const _PField(this.label, this.ctrl, {this.hint, this.required = false, this.keyboardType});
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    const SizedBox(height: 5),
    TextFormField(
      controller: ctrl, keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        filled: true, fillColor: AppColors.lightBlue50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    ),
  ]);
}

class _DatePField extends StatelessWidget {
  const _DatePField(this.label, this.ctrl, {this.required = false});
  final String label;
  final TextEditingController ctrl;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    const SizedBox(height: 5),
    TextFormField(
      controller: ctrl, readOnly: true,
      style: const TextStyle(fontSize: 15),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1950), lastDate: DateTime(2100),
        );
        if (picked != null) ctrl.text = EmployeeModel.fmtDate(picked);
      },
      decoration: InputDecoration(
        hintText: 'Select date',
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        suffixIcon: const AppIcon(AppIcons.calendarTodayOutlined, size: 16, color: AppColors.textSecondary),
        filled: true, fillColor: AppColors.lightBlue50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    ),
  ]);
}

class _DropPField extends StatelessWidget {
  const _DropPField(this.label, this.value, this.items, this.onChanged);
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    const SizedBox(height: 5),
    Container(
      decoration: BoxDecoration(color: AppColors.lightBlue50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value) ? value : null,
          items: items, onChanged: onChanged, isExpanded: true,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          icon: const AppIcon(AppIcons.keyboardArrowDown, size: 18, color: AppColors.textSecondary),
        ),
      ),
    ),
  ]);
}
