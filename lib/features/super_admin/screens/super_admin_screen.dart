// Super Admin Screen — UI shell only (Part 3)
// Backend wiring deferred — no Firestore, no API calls.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────
const _sidebarBg = Color(0xFF0A1628);

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
            bg: Color(0xFF070E1C), card: Color(0xFF0D1E35),
            border: Color(0xFF1A3050), text: Colors.white,
            subText: AppColors.textSecondary, fieldBg: Color(0xFF060C18),
            dark: true)
        : const _P(
            bg: Color(0xFFF0F4FF), card: Colors.white,
            border: Color(0xFFE8EEF8), text: Color(0xFF0A1628),
            subText: AppColors.textSecondary, fieldBg: Color(0xFFF8FAFF),
            dark: false);
  }

  BoxDecoration get card16 => _cardDeco(16);
  BoxDecoration cardR(double r) => _cardDeco(r);

  BoxDecoration _cardDeco(double r) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(r),
    boxShadow: [
      BoxShadow(
        color: dark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(14),
        blurRadius: dark ? 16 : 12,
        offset: const Offset(0, 3)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// ─────────────────────────────────────────────────────────────────────────────
class _Co {
  final String id, name, type, industry, status, hrEmail, hrName, phone, address, tin;
  final int price, employees;
  final String added;
  const _Co({
    required this.id, required this.name, required this.type,
    required this.industry, required this.status, required this.hrEmail,
    required this.hrName, required this.phone, required this.address,
    required this.tin, required this.price, required this.employees,
    required this.added,
  });
  bool get isMulti  => type == 'multi_branch';
  bool get isActive => status == 'active';
}

const _mock = <_Co>[
  _Co(id: '1', name: 'Kigali Polytechnic',      type: 'multi_branch', industry: 'Polytechnic',  status: 'active',
      hrEmail: 'hr@kigalipoly.rw',  hrName: 'Amina Uwase',              phone: '+250 788 111 222',
      address: 'KN 5 Rd, Kigali',   tin: '100123456', price: 150000, employees: 320, added: 'Jun 10, 2025'),
  _Co(id: '2', name: 'Rwanda Medical Centre',    type: 'single',       industry: 'Clinic',       status: 'active',
      hrEmail: 'hr@rmc.rw',         hrName: 'Jean-Pierre Nkurunziza',   phone: '+250 789 333 444',
      address: 'KG 11 Ave, Kigali', tin: '100234567', price: 80000,  employees: 45,  added: 'Jun 14, 2025'),
  _Co(id: '3', name: 'Green Valley School',      type: 'single',       industry: 'School',       status: 'suspended',
      hrEmail: 'hr@greenvalley.rw', hrName: 'Claudine Ingabire',        phone: '+250 782 555 666',
      address: 'Musanze District',   tin: '100345678', price: 60000,  employees: 78,  added: 'Jun 20, 2025'),
  _Co(id: '4', name: 'Horizon Construction Ltd', type: 'multi_branch', industry: 'Construction', status: 'active',
      hrEmail: 'hr@horizoncon.rw',  hrName: 'Patrick Habimana',         phone: '+250 781 777 888',
      address: 'Kicukiro, Kigali',  tin: '100456789', price: 200000, employees: 510, added: 'Jun 22, 2025'),
  _Co(id: '5', name: 'Lake Hotel Kivu',          type: 'single',       industry: 'Hotel',        status: 'active',
      hrEmail: 'hr@lakehotelkivu.rw', hrName: 'Solange Mukamana',       phone: '+250 783 999 000',
      address: 'Rubavu District',   tin: '100567890', price: 95000,  employees: 130, added: 'Jun 25, 2025'),
];

// Branch data per company (key = companyId_branchIndex)
const _branchDetail = <String, Map<String, String>>{
  '1_0': {'name': 'Kigali HQ',      'location': 'KN 5 Rd, Kigali',  'code': 'KIG-01',
          'manager': 'Eric Muhire',      'managerEmail': 'kig@kigalipoly.rw',
          'phone': '+250 788 100 001',   'employees': '180', 'status': 'active', 'added': 'Jun 10, 2025'},
  '1_1': {'name': 'Huye Campus',    'location': 'Huye District',     'code': 'HUY-01',
          'manager': 'Diane Uwimana',    'managerEmail': 'huy@kigalipoly.rw',
          'phone': '+250 788 100 002',   'employees': '85',  'status': 'active', 'added': 'Jun 10, 2025'},
  '1_2': {'name': 'Musanze Branch', 'location': 'Musanze District',  'code': 'MUS-01',
          'manager': 'James Nkusi',      'managerEmail': 'mus@kigalipoly.rw',
          'phone': '+250 788 100 003',   'employees': '55',  'status': 'active', 'added': 'Jun 10, 2025'},
  '4_0': {'name': 'Kigali Office',  'location': 'Kicukiro, Kigali', 'code': 'KIG-01',
          'manager': 'Alice Ineza',      'managerEmail': 'kig@horizoncon.rw',
          'phone': '+250 788 200 001',   'employees': '310', 'status': 'active', 'added': 'Jun 22, 2025'},
  '4_1': {'name': 'Rubavu Site',    'location': 'Rubavu District',   'code': 'RUB-01',
          'manager': 'Robert Habimana',  'managerEmail': 'rub@horizoncon.rw',
          'phone': '+250 788 200 002',   'employees': '200', 'status': 'active', 'added': 'Jun 22, 2025'},
};

const _branchList = <String, List<Map<String, String>>>{
  '1': [
    {'name': 'Kigali HQ',      'location': 'KN 5 Rd, Kigali',  'code': 'KIG-01', 'key': '1_0'},
    {'name': 'Huye Campus',    'location': 'Huye District',     'code': 'HUY-01', 'key': '1_1'},
    {'name': 'Musanze Branch', 'location': 'Musanze District',  'code': 'MUS-01', 'key': '1_2'},
  ],
  '4': [
    {'name': 'Kigali Office',  'location': 'Kicukiro, Kigali', 'code': 'KIG-01', 'key': '4_0'},
    {'name': 'Rubavu Site',    'location': 'Rubavu District',   'code': 'RUB-01', 'key': '4_1'},
  ],
};

const _recentPayments = <Map<String, dynamic>>[
  {'date': 'Jun 2025', 'amount': 150000, 'method': 'Bank Transfer', 'ref': 'BNK-2025-06-001'},
  {'date': 'May 2025', 'amount': 150000, 'method': 'Mobile Money',  'ref': 'MOM-2025-05-087'},
  {'date': 'Apr 2025', 'amount': 140000, 'method': 'Bank Transfer', 'ref': 'BNK-2025-04-033'},
];

enum _PayStatus { paid, pending, notPaid }

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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// Primary button — pill shape (100px radius), consistent everywhere
class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;
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
                Icon(icon, color: outline ? c : Colors.white, size: 17),
                const SizedBox(width: 7),
              ],
              Text(label, style: TextStyle(
                color: outline ? c : Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// KPI card — build() returns Container; caller wraps with Expanded
class _KpiCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.value, required this.label,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: p.cardR(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13, fontWeight: FontWeight.w500)),
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(20)),
              child: Icon(icon, color: color, size: 22)),
          ]),
        const SizedBox(height: 14),
        Text(value, style: TextStyle(
          color: p.text, fontSize: 28,
          fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
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
        fontSize: 12, fontWeight: FontWeight.w600)));
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
        fontSize: 13, fontWeight: FontWeight.w600)),
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
          color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

// Info row (label + value) — used in detail panels
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
            fontSize: 14, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(
          color: p.text,
          fontSize: 14, fontWeight: FontWeight.w600))),
      ]));
  }
}

// Section divider with label
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
          color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: p.border, height: 1)),
      ]));
  }
}

// Filter chip
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
            borderRadius: BorderRadius.circular(100)),
          child: Text(label, style: TextStyle(
            color: active ? Colors.white : p.subText,
            fontSize: 13, fontWeight: FontWeight.w600)))));
  }
}

// Company avatar (letter + gradient)
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
          fontSize: size * 0.42, fontWeight: FontWeight.w800))));
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
    return Container(
      color: _sidebarBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: RichText(text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
            children: [
              TextSpan(text: 'HR',   style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Nova', style: TextStyle(color: AppColors.primaryBlue)),
            ]))),
        Container(height: 1, color: const Color(0xFF1A3050),
          margin: const EdgeInsets.symmetric(horizontal: 16)),
        const SizedBox(height: 10),
        _SItem(icon: Icons.home_rounded,         label: 'Dashboard',
          active: view == _View.dashboard && !panelOpen, onTap: onDashboard),
        _SItem(icon: Icons.business_rounded,     label: 'Companies',
          active: view == _View.companies || panelOpen,  onTap: onCompanies),
        _SItem(icon: Icons.receipt_long_rounded, label: 'Billing',
          active: view == _View.billing && !panelOpen,   onTap: onBilling),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          child: _SItem(icon: Icons.logout_rounded, label: 'Sign Out',
            active: false, danger: true,
            onTap: () => FirebaseAuth.instance.signOut())),
      ]),
    );
  }
}

class _SItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active, danger;
  final VoidCallback onTap;
  const _SItem({required this.icon, required this.label,
    required this.active, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = danger
      ? AppColors.errorRed
      : (active ? AppColors.primaryBlue : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active ? AppColors.primaryBlue.withAlpha(28) : Colors.transparent,
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                color: c, fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ])))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR — title + super admin badge + search + theme toggle
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  final _View view;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  const _TopBar({
    required this.view,
    required this.searchQuery,
    required this.onSearchChanged,
  });

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
          color: p.text, fontSize: 21, fontWeight: FontWeight.w800,
          letterSpacing: -0.3)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(20),
            borderRadius: BorderRadius.circular(100)),
          child: const Text('Super Admin', style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 12, fontWeight: FontWeight.w700))),
        const Spacer(),
        // Search — only on dashboard + companies
        if (showSearch) ...[
          SizedBox(
            width: 280, height: 44,
            child: TextField(
              onChanged: onSearchChanged,
              style: TextStyle(color: p.text, fontSize: 14),
              decoration: InputDecoration(
                filled: true, fillColor: p.card,
                hintText: 'Search companies…',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // Theme toggle
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => ref.read(themeNotifierProvider.notifier).toggle(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: p.cardR(100),
              child: Icon(
                p.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: p.dark ? AppColors.warningAmber : AppColors.textSecondary,
                size: 20)))),
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
  _View   _view         = _View.dashboard;
  String  _searchQ      = '';
  String? _detailId;
  String? _branchKey;
  bool    _addCoOpen    = false;

  void _nav(_View v) => setState(() {
    _view = v; _searchQ = ''; _detailId = null; _branchKey = null; _addCoOpen = false;
  });

  void _openDetail(String id) => setState(() {
    _detailId = id; _branchKey = null; _addCoOpen = false;
  });

  void _openBranch(String key) => setState(() { _branchKey = key; _addCoOpen = false; });

  void _closeDetail() => setState(() {
    _detailId = null; _branchKey = null;
  });

  void _closeBranch() => setState(() => _branchKey = null);

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final bool anyPanelOpen = _detailId != null || _branchKey != null || _addCoOpen;
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(fit: StackFit.expand, children: [

        // Sidebar
        Positioned(left: 0, top: 0, bottom: 0, width: 220,
          child: _Sidebar(
            view: _view, panelOpen: anyPanelOpen,
            onDashboard: () => _nav(_View.dashboard),
            onCompanies: () => _nav(_View.companies),
            onBilling:   () => _nav(_View.billing),
          )),

        // TopBar
        Positioned(left: 220, top: 0, right: 0, height: 64,
          child: _TopBar(
            view: _view,
            searchQuery: _searchQ,
            onSearchChanged: (v) => setState(() => _searchQ = v),
          )),

        // Main content
        Positioned(left: 220, top: 64, right: 0, bottom: 0,
          child: _page(p)),

        // Add company overlay (future — not open via current nav)

        // Company detail panel
        if (_detailId != null && _branchKey == null)
          Positioned(left: 220, top: 0, right: 0, bottom: 0,
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _closeDetail,
                child: Container(color: Colors.black.withAlpha(100)))),
              _CoDetailPanel(
                co: _mock.firstWhere((c) => c.id == _detailId,
                  orElse: () => _mock.first),
                onClose: _closeDetail,
                onBranch: _openBranch,
              ),
            ])),

        // Branch detail panel
        if (_branchKey != null)
          Positioned(left: 220, top: 0, right: 0, bottom: 0,
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _closeDetail,
                child: Container(color: Colors.black.withAlpha(100)))),
              _BranchDetailPanel(
                branchKey: _branchKey!,
                coName: _mock.firstWhere(
                  (c) => c.id == _branchKey!.split('_')[0],
                  orElse: () => _mock.first).name,
                onClose: _closeDetail,
                onBack:  _closeBranch,
              ),
            ])),

        // Add company panel
        if (_addCoOpen)
          Positioned(left: 220, top: 0, right: 0, bottom: 0,
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
        onAdd:    () => _openAddCompany(),
        onViewAll: () => _nav(_View.companies),
        onDetail:  _openDetail,
      ),
    _View.companies => _CompaniesView(
        searchQuery: _searchQ,
        onAdd:   () => _openAddCompany(),
        onDetail: _openDetail,
      ),
    _View.billing => const _BillingView(),
  };

  void _openAddCompany() => setState(() {
    _addCoOpen = true; _detailId = null; _branchKey = null;
  });

  void _closeAddCo() => setState(() => _addCoOpen = false);
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DashView extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onAdd, onViewAll;
  final ValueChanged<String> onDetail;
  const _DashView({required this.searchQuery, required this.onAdd,
    required this.onViewAll, required this.onDetail});

  List<_Co> get _recent {
    if (searchQuery.isEmpty) return _mock.take(5).toList();
    return _mock.where((c) =>
      c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
      c.industry.toLowerCase().contains(searchQuery.toLowerCase()))
      .take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final total     = _mock.length;
    final active    = _mock.where((c) => c.isActive).length;
    final suspended = total - active;
    final revenue   = _mock.where((c) => c.isActive).fold(0, (s, c) => s + c.price);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(children: [
          Text('Overview', style: TextStyle(
            color: p.subText, fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          _Btn(label: 'Add Company', icon: Icons.add_rounded, onTap: onAdd),
        ])),

      // KPIs
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Row(children: [
          Expanded(child: _KpiCard(value: '$total',      label: 'Total Companies',
            icon: Icons.business_rounded,   color: AppColors.primaryBlue)),
          const SizedBox(width: 14),
          Expanded(child: _KpiCard(value: '$active',     label: 'Active',
            icon: Icons.check_circle_rounded, color: AppColors.successGreen)),
          const SizedBox(width: 14),
          Expanded(child: _KpiCard(value: '$suspended',  label: 'Suspended',
            icon: Icons.block_rounded,      color: AppColors.errorRed)),
          const SizedBox(width: 14),
          Expanded(child: _KpiCard(value: _fmt(revenue), label: 'Monthly Revenue',
            icon: Icons.payments_rounded,   color: AppColors.warningAmber)),
        ])),

      // Recent Companies header
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        child: Row(children: [
          Text('Recent Companies', style: TextStyle(
            color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withAlpha(18),
              borderRadius: BorderRadius.circular(100)),
            child: Text('${_mock.length}', style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 11, fontWeight: FontWeight.w700))),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onViewAll,
              child: const Text('View all →',
                style: TextStyle(color: AppColors.primaryBlue,
                  fontSize: 14, fontWeight: FontWeight.w600)))),
        ])),

      // Table
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Container(
            decoration: p.card16,
            child: _CoTable(
              rows: _recent,
              columns: _CoTableCols.dashboard,
              onDetail: onDetail,
              onAdd: onAdd,
            )))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANIES VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _CompaniesView extends StatefulWidget {
  final String searchQuery;
  final VoidCallback onAdd;
  final ValueChanged<String> onDetail;
  const _CompaniesView({required this.searchQuery, required this.onAdd,
    required this.onDetail});
  @override
  State<_CompaniesView> createState() => _CompaniesViewState();
}

class _CompaniesViewState extends State<_CompaniesView> {
  String _filter       = 'all';
  String _statusFilter = 'all'; // 'all' | 'active' | 'suspended'
  String _sort         = 'newest';

  List<_Co> get _filtered {
    var list = _mock.where((c) {
      final q = widget.searchQuery.toLowerCase();
      final matchQ = q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        c.industry.toLowerCase().contains(q);
      final matchF = _filter == 'all' ||
        (_filter == 'single'       && !c.isMulti) ||
        (_filter == 'multi_branch' &&  c.isMulti);
      final matchS = _statusFilter == 'all' ||
        (_statusFilter == 'active'    &&  c.isActive) ||
        (_statusFilter == 'suspended' && !c.isActive);
      return matchQ && matchF && matchS;
    }).toList();
    switch (_sort) {
      case 'price_high': list.sort((a, b) => b.price.compareTo(a.price));
      case 'price_low':  list.sort((a, b) => a.price.compareTo(b.price));
      case 'name':       list.sort((a, b) => a.name.compareTo(b.name));
      default: break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final list = _filtered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Toolbar
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
        child: Row(children: [
          _FilterChip('All',          'all',          _filter, (v) => setState(() => _filter = v)),
          const SizedBox(width: 8),
          _FilterChip('Single',       'single',        _filter, (v) => setState(() => _filter = v)),
          const SizedBox(width: 8),
          _FilterChip('Multi-Branch', 'multi_branch',  _filter, (v) => setState(() => _filter = v)),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: AppColors.textSecondary.withAlpha(40)),
          const SizedBox(width: 16),
          _FilterChip('Active',    'active',    _statusFilter, (v) => setState(() => _statusFilter = v)),
          const SizedBox(width: 8),
          _FilterChip('Suspended', 'suspended', _statusFilter, (v) => setState(() => _statusFilter = v)),
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
                style: TextStyle(color: p.text, fontSize: 13),
                icon: const Icon(Icons.unfold_more_rounded,
                  color: AppColors.textSecondary, size: 16),
                items: const [
                  DropdownMenuItem(value: 'newest',     child: Text('Newest')),
                  DropdownMenuItem(value: 'price_high', child: Text('Price: High → Low')),
                  DropdownMenuItem(value: 'price_low',  child: Text('Price: Low → High')),
                  DropdownMenuItem(value: 'name',       child: Text('Name A–Z')),
                ],
                onChanged: (v) => setState(() => _sort = v!)))),
          const Spacer(),
          _Btn(label: 'Add Company', icon: Icons.add_rounded, onTap: widget.onAdd),
        ])),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        child: Text('${list.length} of ${_mock.length} companies',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPANY TABLE
// ─────────────────────────────────────────────────────────────────────────────
enum _CoTableCols { dashboard, companies }

class _CoTable extends StatelessWidget {
  final List<_Co> rows;
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
              Icon(Icons.business_outlined,
                color: p.text.withAlpha(50), size: 44),
              const SizedBox(height: 12),
              Text('No companies found',
                style: TextStyle(color: p.text.withAlpha(100), fontSize: 14)),
              const SizedBox(height: 16),
              _Btn(label: 'Add Company', icon: Icons.add_rounded, onTap: onAdd),
            ]))
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                Divider(height: 1, color: p.border.withAlpha(100)),
              itemBuilder: (ctx, i) => _CoRow(
                co: rows[i], isDash: isDash,
                onView: () => onDetail(rows[i].id)))),
    ]);
  }
}

class _CoRow extends StatefulWidget {
  final _Co co;
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
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(co.name, style: TextStyle(
                  color: p.text, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
                Text(co.hrEmail, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              ])),
            ])),
            Expanded(flex: 2, child: Align(
              alignment: Alignment.centerLeft,
              child: _TypeBadge(co.isMulti))),
            if (!widget.isDash)
              Expanded(flex: 2, child: Text(co.industry,
                style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13))),
            Expanded(flex: 2, child: _StatusDot(co.isActive)),
            Expanded(flex: 2, child: Text(_fmt(co.price),
              style: TextStyle(
                color: p.text, fontSize: 13, fontWeight: FontWeight.w500))),
            Expanded(flex: 2, child: Text(
              widget.isDash ? co.added : '${co.employees}',
              style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13))),
            SizedBox(width: 56,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onView,
                  child: const Text('View',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13, fontWeight: FontWeight.w600))))),
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANY DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _CoDetailPanel extends StatelessWidget {
  final _Co co;
  final VoidCallback onClose;
  final ValueChanged<String> onBranch;
  const _CoDetailPanel({required this.co, required this.onClose,
    required this.onBranch});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final brs = _branchList[co.id] ?? [];

    return Container(
      width: 500,
      color: p.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
          color: p.card,
          child: Row(children: [
            Text('Company Details', style: TextStyle(
              color: p.text, fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.bg, borderRadius: BorderRadius.circular(100)),
                  child: Icon(Icons.close_rounded,
                    color: p.subText, size: 18)))),
          ])),
        Divider(height: 1, color: p.border.withAlpha(80)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Identity card
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
                      color: p.text, fontSize: 16, fontWeight: FontWeight.w800),
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
              _IRow('Industry',      co.industry),
              _IRow('Type',          co.isMulti ? 'Multi-Branch' : 'Single Location'),
              _IRow('Address',       co.address),
              _IRow('TIN Number',    co.tin),
              _IRow('Added on',      co.added),
              _IRow('Employees',     '${co.employees}'),

              _SDivider('HR Administrator'),
              _IRow('Name',          co.hrName),
              _IRow('Email',         co.hrEmail),
              _IRow('Phone',         co.phone),

              _SDivider('Financial'),
              _IRow('Monthly Price', _fmt(co.price)),
              _IRow('Payment Method','Bank Transfer'),

              if (co.isMulti && brs.isNotEmpty) ...[
                _SDivider('Branches (${brs.length})'),
                ...brs.asMap().entries.map((e) {
                  final b = e.value;
                  final key = b['key'] ?? '${co.id}_${e.key}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => onBranch(key),
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
                              child: const Icon(Icons.location_on_rounded,
                                color: AppColors.primaryBlue, size: 18)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(b['name']!, style: TextStyle(
                                color: p.text, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                              Text(b['location']!, style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withAlpha(12),
                                borderRadius: BorderRadius.circular(100)),
                              child: Text(b['code']!, style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 11, fontWeight: FontWeight.w600))),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary, size: 18),
                          ])))));
                }),
              ],

              _SDivider('Recent Payments'),
              ..._recentPayments.take(3).map((pay) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                        color: AppColors.successGreen.withAlpha(18),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.check_rounded,
                        color: AppColors.successGreen, size: 17)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pay['date'] as String, style: TextStyle(
                        color: p.text, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                      Text('${pay['method']} · ${pay['ref']}',
                        style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                    ])),
                    Text(_fmt(pay['amount'] as int),
                      style: const TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  ])))),

              const SizedBox(height: 8),
            ]))),

        // Bottom actions
        Container(
          padding: const EdgeInsets.all(20),
          color: p.card,
          child: Row(children: [
            Expanded(child: _Btn(
              label: co.isActive ? 'Suspend' : 'Activate',
              color: co.isActive ? AppColors.errorRed : AppColors.successGreen,
              outline: true, fullWidth: true, onTap: () {})),
            const SizedBox(width: 12),
            Expanded(child: _Btn(
              label: 'Edit Company',
              fullWidth: true, onTap: () {})),
          ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _BranchDetailPanel extends StatelessWidget {
  final String branchKey;
  final String coName;
  final VoidCallback onClose;
  final VoidCallback onBack;
  const _BranchDetailPanel({required this.branchKey, required this.coName,
    required this.onClose, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final b = _branchDetail[branchKey];
    if (b == null) return const SizedBox(width: 500);

    final isActive = (b['status'] ?? 'active') == 'active';
    final employees = b['employees'] ?? '—';
    final name     = b['name']     ?? '—';
    final location = b['location'] ?? '—';
    final code     = b['code']     ?? '—';
    final manager  = b['manager']  ?? '—';
    final email    = b['managerEmail'] ?? '—';
    final phone    = b['phone']    ?? '—';
    final added    = b['added']    ?? '—';
    final letter   = name[0].toUpperCase();
    final colors   = AppColors.avatarGradients[letter]
                      ?? AppColors.avatarGradients['A']!;

    return Container(
      width: 500,
      color: p.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Header with back button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          color: p.card,
          child: Row(children: [
            // Back to company
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.bg, borderRadius: BorderRadius.circular(100)),
                  child: Icon(Icons.arrow_back_rounded,
                    color: p.subText, size: 18)))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Branch Details', style: TextStyle(
                  color: p.text, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(coName, style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11, fontWeight: FontWeight.w500)),
              ])),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: p.bg, borderRadius: BorderRadius.circular(100)),
                  child: Icon(Icons.close_rounded,
                    color: p.subText, size: 18)))),
          ])),
        Divider(height: 1, color: p.border.withAlpha(80)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Branch identity card
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
                        fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(
                      color: p.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(18),
                          borderRadius: BorderRadius.circular(100)),
                        child: Text(code, style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _StatusDot(isActive),
                    ]),
                  ])),
                ])),

              _SDivider('Branch Information'),
              _IRow('Location',    location),
              _IRow('Branch Code', code),
              _IRow('Employees',   employees),
              _IRow('Status',      isActive ? 'Active' : 'Suspended'),
              _IRow('Added on',    added),
              _IRow('Company',     coName),

              _SDivider('Branch Manager'),
              _IRow('Name',        manager),
              _IRow('Email',       email),
              _IRow('Phone',       phone),

              _SDivider('Attendance Overview'),
              _AttendanceStat(label: 'Present Today',  value: '42',  color: AppColors.successGreen),
              const SizedBox(height: 8),
              _AttendanceStat(label: 'On Leave',       value: '5',   color: AppColors.warningAmber),
              const SizedBox(height: 8),
              _AttendanceStat(label: 'Absent',         value: '3',   color: AppColors.errorRed),
              const SizedBox(height: 8),
              _AttendanceStat(label: 'Late Check-in',  value: '7',   color: AppColors.primaryBlue),

              const SizedBox(height: 8),
            ]))),

        // Bottom actions
        Container(
          padding: const EdgeInsets.all(20),
          color: p.card,
          child: Row(children: [
            Expanded(child: _Btn(
              label: isActive ? 'Suspend Branch' : 'Activate Branch',
              color: isActive ? AppColors.errorRed : AppColors.successGreen,
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
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(
          color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BILLING VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _BillingView extends StatefulWidget {
  const _BillingView();
  @override
  State<_BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<_BillingView> {
  final Map<String, _PayStatus> _status = {
    '1': _PayStatus.paid,
    '2': _PayStatus.paid,
    '3': _PayStatus.notPaid,
    '4': _PayStatus.pending,
    '5': _PayStatus.pending,
  };

  void _setStatus(String id, _PayStatus s) =>
      setState(() => _status[id] = s);

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);
    final active  = _mock.where((c) => c.isActive).toList();
    final paid    = _status.values.where((s) => s == _PayStatus.paid).length;
    final pending = _status.values.where((s) => s == _PayStatus.pending).length;
    final notPaid = _status.values.where((s) => s == _PayStatus.notPaid).length;
    final revenue = active.fold(0, (s, c) => s + c.price);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _KpiCard(value: _fmt(revenue),
            label: 'Monthly Revenue',
            icon: Icons.trending_up_rounded, color: AppColors.successGreen)),
          const SizedBox(width: 14),
          Expanded(child: _KpiCard(value: '$paid',
            label: 'Paid This Month',
            icon: Icons.check_circle_rounded, color: AppColors.primaryBlue)),
          const SizedBox(width: 14),
          Expanded(child: _KpiCard(value: '$pending',
            label: 'Pending',
            icon: Icons.schedule_rounded, color: AppColors.warningAmber)),
          const SizedBox(width: 14),
          Expanded(child: _KpiCard(value: '$notPaid',
            label: 'Not Paid',
            icon: Icons.cancel_rounded, color: AppColors.errorRed)),
        ]),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(12),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
              color: AppColors.primaryBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(child: const Text(
              'Payments are received via bank transfer. '
              'Update each company\'s status manually after confirming receipt.',
              style: TextStyle(color: AppColors.primaryBlue,
                fontSize: 13, fontWeight: FontWeight.w500))),
          ])),

        Row(children: [
          Text('Payment Status — June 2025', style: TextStyle(
            color: p.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Text('Tap status badge to update',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 12),

        Container(
          decoration: p.card16,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(children: const [
                Expanded(flex: 3, child: _TH('Company')),
                Expanded(flex: 2, child: _TH('Type')),
                Expanded(flex: 2, child: _TH('Monthly Price')),
                Expanded(flex: 2, child: _TH('Company Status')),
                Expanded(flex: 2, child: _TH('Payment Status')),
              ])),
            Divider(height: 1, color: p.border),
            ..._mock.map((co) {
              final ps = _status[co.id] ?? _PayStatus.pending;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
                child: Row(children: [
                  Expanded(flex: 3, child: Row(children: [
                    _CoAvatar(co.name, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(co.name, style: TextStyle(
                        color: p.text, fontSize: 13,
                        fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                      Text(co.hrEmail, style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                    ])),
                  ])),
                  Expanded(flex: 2, child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TypeBadge(co.isMulti))),
                  Expanded(flex: 2, child: Text(_fmt(co.price),
                    style: TextStyle(
                      color: p.text, fontSize: 13,
                      fontWeight: FontWeight.w500))),
                  Expanded(flex: 2, child: _StatusDot(co.isActive)),
                  Expanded(flex: 2, child: _PayStatusPicker(
                    status: ps,
                    enabled: co.isActive,
                    onChange: (s) => _setStatus(co.id, s))),
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
      color: AppColors.textSecondary, fontSize: 12)),
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
        const Icon(Icons.keyboard_arrow_down_rounded,
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
          color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
  final _name    = TextEditingController();
  final _email   = TextEditingController();
  final _hrName  = TextEditingController();
  final _phone   = TextEditingController();
  final _address = TextEditingController();
  final _tin     = TextEditingController();
  final _price   = TextEditingController();
  String _type   = 'single';
  String _industry = 'Other';

  static const _industries = [
    'School', 'Polytechnic', 'Clinic', 'Hospital',
    'Hotel', 'Construction', 'Finance', 'NGO', 'Other',
  ];

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _hrName.dispose();
    _phone.dispose(); _address.dispose(); _tin.dispose(); _price.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, String hint = ''}) {
    final p = _P.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
        color: p.text.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: p.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          filled: true, fillColor: p.fieldBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
      color: p.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          color: p.card,
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF6B8EFF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.business_rounded,
                color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('Add New Company',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('Fill in the company details below',
                style: TextStyle(
                  color: p.subText, fontSize: 13, fontWeight: FontWeight.w400)),
            ])),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: p.fieldBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.close_rounded,
                    color: p.subText, size: 18)))),
          ])),
        Divider(height: 1, color: p.border),

        // Form
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _field('Company Name', _name, hint: 'e.g. Kigali Polytechnic'),
            _field('HR Admin Email', _email,
              type: TextInputType.emailAddress, hint: 'hr@company.rw'),
            _field('HR Admin Name', _hrName, hint: 'Full name'),

            // Type toggle
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Company Type', style: TextStyle(
                color: p.text.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: p.fieldBg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _TypeToggle('Single Branch', 'single', _type,
                    (v) => setState(() => _type = v), p),
                  _TypeToggle('Multi-Branch', 'multi_branch', _type,
                    (v) => setState(() => _type = v), p),
                ])),
              const SizedBox(height: 16),
            ]),

            // Industry dropdown
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Industry', style: TextStyle(
                color: p.text.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: p.fieldBg, borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _industry,
                    isExpanded: true,
                    dropdownColor: p.card,
                    style: TextStyle(color: p.text, fontSize: 14),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary, size: 20),
                    items: _industries.map((i) => DropdownMenuItem(
                      value: i, child: Text(i))).toList(),
                    onChanged: (v) => setState(() => _industry = v!)))),
              const SizedBox(height: 16),
            ]),

            _field('Phone Number', _phone,
              type: TextInputType.phone, hint: '+250 7XX XXX XXX'),
            _field('Address', _address, hint: 'Street, District'),
            _field('TIN Number', _tin, hint: '100XXXXXXX'),
            _field('Monthly Price (RWF)', _price,
              type: TextInputType.number, hint: '80000'),
          ]))),

        // Bottom actions
        Container(
          padding: const EdgeInsets.all(20),
          color: p.card,
          child: Row(children: [
            Expanded(child: _Btn(
              label: 'Cancel', outline: true, fullWidth: true,
              onTap: widget.onClose)),
            const SizedBox(width: 12),
            Expanded(child: _Btn(
              label: 'Add Company',
              icon: Icons.add_rounded,
              fullWidth: true,
              onTap: widget.onClose)), // UI-only: closes panel
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
            fontSize: 13, fontWeight: FontWeight.w600)))))));
  }
}
