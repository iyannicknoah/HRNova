import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key, required this.companySlug});
  final String companySlug;

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get(
          '/api/recruitment/public/company/${widget.companySlug}');
      if (!mounted) return;
      setState(() {
        _company = res.data['company'] as Map<String, dynamic>?;
        _jobs = (res.data['jobs'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, Color(0xFF2979E0)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AppIcon(AppIcons.boltRounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('HRNovva',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.cardBorder),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!)
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Company header
                      _CompanyHeader(company: _company),

                      // Jobs
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: _jobs.isEmpty
                                ? const _NoJobs()
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_jobs.length} Open Position${_jobs.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 16),
                                      ..._jobs.map((j) => _JobListCard(
                                            job: j,
                                            companySlug: widget.companySlug,
                                          )),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      // Footer
                      const _Footer(),
                    ],
                  ),
                ),
    );
  }
}

// ── Company header ────────────────────────────────────────────────────────────
class _CompanyHeader extends StatelessWidget {
  final Map<String, dynamic>? company;
  const _CompanyHeader({required this.company});

  @override
  Widget build(BuildContext context) {
    if (company == null) return const SizedBox();
    return Container(
      color: AppColors.darkNavy,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company!['name'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              if ((company!['industry'] as String?)?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(30),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.primaryBlue.withAlpha(60)),
                  ),
                  child: Text(company!['industry'] as String,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primaryBlue)),
                ),
              const SizedBox(height: 16),
              const Text('We are hiring! Browse our open positions below and apply today.',
                  style: TextStyle(
                      fontSize: 15, color: Color(0xFF94A3B8), height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Job card ─────────────────────────────────────────────────────────────────
class _JobListCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String companySlug;
  const _JobListCard({required this.job, required this.companySlug});

  @override
  Widget build(BuildContext context) {
    final deadline = job['deadline'] as String?;
    final deadlineDate = deadline != null ? DateTime.tryParse(deadline) : null;
    final isExpired = deadlineDate != null && deadlineDate.isBefore(DateTime.now());
    final jobSlug = job['jobSlug'] as String? ?? job['id'] as String;

    final salaryMin = (job['salaryMin'] as num?)?.toInt();
    final salaryMax = (job['salaryMax'] as num?)?.toInt();
    final showSalary = job['showSalary'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job['title'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const AppIcon(AppIcons.businessRounded,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(job['department'] as String? ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      if (showSalary && salaryMin != null) ...[
                        const SizedBox(width: 16),
                        const AppIcon(AppIcons.attachMoneyRounded,
                            size: 13, color: AppColors.textSecondary),
                        Text(
                          salaryMax != null
                              ? 'RWF ${_fmt(salaryMin)} – ${_fmt(salaryMax)}'
                              : 'From RWF ${_fmt(salaryMin)}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  if (deadlineDate != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        AppIcon(AppIcons.calendarTodayOutlined,
                            size: 13,
                            color: isExpired
                                ? AppColors.errorRed
                                : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          isExpired
                              ? 'Deadline passed'
                              : 'Apply by ${DateFormat('dd MMM yyyy').format(deadlineDate)}',
                          style: TextStyle(
                              fontSize: 13,
                              color: isExpired
                                  ? AppColors.errorRed
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (!isExpired)
              HRNovaButton(
                label: 'Apply Now',
                isFullWidth: false,
                height: 42,
                onPressed: () => context.go('/apply/$companySlug/$jobSlug'),
              )
            else
              const StatusBadge(text: 'Closed', type: StatusType.neutral),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    final f = NumberFormat('#,###');
    return f.format(n);
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────
class _NoJobs extends StatelessWidget {
  const _NoJobs();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          AppIcon(AppIcons.workOffOutlined,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text('No open positions right now',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text('Check back later for new opportunities.',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.errorOutlineRounded,
                size: 48, color: AppColors.errorRed),
            const SizedBox(height: 16),
            const Text('Could not load job board',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkNavy,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Column(
        children: [
          Text('Powered by HRNovva',
              style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w400)),
          SizedBox(height: 4),
          Text('Your HR Team, Supercharged',
              style: TextStyle(color: Color(0xFF334155), fontSize: 11)),
        ],
      ),
    );
  }
}
