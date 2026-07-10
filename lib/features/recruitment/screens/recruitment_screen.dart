import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/job_posting_model.dart';
import '../providers/recruitment_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

class RecruitmentScreen extends ConsumerWidget {
  const RecruitmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(currentCompanyIdProvider) ?? '';
    final jobsAsync = ref.watch(jobPostingsStreamProvider(companyId));
    final statsAsync = ref.watch(recruitmentStatsProvider(companyId));

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(companyId: companyId),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metric cards
                  statsAsync.when(
                    data: (s) => _StatsRow(stats: s),
                    loading: () => const _StatsRowSkeleton(),
                    error: (_, __) => const _StatsRow(stats: RecruitmentStats()),
                  ),
                  const SizedBox(height: 28),

                  // Job postings
                  Row(
                    children: [
                      Text('Job Postings',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: context.appText)),
                      const Spacer(),
                      if (jobsAsync.value?.isNotEmpty == true)
                        Text('${jobsAsync.value!.length} jobs',
                            style: TextStyle(fontSize: 13, color: context.appSubtext)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  jobsAsync.when(
                    data: (jobs) => jobs.isEmpty
                        ? _EmptyJobs(onNew: () => context.go('/recruitment/new'))
                        : Column(
                            children: jobs
                                .map((j) => _JobCard(job: j))
                                .toList(),
                          ),
                    loading: () => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator())),
                    error: (e, _) => Center(
                        child: Text('Error: $e',
                            style: TextStyle(color: context.appSubtext))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String companyId;
  const _Header({required this.companyId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF4A9EFF), Color(0xFF2979E0)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const AppIcon(AppIcons.workRounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Recruitment',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: context.appText)),
          const Spacer(),
          HRNovaButton(
            label: 'New Job Posting',
            icon: AppIcons.addRounded,
            isFullWidth: false,
            height: 44,
            onPressed: () => context.go('/recruitment/new'),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final RecruitmentStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Open Positions', value: stats.openPositions),
        const SizedBox(width: 12),
        _StatCard(label: 'Total Applications', value: stats.totalApplications),
        const SizedBox(width: 12),
        _StatCard(label: 'Shortlisted', value: stats.shortlisted),
        const SizedBox(width: 12),
        _StatCard(label: 'Hired', value: stats.hired),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: context.cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: context.appText)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: context.appSubtext)),
          ],
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (_) => Expanded(
        child: Container(
          height: 88,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      )),
    );
  }
}

// ── Job card ─────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final JobPostingModel job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final deadline = job.deadline;
    final deadlineStr = deadline != null
        ? DateFormat('dd MMM yyyy').format(deadline)
        : 'No deadline';
    final isExpired = deadline != null && deadline.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: context.cardDeco(),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/recruitment/${job.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Job icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const AppIcon(AppIcons.workOutlineRounded,
                    color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),

              // Job info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(job.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.appText)),
                        const SizedBox(width: 8),
                        _StatusBadge(status: job.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppIcon(AppIcons.businessRounded,
                            size: 12, color: context.appSubtext),
                        const SizedBox(width: 4),
                        Text(job.department,
                            style: TextStyle(fontSize: 12, color: context.appSubtext)),
                        const SizedBox(width: 12),
                        AppIcon(AppIcons.calendarTodayOutlined,
                            size: 12,
                            color: isExpired
                                ? AppColors.errorRed
                                : context.appSubtext),
                        const SizedBox(width: 4),
                        Text(deadlineStr,
                            style: TextStyle(
                                fontSize: 12,
                                color: isExpired
                                    ? AppColors.errorRed
                                    : context.appSubtext)),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats
              _CountChip(
                  icon: AppIcons.descriptionOutlined,
                  label: '${job.totalApplications} applied',
                  color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              _CountChip(
                  icon: AppIcons.starOutlineRounded,
                  label: '${job.shortlistedCount} shortlisted',
                  color: AppColors.successGreen),
              const SizedBox(width: 8),

              IconButton(
                icon: AppIcon(AppIcons.editOutlined, size: 17, color: context.appSubtext),
                tooltip: 'Edit job',
                onPressed: () => context.go('/recruitment/${job.id}/edit'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              const SizedBox(width: 4),
              AppIcon(AppIcons.chevronRightRounded,
                  color: context.appSubtext, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (status) {
      'open' => (context.pillGreenBg, context.pillGreenText, 'Open'),
      'draft' => (context.pillAmberBg, context.pillAmberText, 'Draft'),
      'closed' => (context.pillNavyBg, context.pillNavyText, 'Closed'),
      _ => (context.pillNavyBg, context.pillNavyText, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: text)),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconRef icon;
  final String label;
  final Color color;
  const _CountChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyJobs extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyJobs({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const AppIcon(AppIcons.workOutlineRounded,
                  color: AppColors.primaryBlue, size: 34),
            ),
            const SizedBox(height: 16),
            Text('No job postings yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appText)),
            const SizedBox(height: 8),
            Text('Create your first job posting to start receiving applications.',
                style: TextStyle(fontSize: 13, color: context.appSubtext)),
            const SizedBox(height: 20),
            HRNovaButton(
              label: 'Create Job Posting',
              icon: AppIcons.addRounded,
              isFullWidth: false,
              height: 44,
              onPressed: onNew,
            ),
          ],
        ),
      ),
    );
  }
}
