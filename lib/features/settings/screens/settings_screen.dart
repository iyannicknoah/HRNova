import 'dart:async';
import '../../../shared/widgets/language_switcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_dropdown.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/company_settings_model.dart';
import '../providers/settings_provider.dart';
import '../widgets/deductions_editor.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../l10n/tr.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hydrationStarted = false;
  bool _saving = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _hydrationSub;

  @override
  void initState() {
    super.initState();
    _maybeStartHydration();
  }

  /// Starts form hydration exactly once, as soon as the companyId claim is
  /// available. Deliberately NOT triggered from a `ref.listen` on
  /// `companySettingsProvider`: that provider is watched by half the app
  /// (dashboard, attendance, payroll, ...), so it is usually already alive
  /// with data before this screen mounts — meaning a listen callback would
  /// never fire and the form would silently stay on its built-in defaults.
  /// That was the root cause of the "settings look unsaved / revert to 0"
  /// bug: the save always worked, the form just never loaded the saved
  /// values back.
  void _maybeStartHydration() {
    if (_hydrationStarted) return;
    final companyId = ref.read(currentCompanyIdProvider);
    if (companyId == null) return; // claims not loaded yet — retried in build
    _hydrationStarted = true;
    _hydrateFromServer(companyId);
  }

  // Expansion state (visual grouping only — one Save button for everything)
  final Map<String, bool> _expanded = {
    'schedule': true, 'leave': false, 'payroll': false, 'deductions': false,
    'notifications': false, 'performance': false,
  };

  // Company-defined payroll deductions
  List<DeductionRule> _deductions = List.of(DeductionRule.rssbDefaults);

  // Performance criteria
  List<PerformanceCriterion> _criteria = PerformanceCriterion.defaults;

  // Work Schedule
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime   = const TimeOfDay(hour: 17, minute: 0);
  final _graceCtrl     = TextEditingController(text: '10');
  final _minHoursCtrl  = TextEditingController(text: '0');
  Set<String> _days    = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};

  // Leave
  final _annualCtrl = TextEditingController(text: '18');
  final _sickCtrl   = TextEditingController(text: '10');

  // Payroll
  final _payDayCtrl  = TextEditingController(text: '28');
  String _overtime   = '1.5x';
  final _lateCtrl    = TextEditingController(text: '500');
  final _maxLateCtrl = TextEditingController(text: '3');
  bool _deductAbsent = false;

  // Notifications
  final _mgrPhone       = TextEditingController();
  final _hrPhone        = TextEditingController();
  final _mgrEmail       = TextEditingController();
  final _hrEmail        = TextEditingController();
  final _directorEmail  = TextEditingController();
  final _directorPhone  = TextEditingController();
  final _tinCtrl        = TextEditingController();
  final String _notif   = 'email';

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
    _hydrationSub?.cancel();
    _graceCtrl.dispose(); _minHoursCtrl.dispose(); _annualCtrl.dispose(); _sickCtrl.dispose();
    _payDayCtrl.dispose(); _lateCtrl.dispose(); _maxLateCtrl.dispose();
    _mgrPhone.dispose(); _hrPhone.dispose();
    _mgrEmail.dispose(); _hrEmail.dispose();
    _directorEmail.dispose(); _directorPhone.dispose();
    _tinCtrl.dispose();
    super.dispose();
  }

  void _populate(CompanySettingsModel s) {
    _startTime = _parseTime(s.workStartTime);
    _endTime   = _parseTime(s.workEndTime);
    _graceCtrl.text  = s.gracePeriodMinutes.toString();
    _minHoursCtrl.text = s.minimumHoursBeforeCheckout == 0
        ? '0'
        : (s.minimumHoursBeforeCheckout % 1 == 0
            ? s.minimumHoursBeforeCheckout.toStringAsFixed(0)
            : s.minimumHoursBeforeCheckout.toString());
    _days = s.workingDays.map((d) => _longToShort[d] ?? d).toSet();
    _annualCtrl.text = s.annualLeaveDays.toString();
    _sickCtrl.text   = s.sickLeaveDays.toString();
    _payDayCtrl.text = s.salaryPaymentDay.toString();
    _overtime = switch (s.overtimeMultiplier) {
      1.0 => '1x', 2.0 => '2x', _ => '1.5x',
    };
    _lateCtrl.text    = s.lateDeductionPerHourRwf.toString();
    _maxLateCtrl.text = s.maxLateBeforeWarning.toString();
    _deductAbsent     = s.deductAbsentDays;
    _mgrPhone.text        = s.managerPhone.isEmpty ? '+250' : s.managerPhone;
    _hrPhone.text         = s.hrAdminPhone.isEmpty ? '+250' : s.hrAdminPhone;
    _mgrEmail.text        = s.managerEmail;
    _hrEmail.text         = s.hrAdminEmail;
    _directorEmail.text   = s.directorEmail;
    _directorPhone.text   = s.directorPhone;
    _tinCtrl.text         = s.rraTinNumber ?? '';
    _criteria = s.performanceCriteria.isEmpty
        ? PerformanceCriterion.defaults
        : s.performanceCriteria;
    _deductions = List.of(s.deductions);
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return TimeOfDay(hour: h ?? 8, minute: m ?? 0);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (t != null && mounted) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  /// Populates the form once from the first snapshot confirmed by the
  /// server (`!metadata.isFromCache`), not just whatever the live
  /// `companySettingsProvider` stream happens to emit first. A locally
  /// cached snapshot can be stale — harmless for live display, but wrong
  /// to lock a one-shot form hydration onto, since it can make a
  /// just-saved value appear to have reverted when navigating back to
  /// this screen. Uses the same `.snapshots()` API the rest of the app
  /// already relies on everywhere (unlike `GetOptions(source: server)`,
  /// which has inconsistent support across platforms, notably web).
  void _hydrateFromServer(String companyId) {
    debugPrint('[Settings] Hydrating form for companies/$companyId/settings/config...');
    _hydrationSub = FirebaseService.settingsRef(companyId)
        .snapshots(includeMetadataChanges: true)
        .listen((doc) {
      if (doc.metadata.isFromCache) {
        debugPrint('[Settings] Ignoring cached snapshot, waiting for server-confirmed one.');
        return;
      }
      _hydrationSub?.cancel();
      if (!mounted) return;
      try {
        if (doc.exists && doc.data() != null) {
          debugPrint('[Settings] Server-confirmed data received, populating form: ${doc.data()}');
          setState(() => _populate(CompanySettingsModel.fromMap(companyId, doc.data()!)));
        } else {
          debugPrint('[Settings] No settings doc exists yet for companies/$companyId/settings/config — leaving form defaults.');
        }
      } catch (e) {
        debugPrint('[Settings] Failed to parse/populate settings doc: $e');
      }
    }, onError: (e) => debugPrint('[Settings] Hydration stream error: $e'));
  }

  /// Parses [ctrl]'s text for saving. An empty field means "use the
  /// default" (returns [fallback]); a non-empty field that fails to parse
  /// throws instead of silently falling back, so invalid input is never
  /// saved as if it were the default.
  num _reqNum(TextEditingController ctrl, num fallback, {bool decimal = false}) {
    final t = ctrl.text.trim();
    if (t.isEmpty) return fallback;
    final v = decimal ? double.tryParse(t) : int.tryParse(t);
    if (v == null) throw Exception('"${ctrl.text}" is not a valid number.');
    return v;
  }

  double _parseMultiplier(String val) => switch (val) {
    '1x' => 1.0, '2x' => 2.0, _ => 1.5,
  };

  Future<void> _save() async {
    final Map<String, dynamic> data;
    try {
      if (_criteria.isEmpty) {
        throw Exception(context.tr('Add at least one performance criterion.'));
      }
      final totalWeight = _criteria.fold<double>(0, (s, c) => s + c.weight);
      if ((totalWeight - 100).abs() > 0.5) {
        throw Exception(context.trp('Performance criteria weights must total 100% (currently {w}%).', {'w': totalWeight.toStringAsFixed(0)}));
      }
      if (_deductions.any((d) => d.title.trim().isEmpty)) {
        throw Exception(context.tr('Every deduction needs a title.'));
      }
      if (_deductions.any((d) => d.percent <= 0 || d.percent > 100)) {
        throw Exception(context.tr('Deduction rates must be between 0 and 100%.'));
      }
      data = {
        'workStartTime': _fmtTime(_startTime),
        'workEndTime': _fmtTime(_endTime),
        'gracePeriodMinutes': _reqNum(_graceCtrl, 10),
        'minimumHoursBeforeCheckout': _reqNum(_minHoursCtrl, 0, decimal: true),
        'workingDays': _days.map((d) => _shortToLong[d] ?? d.toLowerCase()).toList(),
        'annualLeaveDays': _reqNum(_annualCtrl, 18),
        'sickLeaveDays': _reqNum(_sickCtrl, 10),
        'salaryPaymentDay': _reqNum(_payDayCtrl, 28),
        'overtimeMultiplier': _parseMultiplier(_overtime),
        'lateDeductionPerHourRwf': _reqNum(_lateCtrl, 500),
        'maxLateBeforeWarning': _reqNum(_maxLateCtrl, 3),
        'deductAbsentDays': _deductAbsent,
        'managerPhone': _mgrPhone.text.trim(),
        'hrAdminPhone': _hrPhone.text.trim(),
        'managerEmail': _mgrEmail.text.trim(),
        'hrAdminEmail': _hrEmail.text.trim(),
        'directorEmail': _directorEmail.text.trim(),
        'directorPhone': _directorPhone.text.trim(),
        'notificationMethod': _notif,
        'rraTinNumber': _tinCtrl.text.trim(),
        'performanceCriteria': _criteria.map((c) => c.toMap()).toList(),
        'deductions': _deductions.map((d) => d.toMap()).toList(),
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(settingsNotifierProvider.notifier).updateSettings(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('Settings saved successfully')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successGreen,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);
    final role     = ref.watch(currentUserRoleProvider);
    final canEdit  = role != AppConstants.roleBranchHrAdmin;

    // Retry in case the companyId claim wasn't loaded yet at initState —
    // guarded by _hydrationStarted, so this runs at most once.
    _maybeStartHydration();

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
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('Settings'), style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text(context.tr('Configure your company preferences'), style: TextStyle(color: context.appSubtext, fontSize: 15)),
                ]),
                const Spacer(),
                const LanguageSwitcher(size: 36),
              ]),
              if (!canEdit) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.pillAmberBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const AppIcon(AppIcons.lockOutlineRounded, color: AppColors.warningAmber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      context.tr('Settings can only be changed by the company HR Admin. Contact them to update policies.'),
                      style: TextStyle(color: context.appSubtext, fontSize: 14),
                    )),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              _section('schedule', AppIcons.scheduleRounded, context.tr('Work Schedule'), context.tr('Work hours, grace period and working days'), _scheduleBody()),
              const SizedBox(height: 14),
              _section('leave', AppIcons.beachAccessRounded, context.tr('Leave Policy'), context.tr('Annual and sick leave entitlements'), _leaveBody()),
              const SizedBox(height: 14),
              _section('payroll', AppIcons.accountBalanceWalletRounded, context.tr('Payroll Rules'), context.tr('Salary payment day, overtime and late deduction'), _payrollBody()),
              const SizedBox(height: 14),
              _section('deductions', AppIcons.healthAndSafetyRounded, context.tr('Payroll Deductions'), context.tr('Company-defined deductions applied on every payroll run'), _deductionsBody()),
              const SizedBox(height: 14),
              _section('notifications', AppIcons.notificationsRounded, context.tr('Notifications & Contacts'), context.tr('Emergency contacts and notification preferences'), _notificationsBody()),
              const SizedBox(height: 14),
              _section('performance', AppIcons.trendingUpRounded, context.tr('Performance Criteria'), context.tr('Weighted criteria used for performance reviews'), _performanceBody()),
              const SizedBox(height: 28),
              if (canEdit)
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 220,
                    child: HRNovaButton(
                      label: _saving ? 'Saving...' : 'Save Changes',
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String key, IconRef icon, String title, String subtitle, Widget body) {
    final expanded = _expanded[key] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded[key] = !expanded),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: context.pillBlueBg, borderRadius: BorderRadius.circular(10)),
                child: AppIcon(icon, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: context.appSubtext, fontSize: 14)),
              ])),
              AppIcon(expanded ? AppIcons.keyboardArrowUpRounded : AppIcons.keyboardArrowDownRounded, color: context.appSubtext, size: 22),
            ]),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: body,
          ),
      ]),
    );
  }

  Widget _scheduleBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _timeField('Work Start', _startTime, () => _pickTime(true))),
      const SizedBox(width: 16),
      Expanded(child: _timeField('Work End', _endTime, () => _pickTime(false))),
    ]),
    const SizedBox(height: 16),
    _field(context.tr('Grace Period'), _graceCtrl, hint: '10', suffix: 'minutes', type: TextInputType.number),
    const SizedBox(height: 16),
    _field(context.tr('Minimum Hours Before Checkout'), _minHoursCtrl, hint: context.tr('0 = no minimum'), suffix: 'hours', type: TextInputType.number, allowDecimal: true),
    const SizedBox(height: 16),
    Text(context.tr('Working Days'), style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w400)),
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
          child: Text(d, style: TextStyle(color: sel ? AppColors.primaryBlue : context.appSubtext, fontSize: 15, fontWeight: sel ? FontWeight.w500 : FontWeight.w400)),
        ),
      );
    }).toList()),
  ]);

  Widget _leaveBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _field(context.tr('Annual Leave Days'), _annualCtrl, hint: '18', suffix: 'days', type: TextInputType.number)),
      const SizedBox(width: 16),
      Expanded(child: _field(context.tr('Sick Leave Days'), _sickCtrl, hint: '10', suffix: 'days', type: TextInputType.number)),
    ]),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.pillBlueBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primaryBlue.withAlpha(60))),
      child: Row(children: [
        AppIcon(AppIcons.infoOutlineRounded, color: AppColors.primaryBlue, size: 16),
        SizedBox(width: 10),
        Expanded(child: Text(context.tr('Maternity: 84 days  •  Paternity: 4 days — Fixed by Rwanda Law'), style: TextStyle(color: AppColors.primaryBlue, fontSize: 14, height: 1.4))),
      ]),
    ),
  ]);

  Widget _payrollBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _field(context.tr('Salary Payment Day'), _payDayCtrl, hint: '28', suffix: 'of month', type: TextInputType.number)),
      const SizedBox(width: 16),
      Expanded(child: HRNovaDropdown<String>(
        label: context.tr('Overtime Multiplier'),
        value: _overtime,
        items: const ['1x', '1.5x', '2x'].map((v) => DropdownMenuItem(
          value: v,
          child: Text(v),
        )).toList(),
        onChanged: (v) => setState(() => _overtime = v!),
      )),
    ]),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _field(context.tr('Late Deduction / Hour'), _lateCtrl, hint: '500', suffix: 'RWF', type: TextInputType.number)),
      const SizedBox(width: 16),
      Expanded(child: _field(context.tr('Max Late Before Warning'), _maxLateCtrl, hint: '3', suffix: 'times', type: TextInputType.number)),
    ]),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: context.appBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Deduct salary for absent days'),
              style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(context.tr('When on, fixed-monthly employees lose one day\'s pay for each unexcused absent day'),
              style: TextStyle(color: context.appSubtext, fontSize: 13)),
        ])),
        Switch(
          value: _deductAbsent,
          activeThumbColor: AppColors.primaryBlue,
          onChanged: (v) => setState(() => _deductAbsent = v),
        ),
      ]),
    ),
  ]);

  Widget _deductionsBody() => DeductionsEditor(
    deductions: _deductions,
    onChanged: (rules) => setState(() => _deductions = rules),
  );

  Widget _notificationsBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: _field(context.tr('Manager WhatsApp'), _mgrPhone, hint: '+250 788 000 000')),
      const SizedBox(width: 16),
      Expanded(child: _field(context.tr('HR Admin WhatsApp'), _hrPhone, hint: '+250 788 000 001')),
    ]),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _field(context.tr('Manager Email'), _mgrEmail, hint: context.tr('manager@company.com'), type: TextInputType.emailAddress)),
      const SizedBox(width: 16),
      Expanded(child: _field(context.tr('HR Admin Email'), _hrEmail, hint: context.tr('hr@company.com'), type: TextInputType.emailAddress)),
    ]),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _field(context.tr('Director Email'), _directorEmail, hint: context.tr('director@company.rw'), type: TextInputType.emailAddress)),
      const SizedBox(width: 16),
      Expanded(child: _field(context.tr('Director Phone'), _directorPhone, hint: '+250 7XX XXX XXX')),
    ]),
    const SizedBox(height: 14),
    _field(context.tr('RRA TIN Number'), _tinCtrl, hint: context.tr('102XXXXXXXXX (for RRA payroll export)')),
  ]);

  Widget _performanceBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(context.tr('Weights must total 100%.'), style: TextStyle(color: context.appSubtext, fontSize: 14)),
    const SizedBox(height: 12),
    ..._criteria.asMap().entries.map((e) => _CriterionRow(
      criterion: e.value,
      appText: context.appText,
      appSubtext: context.appSubtext,
      onWeightChanged: (w) => setState(() => _criteria[e.key] = PerformanceCriterion(name: e.value.name, weight: w)),
      onRemove: () => setState(() => _criteria.removeAt(e.key)),
    )),
    const SizedBox(height: 8),
    _AddCriterionRow(onAdd: (name, weight) => setState(() => _criteria = [..._criteria, PerformanceCriterion(name: name, weight: weight)])),
  ]);

  Widget _field(String label, TextEditingController ctrl, {String? hint, String? suffix, TextInputType? type, bool allowDecimal = false}) =>
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
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w400)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: context.appField, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.appBorder)),
            child: Row(children: [
              AppIcon(AppIcons.accessTimeRounded, color: context.appSubtext, size: 18),
              const SizedBox(width: 10),
              Text(_fmtTime(t), style: TextStyle(color: context.appText, fontSize: 15)),
            ]),
          ),
        ),
      ]);
}

// ── Performance criterion row ─────────────────────────────────────────────────
class _CriterionRow extends StatefulWidget {
  const _CriterionRow({
    required this.criterion,
    required this.appText,
    required this.appSubtext,
    required this.onWeightChanged,
    required this.onRemove,
  });
  final PerformanceCriterion criterion;
  final Color appText, appSubtext;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onRemove;

  @override
  State<_CriterionRow> createState() => _CriterionRowState();
}

class _CriterionRowState extends State<_CriterionRow> {
  late final _ctrl = TextEditingController(text: widget.criterion.weight.toStringAsFixed(0));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(flex: 5, child: Text(widget.criterion.name, style: TextStyle(color: widget.appText, fontSize: 15))),
        Expanded(flex: 2, child: HRNovaTextField(
          label: context.tr('Weight'),
          controller: _ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text('%', style: TextStyle(color: widget.appSubtext, fontSize: 15)),
            ),
          ),
          onChanged: (v) {
            final w = double.tryParse(v);
            if (w != null) widget.onWeightChanged(w);
          },
        )),
        const SizedBox(width: 8),
        IconButton(
          onPressed: widget.onRemove,
          icon: const AppIcon(AppIcons.removeCircleOutlineRounded, size: 20, color: AppColors.errorRed),
          tooltip: context.tr('Remove'),
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
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(flex: 5, child: HRNovaTextField(
        label: context.tr('Criterion Name'),
        controller: _nameCtrl,
        hint: context.tr('New criterion name...'),
      )),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: HRNovaTextField(
        label: context.tr('Weight'),
        controller: _weightCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
        hint: context.tr('Weight%'),
      )),
      const SizedBox(width: 8),
      HRNovaButton(
        label: context.tr('Add'),
        icon: AppIcons.addRounded,
        isFullWidth: false,
        onPressed: _add,
      ),
    ]);
  }
}
