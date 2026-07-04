import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/providers/branches_provider.dart';
import '../providers/reports_provider.dart';
import 'nova_ai_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabs;
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this); // placeholder; rebuilt in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final role = ref.read(currentUserRoleProvider);
    _isGroup = role == AppConstants.roleGroupHrAdmin;
    final tabCount = _isGroup ? 5 : 4;
    if (_tabs.length != tabCount) {
      _tabs.dispose();
      _tabs = TabController(length: tabCount, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(isGroup: _isGroup, tabs: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                if (_isGroup) const _GroupTab(),
                const _DailyTab(),
                const _WeeklyTab(),
                const _MonthlyTab(),
                const NovaAiView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header + TabBar ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isGroup;
  final TabController tabs;
  const _Header({required this.isGroup, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final labels = [
      if (isGroup) 'Group',
      'Daily',
      'Weekly',
      'Monthly',
      'Ask Nova',
    ];
    return Container(
      color: context.appCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 10),
                Text('Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.appText)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9EFF).withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 13),
                      const SizedBox(width: 4),
                      Text('AI-Powered', style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primaryBlue,
            indicatorWeight: 2,
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: context.appSubtext,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: labels.map((l) => Tab(text: l)).toList(),
          ),
          Divider(height: 1, color: context.appBorder),
        ],
      ),
    );
  }
}

// ── Branch filter dropdown shared widget ──────────────────────────────────────
class _BranchFilter extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _BranchFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesStreamProvider).valueOrNull ?? [];
    if (branches.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: context.appField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          dropdownColor: context.appCard,
          hint: Text('All branches', style: TextStyle(color: context.appSubtext, fontSize: 13)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All branches', style: TextStyle(fontSize: 13, color: context.appText)),
            ),
            ...branches.map((b) => DropdownMenuItem<String?>(
                  value: b.id,
                  child: Text(b.name, style: TextStyle(fontSize: 13, color: context.appText)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _ReportCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final report = doc['report'] as String? ?? '';
    final generatedAt = doc['generatedAt'];
    String timeStr = '';
    if (generatedAt is String) {
      try {
        timeStr = DateFormat('d MMM y, HH:mm').format(DateTime.parse(generatedAt));
      } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: context.cardDeco(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded, color: AppColors.primaryBlue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _docLabel(doc),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.appText),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: TextStyle(fontSize: 11, color: context.appSubtext)),
              ],
            ),
            const SizedBox(height: 12),
            Text(report, style: TextStyle(fontSize: 13, color: context.appText, height: 1.65)),
          ],
        ),
      ),
    );
  }

  String _docLabel(Map<String, dynamic> doc) {
    final type = doc['type'] as String? ?? '';
    switch (type) {
      case 'daily':       return 'Daily — ${doc['date'] ?? ''}';
      case 'weekly':      return 'Week of ${doc['startDate'] ?? ''}';
      case 'monthly':     return 'Monthly — ${doc['month'] ?? ''}';
      case 'group_daily': return 'Group Daily — ${doc['date'] ?? ''}';
      case 'end_of_day':  return 'End of Day — ${doc['date'] ?? ''}';
      default:            return doc['id'] as String? ?? '';
    }
  }
}

// ── Generate button ────────────────────────────────────────────────────────────
class _GenButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final String label;
  const _GenButton({required this.loading, required this.onTap, this.label = 'Generate Report'});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome_rounded, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

// ── DAILY TAB ─────────────────────────────────────────────────────────────────
class _DailyTab extends ConsumerStatefulWidget {
  const _DailyTab();
  @override
  ConsumerState<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends ConsumerState<_DailyTab> {
  String? _branchId;
  DateTime _date = DateTime.now();
  final _fmt = DateFormat('yyyy-MM-dd');

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('daily'));
    final notifier = ref.read(reportNotifierProvider('daily').notifier);
    final docs     = ref.watch(reportsStreamProvider('daily')).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls
          Row(
            children: [
              if (_showBranchFilter) ...[
                _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
                const SizedBox(width: 10),
              ],
              _DateChip(date: _date, onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2024), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              }),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                onTap: () => notifier.generateDaily(date: _fmt.format(_date), branchId: _branchId),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AutoNote('Morning reports are sent automatically to HR Admin and Manager at 9:30am every working day.'),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(state.error!),
          ],
          if (state.report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(doc: {'type': 'daily', 'report': state.report, 'date': _fmt.format(_date)}),
          ],
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
          const SizedBox(height: 20),
          const _AnomalySection(),
        ],
      ),
    );
  }
}

// ── ANOMALY SECTION ───────────────────────────────────────────────────────────
class _AnomalySection extends ConsumerWidget {
  const _AnomalySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(reportsStreamProvider('anomaly_alert')).valueOrNull ?? [];
    if (docs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 16),
          const SizedBox(width: 6),
          Text('AI Anomaly Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
        ]),
        const SizedBox(height: 10),
        ...docs.take(5).map((d) => _AnomalyCard(doc: d)),
      ],
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({required this.doc});
  final Map<String, dynamic> doc;

  @override
  Widget build(BuildContext context) {
    final report = (doc['report'] as String?) ?? (doc['summary'] as String?) ?? '';
    final ts = doc['generatedAt'];
    String dateLabel = '';
    if (ts != null) {
      try {
        final dt = ts is DateTime ? ts : DateTime.tryParse(ts.toString());
        if (dt != null) dateLabel = DateFormat('d MMM y, HH:mm').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.warningAmber, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.warningAmber, size: 14),
          const SizedBox(width: 6),
          const Text('Anomaly Alert', style: TextStyle(color: AppColors.warningAmber, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (dateLabel.isNotEmpty)
            Text(dateLabel, style: TextStyle(color: context.appSubtext, fontSize: 12)),
        ]),
        if (report.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(report, style: TextStyle(color: context.appText, fontSize: 14, height: 1.45)),
        ],
      ]),
    );
  }
}

// ── WEEKLY TAB ────────────────────────────────────────────────────────────────
class _WeeklyTab extends ConsumerStatefulWidget {
  const _WeeklyTab();
  @override
  ConsumerState<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends ConsumerState<_WeeklyTab> {
  String? _branchId;
  DateTime _weekStart = _calcWeekStart(DateTime.now());

  static DateTime _calcWeekStart(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day - diff);
  }

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('weekly'));
    final notifier = ref.read(reportNotifierProvider('weekly').notifier);
    final docs     = ref.watch(reportsStreamProvider('weekly')).valueOrNull ?? [];
    final fmt      = DateFormat('yyyy-MM-dd');
    final displayFmt = DateFormat('d MMM');

    final weekEnd = _weekStart.add(const Duration(days: 6));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_showBranchFilter) ...[
                _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
                const SizedBox(width: 10),
              ],
              // Week navigator
              Container(
                decoration: BoxDecoration(
                  color: context.appField,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${displayFmt.format(_weekStart)} – ${displayFmt.format(weekEnd)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: _weekStart.isBefore(DateTime.now().subtract(const Duration(days: 7)))
                          ? () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)))
                          : null,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                onTap: () => notifier.generateWeekly(startDate: fmt.format(_weekStart), branchId: _branchId),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(state.error!),
          ],
          if (state.report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(doc: {'type': 'weekly', 'report': state.report, 'startDate': fmt.format(_weekStart)}),
          ],
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
        ],
      ),
    );
  }
}

// ── MONTHLY TAB ───────────────────────────────────────────────────────────────
class _MonthlyTab extends ConsumerStatefulWidget {
  const _MonthlyTab();
  @override
  ConsumerState<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends ConsumerState<_MonthlyTab> {
  String? _branchId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _showBranchFilter {
    final role = ref.watch(currentUserRoleProvider);
    return role == AppConstants.roleGroupHrAdmin || role == AppConstants.roleHrAdmin;
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_month);

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('monthly'));
    final notifier = ref.read(reportNotifierProvider('monthly').notifier);
    final docs     = ref.watch(reportsStreamProvider('monthly')).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_showBranchFilter) ...[
                _BranchFilter(value: _branchId, onChanged: (v) => setState(() => _branchId = v)),
                const SizedBox(width: 10),
              ],
              // Month navigator
              Container(
                decoration: BoxDecoration(
                  color: context.appField,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        DateFormat('MMMM yyyy').format(_month),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: _month.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                          ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                          : null,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                onTap: () => notifier.generateMonthly(month: _monthKey, branchId: _branchId),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(state.error!),
          ],
          if (state.report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(doc: {'type': 'monthly', 'report': state.report, 'month': _monthKey}),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningAmber.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.warningAmber, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Employee photos in this report will be automatically deleted after 14 days per data minimisation policy.',
                      style: const TextStyle(fontSize: 12, color: AppColors.warningAmber),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Previous Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
        ],
      ),
    );
  }
}

// ── GROUP TAB (group_hr_admin only) ───────────────────────────────────────────
class _GroupTab extends ConsumerStatefulWidget {
  const _GroupTab();
  @override
  ConsumerState<_GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends ConsumerState<_GroupTab> {
  DateTime _date = DateTime.now();
  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reportNotifierProvider('group'));
    final notifier = ref.read(reportNotifierProvider('group').notifier);
    final docs     = ref.watch(reportsStreamProvider('group_daily')).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateChip(date: _date, onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2024), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              }),
              const Spacer(),
              _GenButton(
                loading: state.loading,
                label: 'Generate Group Report',
                onTap: () => notifier.generateGroupDaily(date: _fmt.format(_date)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AutoNote('Group reports are sent automatically to Group HR Admin at 9:30am every working day.'),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(state.error!),
          ],
          if (state.report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(doc: {'type': 'group_daily', 'report': state.report, 'date': _fmt.format(_date)}),
          ],
          // Branch comparison from latest group report
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GroupBranchChart(doc: docs.first),
            const SizedBox(height: 20),
            Text('Previous Group Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 10),
            ...docs.take(5).map((d) => _ReportCard(doc: d)),
          ],
        ],
      ),
    );
  }
}

class _GroupBranchChart extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _GroupBranchChart({required this.doc});

  @override
  Widget build(BuildContext context) {
    final summary = doc['summary'] as Map<String, dynamic>?;
    if (summary == null) return const SizedBox.shrink();
    final branches = (summary['branches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (branches.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: context.cardDeco(12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Branch Attendance Comparison', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.appText)),
          const SizedBox(height: 16),
          ...branches.map((b) {
            final rate = (b['attendanceRate'] ?? b['avgAttendanceRate'] ?? 0) as num;
            final name = b['branchName'] as String? ?? 'Branch';
            final color = rate >= 90 ? AppColors.successGreen : rate >= 70 ? AppColors.warningAmber : AppColors.errorRed;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontSize: 13, color: context.appText, fontWeight: FontWeight.w600)),
                      Text('${rate.toInt()}%', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 8,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Date chip ─────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateChip({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: context.appField,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: context.appSubtext),
            const SizedBox(width: 6),
            Text(
              isToday ? 'Today' : DateFormat('d MMM yyyy').format(date),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appText),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 14, color: context.appSubtext),
          ],
        ),
      ),
    );
  }
}

// ── Auto-delivery info note ───────────────────────────────────────────────────
class _AutoNote extends StatelessWidget {
  final String message;
  const _AutoNote(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_send_rounded, color: AppColors.primaryBlue, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) {
    final clean = message.replaceAll(RegExp(r'Exception:|DioException.*'), '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.errorRed.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(clean.isNotEmpty ? clean : 'Something went wrong.', style: const TextStyle(fontSize: 12, color: AppColors.errorRed))),
        ],
      ),
    );
  }
}
