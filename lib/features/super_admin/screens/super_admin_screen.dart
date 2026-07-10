import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/branch_model.dart';
import '../models/company_model.dart';
import '../providers/super_admin_provider.dart';
import '../services/super_admin_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/confirm_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────

class _P {
  final Color bg, card, border, text, subText, fieldBg;
  final bool dark;
  const _P({
    required this.bg, required this.card, required this.border,
    required this.text, required this.subText, required this.fieldBg,
    required this.dark,
  });

  static _P of(BuildContext ctx) {
    final d = Theme.of(ctx).brightness == Brightness.dark;
    return d
        ? const _P(
            bg: AppColors.darkBackground, card: AppColors.darkBackground,
            border: Color(0xFF2A3236), text: Colors.white,
            subText: AppColors.textSecondary, fieldBg: AppColors.darkCard,
            dark: true)
        : const _P(
            bg: Colors.white, card: Colors.white,
            border: AppColors.cardBorder, text: Color(0xFF0A1628),
            subText: AppColors.textSecondary, fieldBg: AppColors.lightBlue50,
            dark: false);
  }

  BoxDecoration get card16 => _cardDeco(18);
  BoxDecoration cardR(double r) => _cardDeco(r);

  BoxDecoration _cardDeco(double r) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: border, width: 1),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmt(int n) {
  if (n == 0) return '—';
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'RWF ${b.toString()}';
}

void _showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: AppColors.errorRed,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

Future<void> _showSuccessDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(80),
    builder: (ctx) => _SuccessDialog(message: message),
  );
}

class _SuccessDialog extends StatefulWidget {
  final String message;
  const _SuccessDialog({required this.message});
  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 30, offset: const Offset(0, 10)),
          ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 100, height: 100,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: const BoxDecoration(
                  color: Color(0x281E8CFF), shape: BoxShape.circle)),
              Container(
                width: 78, height: 78,
                decoration: const BoxDecoration(
                  color: Color(0x451E8CFF), shape: BoxShape.circle)),
              Container(
                width: 58, height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue, shape: BoxShape.circle),
                child: const AppIcon(AppIcons.checkRounded,
                  color: Colors.white, size: 32)),
            ])),
          const SizedBox(height: 20),
          Text(widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

enum _PayStatus { paid, pending, notPaid }

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconRef? icon;
  final bool outline;
  final bool fullWidth;
  const _Btn({
    required this.label, this.onTap, this.color,
    this.icon, this.outline = false, this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryBlue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: outline ? c.withAlpha(18) : c,
            borderRadius: BorderRadius.circular(100),
            boxShadow: outline ? null : [
              BoxShadow(color: c.withAlpha(55),
                blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, color: outline ? c : Colors.white, size: 17),
                const SizedBox(width: 7),
              ],
              Text(label, style: TextStyle(
                color: outline ? c : Colors.white,
                fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value, label;
  const _KpiCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: p.cardR(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          color: p.subText,
          fontSize: 14, fontWeight: FontWeight.w400)),
        const SizedBox(height: 14),
        Text(value, style: TextStyle(
          color: p.text, fontSize: 22,
          fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1)),
      ]),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isMulti;
  const _TypeBadge(this.isMulti);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: isMulti
        ? AppColors.primaryBlue.withAlpha(18)
        : AppColors.textSecondary.withAlpha(18),
      borderRadius: BorderRadius.circular(100)),
    child: Text(isMulti ? 'Multi-Branch' : 'Single',
      style: TextStyle(
        color: isMulti ? AppColors.primaryBlue : AppColors.textSecondary,
        fontSize: 13, fontWeight: FontWeight.w600)));
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot(this.active);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
    Container(width: 7, height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.successGreen : AppColors.errorRed)),
    const SizedBox(width: 6),
    Text(active ? 'Active' : 'Suspended',
      style: TextStyle(
        color: active ? AppColors.successGreen : AppColors.errorRed,
        fontSize: 14, fontWeight: FontWeight.w600)),
  ]);
}

class _PayBadge extends StatelessWidget {
  final _PayStatus status;
  const _PayBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      _PayStatus.paid    => (AppColors.successGreen, 'Paid'),
      _PayStatus.pending => (AppColors.warningAmber, 'Pending'),
      _PayStatus.notPaid => (AppColors.errorRed,     'Not Paid'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]));
  }
}

class _TH extends StatelessWidget {
  final String t;
  const _TH(this.t);
  @override
  Widget build(BuildContext context) => Text(t.toUpperCase(),
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

class _IRow extends StatelessWidget {
  final String label, value;
  const _IRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        SizedBox(width: 148,
          child: Text(label, style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(
          color: p.text,
          fontSize: 15, fontWeight: FontWeight.w500))),
      ]));
  }
}

class _SDivider extends StatelessWidget {
  final String label;
  const _SDivider(this.label);
  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        Text(label, style: TextStyle(
          color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: p.border, height: 1)),
      ]));
  }
}

class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onChange;
  const _FilterChip(this.label, this.value, this.current, this.onChange);
  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final active = value == current;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBlue : p.card,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: active ? AppColors.primaryBlue : p.border)),
          child: Text(label, style: TextStyle(
            color: active ? Colors.white : p.subText,
            fontSize: 14, fontWeight: FontWeight.w500)))));
  }
}

class _CoAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _CoAvatar(this.name, {this.size = 48});
  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? 'A' : name[0].toUpperCase();
    final colors = AppColors.avatarGradients[letter] ?? AppColors.avatarGradients['A']!;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(child: Text(letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42, fontWeight: FontWeight.w700))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
enum _View { dashboard, companies, billing }

class _Sidebar extends StatelessWidget {
  final _View view;
  final bool panelOpen;
  final VoidCallback onDashboard, onCompanies, onBilling;
  const _Sidebar({required this.view, required this.panelOpen,
    required this.onDashboard, required this.onCompanies,
    required this.onBilling});

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'super@hrnova.rw';

    return Container(
      decoration: BoxDecoration(
        color: context.appCard,
        border: Border(right: BorderSide(color: context.alternate)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Logo area
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                context.isDark
                    ? 'assets/icon/icon_dark.png'
                    : 'assets/icon/icon_light.png',
                width: 22,
                height: 22,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text('HRNovva', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3,
              color: context.appText)),
          ]),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, thickness: 1, color: context.alternate),
        const SizedBox(height: 16),
        // Nav items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _SItem(icon: AppIcons.homeRounded,         label: 'Dashboard',
                active: view == _View.dashboard && !panelOpen, onTap: onDashboard),
              _SItem(icon: AppIcons.businessRounded,     label: 'Companies',
                active: view == _View.companies || panelOpen,  onTap: onCompanies),
              _SItem(icon: AppIcons.receiptLongRounded, label: 'Billing',
                active: view == _View.billing && !panelOpen,   onTap: onBilling),
            ],
          ),
        ),
        // Profile container
        Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.appTint,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF0066CC)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const AppIcon(AppIcons.adminPanelSettingsRounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Super Admin', style: TextStyle(
                color: context.appText, fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(userEmail, style: TextStyle(
                color: context.appSubtext, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Log out?',
                  message: 'Are you sure you want to log out of your account?',
                  confirmLabel: 'Log Out',
                  danger: true,
                );
                if (confirmed) {
                  FirebaseAuth.instance.signOut();
                }
              },
              child: Tooltip(
                message: 'Sign Out',
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: context.appBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppIcon(AppIcons.logoutRounded, size: 16, color: context.appSubtext),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }
}

class _SItem extends StatelessWidget {
  final IconRef icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SItem({required this.icon, required this.label,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Color.alphaBlend(context.appText.withAlpha(40), context.appSubtext);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: context.appTint,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.primaryBlue.withAlpha(20) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              AppIcon(icon,
                size: 18,
                color: active ? AppColors.primaryBlue : inactiveColor),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                color: active ? AppColors.primaryBlue : inactiveColor,
                fontSize: 15,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  final _View view;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  const _TopBar({required this.view, required this.searchQuery,
    required this.onSearchChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = _P.of(context);
    final title = switch (view) {
      _View.dashboard => 'Dashboard',
      _View.companies => 'Companies',
      _View.billing   => 'Billing',
    };
    final showSearch = view != _View.billing;
    return Container(
      color: p.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Text(title, style: TextStyle(
          color: p.text, fontSize: 20, fontWeight: FontWeight.w600,
          letterSpacing: -0.3)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(20),
            borderRadius: BorderRadius.circular(100)),
          child: const Text('Super Admin', style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 13, fontWeight: FontWeight.w600))),
        const Spacer(),
        if (showSearch) ...[
          SizedBox(
            width: 280, height: 44,
            child: TextField(
              onChanged: onSearchChanged,
              style: TextStyle(color: p.text, fontSize: 15),
              decoration: InputDecoration(
                filled: true, fillColor: p.card,
                hintText: 'Search companies…',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
                prefixIcon: const AppIcon(AppIcons.searchRounded,
                  color: AppColors.textSecondary, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: p.border)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: p.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => ref.read(themeNotifierProvider.notifier).toggle(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: p.cardR(100),
              child: AppIcon(
                p.dark ? AppIcons.lightModeRounded : AppIcons.darkModeRounded,
                color: p.dark ? AppColors.warningAmber : AppColors.textSecondary,
                size: 16)))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  ConsumerState<SuperAdminScreen> createState() => _SAState();
}

class _SAState extends ConsumerState<SuperAdminScreen> {
  _View         _view           = _View.dashboard;
  String        _searchQ        = '';
  String?       _detailId;
  BranchModel?  _selectedBranch;
  bool          _addCoOpen      = false;

  void _nav(_View v) => setState(() {
    _view = v; _searchQ = ''; _detailId = null;
    _selectedBranch = null; _addCoOpen = false;
  });

  void _openDetail(String id) => setState(() {
    _detailId = id; _selectedBranch = null; _addCoOpen = false;
  });

  void _openBranch(BranchModel branch) =>
      setState(() { _selectedBranch = branch; _addCoOpen = false; });

  void _closeDetail() => setState(() {
    _detailId = null; _selectedBranch = null;
  });

  void _closeBranch() => setState(() => _selectedBranch = null);

  void _openAddCompany() => setState(() {
    _addCoOpen = true; _detailId = null; _selectedBranch = null;
  });

  void _closeAddCo() => setState(() => _addCoOpen = false);

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final companies = ref.watch(companiesStreamProvider).valueOrNull ?? [];
    CompanyModel? selectedCo;
    if (_detailId != null) {
      for (final c in companies) {
        if (c.id == _detailId) { selectedCo = c; break; }
      }
    }
    final bool anyPanelOpen = _detailId != null || _selectedBranch != null || _addCoOpen;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(fit: StackFit.expand, children: [

        Positioned(left: 0, top: 0, bottom: 0, width: 220,
          child: _Sidebar(
            view: _view, panelOpen: anyPanelOpen,
            onDashboard: () => _nav(_View.dashboard),
            onCompanies: () => _nav(_View.companies),
            onBilling:   () => _nav(_View.billing),
          )),

        Positioned(left: 220, top: 0, right: 0, height: 64,
          child: _TopBar(
            view: _view,
            searchQuery: _searchQ,
            onSearchChanged: (v) => setState(() => _searchQ = v),
          )),

        Positioned(left: 220, top: 64, right: 0, bottom: 0,
          child: _page(p)),

        if (_selectedBranch != null && selectedCo != null)
          Positioned(left: 220, top: 0, right: 0, bottom: 0,
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _closeDetail,
                child: Container(color: Colors.black.withAlpha(100)))),
              _BranchDetailPanel(
                branch: _selectedBranch!,
                coName: selectedCo.name,
                onClose: _closeDetail,
                onBack:  _closeBranch,
              ),
            ])),

        if (_selectedBranch == null && selectedCo != null)
          Positioned(left: 220, top: 0, right: 0, bottom: 0,
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _closeDetail,
                child: Container(color: Colors.black.withAlpha(100)))),
              _CoDetailPanel(
                co: selectedCo,
                onClose: _closeDetail,
                onBranch: _openBranch,
              ),
            ])),

        if (_addCoOpen)
          Positioned(left: 0, top: 0, right: 0, bottom: 0,
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _closeAddCo,
                child: Container(color: Colors.black.withAlpha(100)))),
              _AddCoPanel(onClose: _closeAddCo),
            ])),

      ]),
    );
  }

  Widget _page(_P p) => switch (_view) {
    _View.dashboard => _DashView(
        searchQuery: _searchQ,
        onAdd:     _openAddCompany,
        onViewAll: () => _nav(_View.companies),
        onDetail:  _openDetail,
      ),
    _View.companies => _CompaniesView(
        searchQuery: _searchQ,
        onAdd:    _openAddCompany,
        onDetail: _openDetail,
      ),
    _View.billing => const _BillingView(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DashView extends ConsumerWidget {
  final String searchQuery;
  final VoidCallback onAdd, onViewAll;
  final ValueChanged<String> onDetail;
  const _DashView({required this.searchQuery, required this.onAdd,
    required this.onViewAll, required this.onDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = _P.of(context);
    final async = ref.watch(companiesStreamProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
        style: const TextStyle(color: AppColors.errorRed))),
      data: (companies) {
        final q = searchQuery.toLowerCase();
        final recent = companies.where((c) =>
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.industry.toLowerCase().contains(q)).take(5).toList();
        final total     = companies.length;
        final active    = companies.where((c) => c.isActive).length;
        final suspended = total - active;
        final revenue   = companies.where((c) => c.isActive)
            .fold(0, (s, c) => s + c.monthlyPrice);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(children: [
              Text('Overview', style: TextStyle(
                color: p.subText, fontSize: 15, fontWeight: FontWeight.w400)),
              const Spacer(),
              _Btn(label: 'Add Company', icon: AppIcons.addRounded, onTap: onAdd),
            ])),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              Expanded(child: _KpiCard(value: '$total',      label: 'Total Companies')),
              const SizedBox(width: 14),
              Expanded(child: _KpiCard(value: '$active',     label: 'Active')),
              const SizedBox(width: 14),
              Expanded(child: _KpiCard(value: '$suspended',  label: 'Suspended')),
              const SizedBox(width: 14),
              Expanded(child: _KpiCard(value: _fmt(revenue), label: 'Monthly Revenue')),
            ])),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            child: Row(children: [
              Text('Recent Companies', style: TextStyle(
                color: p.text, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(18),
                  borderRadius: BorderRadius.circular(100)),
                child: Text('${companies.length}', style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 15, fontWeight: FontWeight.w600))),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onViewAll,
                  child: const Text('View all →',
                    style: TextStyle(color: AppColors.primaryBlue,
                      fontSize: 15, fontWeight: FontWeight.w600)))),
            ])),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                decoration: p.card16,
                child: _CoTable(
                  rows: recent,
                  columns: _CoTableCols.dashboard,
                  onDetail: onDetail,
                  onAdd: onAdd,
                )))),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANIES VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _CompaniesView extends ConsumerStatefulWidget {
  final String searchQuery;
  final VoidCallback onAdd;
  final ValueChanged<String> onDetail;
  const _CompaniesView({required this.searchQuery, required this.onAdd,
    required this.onDetail});
  @override
  ConsumerState<_CompaniesView> createState() => _CompaniesViewState();
}

class _CompaniesViewState extends ConsumerState<_CompaniesView> {
  String _chip = 'all';
  String _sort = 'newest';

  List<CompanyModel> _filtered(List<CompanyModel> all) {
    var list = all.where((c) {
      final q = widget.searchQuery.toLowerCase();
      final matchQ = q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        c.industry.toLowerCase().contains(q);
      final matchChip = _chip == 'all' ||
        (_chip == 'single'       && !c.isMulti) ||
        (_chip == 'multi_branch' &&  c.isMulti) ||
        (_chip == 'active'       &&  c.isActive) ||
        (_chip == 'suspended'    && !c.isActive);
      return matchQ && matchChip;
    }).toList();
    switch (_sort) {
      case 'price_high': list.sort((a, b) => b.monthlyPrice.compareTo(a.monthlyPrice));
      case 'price_low':  list.sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
      case 'name':       list.sort((a, b) => a.name.compareTo(b.name));
      default: break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final async = ref.watch(companiesStreamProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
        style: const TextStyle(color: AppColors.errorRed))),
      data: (all) {
        final list = _filtered(all);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
            child: Row(children: [
              _FilterChip('All',          'all',          _chip, (v) => setState(() => _chip = v)),
              const SizedBox(width: 8),
              _FilterChip('Single',       'single',       _chip, (v) => setState(() => _chip = v)),
              const SizedBox(width: 8),
              _FilterChip('Multi-Branch', 'multi_branch', _chip, (v) => setState(() => _chip = v)),
              const SizedBox(width: 8),
              _FilterChip('Active',       'active',       _chip, (v) => setState(() => _chip = v)),
              const SizedBox(width: 8),
              _FilterChip('Suspended',    'suspended',    _chip, (v) => setState(() => _chip = v)),
              const SizedBox(width: 14),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: p.card, borderRadius: BorderRadius.circular(100)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sort,
                    dropdownColor: p.card,
                    style: TextStyle(color: p.text, fontSize: 15),
                    icon: const AppIcon(AppIcons.unfoldMoreRounded,
                      color: AppColors.textSecondary, size: 16),
                    items: const [
                      DropdownMenuItem(value: 'newest',     child: Text('Newest')),
                      DropdownMenuItem(value: 'price_high', child: Text('Price: High → Low')),
                      DropdownMenuItem(value: 'price_low',  child: Text('Price: Low → High')),
                      DropdownMenuItem(value: 'name',       child: Text('Name A–Z')),
                    ],
                    onChanged: (v) => setState(() => _sort = v!)))),
              const Spacer(),
              _Btn(label: 'Add Company', icon: AppIcons.addRounded, onTap: widget.onAdd),
            ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text('${list.length} of ${all.length} companies',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                decoration: p.card16,
                child: _CoTable(
                  rows: list,
                  columns: _CoTableCols.companies,
                  onDetail: widget.onDetail,
                  onAdd: widget.onAdd,
                )))),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPANY TABLE
// ─────────────────────────────────────────────────────────────────────────────
enum _CoTableCols { dashboard, companies }

class _CoTable extends StatelessWidget {
  final List<CompanyModel> rows;
  final _CoTableCols columns;
  final ValueChanged<String> onDetail;
  final VoidCallback onAdd;
  const _CoTable({required this.rows, required this.columns,
    required this.onDetail, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final isDash = columns == _CoTableCols.dashboard;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          const Expanded(flex: 3, child: _TH('Company')),
          const Expanded(flex: 2, child: _TH('Type')),
          if (!isDash) const Expanded(flex: 2, child: _TH('Industry')),
          const Expanded(flex: 2, child: _TH('Status')),
          const Expanded(flex: 2, child: _TH('Monthly Price')),
          Expanded(flex: 2, child: _TH(isDash ? 'Added' : 'Employees')),
          const SizedBox(width: 56),
        ])),
      Divider(height: 1, color: p.border),
      Expanded(
        child: rows.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppIcon(AppIcons.businessOutlined,
                color: p.text.withAlpha(50), size: 44),
              const SizedBox(height: 12),
              Text('No companies found',
                style: TextStyle(color: p.text.withAlpha(100), fontSize: 15)),
              const SizedBox(height: 16),
              _Btn(label: 'Add Company', icon: AppIcons.addRounded, onTap: onAdd),
            ]))
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (ctx, i) =>
                Divider(height: 1, color: p.border.withAlpha(100)),
              itemBuilder: (ctx, i) => _CoRow(
                co: rows[i], isDash: isDash,
                onView: () => onDetail(rows[i].id)))),
    ]);
  }
}

class _CoRow extends StatefulWidget {
  final CompanyModel co;
  final bool isDash;
  final VoidCallback onView;
  const _CoRow({required this.co, required this.isDash, required this.onView});
  @override
  State<_CoRow> createState() => _CoRowState();
}

class _CoRowState extends State<_CoRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final co = widget.co;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter:  (_) => setState(() => _hover = true),
      onExit:   (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover
            ? (p.dark ? const Color(0xFF122440) : const Color(0xFFF5F8FF))
            : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Expanded(flex: 3, child: Row(children: [
              _CoAvatar(co.name, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(co.name, style: TextStyle(
                color: p.text, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            ])),
            Expanded(flex: 2, child: Align(
              alignment: Alignment.centerLeft,
              child: _TypeBadge(co.isMulti))),
            if (!widget.isDash)
              Expanded(flex: 2, child: Text(co.industry,
                style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15))),
            Expanded(flex: 2, child: _StatusDot(co.isActive)),
            Expanded(flex: 2, child: Text(_fmt(co.monthlyPrice),
              style: TextStyle(
                color: p.text, fontSize: 16, fontWeight: FontWeight.w500))),
            Expanded(flex: 2, child: Text(
              widget.isDash ? co.createdAtFormatted : '${co.employeeCount}',
              style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15))),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onView,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(18),
                    borderRadius: BorderRadius.circular(10)),
                  child: const AppIcon(AppIcons.removeRedEyeRounded,
                    color: AppColors.primaryBlue, size: 18)))),
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANY DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _CoDetailPanel extends ConsumerStatefulWidget {
  final CompanyModel co;
  final VoidCallback onClose;
  final ValueChanged<BranchModel> onBranch;
  const _CoDetailPanel({required this.co, required this.onClose,
    required this.onBranch});
  @override
  ConsumerState<_CoDetailPanel> createState() => _CoDetailPanelState();
}

class _CoDetailPanelState extends ConsumerState<_CoDetailPanel> {
  bool _suspending = false;

  Future<void> _toggleStatus() async {
    final co        = widget.co;
    final newStatus = co.isActive ? 'suspended' : 'active';
    setState(() => _suspending = true);
    try {
      await SuperAdminService().updateStatus(co.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${co.name} has been ${newStatus == 'active' ? 'activated' : 'suspended'}.'),
          backgroundColor: newStatus == 'active'
            ? AppColors.successGreen : AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar(context, e.toString());
    } finally {
      if (mounted) setState(() => _suspending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p   = _P.of(context);
    final co  = widget.co;
    final brsAsync  = ref.watch(branchesProvider(co.id));
    final paysAsync = ref.watch(paymentsProvider(co.id));
    final brs = brsAsync.valueOrNull ?? [];

    return Container(
      width: 500,
      color: p.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
          color: p.card,
          child: Row(children: [
            Text('Company Details', style: TextStyle(
              color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.bg, borderRadius: BorderRadius.circular(100)),
                  child: AppIcon(AppIcons.closeRounded, color: p.subText, size: 18)))),
          ])),
        Divider(height: 1, color: p.border.withAlpha(80)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(12),
                  borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  _CoAvatar(co.name, size: 52),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(co.name, style: TextStyle(
                      color: p.text, fontSize: 20, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      _TypeBadge(co.isMulti),
                      const SizedBox(width: 8),
                      _StatusDot(co.isActive),
                    ]),
                  ])),
                ])),

              _SDivider('Company Information'),
              _IRow('Industry',   co.industry.isEmpty ? '—' : co.industry),
              _IRow('Type',       co.isMulti ? 'Multi-Branch' : 'Single Location'),
              _IRow('Address',    co.address.isEmpty ? '—' : co.address),
              _IRow('Added on',   co.createdAtFormatted),
              _IRow('Employees',  '${co.employeeCount}'),

              _SDivider('HR Administrator'),
              _IRow('Name',  co.contactPerson.isEmpty ? '—' : co.contactPerson),
              _IRow('Email', co.hrAdminEmail),
              _IRow('Phone', co.hrAdminPhone.isEmpty ? '—' : co.hrAdminPhone),

              _SDivider('Financial'),
              _IRow('Monthly Price',   _fmt(co.monthlyPrice)),
              _IRow('Payment Method', 'Bank Transfer'),

              if (co.isMulti) ...[
                _SDivider('Branches (${brs.length})'),
                ...brs.map((branch) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onBranch(branch),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withAlpha(18),
                              borderRadius: BorderRadius.circular(10)),
                            child: const AppIcon(AppIcons.locationOnRounded,
                              color: AppColors.primaryBlue, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(branch.name, style: TextStyle(
                              color: p.text, fontSize: 16,
                              fontWeight: FontWeight.w500)),
                            Text(branch.location, style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                          ])),
                          if (branch.code.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withAlpha(12),
                                borderRadius: BorderRadius.circular(100)),
                              child: Text(branch.code, style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 15, fontWeight: FontWeight.w500))),
                          const SizedBox(width: 8),
                          const AppIcon(AppIcons.chevronRightRounded,
                            color: AppColors.textSecondary, size: 18),
                        ])))))),
                const SizedBox(height: 4),
                _Btn(
                  label: 'Add Branch', icon: AppIcons.addRounded,
                  outline: true, fullWidth: true,
                  onTap: () => AppDialogShell.show<void>(
                    context: context,
                    alignment: Alignment.center,
                    child: _AddBranchDialog(companyId: co.id))),
                const SizedBox(height: 8),
              ],

              _SDivider('Recent Payments'),
              ...paysAsync.when(
                loading: () => [const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)))],
                error: (_, _) => [const Text('Could not load payments',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15))],
                data: (pays) => pays.isEmpty
                  ? [Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('No payments recorded yet.',
                        style: TextStyle(
                          color: p.subText, fontSize: 15)))]
                  : pays.take(3).map((pay) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: p.bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withAlpha(18),
                            borderRadius: BorderRadius.circular(10)),
                          child: const AppIcon(AppIcons.checkRounded,
                            color: AppColors.successGreen, size: 17)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pay.date, style: TextStyle(
                            color: p.text, fontSize: 16, fontWeight: FontWeight.w500)),
                          Text('${pay.methodLabel} · ${pay.reference}',
                            style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                        Text(_fmt(pay.amount), style: const TextStyle(
                          color: AppColors.successGreen,
                          fontSize: 17, fontWeight: FontWeight.w600)),
                      ])))).toList(),
              ),
              const SizedBox(height: 6),
              _Btn(
                label: 'Record Payment', icon: AppIcons.addRounded,
                outline: true, fullWidth: true,
                onTap: () => AppDialogShell.show<void>(
                  context: context,
                  alignment: Alignment.center,
                  child: _AddPaymentDialog(co: co))),
              const SizedBox(height: 8),
            ]))),

        Container(
          padding: const EdgeInsets.all(20),
          color: p.card,
          child: Row(children: [
            Expanded(child: _Btn(
              label: _suspending
                ? 'Please wait…'
                : (co.isActive ? 'Suspend' : 'Activate'),
              color: co.isActive ? AppColors.errorRed : AppColors.successGreen,
              outline: true, fullWidth: true,
              onTap: _suspending ? null : _toggleStatus)),
            const SizedBox(width: 12),
            Expanded(child: _Btn(
              label: 'Edit Company',
              fullWidth: true,
              onTap: () => AppDialogShell.show<void>(
                context: context,
                alignment: Alignment.center,
                child: _EditCoDialog(co: co)))),
          ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _BranchDetailPanel extends StatelessWidget {
  final BranchModel branch;
  final String coName;
  final VoidCallback onClose;
  final VoidCallback onBack;
  const _BranchDetailPanel({required this.branch, required this.coName,
    required this.onClose, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final b = branch;
    final letter = b.name.isEmpty ? 'A' : b.name[0].toUpperCase();
    final colors = AppColors.avatarGradients[letter]
                    ?? AppColors.avatarGradients['A']!;

    return Container(
      width: 500,
      color: p.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          color: p.card,
          child: Row(children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.bg, borderRadius: BorderRadius.circular(100)),
                  child: AppIcon(AppIcons.arrowBackRounded,
                    color: p.subText, size: 18)))),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Branch Details', style: TextStyle(
                color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
              Text(coName, style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15, fontWeight: FontWeight.w500)),
            ])),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.bg, borderRadius: BorderRadius.circular(100)),
                  child: AppIcon(AppIcons.closeRounded,
                    color: p.subText, size: 18)))),
          ])),
        Divider(height: 1, color: p.border.withAlpha(80)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors[0].withAlpha(18),
                  borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(letter,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w700)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: TextStyle(
                      color: p.text, fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (b.code.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(18),
                            borderRadius: BorderRadius.circular(100)),
                          child: Text(b.code, style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 15, fontWeight: FontWeight.w500))),
                        const SizedBox(width: 8),
                      ],
                      _StatusDot(b.isActive),
                    ]),
                  ])),
                ])),

              _SDivider('Branch Information'),
              _IRow('Location',    b.location.isEmpty ? '—' : b.location),
              _IRow('Branch Code', b.code.isEmpty ? '—' : b.code),
              _IRow('Status',      b.isActive ? 'Active' : 'Suspended'),
              _IRow('Added on',    b.createdAtFormatted),
              _IRow('Company',     coName),

              _SDivider('Attendance Overview'),
              _AttendanceStat(label: 'Present Today',  value: '—', color: AppColors.successGreen),
              const SizedBox(height: 8),
              _AttendanceStat(label: 'On Leave',       value: '—', color: AppColors.warningAmber),
              const SizedBox(height: 8),
              _AttendanceStat(label: 'Absent',         value: '—', color: AppColors.errorRed),
              const SizedBox(height: 8),
              _AttendanceStat(label: 'Late Check-in',  value: '—', color: AppColors.primaryBlue),
              const SizedBox(height: 8),
            ]))),

        Container(
          padding: const EdgeInsets.all(20),
          color: p.card,
          child: Row(children: [
            Expanded(child: _Btn(
              label: b.isActive ? 'Suspend Branch' : 'Activate Branch',
              color: b.isActive ? AppColors.errorRed : AppColors.successGreen,
              outline: true, fullWidth: true, onTap: () {})),
            const SizedBox(width: 12),
            Expanded(child: _Btn(
              label: 'Edit Branch',
              fullWidth: true, onTap: () {})),
          ])),
      ]),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttendanceStat({required this.label, required this.value,
    required this.color});
  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(
          color: color, fontSize: 18, fontWeight: FontWeight.w600)),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BILLING VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _BillingView extends ConsumerStatefulWidget {
  const _BillingView();
  @override
  ConsumerState<_BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends ConsumerState<_BillingView> {
  final Map<String, _PayStatus> _status = {};

  _PayStatus _getStatus(String id) => _status[id] ?? _PayStatus.pending;

  Future<void> _onStatusChange(CompanyModel co, _PayStatus newStatus) async {
    if (newStatus == _PayStatus.paid) {
      final confirmed = await AppDialogShell.show<bool>(
        context: context,
        alignment: Alignment.center,
        child: _AddPaymentDialog(co: co),
      );
      if (confirmed != true) return;
    }
    if (mounted) setState(() => _status[co.id] = newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final async = ref.watch(companiesStreamProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
        style: const TextStyle(color: AppColors.errorRed))),
      data: (companies) {
        final now = DateTime.now();
        const monthNames = [
          'January','February','March','April','May','June',
          'July','August','September','October','November','December'
        ];
        final period = '${monthNames[now.month - 1]} ${now.year}';

        final active  = companies.where((c) => c.isActive).toList();
        final revenue = active.fold(0, (s, c) => s + c.monthlyPrice);
        final paid    = active.where((c) => _getStatus(c.id) == _PayStatus.paid).length;
        final pending = active.where((c) => _getStatus(c.id) == _PayStatus.pending).length;
        final notPaid = active.where((c) => _getStatus(c.id) == _PayStatus.notPaid).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _KpiCard(value: _fmt(revenue),
                label: 'Monthly Revenue')),
              const SizedBox(width: 14),
              Expanded(child: _KpiCard(value: '$paid',
                label: 'Paid This Month')),
              const SizedBox(width: 14),
              Expanded(child: _KpiCard(value: '$pending',
                label: 'Pending')),
              const SizedBox(width: 14),
              Expanded(child: _KpiCard(value: '$notPaid',
                label: 'Not Paid')),
            ]),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(12),
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const AppIcon(AppIcons.infoOutlineRounded,
                  color: AppColors.primaryBlue, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text(
                  'Payments are received via bank transfer. '
                  'Select "Paid" on a company to record a payment.',
                  style: TextStyle(color: AppColors.primaryBlue,
                    fontSize: 16, fontWeight: FontWeight.w500))),
              ])),

            Row(children: [
              Text('Payment Status — $period', style: TextStyle(
                color: p.text, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('Tap status badge to update',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ]),
            const SizedBox(height: 12),

            Container(
              decoration: p.card16,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: const Row(children: [
                    Expanded(flex: 3, child: _TH('Company')),
                    Expanded(flex: 2, child: _TH('Type')),
                    Expanded(flex: 2, child: _TH('Monthly Price')),
                    Expanded(flex: 2, child: _TH('Company Status')),
                    Expanded(flex: 2, child: _TH('Payment Status')),
                  ])),
                Divider(height: 1, color: p.border),
                if (companies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text('No companies yet.',
                      style: TextStyle(color: p.subText, fontSize: 15))))
                else
                  ...companies.map((co) {
                    final ps = _getStatus(co.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Expanded(flex: 3, child: Row(children: [
                          _CoAvatar(co.name, size: 34),
                          const SizedBox(width: 10),
                          Expanded(child: Text(co.name, style: TextStyle(
                            color: p.text, fontSize: 16,
                            fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                        ])),
                        Expanded(flex: 2, child: Align(
                          alignment: Alignment.centerLeft,
                          child: _TypeBadge(co.isMulti))),
                        Expanded(flex: 2, child: Text(_fmt(co.monthlyPrice),
                          style: TextStyle(
                            color: p.text, fontSize: 16,
                            fontWeight: FontWeight.w500))),
                        Expanded(flex: 2, child: _StatusDot(co.isActive)),
                        Expanded(flex: 2, child: _PayStatusPicker(
                          status: ps,
                          enabled: co.isActive,
                          onChange: (s) => _onStatusChange(co, s))),
                      ]));
                  }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(children: [
                    _LegendDot(AppColors.successGreen, 'Paid'),
                    const SizedBox(width: 16),
                    _LegendDot(AppColors.warningAmber, 'Pending'),
                    const SizedBox(width: 16),
                    _LegendDot(AppColors.errorRed, 'Not Paid'),
                  ])),
              ])),
          ]),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
    Container(width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(
      color: AppColors.textSecondary, fontSize: 14)),
  ]);
}

class _PayStatusPicker extends StatelessWidget {
  final _PayStatus status;
  final bool enabled;
  final ValueChanged<_PayStatus> onChange;
  const _PayStatusPicker({required this.status, required this.enabled,
    required this.onChange});

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const Text('—',
        style: TextStyle(color: AppColors.textSecondary));
    }
    return PopupMenuButton<_PayStatus>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onChange,
      itemBuilder: (ctx) => [
        _pItem(_PayStatus.paid,    'Paid',     AppColors.successGreen),
        _pItem(_PayStatus.pending, 'Pending',  AppColors.warningAmber),
        _pItem(_PayStatus.notPaid, 'Not Paid', AppColors.errorRed),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _PayBadge(status),
        const SizedBox(width: 4),
        const AppIcon(AppIcons.keyboardArrowDownRounded,
          color: AppColors.textSecondary, size: 14),
      ]));
  }

  PopupMenuItem<_PayStatus> _pItem(
      _PayStatus s, String label, Color color) =>
    PopupMenuItem(
      value: s,
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
          color: color, fontSize: 16, fontWeight: FontWeight.w500)),
      ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD COMPANY PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _AddCoPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _AddCoPanel({required this.onClose});
  @override
  State<_AddCoPanel> createState() => _AddCoPanelState();
}

class _AddCoPanelState extends State<_AddCoPanel> {
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _hrName   = TextEditingController();
  final _password = TextEditingController();
  final _phone    = TextEditingController(text: '+250');
  final _address  = TextEditingController();
  final _price    = TextEditingController();
  final _empCount = TextEditingController();
  final _bName    = TextEditingController();
  final _bLoc     = TextEditingController();
  final _bCode    = TextEditingController();
  String _type     = 'single';
  String _industry = 'Other';
  bool   _loading  = false;
  bool   _obscure  = true;

  static const _industries = [
    'School', 'Polytechnic', 'Clinic', 'Hospital',
    'Hotel', 'Construction', 'Finance', 'NGO', 'Other',
  ];

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _hrName.dispose();
    _password.dispose(); _phone.dispose(); _address.dispose();
    _price.dispose(); _empCount.dispose();
    _bName.dispose(); _bLoc.dispose(); _bCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 8) {
      _showErrorSnackbar(context,
        _password.text.length < 8
          ? 'Temporary password must be at least 8 characters.'
          : 'Company name and HR admin email are required.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await SuperAdminService().createCompany(
        name:          _name.text.trim(),
        hrAdminEmail:  _email.text.trim(),
        tempPassword:  _password.text,
        contactPerson: _hrName.text.trim(),
        hrAdminPhone:  _phone.text.trim(),
        address:       _address.text.trim(),
        industry:      _industry,
        companyType:   _type,
        monthlyPrice:  int.tryParse(_price.text.trim()) ?? 0,
        employeeCount: int.tryParse(_empCount.text.trim()) ?? 0,
        firstBranchName:     _bName.text.trim().isEmpty ? null : _bName.text.trim(),
        firstBranchLocation: _bLoc.text.trim().isEmpty  ? null : _bLoc.text.trim(),
        firstBranchCode:     _bCode.text.trim().isEmpty  ? null : _bCode.text.trim(),
      );
      if (!mounted) return;
      final companyName  = result['companyName'] as String? ?? 'Company';
      final adminEmail   = result['hrAdminEmail'] as String? ?? '';
      final tempPassword = _password.text;
      widget.onClose();
      await _showSuccessDialog(context, '$companyName Added Successfully!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'HR Admin: $adminEmail  •  Temp Password: $tempPassword\n'
            'Share these credentials securely.',
            style: const TextStyle(fontSize: 15)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          backgroundColor: const Color(0xFF0D1E35),
        ));
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, String hint = '',
       bool isPassword = false}) {
    final p = _P.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
        color: p.text.withAlpha(180), fontSize: 16, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: isPassword && _obscure,
        style: TextStyle(color: p.text, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          filled: true, fillColor: p.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: isPassword
            ? IconButton(
                icon: AppIcon(
                  _obscure ? AppIcons.visibilityOffRounded : AppIcons.visibilityRounded,
                  color: AppColors.textSecondary, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure))
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        )),
      const SizedBox(height: 16),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Container(
      width: 520,
      color: p.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          color: p.bg,
          child: Row(children: [
            Expanded(child: Text('Add New Company',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text))),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: p.card, borderRadius: BorderRadius.circular(10)),
                  child: AppIcon(AppIcons.closeRounded,
                    color: p.subText, size: 18)))),
          ])),
        Divider(height: 1, color: p.border),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _field('Company Name', _name, hint: 'e.g. Kigali Polytechnic'),
            _field('HR Admin Email', _email,
              type: TextInputType.emailAddress, hint: 'hr@company.rw'),
            _field('HR Admin Name', _hrName, hint: 'Full name'),
            _field('Temporary Password', _password,
              hint: 'Min 8 characters', isPassword: true),

            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Company Type', style: TextStyle(
                color: p.text.withAlpha(180), fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: p.card, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border)),
                child: Row(children: [
                  _TypeToggle('Single Branch', 'single', _type,
                    (v) => setState(() => _type = v), p),
                  _TypeToggle('Multi-Branch', 'multi_branch', _type,
                    (v) => setState(() => _type = v), p),
                ])),
              const SizedBox(height: 16),
            ]),

            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Industry', style: TextStyle(
                color: p.text.withAlpha(180), fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: p.card, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _industry,
                    isExpanded: true,
                    dropdownColor: p.card,
                    style: TextStyle(color: p.text, fontSize: 15),
                    icon: const AppIcon(AppIcons.keyboardArrowDownRounded,
                      color: AppColors.textSecondary, size: 20),
                    items: _industries.map((i) => DropdownMenuItem(
                      value: i, child: Text(i))).toList(),
                    onChanged: (v) => setState(() => _industry = v!)))),
              const SizedBox(height: 16),
            ]),

            _field('Phone Number', _phone,
              type: TextInputType.phone, hint: '7XX XXX XXX'),
            _field('Address', _address, hint: 'Street, District'),
            _field('Monthly Price (RWF)', _price,
              type: TextInputType.number, hint: '80000'),
            _field('Employee Count', _empCount,
              type: TextInputType.number, hint: '50'),

            if (_type == 'multi_branch') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('First Branch (optional)', style: TextStyle(
                  color: p.text, fontSize: 15, fontWeight: FontWeight.w600))),
              _field('Branch Name', _bName, hint: 'e.g. Kigali HQ'),
              _field('Branch Location', _bLoc, hint: 'District or address'),
              _field('Branch Code', _bCode, hint: 'e.g. KIG-01'),
            ],
          ]))),

        Container(
          padding: const EdgeInsets.all(20),
          color: p.bg,
          child: Row(children: [
            Expanded(child: _Btn(
              label: 'Cancel', outline: true, fullWidth: true,
              onTap: widget.onClose)),
            const SizedBox(width: 12),
            Expanded(child: _Btn(
              label: _loading ? 'Creating…' : 'Add Company',
              icon: _loading ? null : AppIcons.addRounded,
              fullWidth: true,
              onTap: _loading ? null : _submit)),
          ])),
      ]),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onChange;
  final _P p;
  const _TypeToggle(this.label, this.value, this.current, this.onChange, this.p);
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return Expanded(child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryBlue.withAlpha(22) : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
          child: Center(child: Text(label, style: TextStyle(
            color: sel ? AppColors.primaryBlue : p.subText,
            fontSize: 16, fontWeight: FontWeight.w500)))))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

class _EditCoDialog extends StatefulWidget {
  final CompanyModel co;
  const _EditCoDialog({required this.co});
  @override
  State<_EditCoDialog> createState() => _EditCoDialogState();
}

class _EditCoDialogState extends State<_EditCoDialog> {
  late final _name    = TextEditingController(text: widget.co.name);
  late final _person  = TextEditingController(text: widget.co.contactPerson);
  late final _phone   = TextEditingController(
      text: widget.co.hrAdminPhone.isEmpty ? '+250' : widget.co.hrAdminPhone);
  late final _address = TextEditingController(text: widget.co.address);
  late final _price   = TextEditingController(text: '${widget.co.monthlyPrice}');
  late final _emp     = TextEditingController(text: '${widget.co.employeeCount}');
  late String _companyType = widget.co.companyType;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose(); _person.dispose(); _phone.dispose();
    _address.dispose(); _price.dispose(); _emp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await SuperAdminService().updateCompany(widget.co.id, {
        'name':          _name.text.trim(),
        'contactPerson': _person.text.trim(),
        'hrAdminPhone':  _phone.text.trim(),
        'address':       _address.text.trim(),
        'monthlyPrice':  int.tryParse(_price.text.trim()) ?? widget.co.monthlyPrice,
        'employeeCount': int.tryParse(_emp.text.trim()) ?? widget.co.employeeCount,
        'companyType':   _companyType,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Company updated successfully.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) _showErrorSnackbar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(children: [
              Text('Edit Company', style: TextStyle(
                color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: AppIcon(AppIcons.closeRounded, color: p.subText, size: 20)),
            ])),
          Divider(height: 1, color: p.border),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                _df(p, 'Company Name', _name),
                _df(p, 'Contact Person', _person),
                _df(p, 'Phone', _phone, type: TextInputType.phone),
                _df(p, 'Address', _address),
                _df(p, 'Monthly Price (RWF)', _price, type: TextInputType.number),
                _df(p, 'Employee Count', _emp, type: TextInputType.number),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Company Type',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.subText)),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(builder: (ctx, setLocal) {
                  return Row(children: [
                    _typeOption(p, 'Single Location', 'single', _companyType, () {
                      setLocal(() => _companyType = 'single');
                    }),
                    const SizedBox(width: 10),
                    _typeOption(p, 'Multi-Branch', 'multi_branch', _companyType, () {
                      setLocal(() => _companyType = 'multi_branch');
                    }),
                  ]);
                }),
                if (_companyType == 'multi_branch') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
                    ),
                    child: Row(children: [
                      const AppIcon(AppIcons.infoOutlineRounded, color: AppColors.primaryBlue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Switching to Multi-Branch enables branch management for this company.',
                        style: TextStyle(fontSize: 13, color: p.text),
                      )),
                    ]),
                  ),
                ],
              ]))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(child: _Btn(
                label: 'Cancel', outline: true, fullWidth: true,
                onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(child: _Btn(
                label: _loading ? 'Saving…' : 'Save Changes',
                fullWidth: true,
                onTap: _loading ? null : _save)),
            ])),
        ]),
    );
  }

  Widget _typeOption(_P p, String label, String value, String current, VoidCallback onTap) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue : p.fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : p.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : p.subText,
                )),
          ),
        ),
      ),
    );
  }

  Widget _df(_P p, String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          color: p.text.withAlpha(180), fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type,
          style: TextStyle(color: p.text, fontSize: 15),
          decoration: InputDecoration(
            filled: true, fillColor: p.fieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          )),
      ]));
}

// ─── Add Payment Dialog ───────────────────────────────────────────────────────
class _AddPaymentDialog extends StatefulWidget {
  final CompanyModel co;
  const _AddPaymentDialog({required this.co});
  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  static const _shortMonths = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  late final _amount = TextEditingController(
    text: '${widget.co.monthlyPrice}');
  late final _ref    = TextEditingController();
  late String _date;
  String _method = 'bank_transfer';
  bool   _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = '${_shortMonths[now.month - 1]} ${now.year}';
  }

  @override
  void dispose() { _amount.dispose(); _ref.dispose(); super.dispose(); }

  Future<void> _record() async {
    final amt = int.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      _showErrorSnackbar(context, 'Enter a valid payment amount.');
      return;
    }
    setState(() => _loading = true);
    try {
      await SuperAdminService().addPayment(
        companyId: widget.co.id,
        date:      _date,
        amount:    amt,
        method:    _method,
        reference: _ref.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showErrorSnackbar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final methods = [
      ('bank_transfer', 'Bank Transfer'),
      ('mobile_money',  'Mobile Money'),
      ('cash',          'Cash'),
    ];
    return SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withAlpha(20),
                  shape: BoxShape.circle),
                child: const AppIcon(AppIcons.paymentsRounded,
                  color: AppColors.successGreen, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text('Record Payment', style: TextStyle(
                color: p.text, fontSize: 17, fontWeight: FontWeight.w600))),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: AppIcon(AppIcons.closeRounded, color: p.subText, size: 20)),
            ]),
            const SizedBox(height: 8),
            Text(widget.co.name,
              style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 20),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 20),
            // Period
            Row(children: [
              Text('Period', style: TextStyle(
                color: p.text.withAlpha(180), fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _date,
                    dropdownColor: p.card,
                    style: TextStyle(color: p.text, fontSize: 15),
                    items: _buildMonthItems(),
                    onChanged: (v) => setState(() => _date = v!)))),
            ]),
            const SizedBox(height: 14),
            // Amount
            _pField(p, 'Amount (RWF)', _amount, type: TextInputType.number),
            const SizedBox(height: 4),
            // Method
            Row(children: [
              Text('Method', style: TextStyle(
                color: p.text.withAlpha(180), fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _method,
                    dropdownColor: p.card,
                    style: TextStyle(color: p.text, fontSize: 15),
                    items: methods.map((m) =>
                      DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
                    onChanged: (v) => setState(() => _method = v!)))),
            ]),
            const SizedBox(height: 14),
            _pField(p, 'Reference (optional)', _ref, hint: 'BNK-2025-07-001'),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _Btn(
                label: 'Cancel', outline: true, fullWidth: true,
                onTap: () => Navigator.pop(context, false))),
              const SizedBox(width: 12),
              Expanded(child: _Btn(
                label: _loading ? 'Recording…' : 'Record Payment',
                color: AppColors.successGreen,
                fullWidth: true,
                onTap: _loading ? null : _record)),
            ]),
          ]),
        ),
    );
  }

  List<DropdownMenuItem<String>> _buildMonthItems() {
    final items = <DropdownMenuItem<String>>[];
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final label = '${_shortMonths[d.month - 1]} ${d.year}';
      items.add(DropdownMenuItem(value: label, child: Text(label)));
    }
    return items;
  }

  Widget _pField(_P p, String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, String hint = ''}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
        color: p.text.withAlpha(180), fontSize: 15, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, keyboardType: type,
        style: TextStyle(color: p.text, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        )),
    ]);
}

// ─── Add Branch Dialog ────────────────────────────────────────────────────────
class _AddBranchDialog extends StatefulWidget {
  final String companyId;
  const _AddBranchDialog({required this.companyId});
  @override
  State<_AddBranchDialog> createState() => _AddBranchDialogState();
}

class _AddBranchDialogState extends State<_AddBranchDialog> {
  final _name     = TextEditingController();
  final _location = TextEditingController();
  final _code     = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPwd   = TextEditingController();
  final _adminName  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose(); _location.dispose(); _code.dispose();
    _adminEmail.dispose(); _adminPwd.dispose(); _adminName.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) {
      _showErrorSnackbar(context, 'Branch name is required.');
      return;
    }
    setState(() => _loading = true);
    try {
      await SuperAdminService().addBranch(
        companyId:           widget.companyId,
        name:                _name.text.trim(),
        location:            _location.text.trim(),
        code:                _code.text.trim(),
        branchAdminEmail:    _adminEmail.text.trim().isEmpty ? null : _adminEmail.text.trim(),
        branchAdminPassword: _adminPwd.text.isEmpty ? null : _adminPwd.text,
        branchAdminName:     _adminName.text.trim().isEmpty ? null : _adminName.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Branch added successfully.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) _showErrorSnackbar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(children: [
              Text('Add Branch', style: TextStyle(
                color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: AppIcon(AppIcons.closeRounded, color: p.subText, size: 20)),
            ])),
          Divider(height: 1, color: p.border),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bf(p, 'Branch Name *', _name, hint: 'e.g. Kigali HQ'),
                _bf(p, 'Location', _location, hint: 'District or address'),
                _bf(p, 'Branch Code', _code, hint: 'e.g. KIG-01'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text('Branch Admin (optional)', style: TextStyle(
                    color: p.text, fontSize: 15, fontWeight: FontWeight.w600))),
                _bf(p, 'Admin Email', _adminEmail, type: TextInputType.emailAddress),
                _bf(p, 'Admin Name', _adminName),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Admin Password', style: TextStyle(
                    color: p.text.withAlpha(180), fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _adminPwd,
                    obscureText: _obscure,
                    style: TextStyle(color: p.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Min 8 characters',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      filled: true, fillColor: p.fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: AppIcon(
                          _obscure ? AppIcons.visibilityOffRounded : AppIcons.visibilityRounded,
                          color: AppColors.textSecondary, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                    )),
                ]),
              ]))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(child: _Btn(
                label: 'Cancel', outline: true, fullWidth: true,
                onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(child: _Btn(
                label: _loading ? 'Adding…' : 'Add Branch',
                icon: _loading ? null : AppIcons.addRounded,
                fullWidth: true,
                onTap: _loading ? null : _add)),
            ])),
        ]),
    );
  }

  Widget _bf(_P p, String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, String hint = ''}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          color: p.text.withAlpha(180), fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type,
          style: TextStyle(color: p.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            filled: true, fillColor: p.fieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          )),
      ]));
}
