import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/application_model.dart';
import '../providers/recruitment_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../l10n/tr.dart';

class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.jobId,
    required this.applicationId,
  });

  final String jobId;
  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = ref.watch(currentCompanyIdProvider) ?? '';
    final appAsync = ref.watch(applicationDetailStreamProvider(
        (companyId: companyId, jobId: jobId, appId: applicationId)));

    ref.listen<RecruitmentState>(recruitmentNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!), backgroundColor: AppColors.errorRed));
        ref.read(recruitmentNotifierProvider.notifier).clear();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.successMessage!),
          backgroundColor: AppColors.successGreen,
        ));
        ref.read(recruitmentNotifierProvider.notifier).clear();
      }
    });

    return Scaffold(
      backgroundColor: context.appBg,
      body: appAsync.when(
        data: (app) {
          if (app == null) {
            return Center(
                child: Text(context.tr('Application not found'),
                    style: TextStyle(color: context.appSubtext)));
          }
          return _DetailBody(app: app, jobId: jobId, companyId: companyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e', style: TextStyle(color: context.appSubtext))),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────
class _DetailBody extends ConsumerWidget {
  final ApplicationModel app;
  final String jobId;
  final String companyId;
  const _DetailBody(
      {required this.app, required this.jobId, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(recruitmentNotifierProvider);

    return Column(
      children: [
        // Header
        Container(
          color: context.appCard,
          padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
          child: Row(
            children: [
              IconButton(
                icon: const AppIcon(AppIcons.arrowBackRounded),
                onPressed: () => context.go('/recruitment/$jobId'),
                color: context.appText,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.applicantName,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.appText)),
                    Text('${app.jobTitle} · Applied ${DateFormat('dd MMM yyyy').format(app.appliedAt)}',
                        style: TextStyle(fontSize: 12, color: context.appSubtext)),
                  ],
                ),
              ),

              if (app.cvUrl != null)
                HRNovaButton(
                  label: context.tr('Download CV'),
                  icon: AppIcons.downloadRounded,
                  outlined: true,
                  backgroundColor: context.appSubtext,
                  isFullWidth: false,
                  height: 40,
                  onPressed: () => openInNewTab(app.cvUrl!),
                ),
              const SizedBox(width: 10),

              // Action buttons
              if (app.status == 'pending' || app.status == 'shortlisted') ...[
                if (app.status != 'shortlisted')
                  HRNovaButton(
                    label: context.tr('Decline'),
                    outlined: true,
                    backgroundColor: AppColors.errorRed,
                    isFullWidth: false,
                    height: 40,
                    onPressed: notifier.loading
                        ? null
                        : () => _confirmDecline(context, ref),
                  ),
                const SizedBox(width: 8),
                HRNovaButton(
                  label: app.status == 'shortlisted'
                      ? 'Send Interview Invite'
                      : 'Shortlist',
                  backgroundColor: AppColors.successGreen,
                  isLoading: notifier.loading,
                  isFullWidth: false,
                  height: 40,
                  onPressed: notifier.loading
                      ? null
                      : () => _showShortlistDialog(context, ref),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: context.appBorder),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: AI analysis
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AI Score Panel
                          if (app.hasAiScore) _AiScorePanel(app: app),
                          if (app.hasAiScore) const SizedBox(height: 20),

                          // Cover Letter
                          if (app.coverLetter?.isNotEmpty == true) ...[
                            _Card(
                              title: context.tr('Cover Letter'),
                              child: Text(app.coverLetter!,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: context.appText,
                                      height: 1.7)),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Strengths & Concerns
                          if (app.aiStrengths.isNotEmpty || app.aiConcerns.isNotEmpty)
                            _StrengthsConcerns(app: app),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right: Applicant info
                    SizedBox(
                      width: 260,
                      child: Column(
                        children: [
                          _ApplicantInfo(app: app),
                          if (app.interviewDate != null) ...[
                            const SizedBox(height: 16),
                            _InterviewInfo(app: app),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDecline(BuildContext context, WidgetRef ref) {
    AppDialogShell.show(
      context: context,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Decline Application'),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: context.appText)),
            const SizedBox(height: 15),
            Text(
              'Mark ${app.applicantName} as declined?\n\nNo email will be sent now. You can send rejection emails in bulk from the applications list.',
              style: TextStyle(fontSize: 13, color: context.appText, height: 1.5),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HRNovaButton.text(
                  label: context.tr('Cancel'),
                  onPressed: () => Navigator.pop(context),
                  textColor: context.appSubtext,
                ),
                HRNovaButton(
                  label: context.tr('Decline'),
                  isFullWidth: false,
                  backgroundColor: AppColors.errorRed,
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(recruitmentNotifierProvider.notifier)
                        .declineApplication(app.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShortlistDialog(BuildContext context, WidgetRef ref) {
    AppDialogShell.show(
      context: context,
      alignment: Alignment.center,
      child: _ShortlistDialog(app: app, jobId: jobId),
    );
  }
}

// ── AI Score Panel ────────────────────────────────────────────────────────────
class _AiScorePanel extends StatelessWidget {
  final ApplicationModel app;
  const _AiScorePanel({required this.app});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: context.tr('AI Screening Analysis'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AiScoreBadge(score: app.aiScore!.toInt(), large: true),
          const SizedBox(width: 8),
          RecommendationBadge(recommendation: app.aiRecommendation),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.aiSummary?.isNotEmpty == true) ...[
            Text(app.aiSummary!,
                style: TextStyle(fontSize: 14, color: context.appText, height: 1.6)),
            const SizedBox(height: 20),
          ],

          // Score bars
          _ScoreBar(label: context.tr('Qualification'), score: app.aiQualificationScore),
          const SizedBox(height: 10),
          _ScoreBar(label: context.tr('Experience'), score: app.aiExperienceScore),
          const SizedBox(height: 10),
          _ScoreBar(label: context.tr('Skills Match'), score: app.aiSkillsScore),
          const SizedBox(height: 10),
          _ScoreBar(label: context.tr('Communication'), score: app.aiCommunicationScore),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double? score;
  const _ScoreBar({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final v = (score ?? 0) / 100;
    final color = v >= 0.8
        ? AppColors.successGreen
        : v >= 0.6
            ? AppColors.primaryBlue
            : v >= 0.4
                ? AppColors.warningAmber
                : AppColors.errorRed;

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: context.appSubtext)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              backgroundColor: context.appBorder,
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text('${score?.toInt() ?? 0}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}

// ── Strengths & Concerns ──────────────────────────────────────────────────────
class _StrengthsConcerns extends StatelessWidget {
  final ApplicationModel app;
  const _StrengthsConcerns({required this.app});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (app.aiStrengths.isNotEmpty)
          Expanded(
            child: _Card(
              title: context.tr('Strengths'),
              child: Column(
                children: app.aiStrengths.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: AppIcon(AppIcons.checkCircleRounded,
                            color: AppColors.successGreen, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s,
                              style: TextStyle(fontSize: 13, color: context.appText, height: 1.5))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        if (app.aiStrengths.isNotEmpty && app.aiConcerns.isNotEmpty)
          const SizedBox(width: 12),
        if (app.aiConcerns.isNotEmpty)
          Expanded(
            child: _Card(
              title: context.tr('Concerns'),
              child: Column(
                children: app.aiConcerns.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: AppIcon(AppIcons.warningAmberRounded,
                            color: AppColors.warningAmber, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(c,
                              style: TextStyle(fontSize: 13, color: context.appText, height: 1.5))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Applicant info card ───────────────────────────────────────────────────────
class _ApplicantInfo extends StatelessWidget {
  final ApplicationModel app;
  const _ApplicantInfo({required this.app});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: context.tr('Applicant'),
      child: Column(
        children: [
          _InfoRow(icon: AppIcons.emailOutlined, label: app.email),
          _InfoRow(icon: AppIcons.phoneOutlined, label: app.phone),
          _InfoRow(
              icon: AppIcons.workHistoryOutlined,
              label: '${app.yearsExperience} years experience'),
          if (app.status == 'declined' && app.rejectionSentAt != null)
            _InfoRow(
              icon: AppIcons.mailOutlined,
              label: 'Rejection sent ${DateFormat('dd MMM').format(app.rejectionSentAt!)}',
              color: AppColors.errorRed,
            ),
          if (app.interviewInviteSentAt != null)
            _InfoRow(
              icon: AppIcons.sendRounded,
              label: 'Invite sent ${DateFormat('dd MMM').format(app.interviewInviteSentAt!)}',
              color: AppColors.successGreen,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconRef icon;
  final String label;
  final Color? color;
  const _InfoRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.appSubtext;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AppIcon(icon, size: 14, color: c),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: c),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ── Interview info card ───────────────────────────────────────────────────────
class _InterviewInfo extends StatelessWidget {
  final ApplicationModel app;
  const _InterviewInfo({required this.app});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: context.tr('Interview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.interviewDate != null)
            _InfoRow(icon: AppIcons.calendarTodayOutlined, label: app.interviewDate!),
          if (app.interviewTime != null)
            _InfoRow(icon: AppIcons.accessTimeRounded, label: app.interviewTime!),
          if (app.interviewLocation != null)
            _InfoRow(icon: AppIcons.locationOnOutlined, label: app.interviewLocation!),
        ],
      ),
    );
  }
}

// ── Shortlist dialog ──────────────────────────────────────────────────────────
class _ShortlistDialog extends ConsumerStatefulWidget {
  final ApplicationModel app;
  final String jobId;
  const _ShortlistDialog({required this.app, required this.jobId});

  @override
  ConsumerState<_ShortlistDialog> createState() => _ShortlistDialogState();
}

class _ShortlistDialogState extends ConsumerState<_ShortlistDialog> {
  bool _sendInvite = false;
  DateTime? _interviewDate;
  final _timeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(recruitmentNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shortlist ${widget.app.applicantName}',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: context.appText)),
            const SizedBox(height: 15),
            Text(context.tr('The applicant will be moved to Shortlisted status.'),
                style: TextStyle(fontSize: 13, color: context.appSubtext)),
            const SizedBox(height: 16),
            Row(
              children: [
                Switch(
                  value: _sendInvite,
                  onChanged: (v) => setState(() => _sendInvite = v),
                  activeColor: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Text(context.tr('Also send interview invitation email'),
                    style: TextStyle(fontSize: 13, color: context.appText)),
              ],
            ),
            if (_sendInvite) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 3)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (d != null) setState(() => _interviewDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appField,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.calendarTodayOutlined, size: 16, color: context.appSubtext),
                      const SizedBox(width: 8),
                      Text(
                        _interviewDate != null
                            ? DateFormat('dd MMM yyyy').format(_interviewDate!)
                            : 'Select interview date *',
                        style: TextStyle(
                            fontSize: 13,
                            color: _interviewDate != null
                                ? context.appText
                                : context.appSubtext),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              HRNovaTextField(
                label: '',
                controller: _timeCtrl,
                hint: context.tr('Time (e.g. 10:00 AM)'),
                prefixIcon: AppIcons.accessTimeRounded,
              ),
              const SizedBox(height: 8),
              HRNovaTextField(
                label: '',
                controller: _locationCtrl,
                hint: context.tr('Location or meeting link'),
                prefixIcon: AppIcons.locationOnOutlined,
              ),
            ],
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HRNovaButton.text(
                  label: context.tr('Cancel'),
                  onPressed: () => Navigator.pop(context),
                  textColor: context.appSubtext,
                ),
                HRNovaButton(
                  label: _sendInvite ? 'Shortlist & Send Invite' : 'Shortlist',
                  isFullWidth: false,
                  isLoading: notifier.loading,
                  backgroundColor: AppColors.successGreen,
                  onPressed: notifier.loading
                      ? null
                      : () async {
                          if (_sendInvite && _interviewDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('Please select an interview date'))));
                            return;
                          }
                          final ok = await ref
                              .read(recruitmentNotifierProvider.notifier)
                              .shortlistApplication(
                                appId: widget.app.id,
                                jobId: widget.jobId,
                                sendInvite: _sendInvite,
                                interviewDate: _interviewDate != null
                                    ? DateFormat('dd MMM yyyy').format(_interviewDate!)
                                    : null,
                                interviewTime: _timeCtrl.text.trim().isNotEmpty
                                    ? _timeCtrl.text.trim()
                                    : null,
                                interviewLocation: _locationCtrl.text.trim().isNotEmpty
                                    ? _locationCtrl.text.trim()
                                    : null,
                              );
                          if (mounted && ok) Navigator.pop(context);
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card wrapper ──────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: context.appText)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS — exported for use in job_posting_screen.dart
// ══════════════════════════════════════════════════════════════════════════════

class AiScoreBadge extends StatelessWidget {
  final int score;
  final bool large;
  const AiScoreBadge({super.key, required this.score, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.successGreen
        : score >= 60
            ? AppColors.primaryBlue
            : score >= 40
                ? AppColors.warningAmber
                : AppColors.errorRed;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text('$score',
          style: TextStyle(
              fontSize: large ? 20 : 14,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class RecommendationBadge extends StatelessWidget {
  final String? recommendation;
  const RecommendationBadge({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (recommendation) {
      'accept' => (context.pillGreenBg, context.pillGreenText, 'Strong Match'),
      'review' => (context.pillBlueBg, context.pillBlueText, 'Review'),
      'reject' => (context.pillRedBg, context.pillRedText, 'Not Suitable'),
      _ => (context.pillNavyBg, context.pillNavyText, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}
