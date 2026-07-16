import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/rwanda_banks.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../../shared/widgets/hrnova_dropdown.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/employee_model.dart';
import '../providers/employees_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/tr.dart';
import '../../../shared/widgets/app_icon.dart';

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
  late final TextEditingController _password;

  String _dept = '';
  String _contract = AppConstants.contractTypePermanent;
  String _salaryType = AppConstants.salaryTypeFixedMonthly;
  String _role = AppConstants.roleEmployee;
  String? _branchId;
  String? _bankCode;
  bool _obscurePassword = true;

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
    _password   = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _nationalId, _phone, _email, _dob,
      _emergency, _jobTitle, _rssb, _startDate, _endDate, _salaryAmt,
      _dailyRate, _hourlyRate, _transport, _housing, _bank, _notes, _password,
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
    _bankCode        = e.bankCode.isNotEmpty ? e.bankCode : null;
  }

  void _initForAdd(List<String> departments, {String? autoBranchId, String defaultRole = AppConstants.roleEmployee}) {
    if (_initialized) return;
    _initialized = true;
    if (departments.isNotEmpty) _dept = departments.first;
    if (autoBranchId != null) _branchId = autoBranchId;
    _role = defaultRole;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.errorRed, content: Text(context.tr('Please fill all required information.'))),
      );
      return;
    }
    if (_dept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.errorRed, content: Text(context.tr('Please select a department. Add departments in Settings first.'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final userRole = ref.read(currentUserRoleProvider);
      // Validate branch required for group HR
      if (userRole == AppConstants.roleGroupHrAdmin && _branchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.errorRed, content: Text(context.tr('Please assign a branch for this employee.'))),
        );
        setState(() => _saving = false);
        return;
      }
      // Password field shown for manager role in add mode; send it if filled
      final showsPassword = !isEdit && _role == AppConstants.roleManager;
      if (showsPassword && _password.text.trim().isNotEmpty && _password.text.trim().length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.errorRed, content: Text(context.tr('Password must be at least 6 characters.'))),
        );
        setState(() => _saving = false);
        return;
      }

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
        'bankCode': _bankCode ?? '',
        'role': _role,
        if (showsPassword && _password.text.trim().isNotEmpty) 'password': _password.text.trim(),
      };
      if (_branchId != null) data['branchId'] = _branchId;
      if (_dob.text.isNotEmpty) data['dateOfBirth'] = _dob.text.trim();
      if (_emergency.text.isNotEmpty) data['emergencyContact'] = _emergency.text.trim();
      if (_contract == 'fixed_term' && _endDate.text.isNotEmpty) data['endDate'] = _endDate.text.trim();
      if (_notes.text.trim().isNotEmpty) data['notes'] = _notes.text.trim();

      final notifier = ref.read(employeesNotifierProvider.notifier);
      if (isEdit) {
        await notifier.updateEmployee(widget.editId!, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Employee updated successfully')),
            backgroundColor: AppColors.successGreen,
          ));
          context.pop();
        }
      } else {
        final (_, tempPassword, authError) = await notifier.addEmployee(data: data);
        if (mounted) {
          final email = (data['email'] as String?) ?? '';
          // tempPassword reflects what was actually set on the Firebase Auth
          // account (null if account creation failed) — never fall back to
          // the raw typed value here, or the dialog can show a password that
          // was never actually applied.
          if (tempPassword != null && email.isNotEmpty) {
            await _showCredentialsDialog(email, tempPassword);
          } else if (email.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(authError != null
                  ? context.trp('Employee added, but the login account could not be created: {error}', {'error': authError})
                  : context.tr('Employee added, but the login account could not be created. Use "Edit" to retry setting a password.')),
              backgroundColor: AppColors.warningAmber,
              duration: const Duration(seconds: 6),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.tr('Employee added successfully')),
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
    await AppDialogShell.show<void>(
      context: context,
      alignment: Alignment.center,
      barrierDismissible: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.successGreen.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: const AppIcon(AppIcons.checkCircleOutlineRounded, color: AppColors.successGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Text(context.tr('Employee Added'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.appText)),
          ]),
          const SizedBox(height: 15),
          Text(context.tr('Share these login credentials with the employee.'),
              style: TextStyle(fontSize: 15, color: context.appSubtext)),
          const SizedBox(height: 16),
          _CredRow(label: context.tr('Email'), value: email, ctx: context),
          const SizedBox(height: 10),
          _CredRow(label: context.tr('Password'), value: tempPassword, ctx: context),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warningAmber.withAlpha(60)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AppIcon(AppIcons.infoOutlineRounded, size: 14, color: AppColors.warningAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('The employee must change this password after their first login.'),
                  style: TextStyle(fontSize: 14, color: context.appText),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerRight,
            child: HRNovaButton(
              label: context.tr('Done'),
              isFullWidth: false,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);
    final departments = settingsAsync.value?.departments ?? const [];
    final branchesAsync = ref.watch(branchesStreamProvider);
    final isMultiBranch = ref.watch(currentCompanyTypeProvider) == AppConstants.companyMultiBranch;
    final userRole     = ref.watch(currentUserRoleProvider);
    final userBranchId = ref.watch(currentBranchIdProvider);

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
      _initForAdd(
        departments,
        autoBranchId: userRole == AppConstants.roleBranchHrAdmin ? userBranchId : null,
        defaultRole: (isMultiBranch && userRole == AppConstants.roleGroupHrAdmin)
            ? AppConstants.roleBranchHrAdmin
            : AppConstants.roleEmployee,
      );
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
                    _buildSection(context.tr('Personal Information'), [
                      _row2(
                        _field(context.tr('First Name'), _firstName, required: true),
                        _field(context.tr('Last Name'), _lastName, required: true),
                      ),
                      _row2(
                        _field(context.tr('National ID'), _nationalId,
                            required: true,
                            keyboard: TextInputType.number,
                            hint: context.tr('16 digits'),
                            validator: _validateNationalId),
                        _field(context.tr('Phone (+250)'), _phone,
                            keyboard: TextInputType.number,
                            hint: '07XXXXXXXX',
                            validator: _validatePhone),
                      ),
                      _field(context.tr('Email Address'), _email, hint: 'employee@company.com'),
                      _row2(
                        _datefield(context.tr('Date of Birth'), _dob),
                        _field(context.tr('Emergency Contact'), _emergency, hint: context.tr('Name & phone')),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection(context.tr('Employment Details'), [
                      _row2(
                        _dropField(context.tr('Department'), _dept, [
                          if (departments.isEmpty) DropdownMenuItem(value: '', child: Text(context.tr('No departments — add in Settings'))),
                          ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                        ], (v) => setState(() => _dept = v ?? '')),
                        _field(context.tr('Job Title'), _jobTitle, required: true),
                      ),
                      if (isMultiBranch)
                        _dropFieldN(context.tr('Branch'), _branchId, [
                          DropdownMenuItem(value: null, child: Text(context.tr('Select branch…'))),
                          ...?branchesAsync.value?.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                        ], (v) => setState(() => _branchId = v)),
                      _row2(
                        _dropField(context.tr('Contract Type'), _contract,
                          AppConstants.contractTypes.map((c) => DropdownMenuItem(value: c, child: Text(context.tr(_ctLabel(c))))).toList(),
                          (v) => setState(() => _contract = v ?? _contract)),
                        _datefield(context.tr('Start Date'), _startDate, required: true),
                      ),
                      if (_contract == 'fixed_term') _datefield(context.tr('End Date'), _endDate),
                      _field(context.tr('Insurance Number'), _rssb),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection(context.tr('Salary & Allowances'), [
                      _dropField(context.tr('Salary Type'), _salaryType,
                        AppConstants.salaryTypes.map((s) => DropdownMenuItem(value: s, child: Text(context.tr(_stLabel(s))))).toList(),
                        (v) => setState(() => _salaryType = v ?? _salaryType)),
                      if (_salaryType == AppConstants.salaryTypeFixedMonthly)
                        _field(context.tr('Monthly Salary (RWF)'), _salaryAmt, hint: '0', keyboard: TextInputType.number),
                      if (_salaryType == AppConstants.salaryTypeDailyRate)
                        _field(context.tr('Daily Rate (RWF)'), _dailyRate, hint: '0', keyboard: TextInputType.number),
                      if (_salaryType == AppConstants.salaryTypeHourlyRate)
                        _field(context.tr('Hourly Rate (RWF)'), _hourlyRate, hint: '0', keyboard: TextInputType.number),
                      _row2(
                        _field(context.tr('Transport Allowance (RWF)'), _transport, hint: '0', keyboard: TextInputType.number),
                        _field(context.tr('Housing Allowance (RWF)'), _housing, hint: '0', keyboard: TextInputType.number),
                      ),
                      _row2(
                        HRNovaDropdown<String?>(
                          label: context.tr('Bank'),
                          value: _bankCode,
                          hint: context.tr('Select bank'),
                          items: RwandaBanks.all
                              .map((b) => DropdownMenuItem(value: b.code, child: Text(b.name, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _bankCode = v),
                        ),
                        _field(context.tr('Bank Account Number'), _bank,
                            hint: context.tr('Account number'),
                            keyboard: TextInputType.number,
                            validator: _validateBankAccount),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection(context.tr('System Access'), _buildSystemAccessFields(isEdit)),
                    const SizedBox(height: 24),
                    _buildSection(context.tr('Notes'), [
                      _field(context.tr('Additional Notes'), _notes, hint: context.tr('Any additional information…'), maxLines: 3),
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
              child: AppIcon(AppIcons.arrowBackRounded, size: 18, color: context.appText),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? context.tr('Edit Employee') : context.tr('Add New Employee'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appText),
              ),
              Text(
                isEdit ? context.tr('Update employee information') : context.tr('Fill in the details to create a new employee record'),
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
              child: Text(context.tr('Cancel'), style: TextStyle(color: context.appText, fontWeight: FontWeight.w500, fontSize: 15)),
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
                      isEdit ? context.tr('Save Changes') : context.tr('Add Employee'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
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
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.appText)),
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
    String? Function(String?)? validator,
  }) {
    return HRNovaTextField(
      label: required ? '$label *' : label,
      hint: hint,
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator ??
          (required ? (v) => (v == null || v.trim().isEmpty) ? context.tr('Required') : null : null),
    );
  }

  /// Validates a Rwandan National ID (Indangamuntu): exactly 16 digits,
  /// where digits 2–5 are a plausible birth year and digit 6 is the gender
  /// marker (7 = female, 8 = male). Digit 1 (citizen/refugee/foreigner) and
  /// the trailing birth-order/reissuance/security digits aren't publicly
  /// documented with a checkable rule, so only the parts that are actually
  /// verifiable are enforced here.
  String? _validateNationalId(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return context.tr('National ID is required');
    if (!RegExp(r'^\d{16}$').hasMatch(value)) {
      return context.tr('National ID must be exactly 16 digits');
    }
    final birthYear = int.tryParse(value.substring(1, 5));
    final currentYear = DateTime.now().year;
    if (birthYear == null || birthYear < 1900 || birthYear > currentYear) {
      return context.tr('Invalid National ID — the year segment (digits 2–5) is not a valid birth year');
    }
    final genderDigit = value[5];
    if (genderDigit != '7' && genderDigit != '8') {
      return context.tr('Invalid National ID — the 6th digit must be 7 or 8');
    }
    return null;
  }

  /// Phone must start with "07" and be exactly 10 digits, digits only.
  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^07\d{8}$').hasMatch(value)) {
      return context.tr('Phone must start with 07 and be exactly 10 digits');
    }
    return null;
  }

  /// Bank account number must contain digits only.
  String? _validateBankAccount(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return context.tr('Bank account number must contain digits only');
    }
    return null;
  }

  Widget _datefield(String label, TextEditingController ctrl, {bool required = false}) {
    return HRNovaTextField(
      label: required ? '$label *' : label,
      hint: context.tr('Select date'),
      controller: ctrl,
      readOnly: true,
      suffixIcon: AppIcon(AppIcons.calendarTodayOutlined, size: 16, color: context.appSubtext),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (picked != null) ctrl.text = EmployeeModel.fmtDate(picked);
      },
      validator: required ? (v) => (v == null || v.isEmpty) ? context.tr('Required') : null : null,
    );
  }

  Widget _dropField(String label, String value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    final validValue = items.any((i) => i.value == value) ? value : null;
    return HRNovaDropdown<String>(
      label: label,
      value: validValue,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _dropFieldN(String label, String? value, List<DropdownMenuItem<String?>> items, ValueChanged<String?> onChanged) {
    return HRNovaDropdown<String?>(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  List<Widget> _buildSystemAccessFields(bool isEdit) {
    final userRole = ref.read(currentUserRoleProvider);
    final isMultiBranch = ref.read(currentCompanyTypeProvider) == AppConstants.companyMultiBranch;
    final showPassword = !isEdit && _role == AppConstants.roleManager;
    final fields = <Widget>[
      _dropField(context.tr('Role'), _role,
        _buildRoleItems(userRole ?? AppConstants.roleEmployee, isMultiBranch),
        (v) => setState(() { _role = v ?? _role; _password.clear(); })),
    ];
    if (showPassword) {
      fields.add(_passwordField());
    } else {
      fields.add(Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.pillBlueBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const AppIcon(AppIcons.infoOutline, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(
            context.tr('If an email is provided, a temporary password is auto-generated so the employee can log in to the app.'),
            style: const TextStyle(fontSize: 14, color: AppColors.primaryBlue),
          )),
        ]),
      ));
    }
    return fields;
  }

  Widget _passwordField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HRNovaTextField(
        label: context.tr('Login Password'),
        hint: context.tr('Leave blank to auto-generate'),
        controller: _password,
        obscureText: _obscurePassword,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: AppIcon(_obscurePassword ? AppIcons.visibilityOutlined : AppIcons.visibilityOffOutlined,
              size: 18, color: context.appSubtext),
        ),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Leave blank to auto-generate a password. You will see it after saving.'),
          style: TextStyle(fontSize: 13, color: context.appSubtext)),
    ]);
  }

  List<DropdownMenuItem<String>> _buildRoleItems(String userRole, bool isMultiBranch) {
    if (isMultiBranch && userRole == AppConstants.roleGroupHrAdmin) {
      return [
        DropdownMenuItem(value: 'branch_hr_admin', child: Text(context.tr('Branch HR Admin'))),
        DropdownMenuItem(value: 'manager', child: Text(context.tr('Manager'))),
      ];
    }
    // Branch HR admin can never create another HR admin
    if (userRole == AppConstants.roleBranchHrAdmin) {
      return [
        DropdownMenuItem(value: 'employee', child: Text(context.tr('Employee'))),
        DropdownMenuItem(value: 'manager', child: Text(context.tr('Manager'))),
        DropdownMenuItem(value: 'director', child: Text(context.tr('Director'))),
        DropdownMenuItem(value: 'finance_manager', child: Text(context.tr('Finance Manager'))),
        DropdownMenuItem(value: 'administration', child: Text(context.tr('Administration'))),
      ];
    }
    return [
      DropdownMenuItem(value: 'employee', child: Text(context.tr('Employee'))),
      DropdownMenuItem(value: 'manager', child: Text(context.tr('Manager'))),
      DropdownMenuItem(value: 'director', child: Text(context.tr('Director'))),
      DropdownMenuItem(value: 'finance_manager', child: Text(context.tr('Finance Manager'))),
      DropdownMenuItem(value: 'administration', child: Text(context.tr('Administration'))),
      DropdownMenuItem(value: 'hr_admin', child: Text(context.tr('HR Admin'))),
    ];
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
              style: TextStyle(fontSize: 13, color: widget.ctx.appSubtext, fontWeight: FontWeight.w400)),
          const SizedBox(height: 2),
          Text(widget.value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: widget.ctx.appText,
                  fontFamily: 'monospace')),
        ])),
        GestureDetector(
          onTap: _copy,
          child: AppIcon(
            _copied ? AppIcons.checkRounded : AppIcons.copyRounded,
            size: 16,
            color: _copied ? AppColors.successGreen : widget.ctx.appSubtext,
          ),
        ),
      ]),
    );
  }
}
