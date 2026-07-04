import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/company_settings_model.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _initialized = false;

  // Expansion state
  final Map<String, bool> _expanded = {
    'schedule': true, 'leave': false, 'payroll': false,
    'departments': false, 'notifications': false, 'performance': false,
  };

  // Performance criteria
  List<PerformanceCriterion> _criteria = PerformanceCriterion.defaults;

  // Work Schedule
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime   = const TimeOfDay(hour: 17, minute: 0);
  final _graceCtrl     = TextEditingController(text: '10');
  Set<String> _days    = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  // Leave
  final _annualCtrl = TextEditingController(text: '18');
  final _sickCtrl   = TextEditingController(text: '10');

  // Payroll
  final _payDayCtrl  = TextEditingController(text: '28');
  String _overtime   = '1.5x';
  final _lateCtrl    = TextEditingController(text: '500');
  final _maxLateCtrl = TextEditingController(text: '3');

  // Departments
  List<String> _depts = [];
  final _deptCtrl = TextEditingController();

  // Notifications
  final _mgrPhone   = TextEditingController();
  final _hrPhone    = TextEditingController();
  final _guardPhone = TextEditingController();
  final _mgrEmail   = TextEditingController();
  final _hrEmail    = TextEditingController();
  final _tinCtrl    = TextEditingController();
  String _notif     = 'email';

  static const _shortToLong = {
    'Mon': 'monday', 'Tue': 'tuesday', 'Wed': 'wednesday',
    'Thu': 'thursday', 'Fri': 'friday', 'Sat': 'saturday',
  };
  static const _longToShort = {
    'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed',
    'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat',
  };
  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void dispose() {
    _graceCtrl.dispose(); _annualCtrl.dispose(); _sickCtrl.dispose();
    _payDayCtrl.dispose(); _lateCtrl.dispose(); _maxLateCtrl.dispose();
    _deptCtrl.dispose(); _mgrPhone.dispose(); _hrPhone.dispose();
    _guardPhone.dispose(); _mgrEmail.dispose(); _hrEmail.dispose();
    _tinCtrl.dispose();
    super.dispose();
  }

  void _populate(CompanySettingsModel s) {
    _startTime = _parseTime(s.workStartTime);
    _endTime   = _parseTime(s.workEndTime);
    _graceCtrl.text  = s.gracePeriodMinutes.toString();
    _annualCtrl.text = s.annualLeaveDays.toString();
    _sickCtrl.text   = s.sickLeaveDays.toString();
    _payDayCtrl.text = s.salaryPaymentDay.toString();
    _lateCtrl.text   = s.lateDeductionPerHourRwf.toString();
    _maxLateCtrl.text = s.maxLateBeforeWarning.toString();
    _mgrPhone.text   = s.managerPhone.isEmpty ? '+250' : s.managerPhone;
    _hrPhone.text    = s.hrAdminPhone.isEmpty ? '+250' : s.hrAdminPhone;
    _guardPhone.text = s.guardPhone.isEmpty ? '+250' : s.guardPhone;
    _mgrEmail.text   = s.managerEmail;
    _hrEmail.text    = s.hrAdminEmail;
    _tinCtrl.text    = s.rraTinNumber ?? '';
    _days  = Set.from(s.workingDays.map((d) => _longToShort[d] ?? d).where((d) => d.isNotEmpty));
    _depts = List.from(s.departments);
    _notif = s.notificationMethod;
    _criteria = s.performanceCriteria.isEmpty ? List.from(PerformanceCriterion.defaults) : List.from(s.performanceCriteria);
    _overtime = _fmtMultiplier(s.overtimeMultiplier);
  }

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 8, minute: 0);
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _fmtMultiplier(double v) => v == 1.0 ? '1x' : v == 2.0 ? '2x' : '1.5x';
  double _parseMultiplier(String v) => switch (v) { '1x' => 1.0, '2x' => 2.0, _ => 1.5 };
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _toggle(String key) => setState(() => _expanded[key] = !(_expanded[key] ?? false));

  void _addDept() {
    final v = _deptCtrl.text.trim();
    if (v.isNotEmpty && !_depts.contains(v)) {
      setState(() { _depts.add(v); _deptCtrl.clear(); });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (t != null && mounted) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  Future<void> _save(String section, Map<String, dynamic> data) async {
    try {
      await ref.read(settingsNotifierProvider.notifier).updateSettings(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$section saved successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CompanySettingsModel?>>(companySettingsProvider, (_, next) {
      if (!_initialized && next.value != null) {
        _initialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _populate(next.value!));
        });
      }
    });

    final settingsAsync = ref.watch(companySettingsProvider);
    final role     = ref.watch(currentUserRoleProvider);
    final canEdit  = role != AppConstants.roleBranchHrAdmin;

    return Scaffold(
      backgroundColor: context.appBg,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.errorRed))),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Settings', style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text('Configure your company preferences', style: TextStyle(color: context.appSubtext, fontSize: 15)),
              ]),
              if (!canEdit) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.pillAmberBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline_rounded, color: AppColors.warningAmber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Settings can only be changed by the company HR Admin. Contact them to update policies.',
                      style: const TextStyle(color: AppColors.warningAmber, fontSize: 14, height: 1.4),
                    )),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              _section('schedule', Icons.schedule_rounded, 'Work Schedule', 'Work hours, grace period and working days', _scheduleBody(canEdit)),
              const SizedBox(height: 14),
              _section('leave', Icons.beach_access_rounded, 'Leave Policy', 'Annual and sick leave entitlements', _leaveBody(canEdit)),
              const SizedBox(height: 14),
              _section('payroll', Icons.payments_rounded, 'Payroll Rules', 'Salary payment day, overtime and late deduction', _payrollBody(canEdit)),
              const SizedBox(height: 14),
              _section('departments', Icons.account_tree_rounded, 'Departments', 'Manage company departments', _deptsBody(canEdit)),
              const SizedBox(height: 14),
              _section('notifications', Icons.notifications_rounded, 'Notifications & Contacts', 'Emergency contacts and notification preferences', _notifBody(canEdit)),
              const SizedBox(height: 14),
              _section('performance', Icons.trending_up_rounded, 'Performance Criteria', 'Scoring criteria and weights — must total 100%', _criteriaBody(canEdit)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String key, IconData icon, String title, String subtitle, Widget body) {
    final open = _expanded[key] ?? false;
    return Container(
      decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(key),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: AppColors.primaryBlue, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: TextStyle(color: context.appSubtext, fontSize: 14)),
                  ])),
                  Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: context.appSubtext),
                ],
              ),
            ),
          ),
          if (open) ...[
            Divider(color: context.appBorder, height: 1),
            Padding(padding: const EdgeInsets.all(20), child: body),
          ],
        ],
      ),
    );
  }

  // ── Section bodies ────────────────────────────────────────────────────────

  Widget _scheduleBody(bool canEdit) => AbsorbPointer(
    absorbing: !canEdit,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _timeField('Work Start', _startTime, () => _pickTime(true))),
      const SizedBox(width: 16),
      Expanded(child: _timeField('Work End', _endTime, () => _pickTime(false))),
    ]),
    const SizedBox(height: 16),
    _field('Grace Period', _graceCtrl, hint: '10', suffix: 'minutes', type: TextInputType.number),
    const SizedBox(height: 16),
    Text('Working Days', style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8, children: _allDays.map((d) {
      final sel = _days.contains(d);
      return GestureDetector(
        onTap: () => setState(() => sel ? _days.remove(d) : _days.add(d)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryBlue.withAlpha(15) : context.appField,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppColors.primaryBlue : context.appBorder, width: sel ? 1.5 : 1),
          ),
          child: Text(d, style: TextStyle(color: sel ? AppColors.primaryBlue : context.appSubtext, fontSize: 15, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList()),
    const SizedBox(height: 20),
    if (canEdit) _saveBtn(() => _save('Work Schedule', {
      'workStartTime': _fmtTime(_startTime),
      'workEndTime': _fmtTime(_endTime),
      'gracePeriodMinutes': int.tryParse(_graceCtrl.text) ?? 10,
      'workingDays': _days.map((d) => _shortToLong[d] ?? d.toLowerCase()).toList(),
    })),
  ]));

  Widget _leaveBody(bool canEdit) => AbsorbPointer(
    absorbing: !canEdit,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _field('Annual Leave Days', _annualCtrl, hint: '18', suffix: 'days', type: TextInputType.number)),
      const SizedBox(width: 16),
      Expanded(child: _field('Sick Leave Days', _sickCtrl, hint: '10', suffix: 'days', type: TextInputType.number)),
    ]),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primaryBlue.withAlpha(60))),
      child: Row(children: const [
        Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 16),
        SizedBox(width: 10),
        Expanded(child: Text('Maternity: 84 days  •  Paternity: 4 days — Fixed by Rwanda Law', style: TextStyle(color: AppColors.primaryBlue, fontSize: 14, height: 1.4))),
      ]),
    ),
    const SizedBox(height: 16),
    if (canEdit) _saveBtn(() => _save('Leave Policy', {
      'annualLeaveDays': int.tryParse(_annualCtrl.text) ?? 18,
      'sickLeaveDays': int.tryParse(_sickCtrl.text) ?? 10,
    })),
  ]));

  Widget _payrollBody(bool canEdit) => AbsorbPointer(
    absorbing: !canEdit,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _field('Salary Payment Day', _payDayCtrl, hint: '28', suffix: 'of month', type: TextInputType.number)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Overtime Multiplier', style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: context.appField, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _overtime,
              dropdownColor: context.appCard,
              items: const ['1x', '1.5x', '2x'].map((v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: TextStyle(color: context.appText, fontSize: 15)),
              )).toList(),
              onChanged: (v) => setState(() => _overtime = v!),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.appSubtext),
              isExpanded: true,
            ),
          ),
        ),
      ])),
    ]),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _field('Late Deduction / Hour', _lateCtrl, hint: '500', suffix: 'RWF', type: TextInputType.number)),
      const SizedBox(width: 16),
      Expanded(child: _field('Max Late Before Warning', _maxLateCtrl, hint: '3', suffix: 'times', type: TextInputType.number)),
    ]),
    const SizedBox(height: 16),
    if (canEdit) _saveBtn(() => _save('Payroll Rules', {
      'salaryPaymentDay': int.tryParse(_payDayCtrl.text) ?? 28,
      'overtimeMultiplier': _parseMultiplier(_overtime),
      'lateDeductionPerHourRwf': int.tryParse(_lateCtrl.text) ?? 500,
      'maxLateBeforeWarning': int.tryParse(_maxLateCtrl.text) ?? 3,
    })),
  ]));

  Widget _deptsBody(bool canEdit) => AbsorbPointer(
    absorbing: !canEdit,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(
        child: TextField(
          controller: _deptCtrl,
          style: TextStyle(color: context.appText, fontSize: 15),
          onSubmitted: (_) => _addDept(),
          decoration: InputDecoration(
            hintText: 'Enter department name...',
            hintStyle: TextStyle(color: context.appSubtext),
            filled: true, fillColor: context.appField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      FilledButton.icon(
        onPressed: _addDept,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
      ),
    ]),
    if (_depts.isNotEmpty) ...[
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: _depts.map((d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.primaryBlue.withAlpha(60))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(d, style: const TextStyle(color: AppColors.primaryBlue, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _depts.remove(d)),
            child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primaryBlue),
          ),
        ]),
      )).toList()),
    ],
    const SizedBox(height: 16),
    if (canEdit) _saveBtn(() => _save('Departments', {'departments': _depts})),
  ]));

  Widget _notifBody(bool canEdit) => AbsorbPointer(
    absorbing: !canEdit,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Emergency Contacts', style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 14),
    _field('Manager WhatsApp', _mgrPhone, hint: '+250 788 000 000'),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _field('HR Admin WhatsApp', _hrPhone, hint: '+250 788 000 001')),
      const SizedBox(width: 14),
      Expanded(child: _field('Guard Phone', _guardPhone, hint: '+250 788 000 002')),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _field('Manager Email', _mgrEmail, hint: 'manager@company.com', type: TextInputType.emailAddress)),
      const SizedBox(width: 14),
      Expanded(child: _field('HR Admin Email', _hrEmail, hint: 'hr@company.com', type: TextInputType.emailAddress)),
    ]),
    const SizedBox(height: 16),
    _field('RRA TIN Number', _tinCtrl, hint: '102XXXXXXXXX'),
    const SizedBox(height: 16),
    if (canEdit) _saveBtn(() => _save('Notifications & Contacts', {
      'managerPhone': _mgrPhone.text.trim(),
      'hrAdminPhone': _hrPhone.text.trim(),
      'guardPhone': _guardPhone.text.trim(),
      'managerEmail': _mgrEmail.text.trim(),
      'hrAdminEmail': _hrEmail.text.trim(),
      'notificationMethod': _notif,
      'rraTinNumber': _tinCtrl.text.trim(),
    })),
  ]));

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _field(String label, TextEditingController ctrl, {String? hint, String? suffix, TextInputType? type}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type,
          style: TextStyle(color: context.appText, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.appSubtext),
            suffixText: suffix,
            suffixStyle: TextStyle(color: context.appSubtext, fontSize: 15),
            filled: true, fillColor: context.appField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
        ),
      ]);

  Widget _timeField(String label, TimeOfDay t, VoidCallback onTap) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: context.appField, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.access_time_rounded, color: context.appSubtext, size: 18),
              const SizedBox(width: 10),
              Text(_fmtTime(t), style: TextStyle(color: context.appText, fontSize: 15)),
            ]),
          ),
        ),
      ]);

  Widget _saveBtn(VoidCallback? onTap) => Align(
    alignment: Alignment.centerRight,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.check_rounded, size: 16),
      label: const Text('Save Changes'),
      style: FilledButton.styleFrom(
        backgroundColor: onTap != null ? AppColors.primaryBlue : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
    ),
  );

  Widget _criteriaBody(bool canEdit) {
    final total = _criteria.fold(0.0, (s, c) => s + c.weight);
    final isValid = (total - 100).abs() < 0.01;
    return AbsorbPointer(
      absorbing: !canEdit,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(flex: 5, child: Text('Criterion Name', style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w600))),
        Expanded(flex: 2, child: Text('Weight %', style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w600))),
        const SizedBox(width: 40),
      ]),
      const SizedBox(height: 10),
      ...List.generate(_criteria.length, (i) {
        final c = _criteria[i];
        return _CriterionRow(
          key: ValueKey('criterion_$i'),
          criterion: c,
          onWeightChanged: (w) => setState(() => _criteria[i] = PerformanceCriterion(name: c.name, weight: w)),
          onRemove: () => setState(() => _criteria.removeAt(i)),
          appText: context.appText,
          appSubtext: context.appSubtext,
          appField: context.appField,
          appBorder: context.appBorder,
        );
      }),
      const SizedBox(height: 8),
      _AddCriterionRow(onAdd: (name, weight) {
        setState(() => _criteria.add(PerformanceCriterion(name: name, weight: weight)));
      }),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isValid ? AppColors.pillGreenBg : AppColors.pillRedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isValid ? AppColors.successGreen.withAlpha(80) : AppColors.errorRed.withAlpha(80)),
        ),
        child: Row(children: [
          Icon(isValid ? Icons.check_circle_rounded : Icons.error_rounded,
              color: isValid ? AppColors.successGreen : AppColors.errorRed, size: 16),
          const SizedBox(width: 8),
          Text(
            isValid ? 'Total: 100% ✓' : 'Total: ${total.toStringAsFixed(1)}% — must equal 100%',
            style: TextStyle(color: isValid ? AppColors.successGreen : AppColors.errorRed, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      if (canEdit) _saveBtn(isValid ? () => _save('Performance Criteria', {
        'performanceCriteria': _criteria.map((c) => c.toMap()).toList(),
      }) : null),
    ]));
  }
}

// ── Criterion row — owns its TextEditingController ────────────────────────────
class _CriterionRow extends StatefulWidget {
  const _CriterionRow({
    super.key,
    required this.criterion,
    required this.onWeightChanged,
    required this.onRemove,
    required this.appText,
    required this.appSubtext,
    required this.appField,
    required this.appBorder,
  });
  final PerformanceCriterion criterion;
  final void Function(double) onWeightChanged;
  final VoidCallback onRemove;
  final Color appText, appSubtext, appField, appBorder;

  @override
  State<_CriterionRow> createState() => _CriterionRowState();
}

class _CriterionRowState extends State<_CriterionRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.criterion.weight.toStringAsFixed(0));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(flex: 5, child: Text(widget.criterion.name, style: TextStyle(color: widget.appText, fontSize: 15))),
        Expanded(flex: 2, child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: widget.appText, fontSize: 15),
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: TextStyle(color: widget.appSubtext),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: widget.appField,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.appBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.appBorder)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
          onChanged: (v) {
            final w = double.tryParse(v);
            if (w != null) widget.onWeightChanged(w);
          },
        )),
        const SizedBox(width: 8),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.errorRed),
          tooltip: 'Remove',
        ),
      ]),
    );
  }
}

// ── Add criterion row ─────────────────────────────────────────────────────────
class _AddCriterionRow extends StatefulWidget {
  const _AddCriterionRow({required this.onAdd});
  final void Function(String name, double weight) onAdd;
  @override
  State<_AddCriterionRow> createState() => _AddCriterionRowState();
}

class _AddCriterionRowState extends State<_AddCriterionRow> {
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  void dispose() { _nameCtrl.dispose(); _weightCtrl.dispose(); super.dispose(); }

  void _add() {
    final name = _nameCtrl.text.trim();
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    if (name.isEmpty || weight <= 0) return;
    widget.onAdd(name, weight);
    _nameCtrl.clear(); _weightCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 5, child: TextField(
        controller: _nameCtrl,
        style: TextStyle(color: context.appText, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'New criterion name...',
          hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true, fillColor: context.appField,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        ),
      )),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: TextField(
        controller: _weightCtrl,
        keyboardType: TextInputType.number,
        style: TextStyle(color: context.appText, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Weight%',
          hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true, fillColor: context.appField,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.appBorder)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        ),
      )),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: _add,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Add'),
      ),
    ]);
  }
}
