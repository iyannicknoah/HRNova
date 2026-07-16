import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_dropdown.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../models/company_settings_model.dart';
import '../providers/settings_provider.dart';
import '../widgets/deductions_editor.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../l10n/tr.dart';

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
  final _minHoursCtrl = TextEditingController(text: '0');
  final Set<String> _days = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  // Step 2 — Leave Policy
  final _annualCtrl = TextEditingController(text: '18');
  final _sickCtrl = TextEditingController(text: '10');

  // Step 3 — Payroll Rules
  final _payDayCtrl = TextEditingController(text: '28');
  String _overtime = '1.5x';
  final _lateCtrl = TextEditingController(text: '500');
  final _maxLateCtrl = TextEditingController(text: '3');

  // Step 4 — Payroll Deductions (pre-filled with standard RSSB, fully editable)
  List<DeductionRule> _deductions = List.of(DeductionRule.rssbDefaults);

  // Step 5 — Notifications & Contacts
  final _mgrPhone = TextEditingController(text: '+250');
  final _hrPhone = TextEditingController(text: '+250');
  final _mgrEmail = TextEditingController();
  final _hrEmail = TextEditingController();
  final _directorEmail = TextEditingController();
  final _directorPhone = TextEditingController();
  final _tinCtrl = TextEditingController();
  final String _notif = 'email';

  // Day abbreviation ↔ Firestore long-form mapping
  static const _toFirestore = {
    'Mon': 'monday', 'Tue': 'tuesday', 'Wed': 'wednesday',
    'Thu': 'thursday', 'Fri': 'friday', 'Sat': 'saturday', 'Sun': 'sunday',
  };

  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _graceCtrl.dispose(); _minHoursCtrl.dispose(); _annualCtrl.dispose(); _sickCtrl.dispose();
    _payDayCtrl.dispose(); _lateCtrl.dispose(); _maxLateCtrl.dispose();
    _mgrPhone.dispose(); _hrPhone.dispose();
    _mgrEmail.dispose(); _hrEmail.dispose();
    _directorEmail.dispose(); _directorPhone.dispose();
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
        data: (ctx.isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBlue,
            brightness: ctx.isDark ? Brightness.dark : Brightness.light,
            primary: AppColors.primaryBlue,
          ),
        ),
        child: child!,
      ),
    );
    if (t != null && mounted) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  /// Parses [ctrl]'s text for saving. An empty field means "use the
  /// default" (returns [fallback]); a non-empty field that fails to parse
  /// throws instead of silently falling back, so a typo is never saved as
  /// if it were the intended value.
  num _reqNum(TextEditingController ctrl, num fallback, {bool decimal = false}) {
    final t = ctrl.text.trim();
    if (t.isEmpty) return fallback;
    final v = decimal ? double.tryParse(t) : int.tryParse(t);
    if (v == null) throw Exception('"${ctrl.text}" is not a valid number.');
    return v;
  }

  Future<void> _next() async {
    if (_step == 3) {
      // Validate deductions before leaving the step
      if (_deductions.any((d) => d.title.trim().isEmpty) ||
          _deductions.any((d) => d.percent <= 0 || d.percent > 100)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('Every deduction needs a title and a rate between 0 and 100%.')),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    if (_step < _total - 1) {
      setState(() => _step++);
      return;
    }
    // Final step — save all to Firestore
    setState(() => _saving = true);
    debugPrint('[Onboarding] Completing setup, saving all settings...');
    try {
      final data = {
        'workStartTime': _fmtTime(_startTime),
        'workEndTime': _fmtTime(_endTime),
        'gracePeriodMinutes': _reqNum(_graceCtrl, 10),
        'minimumHoursBeforeCheckout': _reqNum(_minHoursCtrl, 0, decimal: true),
        'workingDays': _days.map((d) => _toFirestore[d]!).toList(),
        'annualLeaveDays': _reqNum(_annualCtrl, 18),
        'sickLeaveDays': _reqNum(_sickCtrl, 10),
        'salaryPaymentDay': _reqNum(_payDayCtrl, 28),
        'overtimeMultiplier': _parseMultiplier(_overtime),
        'lateDeductionPerHourRwf': _reqNum(_lateCtrl, 500),
        'maxLateBeforeWarning': _reqNum(_maxLateCtrl, 3),
        'managerPhone': _mgrPhone.text.trim(),
        'hrAdminPhone': _hrPhone.text.trim(),
        'managerEmail': _mgrEmail.text.trim(),
        'hrAdminEmail': _hrEmail.text.trim(),
        'directorEmail': _directorEmail.text.trim(),
        'directorPhone': _directorPhone.text.trim(),
        'notificationMethod': _notif,
        'rraTinNumber': _tinCtrl.text.trim(),
        'deductions': _deductions.map((d) => d.toMap()).toList(),
        'isOnboardingComplete': true,
      };
      await ref.read(settingsNotifierProvider.notifier).updateSettings(data);
      debugPrint('[Onboarding] Setup saved successfully, navigating to dashboard.');
      // Local override so router lets us through before stream refreshes
      ref.read(onboardingCompleteOverrideProvider.notifier).state = true;
      if (mounted) context.go('/dashboard');
    } catch (e) {
      debugPrint('[Onboarding] Setup save FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
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

  List<String> _stepTitles(BuildContext context) => [
    context.tr('Work Schedule'), context.tr('Leave Policy'), context.tr('Payroll Rules'),
    context.tr('Payroll Deductions'), context.tr('Notifications & Contacts'),
  ];
  List<String> _stepSubs(BuildContext context) => [
    context.tr('Set your company work hours and working days'),
    context.tr('Define leave entitlements for your employees'),
    context.tr('Configure salary payment and deduction rules'),
    context.tr('Define the deductions applied on every payroll run — standard RSSB rates are pre-filled'),
    context.tr('Set up emergency contacts and notification preferences'),
  ];

  static const _blue = AppColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
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
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          context.isDark
              ? 'assets/icon/icon_dark.png'
              : 'assets/icon/icon_light.png',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(width: 10),
      Text('HRNovva', style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
    ],
  );

  Widget _formCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.appBorder)),
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.trp('Step {i} of {n}', {'i': '${_step + 1}', 'n': '$_total'}), style: const TextStyle(color: _blue, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(_stepTitles(context)[_step], style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(_stepSubs(context)[_step], style: TextStyle(color: context.appSubtext, fontSize: 15)),
        const SizedBox(height: 24),
        Divider(color: context.appBorder, height: 1),
        const SizedBox(height: 24),
        _buildStep(),
      ],
    ),
  );

  Widget _navButtons() => Row(
    children: [
      if (_step > 0) ...[
        HRNovaButton(
          label: context.tr('Back'),
          outlined: true,
          isFullWidth: false,
          textColor: context.appText,
          height: 52,
          onPressed: _saving ? null : _back,
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: HRNovaButton(
          label: _step == _total - 1 ? 'Complete Setup' : 'Continue',
          backgroundColor: _blue,
          isLoading: _saving,
          height: 52,
          onPressed: _saving ? null : _next,
        ),
      ),
    ],
  );

  Widget _buildStep() => switch (_step) {
    0 => _buildWorkSchedule(),
    1 => _buildLeavePolicy(),
    2 => _buildPayrollRules(),
    3 => _buildDeductions(),
    _ => _buildNotifications(),
  };

  // ── Step 4: Payroll Deductions ────────────────────────────────────────────
  Widget _buildDeductions() => DeductionsEditor(
    deductions: _deductions,
    onChanged: (rules) => setState(() => _deductions = rules),
  );

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
      _textField(context.tr('Grace Period'), _graceCtrl, hint: '10', suffix: 'minutes', type: TextInputType.number),
      const SizedBox(height: 20),
      _textField(context.tr('Minimum Hours Before Checkout'), _minHoursCtrl, hint: context.tr('0 = no minimum'), suffix: 'hours', type: TextInputType.number, allowDecimal: true),
      const SizedBox(height: 20),
      Text(context.tr('Working Days'), style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w400)),
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
                color: sel ? _blue.withAlpha(25) : context.appField,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _blue : context.appBorder, width: sel ? 1.5 : 1),
              ),
              child: Text(d, style: TextStyle(color: sel ? _blue : context.appSubtext, fontSize: 15, fontWeight: sel ? FontWeight.w500 : FontWeight.w400)),
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
        Expanded(child: _textField(context.tr('Annual Leave'), _annualCtrl, hint: '18', suffix: 'days', type: TextInputType.number)),
        const SizedBox(width: 16),
        Expanded(child: _textField(context.tr('Sick Leave'), _sickCtrl, hint: '10', suffix: 'days', type: TextInputType.number)),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _blue.withAlpha(18), borderRadius: BorderRadius.circular(12), border: Border.all(color: _blue.withAlpha(60))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon(AppIcons.infoOutlineRounded, color: _blue, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Statutory Leave — Fixed by Rwanda Law'), style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(context.tr('Maternity: 84 days  •  Paternity: 4 days\nThese are mandatory and cannot be configured.'),
                    style: TextStyle(color: context.appSubtext, fontSize: 14, height: 1.5)),
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
        Expanded(child: _textField(context.tr('Salary Payment Day'), _payDayCtrl, hint: '28', suffix: 'of month', type: TextInputType.number)),
        const SizedBox(width: 16),
        Expanded(child: HRNovaDropdown<String>(
          label: context.tr('Overtime Multiplier'),
          value: _overtime,
          items: ['1x', '1.5x', '2x'].map((v) => DropdownMenuItem(
            value: v,
            child: Text(v),
          )).toList(),
          onChanged: (v) => setState(() => _overtime = v!),
        )),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _textField(context.tr('Late Deduction / Hour'), _lateCtrl, hint: '500', suffix: 'RWF', type: TextInputType.number)),
        const SizedBox(width: 16),
        Expanded(child: _textField(context.tr('Max Late Before Warning'), _maxLateCtrl, hint: '3', suffix: 'times', type: TextInputType.number)),
      ]),
    ],
  );

  // ── Step 4: Notifications & Contacts ─────────────────────────────────────
  Widget _buildNotifications() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.tr('Emergency Contacts'), style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      _textField(context.tr('Manager WhatsApp'), _mgrPhone, hint: '+250 788 000 000'),
      const SizedBox(height: 14),
      _textField(context.tr('HR Admin WhatsApp'), _hrPhone, hint: '+250 788 000 001'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _textField(context.tr('Manager Email'), _mgrEmail, hint: context.tr('manager@company.com'), type: TextInputType.emailAddress)),
        const SizedBox(width: 16),
        Expanded(child: _textField(context.tr('HR Admin Email'), _hrEmail, hint: context.tr('hr@company.com'), type: TextInputType.emailAddress)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _textField(context.tr('Director Email'), _directorEmail, hint: context.tr('director@company.rw'), type: TextInputType.emailAddress)),
        const SizedBox(width: 16),
        Expanded(child: _textField(context.tr('Director Phone'), _directorPhone, hint: '+250 7XX XXX XXX')),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _blue.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _blue.withAlpha(60))),
        child: Row(children: [
          AppIcon(AppIcons.infoOutlineRounded, color: _blue, size: 14),
          SizedBox(width: 8),
          Expanded(child: Text(context.tr('Director receives weekly and monthly HR reports automatically.'), style: TextStyle(color: _blue, fontSize: 13))),
        ]),
      ),
      const SizedBox(height: 24),
      Divider(color: context.appBorder, height: 1),
      const SizedBox(height: 20),
      Text(context.tr('Notification Method'), style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _blue.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _blue.withAlpha(60))),
        child: Row(
          children: [
            const AppIcon(AppIcons.emailOutlined, color: _blue, size: 16),
            const SizedBox(width: 8),
            Text(context.tr('Email only'), style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(context.tr('WhatsApp coming in Phase 2'), style: TextStyle(color: context.appSubtext, fontSize: 13)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Divider(color: context.appBorder, height: 1),
      const SizedBox(height: 20),
      _textField(context.tr('RRA TIN Number'), _tinCtrl, hint: context.tr('102XXXXXXXXX (for RRA payroll export)')),
    ],
  );

  // ── Shared field widgets ──────────────────────────────────────────────────
  Widget _textField(String label, TextEditingController ctrl, {String? hint, String? suffix, TextInputType? type, bool allowDecimal = false}) =>
      HRNovaTextField(
        label: label,
        controller: ctrl,
        keyboardType: type,
        inputFormatters: type == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(allowDecimal ? r'[\d.]' : r'\d'))]
            : null,
        hint: hint,
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(suffix, style: TextStyle(color: context.appSubtext, fontSize: 15)),
                ),
              ),
      );

  Widget _timeField(String label, TimeOfDay t, VoidCallback onTap) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w400)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: context.appField, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.appBorder)),
              child: Row(
                children: [
                  AppIcon(AppIcons.accessTimeRounded, color: context.appSubtext, size: 18),
                  const SizedBox(width: 10),
                  Text(_fmtTime(t), style: TextStyle(color: context.appText, fontSize: 15)),
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

  static const _blue = AppColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 2, color: i ~/ 2 < current ? _blue : context.appBorder));
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? _blue : active ? _blue.withAlpha(30) : context.appCard,
            border: Border.all(color: done || active ? _blue : context.appBorder, width: 1.5),
          ),
          child: Center(
            child: done
                ? const AppIcon(AppIcons.checkRounded, color: Colors.white, size: 16)
                : Text('${idx + 1}', style: TextStyle(color: active ? _blue : context.appSubtext, fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        );
      }),
    );
  }
}
