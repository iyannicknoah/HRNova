import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../auth/providers/auth_provider.dart';
import '../../branches/models/branch_model.dart';
import '../../branches/providers/branches_provider.dart';
import '../models/leave_request_model.dart';
import '../providers/leave_provider.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

Color _leaveColor(String t) => switch (t) {
      'annual' => AppColors.primaryBlue,
      'sick' => AppColors.successGreen,
      'maternity' => const Color(0xFF9C27B0),
      'paternity' => const Color(0xFF00897B),
      'unpaid' => AppColors.textSecondary,
      'emergency' => AppColors.errorRed,
      'compassionate' => const Color(0xFFFF9800),
      _ => AppColors.textSecondary,
    };

String _typeLabel(String t) => switch (t) {
      'annual' => 'Annual',
      'sick' => 'Sick',
      'maternity' => 'Maternity',
      'paternity' => 'Paternity',
      'unpaid' => 'Unpaid',
      'emergency' => 'Emergency',
      'compassionate' => 'Compassionate',
      _ => t,
    };

String _srcLabel(String s) => switch (s) {
      'mobile_app' => 'Mobile',
      'whatsapp_portal' => 'WhatsApp',
      'web_dashboard' => 'Web',
      _ => s,
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late bool _isTopHr;

  @override
  void initState() {
    super.initState();
    final role = ref.read(currentUserRoleProvider) ?? '';
    _isTopHr = role == AppConstants.roleHrAdmin || role == AppConstants.roleGroupHrAdmin;
    _tabs = TabController(length: _isTopHr ? 2 : 3, vsync: this);
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
          _LeaveHeader(),
          _LeaveTabBar(controller: _tabs, isTopHr: _isTopHr),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _isTopHr
                  ? const [
                      _AllRequestsTab(showBranchFilter: true),
                      _CalendarTab(),
                    ]
                  : const [
                      _PendingTab(),
                      _AllRequestsTab(showBranchFilter: false),
                      _CalendarTab(),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _LeaveHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 16),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Leave Management',
              style: TextStyle(
                  color: context.appText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text('Review, approve and track employee leave',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),
      ]),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _LeaveTabBar extends StatelessWidget {
  const _LeaveTabBar({required this.controller, required this.isTopHr});
  final TabController controller;
  final bool isTopHr;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.appCard),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: context.appSubtext,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        indicatorColor: AppColors.primaryBlue,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        tabs: isTopHr
            ? const [Tab(text: 'All Requests'), Tab(text: 'Calendar')]
            : const [Tab(text: 'Pending Approvals'), Tab(text: 'All Requests'), Tab(text: 'Calendar')],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'pending' =>
        ('Pending', AppColors.pillAmberBg, AppColors.pillAmberText),
      'approved' =>
        ('Approved', AppColors.pillGreenBg, AppColors.pillGreenText),
      'rejected' =>
        ('Rejected', AppColors.pillRedBg, AppColors.pillRedText),
      _ => ('—', AppColors.pillNavyBg, AppColors.pillNavyText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _leaveColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(100)),
      child: Text(_typeLabel(type),
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.gradientForName(name);
    final parts = name.split(' ');
    final ini =
        parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(ini,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ── PENDING TAB ───────────────────────────────────────────────────────────────

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingLeaveRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: context.appSubtext))),
      data: (requests) => requests.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 56,
                    color: AppColors.successGreen.withAlpha(180)),
                const SizedBox(height: 12),
                Text('No pending requests',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('All leave requests have been processed.',
                    style: TextStyle(
                        color: context.appSubtext, fontSize: 15)),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: requests
                    .map((r) => SizedBox(
                          width: 400,
                          child: _PendingCard(request: r),
                        ))
                    .toList(),
              ),
            ),
    );
  }
}

// ── Pending Card ──────────────────────────────────────────────────────────────

class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.request});
  final LeaveRequestModel request;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _loading = false;
  final _dateF = DateFormat('MMM d, yyyy');

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(leaveNotifierProvider.notifier)
          .approveLeaveRequest(widget.request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Leave approved for ${widget.request.employeeName}'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRejectDialog() {
    showDialog(
        context: context,
        builder: (_) => _RejectDialog(request: widget.request));
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final color = _leaveColor(req.leaveType);

    return Container(
      decoration: context.cardDeco(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _InitialsAvatar(name: req.employeeName, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.employeeName,
                              style: TextStyle(
                                  color: context.appText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _TypeBadge(req.leaveType),
                            const SizedBox(width: 8),
                            Text(() {
                                  final d = req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1;
                                  return '$d day${d != 1 ? "s" : ""}';
                                }(),
                                style: TextStyle(
                                    color: context.appSubtext, fontSize: 14)),
                            const SizedBox(width: 6),
                            Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: context.appSubtext,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(_srcLabel(req.source),
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 14)),
                          ]),
                        ]),
                  ),
                  Text(_dateF.format(req.requestedAt),
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 14)),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FROM',
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(_dateF.format(req.startDate),
                                style: TextStyle(
                                    color: context.appText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: context.appSubtext),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('TO',
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 3),
                            Text(_dateF.format(req.endDate),
                                style: TextStyle(
                                    color: context.appText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ]),
                ),
                if (req.reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Reason: ${req.reason}',
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: _loading ? null : _showRejectDialog,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.errorRed.withAlpha(180)),
                      foregroundColor: AppColors.errorRed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      minimumSize: const Size(90, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _loading ? null : _approve,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      minimumSize: const Size(90, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ]),
              ]),
        ),
      ]),
    );
  }
}

// ── Reject Dialog ─────────────────────────────────────────────────────────────

class _RejectDialog extends ConsumerStatefulWidget {
  const _RejectDialog({required this.request});
  final LeaveRequestModel request;

  @override
  ConsumerState<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends ConsumerState<_RejectDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a reason')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(leaveNotifierProvider.notifier)
          .rejectLeaveRequest(widget.request, reason);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave request declined')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.appCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.pillRedBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.cancel_rounded,
                        color: AppColors.errorRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Decline Leave Request',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: context.appSubtext),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                    'Declining ${widget.request.employeeName}\'s ${_typeLabel(widget.request.leaveType)} leave request.',
                    style: TextStyle(
                        color: context.appSubtext, fontSize: 15)),
                const SizedBox(height: 16),
                Text('Reason for declining *',
                    style: TextStyle(
                        color: context.appSubtext,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  autofocus: true,
                  style: TextStyle(color: context.appText, fontSize: 15),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Critical deadline, insufficient notice…',
                    hintStyle: TextStyle(color: context.appSubtext),
                    filled: true,
                    fillColor: context.appField,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: context.appBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: context.appBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.errorRed, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.appBorder),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(color: context.appText)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : _reject,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Decline',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ── ALL REQUESTS TAB ──────────────────────────────────────────────────────────

class _AllRequestsTab extends ConsumerStatefulWidget {
  const _AllRequestsTab({this.showBranchFilter = false});
  final bool showBranchFilter;

  @override
  ConsumerState<_AllRequestsTab> createState() => _AllRequestsTabState();
}

class _AllRequestsTabState extends ConsumerState<_AllRequestsTab> {
  String _search = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  String? _branchFilter;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allLeaveRequestsProvider);
    final all = requestsAsync.value ?? [];
    final branches = widget.showBranchFilter
        ? (ref.watch(branchesStreamProvider).valueOrNull ?? <BranchModel>[])
        : <BranchModel>[];

    final filtered = all.where((r) {
      final q = _search.toLowerCase();
      final nameOk = q.isEmpty || r.employeeName.toLowerCase().contains(q);
      final typeOk = _typeFilter == 'All' || r.leaveType == _typeFilter;
      final statusOk = _statusFilter == 'All' || r.status == _statusFilter;
      final branchOk = _branchFilter == null || r.branchId == _branchFilter;
      return nameOk && typeOk && statusOk && branchOk;
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: context.appText, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  hintStyle: TextStyle(color: context.appSubtext, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: context.appSubtext),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (widget.showBranchFilter && branches.isNotEmpty) ...[
            _FilterDrop(
              value: _branchFilter ?? 'all',
              items: ['all', ...branches.map((b) => b.id)],
              labels: ['All Branches', ...branches.map((b) => b.name)],
              onChanged: (v) => setState(() => _branchFilter = v == 'all' ? null : v),
            ),
            const SizedBox(width: 10),
          ],
          _FilterDrop(
            value: _typeFilter,
            items: const [
              'All', 'annual', 'sick', 'maternity', 'paternity', 'unpaid', 'emergency', 'compassionate'
            ],
            labels: const [
              'All Types', 'Annual', 'Sick', 'Maternity', 'Paternity', 'Unpaid', 'Emergency', 'Compassionate'
            ],
            onChanged: (v) => setState(() => _typeFilter = v),
          ),
          const SizedBox(width: 10),
          _FilterDrop(
            value: _statusFilter,
            items: const ['All', 'pending', 'approved', 'rejected'],
            labels: const ['All Status', 'Pending', 'Approved', 'Rejected'],
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(width: 10),
          Text('${filtered.length} result${filtered.length != 1 ? "s" : ""}',
              style: TextStyle(color: context.appSubtext, fontSize: 15)),
        ]),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: context.appTint,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: _tableHeader(context),
            ),
            Divider(height: 1, color: context.appBorder),
            Expanded(
              child: requestsAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text('No requests found',
                              style: TextStyle(
                                  color: context.appSubtext,
                                  fontSize: 15)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: context.appBorder),
                          itemBuilder: (_, i) =>
                              _RequestRow(request: filtered[i]),
                        ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _tableHeader(BuildContext context) {
    final s = TextStyle(
        color: context.appSubtext,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5);
    return Row(children: [
      Expanded(flex: 24, child: Text('EMPLOYEE', style: s)),
      Expanded(flex: 12, child: Text('TYPE', style: s)),
      Expanded(flex: 12, child: Text('FROM', style: s)),
      Expanded(flex: 12, child: Text('TO', style: s)),
      Expanded(flex: 7, child: Text('DAYS', style: s)),
      Expanded(flex: 10, child: Text('STATUS', style: s)),
      Expanded(flex: 7, child: Text('SOURCE', style: s)),
    ]);
  }
}

class _RequestRow extends StatefulWidget {
  const _RequestRow({required this.request});
  final LeaveRequestModel request;

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _expanded = false;
  final _dateF = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        hoverColor: context.appTint,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Expanded(
              flex: 24,
              child: Row(children: [
                _InitialsAvatar(name: req.employeeName, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(req.employeeName,
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            Expanded(flex: 12, child: Align(alignment: Alignment.centerLeft, child: _TypeBadge(req.leaveType))),
            Expanded(
              flex: 12,
              child: Text(_dateF.format(req.startDate),
                  style: TextStyle(
                      color: context.appText, fontSize: 14)),
            ),
            Expanded(
              flex: 12,
              child: Text(_dateF.format(req.endDate),
                  style: TextStyle(
                      color: context.appText, fontSize: 14)),
            ),
            Expanded(
              flex: 7,
              child: Text(() {
                  final d = req.totalDays > 0 ? req.totalDays : req.endDate.difference(req.startDate).inDays + 1;
                  return '${d}d';
                }(),
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(flex: 10, child: Align(alignment: Alignment.centerLeft, child: _StatusBadge(req.status))),
            Expanded(
              flex: 7,
              child: Text(_srcLabel(req.source),
                  style: TextStyle(
                      color: context.appSubtext, fontSize: 14)),
            ),
          ]),
        ),
      ),
      if (_expanded) ...[
        Divider(height: 1, color: context.appBorder),
        Container(
          color: context.appTint,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (req.reason.isNotEmpty)
              _detail('Reason', req.reason, context),
            if (req.rejectedReason != null)
              _detail('Decline Reason', req.rejectedReason!, context,
                  color: AppColors.errorRed),
            _detail('Submitted',
                DateFormat('MMM d, yyyy HH:mm').format(req.requestedAt),
                context),
            if (req.approvedAt != null)
              _detail('Approved',
                  DateFormat('MMM d, yyyy HH:mm').format(req.approvedAt!),
                  context),
          ]),
        ),
      ],
    ]);
  }

  Widget _detail(String label, String value, BuildContext context,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    color: context.appSubtext,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: color ?? context.appText,
                      fontSize: 14))),
        ]),
      );
}

class _FilterDrop extends StatelessWidget {
  const _FilterDrop({
    required this.value,
    required this.items,
    required this.labels,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safe,
          isDense: true,
          dropdownColor: context.appCard,
          style: TextStyle(color: context.appText, fontSize: 14),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: context.appSubtext),
          items: items
              .asMap()
              .entries
              .map((e) => DropdownMenuItem(
                    value: e.value,
                    child: Text(labels[e.key],
                        style: TextStyle(
                            color: context.appText, fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// ── CALENDAR TAB ──────────────────────────────────────────────────────────────

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month);

  static const _weekDays = [
    'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
  ];

  @override
  Widget build(BuildContext context) {
    final calAsync = ref.watch(leavesCalendarByMonthProvider(
        (year: _month.year, month: _month.month)));
    final calEntries = calAsync.value ?? [];

    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final entry in calEntries) {
      final date = entry['date'] as String? ?? '';
      if (date.isNotEmpty) byDate.putIfAbsent(date, () => []).add(entry);
    }

    final firstDay = DateTime(_month.year, _month.month, 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + lastDay.day;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          _navBtn(Icons.chevron_left_rounded,
              () => setState(() =>
                  _month = DateTime(_month.year, _month.month - 1)),
              context),
          const SizedBox(width: 12),
          Text(DateFormat('MMMM yyyy').format(_month),
              style: TextStyle(
                  color: context.appText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _navBtn(Icons.chevron_right_rounded,
              () => setState(() =>
                  _month = DateTime(_month.year, _month.month + 1)),
              context),
          const Spacer(),
          ...[
            ('Annual', AppColors.primaryBlue),
            ('Sick', AppColors.successGreen),
            ('Maternity', const Color(0xFF9C27B0)),
            ('Paternity', const Color(0xFF00897B)),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: item.$2,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 5),
                  Text(item.$1,
                      style: TextStyle(
                          color: context.appSubtext, fontSize: 13)),
                ]),
              )),
        ]),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                color: context.appTint,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: Row(
                children: _weekDays
                    .map((d) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Text(d,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: context.appSubtext,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Divider(height: 1, color: context.appBorder),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.3,
                ),
                itemCount: totalCells,
                itemBuilder: (_, index) {
                  if (index < startOffset) {
                    return Container(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: context.appBorder.withAlpha(40),
                                width: 0.5)));
                  }
                  final day = index - startOffset + 1;
                  final dateStr =
                      '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final entries = byDate[dateStr] ?? [];
                  final now = DateTime.now();
                  final isToday = now.year == _month.year &&
                      now.month == _month.month &&
                      now.day == day;

                  return _CalendarCell(
                      day: day, entries: entries, isToday: isToday);
                },
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, BuildContext ctx) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: ctx.appCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ctx.appBorder)),
          child: Icon(icon, color: ctx.appText, size: 18),
        ),
      );
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell(
      {required this.day, required this.entries, required this.isToday});
  final int day;
  final List<Map<String, dynamic>> entries;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final visible = entries.take(2).toList();
    final more = entries.length - visible.length;

    return Container(
      decoration: BoxDecoration(
          border: Border.all(
              color: context.appBorder.withAlpha(50), width: 0.5)),
      padding: const EdgeInsets.fromLTRB(5, 5, 4, 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          decoration: isToday
              ? const BoxDecoration(
                  color: AppColors.primaryBlue, shape: BoxShape.circle)
              : null,
          child: Center(
            child: Text('$day',
                style: TextStyle(
                    color: isToday ? Colors.white : context.appSubtext,
                    fontSize: 13,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400)),
          ),
        ),
        if (visible.isNotEmpty) ...[
          const SizedBox(height: 3),
          ...visible.map((e) {
            final type = e['leaveType'] as String? ?? '';
            final name = e['employeeName'] as String? ?? '';
            final first = name.split(' ').first;
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _leaveColor(type).withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border(
                    left: BorderSide(
                        color: _leaveColor(type), width: 2)),
              ),
              child: Text(first,
                  style: TextStyle(
                      color: _leaveColor(type),
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            );
          }),
          if (more > 0)
            Text('+$more more',
                style: TextStyle(
                    color: context.appSubtext, fontSize: 9)),
        ],
      ]),
    );
  }
}
