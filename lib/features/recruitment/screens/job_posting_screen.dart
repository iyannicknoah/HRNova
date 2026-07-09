import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/application_model.dart';
import '../models/job_posting_model.dart';
import '../providers/recruitment_provider.dart';
import 'application_detail_screen.dart' show AiScoreBadge, RecommendationBadge;

// ── Entry point ───────────────────────────────────────────────────────────────
// jobId == null → create form
// jobId != null → applications list for that job
class JobPostingScreen extends ConsumerWidget {
  const JobPostingScreen({super.key, this.jobId});
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (jobId == null) return const _JobForm();
    return _JobApplicationsPage(jobId: jobId!);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CREATE / EDIT JOB FORM
// ══════════════════════════════════════════════════════════════════════════════
class _JobForm extends ConsumerStatefulWidget {
  const _JobForm({this.initialJob});
  final JobPostingModel? initialJob;

  @override
  ConsumerState<_JobForm> createState() => _JobFormState();
}

class _JobFormState extends ConsumerState<_JobForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _aiCriteria = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _skillInput = TextEditingController();

  String _department = '';
  int _minExperience = 0;
  bool _showSalary = false;
  String _status = 'draft';
  DateTime? _deadline;
  List<String> _skills = [];
  String? _publicUrl;
  String? _createdJobId;

  static const _departments = [
    'Administration', 'Finance', 'Human Resources', 'ICT', 'Legal',
    'Marketing', 'Operations', 'Procurement', 'Production', 'Sales',
    'Security', 'Customer Service', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final j = widget.initialJob;
    if (j != null) {
      _title.text = j.title;
      _description.text = j.description;
      _requirements.text = j.requirements;
      _aiCriteria.text = j.aiCriteria ?? '';
      _salaryMin.text = j.salaryMin?.toStringAsFixed(0) ?? '';
      _salaryMax.text = j.salaryMax?.toStringAsFixed(0) ?? '';
      _department = j.department;
      _minExperience = j.minExperience;
      _showSalary = j.showSalary;
      _status = j.status;
      _deadline = j.deadline;
      _skills = List.from(j.requiredSkills);
    }
  }

  @override
  void dispose() {
    _title.dispose(); _description.dispose(); _requirements.dispose();
    _aiCriteria.dispose(); _salaryMin.dispose(); _salaryMax.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_department.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a department')));
      return;
    }
    final data = {
      'title': _title.text.trim(),
      'department': _department,
      'description': _description.text.trim(),
      'requirements': _requirements.text.trim(),
      'requiredSkills': _skills,
      'minExperience': _minExperience,
      'aiCriteria': _aiCriteria.text.trim(),
      'salaryMin': _salaryMin.text.trim().isEmpty ? null : double.tryParse(_salaryMin.text),
      'salaryMax': _salaryMax.text.trim().isEmpty ? null : double.tryParse(_salaryMax.text),
      'showSalary': _showSalary,
      'deadline': _deadline?.toIso8601String(),
      'status': status,
    };

    final ok = await ref.read(recruitmentNotifierProvider.notifier).createJob(data);
    if (!mounted) return;

    final state = ref.read(recruitmentNotifierProvider);
    if (ok && state.publicUrl != null) {
      setState(() {
        _publicUrl = state.publicUrl;
        _createdJobId = state.createdJobId;
      });
    } else if (!ok && state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!), backgroundColor: AppColors.errorRed));
    }
  }

  void _addSkill() {
    final s = _skillInput.text.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      setState(() { _skills.add(s); _skillInput.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(recruitmentNotifierProvider);

    // Show success/link state after publish
    if (_publicUrl != null) return _SuccessView(publicUrl: _publicUrl!, jobId: _createdJobId);

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          // Header
          Container(
            color: context.appCard,
            padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/recruitment'),
                  color: context.appText,
                ),
                const SizedBox(width: 4),
                Text('New Job Posting',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: context.appText)),
              ],
            ),
          ),
          Divider(height: 1, color: context.appBorder),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info
                        _Section(title: 'Basic Information', children: [
                          _Field(
                            label: 'Job Title',
                            child: TextFormField(
                              controller: _title,
                              style: TextStyle(color: context.appText, fontSize: 14),
                              decoration: _inputDec(context, 'e.g. Senior Accountant'),
                              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Department',
                            child: DropdownButtonFormField<String>(
                              value: _department.isEmpty ? null : _department,
                              decoration: _inputDec(context, 'Select department'),
                              dropdownColor: context.appCard,
                              style: TextStyle(color: context.appText, fontSize: 14),
                              items: _departments.map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d),
                              )).toList(),
                              onChanged: (v) => setState(() => _department = v ?? ''),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  label: 'Min. Years Experience',
                                  child: DropdownButtonFormField<int>(
                                    value: _minExperience,
                                    decoration: _inputDec(context, ''),
                                    dropdownColor: context.appCard,
                                    style: TextStyle(color: context.appText, fontSize: 14),
                                    items: List.generate(11, (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text(i == 0 ? 'Any' : '$i+ years'),
                                    )),
                                    onChanged: (v) => setState(() => _minExperience = v ?? 0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _Field(
                                  label: 'Application Deadline',
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (d != null) setState(() => _deadline = d);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: context.appField,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: context.appBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today_outlined,
                                              size: 16, color: context.appSubtext),
                                          const SizedBox(width: 8),
                                          Text(
                                            _deadline != null
                                                ? DateFormat('dd MMM yyyy').format(_deadline!)
                                                : 'Pick a date',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: _deadline != null
                                                    ? context.appText
                                                    : context.appSubtext),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // Description & Requirements
                        _Section(title: 'Job Details', children: [
                          _Field(
                            label: 'Job Description',
                            child: TextFormField(
                              controller: _description,
                              maxLines: 5,
                              style: TextStyle(color: context.appText, fontSize: 14),
                              decoration: _inputDec(context, 'Describe the role, responsibilities, and daily tasks...'),
                              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Requirements',
                            child: TextFormField(
                              controller: _requirements,
                              maxLines: 4,
                              style: TextStyle(color: context.appText, fontSize: 14),
                              decoration: _inputDec(context, 'Qualifications, certifications, education...'),
                              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Required Skills',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_skills.isNotEmpty)
                                  Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: _skills.map((s) => Chip(
                                      label: Text(s, style: const TextStyle(fontSize: 12)),
                                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                                      onDeleted: () => setState(() => _skills.remove(s)),
                                      backgroundColor: AppColors.primaryBlue.withAlpha(15),
                                      labelStyle: const TextStyle(color: AppColors.primaryBlue),
                                      side: BorderSide(color: AppColors.primaryBlue.withAlpha(40)),
                                    )).toList(),
                                  ),
                                if (_skills.isNotEmpty) const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _skillInput,
                                        style: TextStyle(color: context.appText, fontSize: 14),
                                        decoration: _inputDec(context, 'Type a skill and press Enter'),
                                        onSubmitted: (_) => _addSkill(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _addSkill,
                                      icon: const Icon(Icons.add_circle_rounded,
                                          color: AppColors.primaryBlue),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // Salary
                        _Section(title: 'Salary (Optional)', children: [
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  label: 'Min Salary (RWF)',
                                  child: TextFormField(
                                    controller: _salaryMin,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(color: context.appText, fontSize: 14),
                                    decoration: _inputDec(context, 'e.g. 200000'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _Field(
                                  label: 'Max Salary (RWF)',
                                  child: TextFormField(
                                    controller: _salaryMax,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(color: context.appText, fontSize: 14),
                                    decoration: _inputDec(context, 'e.g. 350000'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Switch(
                                value: _showSalary,
                                onChanged: (v) => setState(() => _showSalary = v),
                                activeColor: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text('Show salary range to applicants',
                                  style: TextStyle(fontSize: 13, color: context.appText)),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // AI Screening
                        _Section(title: 'AI Screening Criteria', children: [
                          Text(
                            'Describe your ideal candidate in plain language. Nova AI will use this to score and rank applications automatically.',
                            style: TextStyle(fontSize: 13, color: context.appSubtext, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _aiCriteria,
                            maxLines: 4,
                            style: TextStyle(color: context.appText, fontSize: 14),
                            decoration: _inputDec(context,
                                'e.g. Looking for someone with strong Excel skills, at least 3 years in a finance role, good communication, and experience with payroll systems...'),
                          ),
                        ]),
                        const SizedBox(height: 28),

                        // Action buttons
                        if (notifier.error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withAlpha(12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.errorRed.withAlpha(40)),
                            ),
                            child: Text(notifier.error!,
                                style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: notifier.loading ? null : () => _save('draft'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: context.appBorder),
                              ),
                              child: Text('Save as Draft',
                                  style: TextStyle(color: context.appText)),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: notifier.loading ? null : () => _save('open'),
                              icon: notifier.loading
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.publish_rounded, size: 18),
                              label: Text(notifier.loading ? 'Publishing...' : 'Publish Job'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(BuildContext context, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.appSubtext, fontSize: 13),
        filled: true,
        fillColor: context.appField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.appBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.errorRed)),
      );
}

// ── Success view after publishing ─────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String publicUrl;
  final String? jobId;
  const _SuccessView({required this.publicUrl, this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.successGreen, size: 40),
                ),
                const SizedBox(height: 20),
                Text('Job Published!',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: context.appText)),
                const SizedBox(height: 8),
                Text('Your job posting is live. Share the link below to start receiving applications.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.appSubtext, height: 1.5)),
                const SizedBox(height: 24),

                // Link box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(publicUrl,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primaryBlue),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 18, color: AppColors.primaryBlue),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: publicUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied!')));
                        },
                        tooltip: 'Copy link',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/recruitment'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back to Recruitment'),
                    ),
                    if (jobId != null) ...[
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => context.go('/recruitment/$jobId'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('View Applications'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// APPLICATIONS LIST PAGE (/:jobId)
// ══════════════════════════════════════════════════════════════════════════════
class _JobApplicationsPage extends ConsumerStatefulWidget {
  const _JobApplicationsPage({required this.jobId});
  final String jobId;

  @override
  ConsumerState<_JobApplicationsPage> createState() => _JobApplicationsPageState();
}

class _JobApplicationsPageState extends ConsumerState<_JobApplicationsPage> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final companyId = ref.watch(currentCompanyIdProvider) ?? '';
    final companyName = ref.watch(companySettingsProvider).value?.companyName ?? '';
    final jobsAsync = ref.watch(jobPostingsStreamProvider(companyId));
    final appsAsync = ref.watch(jobApplicationsStreamProvider(
        (companyId: companyId, jobId: widget.jobId)));
    final pendingAsync = ref.watch(pendingRejectionsProvider(
        (companyId: companyId, jobId: widget.jobId)));

    final job = jobsAsync.value?.where((j) => j.id == widget.jobId).firstOrNull;
    final notifier = ref.watch(recruitmentNotifierProvider);

    ref.listen<RecruitmentState>(recruitmentNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!), backgroundColor: AppColors.errorRed));
        ref.read(recruitmentNotifierProvider.notifier).clear();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.successGreen));
        ref.read(recruitmentNotifierProvider.notifier).clear();
      }
    });

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          // Header
          Container(
            color: context.appCard,
            padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/recruitment'),
                  color: context.appText,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job?.title ?? 'Job Applications',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: context.appText)),
                      if (job != null)
                        Row(
                          children: [
                            Text(job.department,
                                style: TextStyle(fontSize: 12, color: context.appSubtext)),
                            const SizedBox(width: 8),
                            _StatusBadge(status: job.status),
                          ],
                        ),
                    ],
                  ),
                ),

                // Public link
                if (job?.publicLink.isNotEmpty == true)
                  IconButton(
                    icon: const Icon(Icons.link_rounded, color: AppColors.primaryBlue),
                    tooltip: 'Copy public link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: job!.publicLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied!')));
                    },
                  ),

                // Edit job
                OutlinedButton.icon(
                  onPressed: () => _showEditDialog(context, job),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Job'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: context.appBorder),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appBorder),

          Expanded(
            child: Column(
              children: [
                // Pending rejections banner
                pendingAsync.when(
                  data: (pending) => pending.isEmpty
                      ? const SizedBox()
                      : _PendingRejectionsBanner(
                          count: pending.length,
                          onSend: () async {
                            final n = await ref
                                .read(recruitmentNotifierProvider.notifier)
                                .sendRejections(widget.jobId, companyName);
                            if (mounted && n > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Sent $n rejection emails'),
                                backgroundColor: AppColors.successGreen,
                              ));
                            }
                          },
                        ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: context.appCard,
                  child: Row(
                    children: [
                      Text('Filter:',
                          style: TextStyle(fontSize: 12, color: context.appSubtext)),
                      const SizedBox(width: 8),
                      ...[
                        ('all', 'All'),
                        ('pending', 'Pending'),
                        ('shortlisted', 'Shortlisted'),
                        ('declined', 'Declined'),
                        ('hired', 'Hired'),
                      ].map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f.$2, style: const TextStyle(fontSize: 12)),
                              selected: _filterStatus == f.$1,
                              onSelected: (_) => setState(() => _filterStatus = f.$1),
                              selectedColor: AppColors.primaryBlue.withAlpha(30),
                              labelStyle: TextStyle(
                                  color: _filterStatus == f.$1
                                      ? AppColors.primaryBlue
                                      : context.appSubtext),
                              side: BorderSide(
                                  color: _filterStatus == f.$1
                                      ? AppColors.primaryBlue.withAlpha(80)
                                      : context.appBorder),
                            ),
                          )),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.appBorder),

                // Applications list
                Expanded(
                  child: appsAsync.when(
                    data: (apps) {
                      final filtered = _filterStatus == 'all'
                          ? apps
                          : apps.where((a) => a.status == _filterStatus).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_rounded, size: 48, color: context.appSubtext),
                              const SizedBox(height: 12),
                              Text(
                                _filterStatus == 'all'
                                    ? 'No applications yet'
                                    : 'No ${_filterStatus} applications',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.appText),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _filterStatus == 'all'
                                    ? 'Share the job link to start receiving applications.'
                                    : 'No applications match this filter.',
                                style: TextStyle(fontSize: 13, color: context.appSubtext),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ApplicationCard(
                          app: filtered[i],
                          jobId: widget.jobId,
                          companyId: companyId,
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                        child: Text('Error: $e',
                            style: TextStyle(color: context.appSubtext))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, JobPostingModel? job) {
    if (job == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditJobDialog(job: job),
    );
  }
}

// ── Pending rejections banner ─────────────────────────────────────────────────
class _PendingRejectionsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onSend;
  const _PendingRejectionsBanner({required this.count, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.errorRed.withAlpha(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, color: AppColors.errorRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count applicant${count == 1 ? '' : 's'} marked as declined — rejection emails not sent yet.',
              style: const TextStyle(fontSize: 13, color: AppColors.errorRed),
            ),
          ),
          TextButton(
            onPressed: onSend,
            child: const Text('Send Rejections',
                style: TextStyle(
                    color: AppColors.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Application card ──────────────────────────────────────────────────────────
class _ApplicationCard extends ConsumerWidget {
  final ApplicationModel app;
  final String jobId;
  final String companyId;
  const _ApplicationCard({
    required this.app,
    required this.jobId,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.go('/recruitment/$jobId/application/${app.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            // Avatar
            _InitialsAvatar(name: app.applicantName),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(app.applicantName,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.appText)),
                      const SizedBox(width: 8),
                      _AppStatusBadge(status: app.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.work_history_outlined,
                          size: 12, color: context.appSubtext),
                      const SizedBox(width: 4),
                      Text('${app.yearsExperience} yrs exp',
                          style: TextStyle(fontSize: 12, color: context.appSubtext)),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: context.appSubtext),
                      const SizedBox(width: 4),
                      Text(DateFormat('dd MMM yyyy').format(app.appliedAt),
                          style: TextStyle(fontSize: 12, color: context.appSubtext)),
                    ],
                  ),
                  if (app.aiStrengths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...app.aiStrengths.take(3).map((s) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 12, color: AppColors.successGreen),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(s,
                                    style: TextStyle(
                                        fontSize: 12, color: context.appSubtext),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // AI Score & Recommendation
            if (app.hasAiScore) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AiScoreBadge(score: app.aiScore!.toInt()),
                  const SizedBox(height: 6),
                  RecommendationBadge(recommendation: app.aiRecommendation),
                ],
              ),
              const SizedBox(width: 8),
            ] else ...[
              Column(
                children: [
                  const Icon(Icons.hourglass_empty_rounded,
                      color: AppColors.warningAmber, size: 20),
                  Text('Screening',
                      style: TextStyle(fontSize: 11, color: context.appSubtext)),
                ],
              ),
              const SizedBox(width: 8),
            ],

            Icon(Icons.chevron_right_rounded, color: context.appSubtext, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Initials avatar ───────────────────────────────────────────────────────────
class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final colors = AppColors.gradientForName(name);
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AppStatusBadge extends StatelessWidget {
  final String status;
  const _AppStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (status) {
      'pending' => (AppColors.pillNavyBg, AppColors.pillNavyText, 'Pending'),
      'shortlisted' => (AppColors.pillGreenBg, AppColors.pillGreenText, 'Shortlisted'),
      'declined' => (AppColors.pillRedBg, AppColors.pillRedText, 'Declined'),
      'hired' => (AppColors.pillBlueBg, AppColors.pillBlueText, 'Hired'),
      _ => (AppColors.pillNavyBg, AppColors.pillNavyText, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

// ── Edit job dialog ───────────────────────────────────────────────────────────
class _EditJobDialog extends ConsumerStatefulWidget {
  final JobPostingModel job;
  const _EditJobDialog({required this.job});

  @override
  ConsumerState<_EditJobDialog> createState() => _EditJobDialogState();
}

class _EditJobDialogState extends ConsumerState<_EditJobDialog> {
  late String _status;
  late DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _status = widget.job.status;
    _deadline = widget.job.deadline;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(recruitmentNotifierProvider);

    return AlertDialog(
      backgroundColor: context.appCard,
      title: Text('Edit Job',
          style: TextStyle(fontWeight: FontWeight.w700, color: context.appText)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: TextStyle(fontSize: 13, color: context.appSubtext)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'draft', label: Text('Draft'), icon: Icon(Icons.edit_outlined, size: 14)),
                ButtonSegment(value: 'open', label: Text('Open'), icon: Icon(Icons.public_rounded, size: 14)),
                ButtonSegment(value: 'closed', label: Text('Closed'), icon: Icon(Icons.lock_outline, size: 14)),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 16),
            Text('Deadline', style: TextStyle(fontSize: 13, color: context.appSubtext)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _deadline = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: context.appField,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: context.appSubtext),
                    const SizedBox(width: 8),
                    Text(
                      _deadline != null
                          ? DateFormat('dd MMM yyyy').format(_deadline!)
                          : 'No deadline',
                      style: TextStyle(fontSize: 14, color: context.appText),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: context.appSubtext)),
        ),
        FilledButton(
          onPressed: notifier.loading
              ? null
              : () async {
                  final ok = await ref
                      .read(recruitmentNotifierProvider.notifier)
                      .updateJob(widget.job.id, {
                    'status': _status,
                    'deadline': _deadline?.toIso8601String(),
                  });
                  if (mounted && ok) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: notifier.loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (status) {
      'open' => (AppColors.pillGreenBg, AppColors.pillGreenText, 'Open'),
      'draft' => (AppColors.pillAmberBg, AppColors.pillAmberText, 'Draft'),
      'closed' => (AppColors.pillNavyBg, AppColors.pillNavyText, 'Closed'),
      _ => (AppColors.pillNavyBg, AppColors.pillNavyText, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: context.appText)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: context.appSubtext)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
