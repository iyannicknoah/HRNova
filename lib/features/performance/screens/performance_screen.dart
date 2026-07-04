import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../../employees/models/employee_model.dart';
import '../../employees/providers/employees_provider.dart';
import '../../settings/models/company_settings_model.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/performance_model.dart';
import '../providers/performance_provider.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthStr => DateFormat('yyyy-MM').format(_selectedMonth);

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
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('Track and evaluate employee performance',
                      style: TextStyle(color: context.appSubtext, fontSize: 15)),
                ]),
                const Spacer(),
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
                : _HRDashboardView(month: _monthStr),
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
    final isCurrentMonth =
        month.year == now.year && month.month == now.month;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(DateFormat('MMMM yyyy').format(month),
              style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
        _NavBtn(
            icon: Icons.chevron_right_rounded,
            onTap: isCurrentMonth ? null : onNext),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: onTap != null
                ? context.appField
                : context.appField.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: onTap != null
                  ? context.appText
                  : context.appSubtext.withAlpha(100)),
        ),
      );
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

  static const _labels = {
    1: 'Poor', 2: 'Below Average', 3: 'Average', 4: 'Good', 5: 'Excellent'
  };

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
      _scores = {};
      if (existing != null) {
        _scores = Map.from(existing.scores);
      } else {
        for (final c in criteria) {
          _scores[c.name] = 3.0;
        }
      }
    });
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

  Future<void> _save(EmployeeModel e, List<PerformanceCriterion> criteria) async {
    setState(() => _saving = true);
    try {
      final overall = _computeOverall(criteria);
      final uid = ref.read(userClaimsProvider).value?['uid'] as String? ?? '';
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
      );
      await ref.read(performanceNotifierProvider.notifier).saveScore(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Score saved successfully'),
          backgroundColor: AppColors.successGreen,
        ));
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

    final employees = employeesAsync.value ?? [];
    final scores = scoresAsync.value ?? [];
    final scoreMap = {for (final s in scores) s.employeeId: s};

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Employee list ─────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 5, child: _hdr('EMPLOYEE', context)),
                    Expanded(flex: 3, child: _hdr('DEPARTMENT', context)),
                    Expanded(flex: 2, child: _hdr('SCORE', context)),
                    const SizedBox(width: 80),
                  ]),
                ),
                Divider(height: 1, color: context.appBorder),
                Expanded(
                  child: employeesAsync.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                      : employees.isEmpty
                          ? Center(
                              child: Text('No employees found',
                                  style: TextStyle(color: context.appSubtext)))
                          : ListView.separated(
                              itemCount: employees.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: context.appBorder),
                              itemBuilder: (_, i) {
                                final e = employees[i];
                                final existing = scoreMap[e.id];
                                final isSelected = _selected?.id == e.id;
                                return InkWell(
                                  onTap: () => _selectEmployee(e, existing, criteria),
                                  hoverColor: context.appBorder.withAlpha(40),
                                  child: Container(
                                    color: isSelected
                                        ? AppColors.primaryBlue.withAlpha(12)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(children: [
                                      // Avatar + name
                                      Expanded(
                                        flex: 5,
                                        child: Row(children: [
                                          _SmallAvatar(name: e.fullName, photoUrl: e.profilePhotoUrl),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(e.fullName,
                                                style: TextStyle(
                                                    color: context.appText,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ]),
                                      ),
                                      // Department
                                      Expanded(
                                        flex: 3,
                                        child: Text(e.department,
                                            style: TextStyle(
                                                color: context.appSubtext,
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      // Score
                                      Expanded(
                                        flex: 2,
                                        child: existing != null
                                            ? _ScoreStars(existing.overallScore)
                                            : Text('—',
                                                style: TextStyle(
                                                    color: context.appSubtext,
                                                    fontSize: 14)),
                                      ),
                                      // Action
                                      SizedBox(
                                        width: 80,
                                        child: FilledButton(
                                          onPressed: () => _selectEmployee(e, existing, criteria),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: isSelected
                                                ? AppColors.primaryBlue
                                                : context.appField,
                                            foregroundColor: isSelected
                                                ? Colors.white
                                                : context.appText,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          child: Text(
                                              existing != null ? 'Edit' : 'Score',
                                              style: const TextStyle(fontSize: 14)),
                                        ),
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                ),
              ]),
            ),
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
                      aiReview: _aiReview,
                      generatingAi: _generatingAi,
                      saving: _saving,
                      notesCtrl: _notesCtrl,
                      labels: _labels,
                      onScoreChanged: (name, val) =>
                          setState(() => _scores[name] = val),
                      onGenerateAi: () =>
                          _generateAiReview(_selected!, criteria),
                      onAiTextChanged: (v) => setState(() => _aiReview = v),
                      onSave: () => _save(_selected!, criteria),
                      onClose: () => setState(() => _selected = null),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hdr(String t, BuildContext ctx) => Text(t,
      style: TextStyle(
          color: ctx.appSubtext,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Score Panel
// ─────────────────────────────────────────────────────────────────────────────
class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    super.key,
    required this.employee,
    required this.criteria,
    required this.scores,
    required this.aiReview,
    required this.generatingAi,
    required this.saving,
    required this.notesCtrl,
    required this.labels,
    required this.onScoreChanged,
    required this.onGenerateAi,
    required this.onAiTextChanged,
    required this.onSave,
    required this.onClose,
  });

  final EmployeeModel employee;
  final List<PerformanceCriterion> criteria;
  final Map<String, double> scores;
  final String? aiReview;
  final bool generatingAi, saving;
  final TextEditingController notesCtrl;
  final Map<int, String> labels;
  final void Function(String name, double val) onScoreChanged;
  final VoidCallback onGenerateAi, onSave, onClose;
  final void Function(String) onAiTextChanged;

  double get _overall => PerformanceModel.computeOverall(scores, criteria);

  Color get _overallColor {
    if (_overall >= 4) return AppColors.successGreen;
    if (_overall >= 3) return AppColors.warningAmber;
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            _SmallAvatar(name: employee.fullName, photoUrl: employee.profilePhotoUrl, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.fullName,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text(employee.department,
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
                        fontWeight: FontWeight.w800,
                        height: 1)),
                Text('/ 5', style: TextStyle(color: _overallColor, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: context.appSubtext, size: 18),
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
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...criteria.map((c) {
            final score = scores[c.name] ?? 3.0;
            final scoreInt = score.round().clamp(1, 5);
            final label = labels[scoreInt] ?? 'Average';
            final contribution = score * c.weight / 100;
            Color sliderColor;
            if (score >= 4) {
              sliderColor = AppColors.successGreen;
            } else if (score >= 3) {
              sliderColor = AppColors.warningAmber;
            } else {
              sliderColor = AppColors.errorRed;
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
                            fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sliderColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: sliderColor, fontSize: 13, fontWeight: FontWeight.w600)),
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
                        onChanged: (v) => onScoreChanged(c.name, v),
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
                          fontWeight: FontWeight.w800),
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
          Text('Manager Notes',
              style: TextStyle(
                  color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            maxLines: 3,
            style: TextStyle(color: context.appText, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Optional notes for this employee...',
              hintStyle: TextStyle(color: context.appSubtext, fontSize: 14),
              filled: true,
              fillColor: context.appField,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.appBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.appBorder)),
              focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          // AI Review section
          Text('AI Performance Review',
              style: TextStyle(
                  color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (generatingAi)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appField,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appBorder),
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
          else if (aiReview != null && aiReview!.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: TextEditingController(text: aiReview),
                maxLines: 5,
                onChanged: onAiTextChanged,
                style: TextStyle(color: context.appText, fontSize: 15, height: 1.5),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.primaryBlue.withAlpha(8),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.primaryBlue.withAlpha(60))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.primaryBlue.withAlpha(60))),
                  focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: generatingAi ? null : onGenerateAi,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Regenerate', style: TextStyle(fontSize: 14)),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
              ),
            ])
          else
            FilledButton.icon(
              onPressed: onGenerateAi,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Generate AI Review'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue.withAlpha(200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(saving ? 'Saving...' : 'Save Score'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HR Dashboard View
// ─────────────────────────────────────────────────────────────────────────────
class _HRDashboardView extends ConsumerWidget {
  const _HRDashboardView({required this.month});
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(performanceByMonthProvider(month));
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(companySettingsProvider);

    final scores = scoresAsync.value ?? [];
    final employees = employeesAsync.value ?? [];
    final companyType = settingsAsync.value?.companyType ?? 'single';

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

    final scoredIds = {for (final s in scores) s.employeeId};
    final notScoredEmployees =
        employees.where((e) => !scoredIds.contains(e.id)).toList();

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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── KPI Cards ─────────────────────────────────────────────────────
        Row(children: [
          _KpiCard(
            icon: Icons.bar_chart_rounded,
            label: 'Company Average',
            value: scores.isEmpty ? '—' : companyAvg.toStringAsFixed(1),
            sub: '${scores.length} scored this month',
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 14),
          _KpiCard(
            icon: Icons.emoji_events_rounded,
            label: 'Top Department',
            value: topDept?.key ?? '—',
            sub: topDept != null
                ? '${topDept.value.toStringAsFixed(1)}/5 avg'
                : 'No data',
            color: AppColors.successGreen,
          ),
          const SizedBox(width: 14),
          _KpiCard(
            icon: Icons.trending_down_rounded,
            label: 'Needs Attention',
            value: lowestDept?.key ?? '—',
            sub: lowestDept != null
                ? '${lowestDept.value.toStringAsFixed(1)}/5 avg'
                : 'No data',
            color: AppColors.warningAmber,
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
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Department Performance',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
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
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Performers',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      if (top5.isEmpty)
                        Text('No scores this month',
                            style: TextStyle(
                                color: context.appSubtext, fontSize: 15))
                      else
                        ...top5.asMap().entries.map((e) => Padding(
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
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e.value.employeeName,
                                            style: TextStyle(
                                                color: context.appText,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis),
                                        Text(e.value.department,
                                            style: TextStyle(
                                                color: context.appSubtext,
                                                fontSize: 13)),
                                      ]),
                                ),
                                _ScoreStars(e.value.overallScore, size: 10),
                              ]),
                            )),
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
        // ── Not yet scored ────────────────────────────────────────────────
        if (notScoredEmployees.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NotScoredCard(employees: notScoredEmployees),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KPI Card
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final IconData icon;
  final String label, value, sub;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(
                        color: context.appSubtext,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(sub,
                    style:
                        TextStyle(color: context.appSubtext, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      );
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
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Branch Comparison',
            style: TextStyle(
                color: context.appText,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warningAmber.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warningAmber, size: 18),
          const SizedBox(width: 8),
          Text('Needs Attention (${scores.length})',
              style: const TextStyle(
                  color: AppColors.warningAmber,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
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
                        fontWeight: FontWeight.w600)),
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
//  Not Scored Card
// ─────────────────────────────────────────────────────────────────────────────
class _NotScoredCard extends StatelessWidget {
  const _NotScoredCard({required this.employees});
  final List<EmployeeModel> employees;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pending_outlined, color: context.appSubtext, size: 18),
          const SizedBox(width: 8),
          Text('Not Yet Scored (${employees.length})',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
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
              border: Border.all(color: context.appBorder),
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
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          color: (filled || half) ? color : color.withAlpha(60),
          size: size,
        );
      }),
      const SizedBox(width: 4),
      Text(score.toStringAsFixed(1),
          style: TextStyle(
              color: color, fontSize: size - 1, fontWeight: FontWeight.w700)),
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
              fontWeight: FontWeight.w700)),
    );
  }
}
