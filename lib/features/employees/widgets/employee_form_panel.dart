import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/rwanda_banks.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../../shared/widgets/hrnova_dropdown.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/models/branch_model.dart';
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
    this.companyId,
    this.branchesOverride,
    this.isMultiBranchOverride,
  });

  final EmployeeModel? initial;
  final List<String> departments;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  /// When set, targets this company instead of the logged-in user's own
  /// company — used when a super admin completes another company's HR
  /// admin profile, who has no `currentCompanyIdProvider` of their own.
  final String? companyId;
  /// Branch list to use instead of watching `branchesStreamProvider`
  /// (which is scoped to the logged-in user's own company). Required
  /// alongside [companyId] for a super admin acting cross-company.
  final List<BranchModel>? branchesOverride;
  /// Same idea as [branchesOverride], for `currentCompanyTypeProvider`.
  final bool? isMultiBranchOverride;

  @override
  ConsumerState<EmployeeFormPanel> createState() => _EmployeeFormPanelState();
}

class _EmployeeFormPanelState extends ConsumerState<EmployeeFormPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

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
  String? _bankCode;

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
    _bankCode   = (e?.bankCode.isNotEmpty ?? false) ? e!.bankCode : null;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.errorRed, content: Text('Please fill all required information.')),
      );
      return;
    }
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
        'bankCode': _bankCode ?? '',
        'role': _role,
        'profileComplete': true,
      };
      final notifier = ref.read(employeesNotifierProvider.notifier);
      if (widget.initial == null) {
        await notifier.addEmployee(data: data, companyIdOverride: widget.companyId);
      } else {
        await notifier.updateEmployee(widget.initial!.id, data, companyIdOverride: widget.companyId);
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

  /// Phone must start with "07" and be exactly 10 digits, digits only.
  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^07\d{8}$').hasMatch(value)) {
      return 'Phone must start with 07 and be exactly 10 digits';
    }
    return null;
  }

  /// Bank account number must contain digits only.
  String? _validateBankAccount(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Bank account number must contain digits only';
    }
    return null;
  }

  /// Validates a Rwandan National ID (Indangamuntu): exactly 16 digits,
  /// where digits 2–5 are a plausible birth year and digit 6 is the gender
  /// marker (7 = female, 8 = male). Digit 1 (citizen/refugee/foreigner) and
  /// the trailing birth-order/reissuance/security digits aren't publicly
  /// documented with a checkable rule, so only the parts that are actually
  /// verifiable are enforced here.
  String? _validateNationalId(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'National ID is required';
    if (!RegExp(r'^\d{16}$').hasMatch(value)) {
      return 'National ID must be exactly 16 digits';
    }
    final birthYear = int.tryParse(value.substring(1, 5));
    final currentYear = DateTime.now().year;
    if (birthYear == null || birthYear < 1900 || birthYear > currentYear) {
      return 'Invalid National ID — the year segment (digits 2–5) is not a valid birth year';
    }
    final genderDigit = value[5];
    if (genderDigit != '7' && genderDigit != '8') {
      return 'Invalid National ID — the 6th digit must be 7 or 8';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final branches = widget.branchesOverride ?? (ref.watch(branchesStreamProvider).value ?? []);
    final isMultiBranch = widget.isMultiBranchOverride ??
        (ref.watch(currentCompanyTypeProvider) == AppConstants.companyMultiBranch);

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
                  left: _PField('National ID', _nationalId,
                      required: true,
                      keyboardType: TextInputType.number,
                      hint: '16 digits',
                      validator: _validateNationalId),
                  right: _PField('Phone (+250)', _phone,
                      hint: '07XXXXXXXX',
                      keyboardType: TextInputType.number,
                      validator: _validatePhone),
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
                    ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
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
                _PField('Insurance Number', _rssb),
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
                _Row2(
                  left: HRNovaDropdown<String?>(
                    label: 'Bank',
                    value: _bankCode,
                    hint: 'Select bank',
                    items: RwandaBanks.all
                        .map((b) => DropdownMenuItem(value: b.code, child: Text(b.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _bankCode = v),
                  ),
                  right: _PField('Bank Account Number', _bank,
                      hint: 'Account number',
                      keyboardType: TextInputType.number,
                      validator: _validateBankAccount),
                ),
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
  const _PField(this.label, this.ctrl, {this.hint, this.required = false, this.keyboardType, this.validator});
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => HRNovaTextField(
    label: label,
    hint: hint,
    controller: ctrl,
    keyboardType: keyboardType,
    validator: validator ??
        (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
  );
}

class _DatePField extends StatelessWidget {
  const _DatePField(this.label, this.ctrl, {this.required = false});
  final String label;
  final TextEditingController ctrl;
  final bool required;

  @override
  Widget build(BuildContext context) => HRNovaTextField(
    label: label,
    hint: 'Select date',
    controller: ctrl,
    readOnly: true,
    suffixIcon: const AppIcon(AppIcons.calendarTodayOutlined, size: 16, color: AppColors.textSecondary),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1950), lastDate: DateTime(2100),
      );
      if (picked != null) ctrl.text = EmployeeModel.fmtDate(picked);
    },
    validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
  );
}

class _DropPField extends StatelessWidget {
  const _DropPField(this.label, this.value, this.items, this.onChanged);
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => HRNovaDropdown<String>(
    label: label,
    value: items.any((i) => i.value == value) ? value : null,
    items: items,
    onChanged: onChanged,
  );
}
