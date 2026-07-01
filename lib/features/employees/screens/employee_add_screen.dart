import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class EmployeeAddScreen extends StatefulWidget {
  const EmployeeAddScreen({super.key, this.editId});
  final String? editId;

  @override
  State<EmployeeAddScreen> createState() => _EmployeeAddScreenState();
}

class _EmployeeAddScreenState extends State<EmployeeAddScreen> {
  String _contract = 'permanent';
  String _salaryType = 'fixed_monthly';
  String _role = 'employee';

  bool get isEdit => widget.editId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: Column(
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
                      _field('First Name', required: true),
                      _field('Last Name', required: true),
                    ),
                    _row2(
                      _field('National ID'),
                      _field('Phone (+250)'),
                    ),
                    _field('Email Address', hint: 'employee@company.com'),
                    _row2(
                      _datefield('Date of Birth'),
                      _field('Emergency Contact', hint: 'Name & phone'),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Employment Details', [
                    _row2(
                      _field('Department'),
                      _field('Job Title', required: true),
                    ),
                    _row2(
                      _dropField('Contract Type', _contract, const [
                        DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                        DropdownMenuItem(value: 'fixed_term', child: Text('Fixed Term')),
                        DropdownMenuItem(value: 'probation', child: Text('Probation')),
                        DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                      ], (v) => setState(() => _contract = v ?? _contract)),
                      _datefield('Start Date', required: true),
                    ),
                    if (_contract == 'fixed_term') _datefield('End Date'),
                    _field('RSSB Number'),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Profile Photo', [
                    Row(children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightBlue50,
                          border: Border.all(color: AppColors.cardBorder, width: 2),
                        ),
                        child: const Icon(Icons.person_outline, size: 32, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryBlue),
                            foregroundColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.upload_outlined, size: 16),
                          label: const Text('Upload Photo'),
                        ),
                        const SizedBox(height: 4),
                        const Text('JPEG or PNG, max 5 MB',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ]),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Salary & Allowances', [
                    _dropField('Salary Type', _salaryType, const [
                      DropdownMenuItem(value: 'fixed_monthly', child: Text('Fixed Monthly')),
                      DropdownMenuItem(value: 'daily_rate', child: Text('Daily Rate')),
                      DropdownMenuItem(value: 'hourly_rate', child: Text('Hourly Rate')),
                    ], (v) => setState(() => _salaryType = v ?? _salaryType)),
                    if (_salaryType == 'fixed_monthly') _field('Monthly Salary (RWF)', hint: '0'),
                    if (_salaryType == 'daily_rate') _field('Daily Rate (RWF)', hint: '0'),
                    if (_salaryType == 'hourly_rate') _field('Hourly Rate (RWF)', hint: '0'),
                    _row2(
                      _field('Transport Allowance (RWF)', hint: '0'),
                      _field('Housing Allowance (RWF)', hint: '0'),
                    ),
                    _field('Bank Account Number'),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('System Access', [
                    _dropField('Role', _role, const [
                      DropdownMenuItem(value: 'employee', child: Text('Employee')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager (gets app login)')),
                    ], (v) => setState(() => _role = v ?? _role)),
                    if (_role == 'manager')
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.pillBlueBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'A temporary password will be auto-generated and sent to the employee email.',
                            style: TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                          )),
                        ]),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.lightBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Employee' : 'Add New Employee',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                isEdit ? 'Update employee information' : 'Fill in the details to create a new employee record',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Save functionality coming soon'), backgroundColor: AppColors.primaryBlue),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Text(
                isEdit ? 'Save Changes' : 'Add Employee',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 4),
          const Divider(color: AppColors.cardBorder),
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

  Widget _field(String label, {String? hint, bool required = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        children: required ? const [TextSpan(text: ' *', style: TextStyle(color: AppColors.errorRed))] : [],
      )),
      const SizedBox(height: 6),
      TextFormField(
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          filled: true, fillColor: AppColors.lightBlue50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
    ]);
  }

  Widget _datefield(String label, {bool required = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        children: required ? const [TextSpan(text: ' *', style: TextStyle(color: AppColors.errorRed))] : [],
      )),
      const SizedBox(height: 6),
      TextFormField(
        readOnly: true,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Select date',
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
          filled: true, fillColor: AppColors.lightBlue50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
    ]);
  }

  Widget _dropField(String label, String value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: AppColors.lightBlue50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, items: items, onChanged: onChanged, isExpanded: true,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ),
        ),
      ),
    ]);
  }
}
