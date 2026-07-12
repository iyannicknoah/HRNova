import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/models/branch_model.dart';
import '../../branches/providers/branches_provider.dart';
import '../../employees/models/employee_model.dart';
import '../../employees/providers/employees_provider.dart';
import '../../settings/models/company_settings_model.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/performance_model.dart';
import '../providers/performance_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/month_nav.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _branchFilter;
  final _autoScoredMonths = <String>{};

  String get _monthStr => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _triggerAutoScores(
    List<EmployeeModel> employees,
    List<AttendanceModel> allAttendance,
    List<PerformanceModel> existingScores,
    List<PerformanceCriterion> criteria,
  ) async {
    if (!mounted) return;
    const autoKey = 'Attendance and Punctuality';
    final scoreMap = {for (final s in existingScores) s.employeeId: s};
    final byEmployee = <String, List<AttendanceModel>>{};
    for (final a in allAttendance) {
      (byEmployee[a.employeeId] ??= []).add(a);
    }
    for (final e in employees.where((emp) => emp.isActive)) {
      if (scoreMap[e.id]?.systemScoredKeys.contains(autoKey) == true) continue;
      final empRecords = byEmployee[e.id] ?? [];
      if (empRecords.isEmpty) continue;
      try {
        await ref.read(performanceNotifierProvider.notifier).autoScoreAttendance(
          employee: e,
          month: _monthStr,
          records: empRecords,
          criteria: criteria,
          existingScoreMap: scoreMap,
        );
      } catch (_) {}
    }
  }

  void _prevMonth() => setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      });

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _selectedMonth = next);
  }

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(userClaimsProvider);
    final role = claimsAsync.value?['role'] as String? ?? '';
    final companyType = ref.watch(companyTypeProvider).valueOrNull ?? AppConstants.companySingle;
    final isMultiBranch = companyType == AppConstants.companyMultiBranch;
    final isTopHr = role == AppConstants.roleHrAdmin || role == AppConstants.roleGroupHrAdmin;
    final showBranchFilter = isTopHr && isMultiBranch && role != 'manager';
    final branches = showBranchFilter
        ? (ref.watch(branchesStreamProvider).valueOrNull ?? <BranchModel>[])
        : <BranchModel>[];

    // ── Auto-score trigger: fire once per month when all data is ready ──────────
    if (!_autoScoredMonths.contains(_monthStr)) {
      final employees      = ref.watch(employeesProvider).valueOrNull;
      final attendance     = ref.watch(attendanceByMonthProvider(
        (year: _selectedMonth.year, month: _selectedMonth.month),
      )).valueOrNull;
      final existingScores = ref.watch(performanceByMonthProvider(_monthStr)).valueOrNull;
      final criteria       = ref.watch(companySettingsProvider).valueOrNull
              ?.performanceCriteria ?? PerformanceCriterion.defaults;
      if (employees != null && attendance != null && existingScores != null) {
        _autoScoredMonths.add(_monthStr);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerAutoScores(employees, attendance, existingScores, criteria);
        });
      }
    }

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Performance Management',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('Track and evaluate employee performance',
                      style: TextStyle(color: context.appSubtext, fontSize: 15)),
                ]),
                const Spacer(),
                // Branch filter (top HR only, multi-branch)
                if (showBranchFilter && branches.isNotEmpty) ...[
                  _BranchFilterDrop(
                    value: _branchFilter,
                    branches: branches,
                    onChanged: (v) => setState(() => _branchFilter = v),
                  ),
                  const SizedBox(width: 12),
                ],
                // Month picker
                _MonthPicker(
                  month: _selectedMonth,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: role == 'manager'
                ? _ManagerScoringView(month: _monthStr)
                : _HRDashboardView(month: _monthStr, branchFilter: _branchFilter),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Month Picker
// ─────────────────────────────────────────────────────────────────────────────
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    return MonthNav(
      label: DateFormat('MMMM yyyy').format(month),
      onPrev: onPrev,
      onNext: isCurrentMonth ? null : onNext,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Branch Filter Dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _BranchFilterDrop extends StatelessWidget {
  const _BranchFilterDrop({required this.value, required this.branches, required this.onChanged});
  final String? value;
  final List<BranchModel> branches;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value ?? 'all';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value != null ? AppColors.primaryBlue : context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          dropdownColor: context.appCard,
          style: TextStyle(color: context.appText, fontSize: 14),
          icon: AppIcon(AppIcons.keyboardArrowDownRounded, size: 14, color: context.appSubtext),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text('All Branches', style: TextStyle(color: context.appText, fontSize: 14)),
            ),
            ...branches.map((b) => DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name, style: TextStyle(color: context.appText, fontSize: 14)),
                )),
          ],
          onChanged: (v) => onChanged(v == 'all' ? null : v),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Manager Scoring View
// ─────────────────────────────────────────────────────────────────────────────
class _ManagerScoringView extends ConsumerStatefulWidget {
  const _ManagerScoringView({required this.month});
  final String month;

  @override
  ConsumerState<_ManagerScoringView> createState() =>
      _ManagerScoringViewState();
}

class _ManagerScoringViewState extends ConsumerState<_ManagerScoringView> {
  EmployeeModel? _selected;
  Map<String, double> _scores = {};
  final _notesCtrl = TextEditingController();
  String? _aiReview;
  bool _generatingAi = false;
  bool _saving = false;
  List<String> _currentSystemScoredKeys = [];

  // Cached for "Score Next" access after save
  List<EmployeeModel> _cachedEmployees = [];
  Map<String, PerformanceModel> _cachedScoreMap = {};
  List<PerformanceCriterion> _cachedCriteria = PerformanceCriterion.defaults;

  static const _labels = {
    1: 'Poor', 2: 'Below Average', 3: 'Average', 4: 'Good', 5: 'Excellent'
  };

  // True if the employee has at least one manually-scored criterion
  static bool _isManuallyScored(PerformanceModel? ex) {
    if (ex == null) return false;
    const autoKey = 'Attendance and Punctuality';
    return ex.scores.keys.any((k) => k != autoKey);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _selectEmployee(EmployeeModel e, PerformanceModel? existing,
      List<PerformanceCriterion> criteria) {
    setState(() {
      _selected = e;
      _aiReview = existing?.aiReview;
      _notesCtrl.text = existing?.managerNotes ?? '';
      _currentSystemScoredKeys = existing?.systemScoredKeys ?? [];
      _scores = {};
      if (existing != null) {
        _scores = Map.from(existing.scores);
        // Ensure all criteria have a value (in case new criteria were added)
        for (final c in criteria) {
          _scores.putIfAbsent(c.name, () => 3.0);
        }
      } else {
        for (final c in criteria) {
          _scores[c.name] = 3.0;
        }
      }
    });
  }

  void _selectNextUnscored() {
    final unscored = _cachedEmployees
        .where((e) => e.isActive && !_isManuallyScored(_cachedScoreMap[e.id]))
        .toList();
    if (unscored.isNotEmpty) {
      _selectEmployee(unscored.first, _cachedScoreMap[unscored.first.id], _cachedCriteria);
    } else {
      setState(() => _selected = null);
    }
  }

  double _computeOverall(List<PerformanceCriterion> criteria) {
    return PerformanceModel.computeOverall(_scores, criteria);
  }

  Future<void> _generateAiReview(
      EmployeeModel e, List<PerformanceCriterion> criteria) async {
    setState(() => _generatingAi = true);
    try {
      final overall = _computeOverall(criteria);
      final review = await ref
          .read(performanceNotifierProvider.notifier)
          .generateReview(
            employeeName: e.fullName,
            jobTitle: e.jobTitle,
            criteria: criteria.map((c) => c.toMap()).toList(),
            scores: _scores,
            overallScore: overall,
          );
      if (mounted) setState(() => _aiReview = review);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI error: $err'),
          backgroundColor: AppColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Future<void> _save(EmployeeModel e, List<PerformanceCriterion> criteria,
      {bool scoreNext = false}) async {
    setState(() => _saving = true);
    try {
      final overall = _computeOverall(criteria);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final model = PerformanceModel(
        id: PerformanceModel.docId(e.id, widget.month),
        employeeId: e.id,
        employeeName: e.fullName,
        department: e.department,
        branchId: e.branchId,
        month: widget.month,
        scores: Map.from(_scores),
        overallScore: overall,
        aiReview: _aiReview,
        managerNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scoredBy: uid,
        scoredAt: DateTime.now(),
        systemScoredKeys: _currentSystemScoredKeys,
      );
      await ref.read(performanceNotifierProvider.notifier).saveScore(model);
      if (mounted) {
        if (scoreNext) {
          _selectNextUnscored();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saved — loading next employee'),
            backgroundColor: AppColors.primaryBlue,
            duration: Duration(seconds: 1),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Score saved successfully'),
            backgroundColor: AppColors.successGreen,
          ));
        }
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $err'),
          backgroundColor: AppColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final scoresAsync = ref.watch(performanceByMonthProvider(widget.month));
    final settingsAsync = ref.watch(companySettingsProvider);
    final criteria = settingsAsync.value?.performanceCriteria ??
        PerformanceCriterion.defaults;

    final allEmployees = (employeesAsync.value ?? []).where((e) => e.isActive).toList();
    final scores = scoresAsync.value ?? [];
    final scoreMap = {for (final s in scores) s.employeeId: s};

    // Cache for Score Next
    _cachedEmployees = allEmployees;
    _cachedScoreMap = scoreMap;
    _cachedCriteria = criteria;

    final totalCount   = allEmployees.length;
    // "scored" means manager has scored at least one non-auto criterion
    final scoredCount  = allEmployees.where((e) => _isManuallyScored(scoreMap[e.id])).length;
    final unscoredCount = totalCount - scoredCount;
    final allScored    = totalCount > 0 && scoredCount == totalCount;

    // Reminder banner: 25th+ of current scored month, with unscored employees
    final now = DateTime.now();
    final monthDt = DateTime.parse('${widget.month}-01');
    final isCurrentMonth = now.year == monthDt.year && now.month == monthDt.month;
    final showReminder = isCurrentMonth && now.day >= 25 && unscoredCount > 0;

    // Group by department
    final grouped = <String, List<EmployeeModel>>{};
    for (final e in allEmployees) {
      final dept = e.department.isEmpty ? 'Unassigned' : e.department;
      (grouped[dept] ??= []).add(e);
    }
    final sortedDepts = grouped.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Employee list panel ───────────────────────────────────────────
          Expanded(
            child: Column(children: [
              // Progress banner
              if (totalCount > 0) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: allScored
                        ? AppColors.successGreen.withAlpha(20)
                        : context.appCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: allScored
                          ? AppColors.successGreen.withAlpha(60)
                          : context.appBorder,
                    ),
                  ),
                  child: Row(children: [
                    AppIcon(
                      allScored ? AppIcons.celebrationRounded : AppIcons.assignmentTurnedInOutlined,
                      color: allScored ? AppColors.successGreen : AppColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        allScored
                            ? 'All $totalCount employees scored for ${DateFormat('MMMM').format(monthDt)}! 🎉'
                            : 'You have scored $scoredCount of $totalCount employees for ${DateFormat('MMMM yyyy').format(monthDt)}',
                        style: TextStyle(
                          color: allScored ? AppColors.successGreen : context.appText,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (!allScored)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '$unscoredCount remaining',
                          style: const TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ]),
                ),
              ],
              // Reminder banner (25th+)
              if (showReminder) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningAmber.withAlpha(60)),
                  ),
                  child: Row(children: [
                    const AppIcon(AppIcons.warningAmberRounded, color: AppColors.warningAmber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Month-end reminder: $unscoredCount employee${unscoredCount == 1 ? "" : "s"} still need${unscoredCount == 1 ? "s" : ""} to be scored',
                        style: const TextStyle(color: AppColors.warningAmber, fontSize: 13, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ]),
                ),
              ],
              // Employee list card
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: context.cardDeco(),
                  child: employeesAsync.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                      : allEmployees.isEmpty
                          ? Center(child: Text('No employees found', style: TextStyle(color: context.appSubtext)))
                          : ListView(
                              children: [
                                for (final dept in sortedDepts) ...[
                                  _DeptSectionHeader(
                                    dept: dept,
                                    total: grouped[dept]!.length,
                                    scored: grouped[dept]!.where((e) => _isManuallyScored(scoreMap[e.id])).length,
                                    isFirst: dept == sortedDepts.first,
                                  ),
                                  ...grouped[dept]!.map((e) {
                                    final existing = scoreMap[e.id];
                                    final isSelected = _selected?.id == e.id;
                                    final isManual = _isManuallyScored(existing);
                                    final isAutoOnly = existing != null && !isManual;
                                    final badgeColor = isManual
                                        ? AppColors.successGreen
                                        : isAutoOnly
                                            ? AppColors.primaryBlue
                                            : AppColors.warningAmber;
                                    final badgeLabel = isManual
                                        ? 'Scored'
                                        : isAutoOnly
                                            ? 'Auto Only'
                                            : 'Not Scored';
                                    return InkWell(
                                      onTap: () => _selectEmployee(e, existing, criteria),
                                      hoverColor: context.appBorder.withAlpha(40),
                                      child: Container(
                                        color: isSelected ? AppColors.primaryBlue.withAlpha(12) : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                        child: Row(children: [
                                          _SmallAvatar(name: e.fullName, photoUrl: e.profilePhotoUrl),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(e.fullName,
                                                    style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis),
                                                if (e.jobTitle.isNotEmpty)
                                                  Text(e.jobTitle,
                                                      style: TextStyle(color: context.appSubtext, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (existing != null)
                                            _ScoreStars(existing.overallScore)
                                          else
                                            const SizedBox(width: 80),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withAlpha(20),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              badgeLabel,
                                              style: TextStyle(
                                                color: badgeColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    );
                                  }),
                                  Divider(height: 1, color: context.appBorder),
                                ],
                              ],
                            ),
                ),
              ),
            ]),
          ),
          // ── Score panel (animated slide-in) ───────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            width: _selected != null ? 500 : 0,
            child: ClipRect(
              child: _selected == null
                  ? const SizedBox.shrink()
                  : _ScorePanel(
                      key: ValueKey(_selected!.id),
                      employee: _selected!,
                      criteria: criteria,
                      scores: _scores,
                      systemScoredKeys: _currentSystemScoredKeys,
                      aiReview: _aiReview,
                      generatingAi: _generatingAi,
                      saving: _saving,
                      notesCtrl: _notesCtrl,
                      labels: _labels,
                      hasNext: allEmployees.where((e) =>
                          e.isActive &&
                          !_isManuallyScored(scoreMap[e.id]) &&
                          e.id != _selected!.id).isNotEmpty,
                      onScoreChanged: (name, val) {
                        if (_currentSystemScoredKeys.contains(name)) return;
                        setState(() => _scores[name] = val);
                      },
                      onGenerateAi: () =>
                          _generateAiReview(_selected!, criteria),
                      onAiTextChanged: (v) => setState(() => _aiReview = v),
                      onSave: () => _save(_selected!, criteria),
                      onSaveAndNext: () => _save(_selected!, criteria, scoreNext: true),
                      onClose: () => setState(() => _selected = null),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptSectionHeader extends StatelessWidget {
  const _DeptSectionHeader({required this.dept, required this.total, required this.scored, this.isFirst = false});
  final String dept;
  final int total, scored;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final allDone = scored == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.appTint,
        borderRadius: isFirst
            ? const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))
            : BorderRadius.zero,
      ),
      child: Row(children: [
        Text(
          dept,
          style: TextStyle(
            color: context.appSubtext,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: allDone ? AppColors.successGreen.withAlpha(20) : AppColors.primaryBlue.withAlpha(20),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$scored/$total',
            style: TextStyle(
              color: allDone ? AppColors.successGreen : AppColors.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Score Panel
// ─────────────────────────────────────────────────────────────────────────────
class _ScorePanel extends StatefulWidget {
  const _ScorePanel({
    super.key,
    required this.employee,
    required this.criteria,
    required this.scores,
    required this.systemScoredKeys,
    required this.aiReview,
    required this.generatingAi,
    required this.saving,
    required this.notesCtrl,
    required this.labels,
    required this.onScoreChanged,
    required this.onGenerateAi,
    required this.onAiTextChanged,
    required this.onSave,
    required this.onSaveAndNext,
    required this.onClose,
    this.hasNext = false,
  });

  final EmployeeModel employee;
  final List<PerformanceCriterion> criteria;
  final Map<String, double> scores;
  final List<String> systemScoredKeys;
  final String? aiReview;
  final bool generatingAi, saving, hasNext;
  final TextEditingController notesCtrl;
  final Map<int, String> labels;
  final void Function(String name, double val) onScoreChanged;
  final VoidCallback onGenerateAi, onSave, onSaveAndNext, onClose;
  final void Function(String) onAiTextChanged;

  @override
  State<_ScorePanel> createState() => _ScorePanelState();
}

class _ScorePanelState extends State<_ScorePanel> {
  late TextEditingController _aiCtrl;

  @override
  void initState() {
    super.initState();
    _aiCtrl = TextEditingController(text: widget.aiReview ?? '');
  }

  @override
  void didUpdateWidget(_ScorePanel old) {
    super.didUpdateWidget(old);
    if (widget.aiReview != old.aiReview && widget.aiReview != _aiCtrl.text) {
      _aiCtrl.text = widget.aiReview ?? '';
    }
  }

  @override
  void dispose() {
    _aiCtrl.dispose();
    super.dispose();
  }

  double get _overall =>
      PerformanceModel.computeOverall(widget.scores, widget.criteria);

  Color get _overallColor {
    if (_overall >= 4) return AppColors.successGreen;
    if (_overall >= 3) return AppColors.warningAmber;
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: context.cardDeco(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            _SmallAvatar(name: widget.employee.fullName, photoUrl: widget.employee.profilePhotoUrl, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.employee.fullName,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text(widget.employee.department,
                  style: TextStyle(color: context.appSubtext, fontSize: 14)),
            ])),
            // Overall score bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _overallColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _overallColor.withAlpha(80)),
              ),
              child: Column(children: [
                Text(_overall.toStringAsFixed(1),
                    style: TextStyle(
                        color: _overallColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1)),
                Text('/ 5', style: TextStyle(color: _overallColor, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.onClose,
              icon: AppIcon(AppIcons.closeRounded, color: context.appSubtext, size: 18),
            ),
          ]),
          const SizedBox(height: 20),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: 16),
          // Criteria sliders
          Text('Scoring Criteria',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...widget.criteria.map((c) {
            final score = widget.scores[c.name] ?? 3.0;
            final scoreInt = score.round().clamp(1, 5);
            final label = widget.labels[scoreInt] ?? 'Average';
            final contribution = score * c.weight / 100;
            Color sliderColor;
            if (score >= 4) {
              sliderColor = AppColors.successGreen;
            } else if (score >= 3) {
              sliderColor = AppColors.warningAmber;
            } else {
              sliderColor = AppColors.errorRed;
            }
            final isAuto = widget.systemScoredKeys.contains(c.name);
            if (isAuto) {
              return _AutoCriterionRow(
                criterion: c,
                score: score,
                label: label,
                contribution: contribution,
                sliderColor: sliderColor,
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(c.name,
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 14,
                            fontWeight: FontWeight.w400)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sliderColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: sliderColor, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 8),
                  Text('${contribution.toStringAsFixed(2)} pts',
                      style: TextStyle(color: context.appSubtext, fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: sliderColor,
                        inactiveTrackColor: context.appBorder,
                        thumbColor: sliderColor,
                        overlayColor: sliderColor.withAlpha(30),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        min: 1,
                        max: 5,
                        divisions: 4,
                        value: score,
                        onChanged: (v) => widget.onScoreChanged(c.name, v),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      scoreInt.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: sliderColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
                Text('Weight: ${c.weight.toStringAsFixed(0)}%',
                    style: TextStyle(color: context.appSubtext, fontSize: 12)),
              ]),
            );
          }),
          const SizedBox(height: 8),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: 14),
          // Manager notes
          HRNovaTextField(
            label: 'Manager Notes',
            controller: widget.notesCtrl,
            maxLines: 3,
            hint: 'Optional notes for this employee...',
          ),
          const SizedBox(height: 14),
          // AI Review section
          Text('AI Performance Review',
              style: TextStyle(
                  color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (widget.generatingAi)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appField,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryBlue)),
                const SizedBox(width: 12),
                Text('Generating AI review...',
                    style: TextStyle(color: context.appSubtext, fontSize: 15)),
              ]),
            )
          else if (widget.aiReview != null && widget.aiReview!.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HRNovaTextField(
                label: '',
                controller: _aiCtrl,
                maxLines: 5,
                onChanged: widget.onAiTextChanged,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: widget.generatingAi ? null : widget.onGenerateAi,
                icon: const AppIcon(AppIcons.refreshRounded, size: 14),
                label: const Text('Regenerate', style: TextStyle(fontSize: 14)),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
              ),
            ])
          else
            FilledButton.icon(
              onPressed: widget.onGenerateAi,
              icon: const AppIcon(AppIcons.autoAwesomeRounded, size: 16),
              label: const Text('Generate AI Review'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue.withAlpha(200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(height: 20),
          // Save buttons
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.saving ? null : widget.onSave,
                icon: widget.saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const AppIcon(AppIcons.saveRounded, size: 16),
                label: Text(widget.saving ? 'Saving...' : 'Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (widget.hasNext) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.saving ? null : widget.onSaveAndNext,
                  icon: const AppIcon(AppIcons.skipNextRounded, size: 16),
                  label: const Text('Save & Next'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9B59B6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Auto Criterion Row (read-only, system-computed)
// ─────────────────────────────────────────────────────────────────────────────
class _AutoCriterionRow extends StatelessWidget {
  const _AutoCriterionRow({
    required this.criterion,
    required this.score,
    required this.label,
    required this.contribution,
    required this.sliderColor,
  });
  final PerformanceCriterion criterion;
  final double score;
  final String label;
  final double contribution;
  final Color sliderColor;

  @override
  Widget build(BuildContext context) {
    final scoreInt = score.round().clamp(1, 5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Text(criterion.name,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 14,
                      fontWeight: FontWeight.w400)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Auto',
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: sliderColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    color: sliderColor, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Text('${contribution.toStringAsFixed(2)} pts',
              style: TextStyle(color: context.appSubtext, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score - 1) / 4,
                backgroundColor: context.appBorder,
                valueColor: AlwaysStoppedAnimation<Color>(sliderColor),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(scoreInt.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: sliderColor, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ]),
        Text('Weight: ${criterion.weight.toStringAsFixed(0)}% · Computed from attendance records',
            style: TextStyle(color: context.appSubtext, fontSize: 12)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HR Dashboard View
// ─────────────────────────────────────────────────────────────────────────────
class _HRDashboardView extends ConsumerWidget {
  const _HRDashboardView({required this.month, this.branchFilter});
  final String month;
  final String? branchFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(performanceByMonthProvider(month));
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(companySettingsProvider);

    final allScores = scoresAsync.value ?? [];
    final allEmployees = employeesAsync.value ?? [];
    final companyType = settingsAsync.value?.companyType ?? 'single';

    // Apply branch filter when set
    final scores = branchFilter == null
        ? allScores
        : allScores.where((s) => s.branchId == branchFilter).toList();
    final employees = branchFilter == null
        ? allEmployees
        : allEmployees.where((e) => e.branchId == branchFilter).toList();

    // Compute previous month for comparison
    final monthDt = DateTime.parse('$month-01');
    final prevMonth = DateFormat('yyyy-MM')
        .format(DateTime(monthDt.year, monthDt.month - 1));
    final prevScoresAsync = ref.watch(performanceByMonthProvider(prevMonth));
    final prevScores = prevScoresAsync.value ?? [];
    final prevScoreMap = {for (final s in prevScores) s.employeeId: s};

    if (scoresAsync.isLoading || employeesAsync.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    final scoreMap = {for (final s in scores) s.employeeId: s};
    final activeEmployees = employees.where((e) => e.isActive).toList();
    const autoKey = 'Attendance and Punctuality';

    // Auto-scored only = has performance doc with systemScoredKeys but no manual scores
    final autoOnlyEmployees = activeEmployees.where((e) {
      final s = scoreMap[e.id];
      return s != null &&
          s.systemScoredKeys.contains(autoKey) &&
          !s.scores.keys.any((k) => k != autoKey);
    }).toList();

    // Not scored at all = no performance doc
    final notScoredEmployees = activeEmployees.where((e) => !scoreMap.containsKey(e.id)).toList();

    // Needs attention: score < 2.5 OR dropped > 1 from last month
    final needsAttention = scores.where((s) {
      if (s.overallScore < 2.5) return true;
      final prev = prevScoreMap[s.employeeId];
      if (prev != null && (prev.overallScore - s.overallScore) > 1.0) return true;
      return false;
    }).toList();

    // KPI stats
    final double companyAvg = scores.isEmpty
        ? 0
        : scores.fold(0.0, (a, b) => a + b.overallScore) / scores.length;

    // Department averages
    final deptMap = <String, List<double>>{};
    for (final s in scores) {
      deptMap.putIfAbsent(s.department, () => []).add(s.overallScore);
    }
    final deptAvgs = deptMap.map((dept, list) =>
        MapEntry(dept, list.fold(0.0, (a, b) => a + b) / list.length));
    final sortedDepts = deptAvgs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDept = sortedDepts.isNotEmpty ? sortedDepts.first : null;
    final lowestDept =
        sortedDepts.length > 1 ? sortedDepts.last : null;

    // Top 5 performers
    final sorted = List.from(scores)
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    final top5 = sorted.take(5).cast<PerformanceModel>().toList();
    final empById = <String, EmployeeModel>{for (final em in allEmployees) em.id: em};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── KPI Cards ─────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: MetricCard(
              label: 'Company Average',
              value: scores.isEmpty ? '—' : companyAvg.toStringAsFixed(1),
              subtitle: '${scores.length} scored this month',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: MetricCard(
              label: 'Top Department',
              value: topDept?.key ?? '—',
              subtitle: topDept != null
                  ? '${topDept.value.toStringAsFixed(1)}/5 avg'
                  : 'No data',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: MetricCard(
              label: 'Lowest Department',
              value: lowestDept?.key ?? '—',
              subtitle: lowestDept != null
                  ? '${lowestDept.value.toStringAsFixed(1)}/5 avg'
                  : 'No data',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: MetricCard(
              label: 'Not Scored',
              value: notScoredEmployees.length.toString(),
              subtitle: notScoredEmployees.isEmpty
                  ? 'All employees scored'
                  : '${notScoredEmployees.length} employee${notScoredEmployees.length == 1 ? '' : 's'} pending',
            ),
          ),
        ]),
        const SizedBox(height: 20),
        // ── Charts row ────────────────────────────────────────────────────
        if (deptAvgs.isNotEmpty)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Department bar chart
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: context.cardDeco(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Department Performance',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _DeptBarChart(deptAvgs: deptAvgs),
                      ),
                    ]),
              ),
            ),
            const SizedBox(width: 14),
            // Top 5 performers
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: context.cardDeco(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Performers',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      if (top5.isEmpty)
                        Text('No scores this month',
                            style: TextStyle(
                                color: context.appSubtext, fontSize: 15))
                      else
                        ...top5.asMap().entries.map((e) {
                              final perf = e.value;
                              final emp = empById[perf.employeeId];
                              final prevScore =
                                  prevScoreMap[perf.employeeId]?.overallScore;
                              final diff = prevScore != null
                                  ? perf.overallScore - prevScore
                                  : null;
                              final trendColor = diff == null
                                  ? null
                                  : diff > 0.05
                                      ? AppColors.successGreen
                                      : diff < -0.05
                                          ? AppColors.errorRed
                                          : AppColors.warningAmber;
                              final trendIcon = diff == null
                                  ? null
                                  : diff > 0.05
                                      ? AppIcons.trendingUpRounded
                                      : diff < -0.05
                                          ? AppIcons.trendingDownRounded
                                          : AppIcons.trendingFlatRounded;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: e.key == 0
                                          ? const Color(0xFFFFD700).withAlpha(30)
                                          : context.appField,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text('${e.key + 1}',
                                          style: TextStyle(
                                              color: e.key == 0
                                                  ? const Color(0xFFFFD700)
                                                  : context.appSubtext,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _SmallAvatar(
                                    name: perf.employeeName,
                                    photoUrl: emp?.profilePhotoUrl,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(perf.employeeName,
                                              style: TextStyle(
                                                  color: context.appText,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis),
                                          Text(perf.department,
                                              style: TextStyle(
                                                  color: context.appSubtext,
                                                  fontSize: 13)),
                                        ]),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _ScoreStars(perf.overallScore, size: 10),
                                      if (trendIcon != null &&
                                          trendColor != null) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppIcon(trendIcon,
                                                  color: trendColor, size: 11),
                                              const SizedBox(width: 2),
                                              Text(
                                                diff! > 0
                                                    ? '+${diff.toStringAsFixed(1)}'
                                                    : diff.toStringAsFixed(1),
                                                style: TextStyle(
                                                    color: trendColor,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ]),
                                      ],
                                    ],
                                  ),
                                ]),
                              );
                            }),
                    ]),
              ),
            ),
          ]),
        // ── Branch comparison (multi-branch) ──────────────────────────────
        if (companyType == 'multi_branch' && scores.isNotEmpty) ...[
          const SizedBox(height: 16),
          _BranchComparisonCard(scores: scores),
        ],
        // ── Needs Attention ───────────────────────────────────────────────
        if (needsAttention.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AttentionCard(
              scores: needsAttention, prevScoreMap: prevScoreMap),
        ],
        // ── Auto-scored, awaiting manager review ──────────────────────────
        if (autoOnlyEmployees.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AutoOnlyCard(employees: autoOnlyEmployees),
        ],
        // ── Not yet scored (no attendance data) ───────────────────────────
        if (notScoredEmployees.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NotScoredCard(employees: notScoredEmployees),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Department Bar Chart
// ─────────────────────────────────────────────────────────────────────────────
class _DeptBarChart extends StatelessWidget {
  const _DeptBarChart({required this.deptAvgs});
  final Map<String, double> deptAvgs;

  @override
  Widget build(BuildContext context) {
    final entries = deptAvgs.entries.toList();

    return BarChart(
      BarChartData(
        maxY: 5,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.appBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(color: context.appSubtext, fontSize: 12),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final name = entries[i].key;
                final short = name.length > 8 ? '${name.substring(0, 7)}…' : name;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short,
                      style:
                          TextStyle(color: context.appSubtext, fontSize: 9),
                      textAlign: TextAlign.center),
                );
              },
              reservedSize: 28,
            ),
          ),
        ),
        barGroups: entries.asMap().entries.map((e) {
          final avg = e.value.value;
          final barColor = avg >= 4
              ? AppColors.successGreen
              : avg >= 3
                  ? AppColors.warningAmber
                  : AppColors.errorRed;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: avg,
                color: barColor,
                width: 28,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Branch Comparison Card
// ─────────────────────────────────────────────────────────────────────────────
class _BranchComparisonCard extends StatelessWidget {
  const _BranchComparisonCard({required this.scores});
  final List<PerformanceModel> scores;

  @override
  Widget build(BuildContext context) {
    final branchMap = <String, List<double>>{};
    for (final s in scores) {
      final branch = s.branchId ?? 'Head Office';
      branchMap.putIfAbsent(branch, () => []).add(s.overallScore);
    }
    final branchAvgs = branchMap.map((b, list) =>
        MapEntry(b, list.fold(0.0, (a, v) => a + v) / list.length));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Branch Comparison',
            style: TextStyle(
                color: context.appText,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: _DeptBarChart(deptAvgs: branchAvgs),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Needs Attention Card
// ─────────────────────────────────────────────────────────────────────────────
class _AttentionCard extends StatelessWidget {
  const _AttentionCard(
      {required this.scores, required this.prevScoreMap});
  final List<PerformanceModel> scores;
  final Map<String, PerformanceModel> prevScoreMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warningAmber.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AppIcon(AppIcons.warningAmberRounded,
              color: AppColors.warningAmber, size: 18),
          const SizedBox(width: 8),
          Text('Needs Attention (${scores.length})',
              style: const TextStyle(
                  color: AppColors.warningAmber,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        ...scores.map((s) {
          final prev = prevScoreMap[s.employeeId];
          final dropped = prev != null &&
              (prev.overallScore - s.overallScore) > 1.0;
          String reason;
          if (s.overallScore < 2.5 && dropped) {
            reason = 'Low score & declining';
          } else if (s.overallScore < 2.5) {
            reason = 'Score below 2.5/5';
          } else {
            reason = 'Dropped >${(prev!.overallScore - s.overallScore).toStringAsFixed(1)} pts';
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              _SmallAvatar(name: s.employeeName),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.employeeName,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                Text(reason,
                    style: const TextStyle(
                        color: AppColors.warningAmber, fontSize: 13)),
              ])),
              _ScoreStars(s.overallScore),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Auto-Only Card (attendance scored, manager review pending)
// ─────────────────────────────────────────────────────────────────────────────
class _AutoOnlyCard extends StatelessWidget {
  const _AutoOnlyCard({required this.employees});
  final List<EmployeeModel> employees;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AppIcon(AppIcons.autoAwesomeRounded,
              color: AppColors.primaryBlue, size: 18),
          const SizedBox(width: 8),
          Text('Auto-Scored Only — Manager Review Pending (${employees.length})',
              style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text(
          'Attendance & Punctuality computed automatically. Manager has not scored other criteria yet.',
          style: TextStyle(color: context.appSubtext, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: employees.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _SmallAvatar(name: e.fullName, size: 20),
              const SizedBox(width: 8),
              Text(e.fullName,
                  style: TextStyle(color: context.appText, fontSize: 14)),
            ]),
          )).toList(),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Not Scored Card
// ─────────────────────────────────────────────────────────────────────────────
class _NotScoredCard extends StatelessWidget {
  const _NotScoredCard({required this.employees});
  final List<EmployeeModel> employees;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIcon(AppIcons.pendingOutlined, color: context.appSubtext, size: 18),
          const SizedBox(width: 8),
          Text('Not Yet Scored (${employees.length})',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: employees.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.appField,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _SmallAvatar(name: e.fullName, size: 20),
              const SizedBox(width: 8),
              Text(e.fullName,
                  style: TextStyle(color: context.appText, fontSize: 14)),
            ]),
          )).toList(),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _ScoreStars extends StatelessWidget {
  const _ScoreStars(this.score, {this.size = 12});
  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? AppColors.successGreen
        : score >= 3
            ? AppColors.warningAmber
            : AppColors.errorRed;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(5, (i) {
        final filled = (i + 1) <= score.floor();
        final half = !filled && (i + 0.5) < score;
        return AppIcon(
          filled
              ? AppIcons.starRounded
              : half
                  ? AppIcons.starHalfRounded
                  : AppIcons.starOutlineRounded,
          color: (filled || half) ? color : color.withAlpha(60),
          size: size,
        );
      }),
      const SizedBox(width: 4),
      Text(score.toStringAsFixed(1),
          style: TextStyle(
              color: color, fontSize: size - 1, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.name, this.photoUrl, this.size = 34});
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials()),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final colors = AppColors.gradientForName(name);
    final parts = name.trim().split(' ');
    final initials =
        parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.w600)),
    );
  }
}
