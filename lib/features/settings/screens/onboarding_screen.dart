import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _saving = false;
  static const _total = 5;

  // Step 1 — Work Schedule
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _graceCtrl = TextEditingController(text: '10');
  final Set<String> _days = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  // Step 2 — Leave Policy
  final _annualCtrl = TextEditingController(text: '18');
  final _sickCtrl = TextEditingController(text: '10');

  // Step 3 — Payroll Rules
  final _payDayCtrl = TextEditingController(text: '28');
  String _overtime = '1.5x';
  final _lateCtrl = TextEditingController(text: '500');
  final _maxLateCtrl = TextEditingController(text: '3');

  // Step 4 — Departments
  final List<String> _depts = [];
  final _deptCtrl = TextEditingController();

  // Step 5 — Notifications & Contacts
  final _mgrPhone = TextEditingController(text: '+250');
  final _hrPhone = TextEditingController(text: '+250');
  final _guardPhone = TextEditingController(text: '+250');
  final _mgrEmail = TextEditingController();
  final _hrEmail = TextEditingController();
  final _tinCtrl = TextEditingController();
  String _notif = 'email';

  // Day abbreviation ↔ Firestore long-form mapping
  static const _toFirestore = {
    'Mon': 'monday', 'Tue': 'tuesday', 'Wed': 'wednesday',
    'Thu': 'thursday', 'Fri': 'friday', 'Sat': 'saturday', 'Sun': 'sunday',
  };

  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _graceCtrl.dispose(); _annualCtrl.dispose(); _sickCtrl.dispose();
    _payDayCtrl.dispose(); _lateCtrl.dispose(); _maxLateCtrl.dispose();
    _deptCtrl.dispose(); _mgrPhone.dispose(); _hrPhone.dispose();
    _guardPhone.dispose(); _mgrEmail.dispose(); _hrEmail.dispose();
    _tinCtrl.dispose();
    super.dispose();
  }

  double _parseMultiplier(String val) => switch (val) {
    '1x' => 1.0, '2x' => 2.0, _ => 1.5,
  };

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (t != null && mounted) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  Future<void> _next() async {
    if (_step == 3 && _depts.isEmpty) return;
    if (_step < _total - 1) {
      setState(() => _step++);
      return;
    }
    // Final step — save all to Firestore
    setState(() => _saving = true);
    try {
      await ref.read(settingsNotifierProvider.notifier).updateSettings({
        'workStartTime': _fmtTime(_startTime),
        'workEndTime': _fmtTime(_endTime),
        'gracePeriodMinutes': int.tryParse(_graceCtrl.text.trim()) ?? 10,
        'workingDays': _days.map((d) => _toFirestore[d]!).toList(),
        'annualLeaveDays': int.tryParse(_annualCtrl.text.trim()) ?? 18,
        'sickLeaveDays': int.tryParse(_sickCtrl.text.trim()) ?? 10,
        'salaryPaymentDay': int.tryParse(_payDayCtrl.text.trim()) ?? 28,
        'overtimeMultiplier': _parseMultiplier(_overtime),
        'lateDeductionPerHourRwf': int.tryParse(_lateCtrl.text.trim()) ?? 500,
        'maxLateBeforeWarning': int.tryParse(_maxLateCtrl.text.trim()) ?? 3,
        'departments': _depts,
        'managerPhone': _mgrPhone.text.trim(),
        'hrAdminPhone': _hrPhone.text.trim(),
        'guardPhone': _guardPhone.text.trim(),
        'managerEmail': _mgrEmail.text.trim(),
        'hrAdminEmail': _hrEmail.text.trim(),
        'notificationMethod': _notif,
        'rraTinNumber': _tinCtrl.text.trim(),
        'isOnboardingComplete': true,
      });
      // Local override so router lets us through before stream refreshes
      ref.read(onboardingCompleteOverrideProvider.notifier).state = true;
      if (mounted) context.go(kIsWeb ? '/dashboard' : '/guard-mode');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _addDept() {
    final v = _deptCtrl.text.trim();
    if (v.isNotEmpty && !_depts.contains(v)) {
      setState(() { _depts.add(v); _deptCtrl.clear(); });
    }
  }

  static const _stepTitles = [
    'Work Schedule', 'Leave Policy', 'Payroll Rules', 'Departments',
    'Notifications & Contacts',
  ];
  static const _stepSubs = [
    'Set your company work hours and working days',
    'Define leave entitlements for your employees',
    'Configure salary payment and deduction rules',
    'Add the departments in your company',
    'Set up emergency contacts and notification preferences',
  ];

  // ── Shared colours ────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF070E1C);
  static const _card   = Color(0xFF0D1E35);
  static const _field  = Color(0xFF060C18);
  static const _border = Color(0xFF1A3050);
  static const _sub    = Color(0xFF8899BB);
  static const _blue   = AppColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _logo(),
                const SizedBox(height: 32),
                _StepIndicators(current: _step, total: _total),
                const SizedBox(height: 24),
                _formCard(),
                const SizedBox(height: 20),
                _navButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: _blue.withAlpha(20), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.grid_view_rounded, color: _blue, size: 22),
      ),
      const SizedBox(width: 10),
      const Text('HRNova', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
    ],
  );

  Widget _formCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step ${_step + 1} of $_total', style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(_stepTitles[_step], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(_stepSubs[_step], style: const TextStyle(color: _sub, fontSize: 13)),
        const SizedBox(height: 24),
        const Divider(color: _border, height: 1),
        const SizedBox(height: 24),
        _buildStep(),
      ],
    ),
  );

  Widget _navButtons() => Row(
    children: [
      if (_step > 0) ...[
        OutlinedButton(
          onPressed: _saving ? null : _back,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _border),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          child: const Text('Back'),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: FilledButton(
          onPressed: _saving ? null : _next,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            disabledBackgroundColor: _blue.withAlpha(100),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_step == _total - 1 ? 'Complete Setup' : 'Continue',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ),
    ],
  );

  Widget _buildStep() => switch (_step) {
    0 => _buildWorkSchedule(),
    1 => _buildLeavePolicy(),
    2 => _buildPayrollRules(),
    3 => _buildDepartments(),
    _ => _buildNotifications(),
  };

  // ── Step 1: Work Schedule ─────────────────────────────────────────────────
  Widget _buildWorkSchedule() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: _timeField('Work Start', _startTime, () => _pickTime(true))),
        const SizedBox(width: 16),
        Expanded(child: _timeField('Work End', _endTime, () => _pickTime(false))),
      ]),
      const SizedBox(height: 20),
      _textField('Grace Period', _graceCtrl, hint: '10', suffix: 'minutes', type: TextInputType.number),
      const SizedBox(height: 20),
      const Text('Working Days', style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _allDays.map((d) {
          final sel = _days.contains(d);
          return GestureDetector(
            onTap: () => setState(() => sel ? _days.remove(d) : _days.add(d)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: sel ? _blue.withAlpha(25) : _field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _blue : _border, width: sel ? 1.5 : 1),
              ),
              child: Text(d, style: TextStyle(color: sel ? _blue : _sub, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        }).toList(),
      ),
    ],
  );

  // ── Step 2: Leave Policy ──────────────────────────────────────────────────
  Widget _buildLeavePolicy() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: _textField('Annual Leave', _annualCtrl, hint: '18', suffix: 'days', type: TextInputType.number)),
        const SizedBox(width: 16),
        Expanded(child: _textField('Sick Leave', _sickCtrl, hint: '10', suffix: 'days', type: TextInputType.number)),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _blue.withAlpha(18), borderRadius: BorderRadius.circular(12), border: Border.all(color: _blue.withAlpha(60))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline_rounded, color: _blue, size: 18),
            SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statutory Leave — Fixed by Rwanda Law', style: TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Maternity: 84 days  •  Paternity: 4 days\nThese are mandatory and cannot be configured.',
                    style: TextStyle(color: _sub, fontSize: 12, height: 1.5)),
              ],
            )),
          ],
        ),
      ),
    ],
  );

  // ── Step 3: Payroll Rules ─────────────────────────────────────────────────
  Widget _buildPayrollRules() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: _textField('Salary Payment Day', _payDayCtrl, hint: '28', suffix: 'of month', type: TextInputType.number)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overtime Multiplier', style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _overtime,
                  items: const ['1x', '1.5x', '2x'].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  )).toList(),
                  onChanged: (v) => setState(() => _overtime = v!),
                  dropdownColor: _card,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _sub),
                  isExpanded: true,
                ),
              ),
            ),
          ],
        )),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _textField('Late Deduction / Hour', _lateCtrl, hint: '500', suffix: 'RWF', type: TextInputType.number)),
        const SizedBox(width: 16),
        Expanded(child: _textField('Max Late Before Warning', _maxLateCtrl, hint: '3', suffix: 'times', type: TextInputType.number)),
      ]),
    ],
  );

  // ── Step 4: Departments ───────────────────────────────────────────────────
  Widget _buildDepartments() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _deptCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onSubmitted: (_) => _addDept(),
            decoration: InputDecoration(
              hintText: 'e.g. Finance, Operations, IT...',
              hintStyle: const TextStyle(color: Color(0xFF445566)),
              filled: true, fillColor: _field,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _addDept,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add'),
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        ),
      ]),
      if (_depts.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Add at least one department to continue', style: TextStyle(color: AppColors.errorRed.withAlpha(200), fontSize: 12)),
        ),
      if (_depts.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _depts.map((d) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _blue.withAlpha(20), borderRadius: BorderRadius.circular(100), border: Border.all(color: _blue.withAlpha(80))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(d, style: const TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _depts.remove(d)),
                  child: const Icon(Icons.close_rounded, size: 14, color: _blue),
                ),
              ],
            ),
          )).toList(),
        ),
      ],
    ],
  );

  // ── Step 5: Notifications & Contacts ─────────────────────────────────────
  Widget _buildNotifications() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Emergency Contacts', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      _textField('Manager WhatsApp', _mgrPhone, hint: '+250 788 000 000'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _textField('HR Admin WhatsApp', _hrPhone, hint: '+250 788 000 001')),
        const SizedBox(width: 16),
        Expanded(child: _textField('Guard Phone', _guardPhone, hint: '+250 788 000 002')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _textField('Manager Email', _mgrEmail, hint: 'manager@company.com', type: TextInputType.emailAddress)),
        const SizedBox(width: 16),
        Expanded(child: _textField('HR Admin Email', _hrEmail, hint: 'hr@company.com', type: TextInputType.emailAddress)),
      ]),
      const SizedBox(height: 24),
      const Divider(color: _border, height: 1),
      const SizedBox(height: 20),
      const Text('Notification Method', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _blue.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _blue.withAlpha(60))),
        child: Row(
          children: [
            const Icon(Icons.email_outlined, color: _blue, size: 16),
            const SizedBox(width: 8),
            const Text('Email only', style: TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('WhatsApp coming in Phase 2', style: TextStyle(color: _sub, fontSize: 11)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Divider(color: _border, height: 1),
      const SizedBox(height: 20),
      _textField('RRA TIN Number', _tinCtrl, hint: '102XXXXXXXXX (for RRA payroll export)'),
    ],
  );

  // ── Shared field widgets ──────────────────────────────────────────────────
  Widget _textField(String label, TextEditingController ctrl, {String? hint, String? suffix, TextInputType? type}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl, keyboardType: type,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF445566)),
              suffixText: suffix,
              suffixStyle: const TextStyle(color: _sub, fontSize: 13),
              filled: true, fillColor: _field,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
            ),
          ),
        ],
      );

  Widget _timeField(String label, TimeOfDay t, VoidCallback onTap) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: _sub, size: 18),
                  const SizedBox(width: 10),
                  Text(_fmtTime(t), style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      );
}

// ── Step indicator row ────────────────────────────────────────────────────────
class _StepIndicators extends StatelessWidget {
  const _StepIndicators({required this.current, required this.total});
  final int current, total;

  static const _blue   = AppColors.primaryBlue;
  static const _border = Color(0xFF1A3050);
  static const _card   = Color(0xFF0D1E35);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 2, color: i ~/ 2 < current ? _blue : _border));
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? _blue : active ? _blue.withAlpha(30) : _card,
            border: Border.all(color: done || active ? _blue : _border, width: 1.5),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text('${idx + 1}', style: TextStyle(color: active ? _blue : const Color(0xFF445566), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        );
      }),
    );
  }
}
