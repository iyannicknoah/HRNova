import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/hrnova_button.dart';

// ── Dark-theme constants ───────────────────────────────────────────────────────
const _dark = Color(0xFF0A1628);
const _card = Color(0xFF0D1E35);
const _bord = Color(0xFF1A3050);

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
               'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

String _fmtPrice(int p) {
  if (p == 0) return '—';
  final s = p.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'RWF ${b.toString()}';
}

// ── Firestore models ──────────────────────────────────────────────────────────
class _Co {
  final String id, name, companyType, industry, address;
  final String contactPerson, hrAdminEmail, hrAdminPhone;
  final int employeeCount, monthlyPrice;
  final String tinNumber, status;
  final DateTime? createdAt;
  final String lastPaymentDate;

  const _Co({
    required this.id, required this.name, required this.companyType,
    required this.industry, required this.address,
    required this.contactPerson, required this.hrAdminEmail,
    required this.hrAdminPhone, required this.employeeCount,
    required this.monthlyPrice, required this.tinNumber,
    required this.status, required this.lastPaymentDate, this.createdAt,
  });

  factory _Co.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    final ts = m['createdAt'];
    return _Co(
      id: d.id,
      name:          m['name']          as String? ?? '',
      companyType:   m['companyType']   as String? ?? 'single',
      industry:      m['industry']      as String? ?? '',
      address:       m['address']       as String? ?? '',
      contactPerson: m['contactPerson'] as String? ?? '',
      hrAdminEmail:  m['hrAdminEmail']  as String? ?? '',
      hrAdminPhone:  m['hrAdminPhone']  as String? ?? '',
      employeeCount: (m['employeeCount'] as int?) ?? 0,
      monthlyPrice:  (m['monthlyPrice']  as int?) ?? 0,
      tinNumber:     m['tinNumber']     as String? ?? '',
      status:        m['status']        as String? ?? 'active',
      lastPaymentDate: m['lastPaymentDate'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  bool get isMulti  => companyType == 'multi_branch';
  bool get isActive => status == 'active';
}

class _Pay {
  final String id, date, reference, method;
  final int amount;
  final DateTime? createdAt;
  const _Pay({required this.id, required this.date, required this.reference,
    required this.method, required this.amount, this.createdAt});

  factory _Pay.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    final ts = m['createdAt'];
    return _Pay(
      id: d.id, date: m['date'] as String? ?? '',
      reference: m['reference'] as String? ?? '',
      method: m['method'] as String? ?? 'bank_transfer',
      amount: (m['amount'] as int?) ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class _Br {
  final String id, name, location, code, status;
  final DateTime? createdAt;
  const _Br({required this.id, required this.name, required this.location,
    required this.code, required this.status, this.createdAt});

  factory _Br.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    final ts = m['createdAt'];
    return _Br(
      id: d.id, name: m['name'] as String? ?? '',
      location: m['location'] as String? ?? '',
      code: m['code'] as String? ?? '',
      status: m['status'] as String? ?? 'active',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────
final _cosProvider = StreamProvider<List<_Co>>((ref) =>
  FirebaseFirestore.instance
    .collection('companies')
    .orderBy('createdAt', descending: true)
    .snapshots()
    .map((s) => s.docs.map(_Co.fromDoc).toList()));

final _coProvider = StreamProvider.family<_Co?, String>((ref, id) =>
  FirebaseFirestore.instance.collection('companies').doc(id).snapshots()
    .map((d) => d.exists ? _Co.fromDoc(d) : null));

final _paysProvider = StreamProvider.family<List<_Pay>, String>((ref, coId) =>
  FirebaseFirestore.instance.collection('companies').doc(coId)
    .collection('payments').orderBy('createdAt', descending: true).snapshots()
    .map((s) => s.docs.map(_Pay.fromDoc).toList()));

final _brsProvider = StreamProvider.family<List<_Br>, String>((ref, coId) =>
  FirebaseFirestore.instance.collection('companies').doc(coId)
    .collection('branches').orderBy('createdAt').snapshots()
    .map((s) => s.docs.map(_Br.fromDoc).toList()));

// ── Screen ───────────────────────────────────────────────────────────────────
enum _View { companies, billing, detail }

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  ConsumerState<SuperAdminScreen> createState() => _State();
}

class _State extends ConsumerState<SuperAdminScreen> {
  _View _view = _View.companies;
  String? _detailId;
  bool _addOpen = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Row(children: [
        _Sidebar(
          view: _view,
          onCompanies: () => setState(() { _view = _View.companies; _detailId = null; }),
          onBilling:   () => setState(() { _view = _View.billing;   _detailId = null; }),
        ),
        Expanded(child: Stack(children: [
          Column(children: [
            _TopBar(view: _view, onBack: _detailId != null
              ? () => setState(() { _view = _View.companies; _detailId = null; })
              : null),
            Expanded(child: _body()),
          ]),
          if (_addOpen) _AddPanel(
            onClose: () => setState(() => _addOpen = false),
            onDone:  () => setState(() => _addOpen = false),
          ),
        ])),
      ]),
    );
  }

  Widget _body() => switch (_view) {
    _View.companies => _CosList(
      search: _search, ctrl: _searchCtrl,
      onSearch: (s) => setState(() => _search = s),
      onAdd:  () => setState(() => _addOpen = true),
      onView: (id) => setState(() { _detailId = id; _view = _View.detail; }),
    ),
    _View.billing => const _BillingView(),
    _View.detail  => _CoDetail(
      coId: _detailId!,
      onBack: () => setState(() { _view = _View.companies; _detailId = null; }),
    ),
  };
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final _View view;
  final VoidCallback onCompanies, onBilling;
  const _Sidebar({required this.view, required this.onCompanies, required this.onBilling});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _dark,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.accentTeal],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('HRNova',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        Container(height: 0.5, color: _bord, margin: const EdgeInsets.symmetric(horizontal: 16)),
        const SizedBox(height: 12),
        _NavItem(
          icon: Icons.business_rounded, label: 'Companies',
          active: view == _View.companies || view == _View.detail,
          onTap: onCompanies,
        ),
        _NavItem(
          icon: Icons.receipt_long_rounded, label: 'Billing',
          active: view == _View.billing, onTap: onBilling,
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _NavItem(
            icon: Icons.logout_rounded, label: 'Sign Out',
            active: false, color: AppColors.errorRed,
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;
  const _NavItem({required this.icon, required this.label, required this.active,
    required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? AppColors.primaryBlue : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? AppColors.primaryBlue.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                color: c, fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final _View view;
  final VoidCallback? onBack;
  const _TopBar({required this.view, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _bord)),
      ),
      child: Row(children: [
        if (onBack != null) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 20),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          view == _View.companies ? 'Companies'
            : view == _View.billing ? 'Billing'
            : 'Company Details',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withAlpha(80)),
          ),
          child: const Text('Super Admin',
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
          onPressed: () => FirebaseAuth.instance.signOut(),
          tooltip: 'Sign out',
        ),
      ]),
    );
  }
}

// ── Metric card (dark) ────────────────────────────────────────────────────────
class _Metric extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _Metric({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bord),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700,
            letterSpacing: -0.5, height: 1,
          )),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Companies list view ───────────────────────────────────────────────────────
class _CosList extends ConsumerWidget {
  final String search;
  final TextEditingController ctrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final ValueChanged<String> onView;

  const _CosList({required this.search, required this.ctrl,
    required this.onSearch, required this.onAdd, required this.onView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_cosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      data: (cos) {
        final total     = cos.length;
        final active    = cos.where((c) => c.isActive).length;
        final suspended = total - active;
        final revenue   = cos.where((c) => c.isActive).fold(0, (s, c) => s + c.monthlyPrice);
        final filtered  = search.isEmpty ? cos
          : cos.where((c) => c.name.toLowerCase().contains(search.toLowerCase())).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(children: [
              _Metric(value: '$total',           label: 'Total Companies', icon: Icons.business_rounded,  color: AppColors.primaryBlue),
              const SizedBox(width: 14),
              _Metric(value: '$active',          label: 'Active',          icon: Icons.check_circle_rounded, color: AppColors.successGreen),
              const SizedBox(width: 14),
              _Metric(value: '$suspended',       label: 'Suspended',       icon: Icons.block_rounded,        color: AppColors.errorRed),
              const SizedBox(width: 14),
              _Metric(value: _fmtPrice(revenue), label: 'Monthly Revenue', icon: Icons.payments_rounded,     color: AppColors.warningAmber),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bord),
                  ),
                  child: TextField(
                    controller: ctrl, onChanged: onSearch,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search companies…',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withAlpha(160)),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Company', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _CoTable(cos: filtered, onView: onView),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Companies table ───────────────────────────────────────────────────────────
class _CoTable extends StatelessWidget {
  final List<_Co> cos;
  final ValueChanged<String> onView;
  const _CoTable({required this.cos, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bord),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(children: const [
            Expanded(flex: 3, child: _TH('Company')),
            Expanded(flex: 2, child: _TH('Type')),
            Expanded(flex: 2, child: _TH('Industry')),
            Expanded(flex: 2, child: _TH('Status')),
            Expanded(flex: 2, child: _TH('Monthly Price')),
            Expanded(flex: 2, child: _TH('Created')),
            SizedBox(width: 150, child: _TH('Actions')),
          ]),
        ),
        Divider(height: 1, color: _bord),
        Expanded(
          child: cos.isEmpty
            ? const Center(child: Text('No companies yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)))
            : ListView.separated(
                itemCount: cos.length,
                separatorBuilder: (context2, i2) => Divider(height: 1, color: _bord.withAlpha(120)),
                itemBuilder: (ctx, i) => _CoRow(co: cos[i], onView: () => onView(cos[i].id)),
              ),
        ),
      ]),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11,
      fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

class _CoRow extends ConsumerWidget {
  final _Co co;
  final VoidCallback onView;
  const _CoRow({required this.co, required this.onView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onView,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Expanded(flex: 3, child: Text(co.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14))),
          Expanded(flex: 2, child: _TypeBadge(co.isMulti)),
          Expanded(flex: 2, child: Text(co.industry.isEmpty ? '—' : co.industry,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          Expanded(flex: 2, child: _StatusBadge(co.isActive)),
          Expanded(flex: 2, child: Text(_fmtPrice(co.monthlyPrice),
            style: const TextStyle(color: Colors.white, fontSize: 14))),
          Expanded(flex: 2, child: Text(_fmtDate(co.createdAt),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          SizedBox(width: 150, child: Row(children: [
            _ActBtn('View', AppColors.primaryBlue, onView),
            const SizedBox(width: 8),
            _ActBtn(
              co.isActive ? 'Suspend' : 'Activate',
              co.isActive ? AppColors.errorRed : AppColors.successGreen,
              () => _confirmToggle(context, ref),
            ),
          ])),
        ]),
      ),
    );
  }

  void _confirmToggle(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _ConfirmDlg(
      title:   co.isActive ? 'Suspend ${co.name}?' : 'Activate ${co.name}?',
      message: co.isActive
        ? 'All users from this company will be blocked from signing in.'
        : 'Access will be restored for all users at this company.',
      confirmLabel: co.isActive ? 'Suspend' : 'Activate',
      confirmColor: co.isActive ? AppColors.errorRed : AppColors.successGreen,
      onConfirm: () async {
        await ApiService().put('/api/companies/${co.id}/status',
          data: {'status': co.isActive ? 'suspended' : 'active'});
      },
    ));
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isMulti;
  const _TypeBadge(this.isMulti);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isMulti ? AppColors.primaryBlue.withAlpha(25) : AppColors.textSecondary.withAlpha(30),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isMulti ? AppColors.primaryBlue.withAlpha(80) : _bord),
    ),
    child: Text(
      isMulti ? 'Multi-Branch' : 'Single',
      style: TextStyle(
        color: isMulti ? AppColors.primaryBlue : AppColors.textSecondary,
        fontSize: 11, fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge(this.isActive);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.successGreen : AppColors.errorRed,
      ),
    ),
    const SizedBox(width: 6),
    Text(
      isActive ? 'Active' : 'Suspended',
      style: TextStyle(
        color: isActive ? AppColors.successGreen : AppColors.errorRed,
        fontSize: 13, fontWeight: FontWeight.w600,
      ),
    ),
  ]);
}

class _ActBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

// ── Add Company panel (480 px slide-in from right) ────────────────────────────
class _AddPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose, onDone;
  const _AddPanel({required this.onClose, required this.onDone});
  @override
  ConsumerState<_AddPanel> createState() => _AddPanelState();
}

class _AddPanelState extends ConsumerState<_AddPanel> {
  final _fk = GlobalKey<FormState>();
  final _name  = TextEditingController();
  final _addr  = TextEditingController();
  final _cont  = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emp   = TextEditingController();
  final _price = TextEditingController();
  final _tin   = TextEditingController();
  final _pass  = TextEditingController();
  final _br1n  = TextEditingController();
  final _br1l  = TextEditingController();
  final _br1c  = TextEditingController();

  String _type     = 'single';
  String _industry = 'Factory';
  bool _loading = false;
  String? _err;

  static const _industries = [
    'Factory','School','Clinic','NGO','Hotel',
    'Polytechnic','Bank','Church','Construction','Other',
  ];

  @override
  void dispose() {
    for (final c in [_name,_addr,_cont,_email,_phone,_emp,_price,_tin,_pass,_br1n,_br1l,_br1c]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _loading = true; _err = null; });
    try {
      final body = {
        'name': _name.text.trim(), 'companyType': _type,
        'industry': _industry,     'address': _addr.text.trim(),
        'contactPerson': _cont.text.trim(),
        'hrAdminEmail': _email.text.trim(), 'hrAdminPhone': _phone.text.trim(),
        'employeeCount': _emp.text.trim(),  'monthlyPrice': _price.text.trim(),
        'tinNumber': _tin.text.trim(),      'tempPassword': _pass.text,
        if (_type == 'multi_branch') ...{
          'firstBranchName':     _br1n.text.trim(),
          'firstBranchLocation': _br1l.text.trim(),
          'firstBranchCode':     _br1c.text.trim(),
        },
      };
      final res = await ApiService().post('/api/companies/create', data: body);
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        await showDialog(
          context: context, barrierDismissible: false,
          builder: (_) => _SuccessDlg(
            companyName: data['companyName'] as String? ?? _name.text,
            email: data['hrAdminEmail'] as String? ?? _email.text,
            password: _pass.text,
            role: data['role'] as String? ?? 'hr_admin',
            branch: data['branch'] as Map<String, dynamic>?,
          ),
        );
        widget.onDone();
      }
    } catch (e) {
      setState(() => _err = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withAlpha(100)),
          ),
        ),
        Container(
          width: 480,
          color: _card,
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _bord))),
              child: Row(children: [
                const Text('Add Company', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: widget.onClose,
                ),
              ]),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _fk,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _DF(label: 'Company Name *', ctrl: _name,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 20),
                    // Type selector
                    const _FL('Company Type'),
                    const SizedBox(height: 8),
                    Row(children: [
                      _TypeOpt('Single Location', 'single', _type,
                        (v) => setState(() => _type = v)),
                      const SizedBox(width: 12),
                      _TypeOpt('Multi-Branch', 'multi_branch', _type,
                        (v) => setState(() => _type = v)),
                    ]),
                    const SizedBox(height: 20),
                    // Industry
                    const _FL('Industry'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: _dark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _bord),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _industry, isExpanded: true,
                          dropdownColor: _card,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: _industries.map((i) =>
                            DropdownMenuItem(value: i, child: Text(i))).toList(),
                          onChanged: (v) => setState(() => _industry = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DF(label: 'Address', ctrl: _addr),
                    const SizedBox(height: 20),
                    _DF(label: 'Contact Person Name', ctrl: _cont),
                    const SizedBox(height: 20),
                    _DF(label: 'HR Admin Email *', ctrl: _email,
                      type: TextInputType.emailAddress,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                    const SizedBox(height: 20),
                    _DF(label: 'HR Admin Phone', ctrl: _phone, type: TextInputType.phone),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _DF(label: 'No. of Employees', ctrl: _emp,
                        type: TextInputType.number)),
                      const SizedBox(width: 14),
                      Expanded(child: _DF(label: 'Monthly Price (RWF)', ctrl: _price,
                        type: TextInputType.number)),
                    ]),
                    const SizedBox(height: 20),
                    _DF(label: 'TIN Number', ctrl: _tin),
                    const SizedBox(height: 20),
                    _DF(
                      label: 'Temporary Password *', ctrl: _pass, obscure: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) return 'Min 8 characters';
                        return null;
                      },
                    ),
                    // First branch (multi only)
                    if (_type == 'multi_branch') ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('First Branch', style: TextStyle(
                            color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          _DF(label: 'Branch Name', ctrl: _br1n),
                          const SizedBox(height: 14),
                          _DF(label: 'Branch Location', ctrl: _br1l),
                          const SizedBox(height: 14),
                          _DF(label: 'Branch Code', ctrl: _br1c),
                        ]),
                      ),
                    ],
                    if (_err != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.errorRed.withAlpha(60)),
                        ),
                        child: Text(_err!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: _bord))),
              child: HRNovaButton(
                label: 'Create Company & HR Admin',
                onPressed: _loading ? null : _save,
                isLoading: _loading, isFullWidth: true,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Form helpers ──────────────────────────────────────────────────────────────
class _FL extends StatelessWidget {
  final String text;
  const _FL(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600));
}

class _DF extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? type;
  final bool obscure;
  final String? Function(String?)? validator;
  const _DF({required this.label, required this.ctrl,
    this.type, this.obscure = false, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FL(label),
      const SizedBox(height: 7),
      TextFormField(
        controller: ctrl, keyboardType: type, obscureText: obscure,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true, fillColor: _dark,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _bord),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _bord),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.errorRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _TypeOpt extends StatelessWidget {
  final String label, value, groupValue;
  final ValueChanged<String> onChange;
  const _TypeOpt(this.label, this.value, this.groupValue, this.onChange);

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue.withAlpha(30) : _dark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : _bord, width: 1.5),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: selected ? AppColors.primaryBlue : AppColors.textSecondary,
              fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ),
        ),
      ),
    );
  }
}

// ── Success dialog ─────────────────────────────────────────────────────────────
class _SuccessDlg extends StatelessWidget {
  final String companyName, email, password, role;
  final Map<String, dynamic>? branch;
  const _SuccessDlg({required this.companyName, required this.email,
    required this.password, required this.role, this.branch});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.successGreen.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Company Created!', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(companyName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _dark, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _bord),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Login Credentials', style: TextStyle(
                color: AppColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _CredRow('Role', role.replaceAll('_', ' ').toUpperCase()),
              _CredRow('Email', email, copyable: true),
              _CredRow('Password', password, copyable: true),
              if (branch != null) ...[
                const Divider(height: 20, color: Color(0xFF1A3050)),
                _CredRow('Branch', branch!['name'] as String? ?? ''),
                _CredRow('Branch ID', branch!['branchId'] as String? ?? '', copyable: true),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label, value;
  final bool copyable;
  const _CredRow(this.label, this.value, {this.copyable = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        Expanded(child: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
        if (copyable)
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: value)),
            child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
          ),
      ]),
    );
  }
}

// ── Confirm dialog ────────────────────────────────────────────────────────────
class _ConfirmDlg extends StatefulWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final Future<void> Function() onConfirm;
  const _ConfirmDlg({required this.title, required this.message,
    required this.confirmLabel, required this.confirmColor, required this.onConfirm});
  @override
  State<_ConfirmDlg> createState() => _ConfirmDlgState();
}

class _ConfirmDlgState extends State<_ConfirmDlg> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(widget.message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _bord),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : () async {
                  final nav = Navigator.of(context);
                  setState(() => _loading = true);
                  await widget.onConfirm();
                  if (!mounted) return;
                  nav.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.confirmColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                child: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Company detail view ───────────────────────────────────────────────────────
class _CoDetail extends ConsumerStatefulWidget {
  final String coId;
  final VoidCallback onBack;
  const _CoDetail({required this.coId, required this.onBack});
  @override
  ConsumerState<_CoDetail> createState() => _CoDetailState();
}

class _CoDetailState extends ConsumerState<_CoDetail> {
  bool _editing = false;
  bool _saving  = false;

  final _name   = TextEditingController();
  final _addr   = TextEditingController();
  final _cont   = TextEditingController();
  final _phone  = TextEditingController();
  final _emp    = TextEditingController();
  final _price  = TextEditingController();
  final _tin    = TextEditingController();

  bool _addBranchOpen = false;

  void _loadFrom(_Co co) {
    _name.text  = co.name;
    _addr.text  = co.address;
    _cont.text  = co.contactPerson;
    _phone.text = co.hrAdminPhone;
    _emp.text   = co.employeeCount.toString();
    _price.text = co.monthlyPrice.toString();
    _tin.text   = co.tinNumber;
  }

  @override
  void dispose() {
    for (final c in [_name,_addr,_cont,_phone,_emp,_price,_tin]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coAsync = ref.watch(_coProvider(widget.coId));
    final paysAsync = ref.watch(_paysProvider(widget.coId));
    final brsAsync  = ref.watch(_brsProvider(widget.coId));

    return coAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      error:   (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
      data: (co) {
        if (co == null) return const Center(child: Text('Not found', style: TextStyle(color: Colors.white)));
        if (!_editing) _loadFrom(co);

        return Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header card
              _DCard(child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(co.name, style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _TypeBadge(co.isMulti),
                    const SizedBox(width: 10),
                    _StatusBadge(co.isActive),
                  ]),
                ]),
                const Spacer(),
                // Edit / Save
                if (!_editing) ...[
                  _OutBtn('Edit', Icons.edit_rounded, AppColors.primaryBlue,
                    () => setState(() => _editing = true)),
                  const SizedBox(width: 10),
                  _OutBtn(
                    co.isActive ? 'Suspend' : 'Activate',
                    co.isActive ? Icons.pause_circle_outlined : Icons.play_circle_outline_rounded,
                    co.isActive ? AppColors.errorRed : AppColors.successGreen,
                    () => showDialog(context: context, builder: (_) => _ConfirmDlg(
                      title:        co.isActive ? 'Suspend ${co.name}?' : 'Activate ${co.name}?',
                      message:      co.isActive
                        ? 'All users will be blocked from signing in.'
                        : 'Access will be restored for all users.',
                      confirmLabel: co.isActive ? 'Suspend' : 'Activate',
                      confirmColor: co.isActive ? AppColors.errorRed : AppColors.successGreen,
                      onConfirm: () async => ApiService().put(
                        '/api/companies/${co.id}/status',
                        data: {'status': co.isActive ? 'suspended' : 'active'},
                      ),
                    )),
                  ),
                ] else ...[
                  _OutBtn('Cancel', Icons.close_rounded, AppColors.textSecondary,
                    () => setState(() { _editing = false; _loadFrom(co); })),
                  const SizedBox(width: 10),
                  _OutBtn('Save', Icons.check_rounded, AppColors.successGreen,
                    _saving ? null : () => _saveEdit(co)),
                ],
              ])),
              const SizedBox(height: 16),

              // Info grid
              _DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SH('Company Information'),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(children: [
                    _InfoRow('Email', co.hrAdminEmail, editable: false),
                    _InfoRow('Phone', _editing ? null : co.hrAdminPhone,
                      ctrl: _editing ? _phone : null),
                    _InfoRow('Industry', co.industry, editable: false),
                    _InfoRow('Address', _editing ? null : co.address,
                      ctrl: _editing ? _addr : null),
                  ])),
                  const SizedBox(width: 24),
                  Expanded(child: Column(children: [
                    _InfoRow('Contact Person', _editing ? null : co.contactPerson,
                      ctrl: _editing ? _cont : null),
                    _InfoRow('Employees', _editing ? null : '${co.employeeCount}',
                      ctrl: _editing ? _emp : null, isNumber: true),
                    _InfoRow('Monthly Price', _editing ? null : _fmtPrice(co.monthlyPrice),
                      ctrl: _editing ? _price : null, isNumber: true),
                    _InfoRow('TIN Number', _editing ? null : co.tinNumber,
                      ctrl: _editing ? _tin : null),
                  ])),
                ]),
                _InfoRow('Created', _fmtDate(co.createdAt), editable: false),
              ])),
              const SizedBox(height: 16),

              // Branches (multi-branch only)
              if (co.isMulti) ...[
                brsAsync.when(
                  loading: () => const SizedBox(),
                  error:   (e, _) => const SizedBox(),
                  data: (brs) => _DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const _SH('Branches'),
                      const Spacer(),
                      _OutBtn('Add Branch', Icons.add_rounded, AppColors.primaryBlue,
                        () => setState(() => _addBranchOpen = true)),
                    ]),
                    const SizedBox(height: 14),
                    if (brs.isEmpty)
                      const Text('No branches yet.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                    else
                      ...brs.map((b) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _dark, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _bord),
                        ),
                        child: Row(children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b.name, style: const TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            if (b.location.isNotEmpty)
                              Text(b.location, style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                          ])),
                          if (b.code.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _bord, borderRadius: BorderRadius.circular(6)),
                              child: Text(b.code,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ),
                          const SizedBox(width: 10),
                          _StatusBadge(b.status == 'active'),
                        ]),
                      )),
                  ])),
                ),
                const SizedBox(height: 16),
              ],

              // Payments
              paysAsync.when(
                loading: () => const SizedBox(),
                error:   (e, _) => const SizedBox(),
                data: (pays) => _DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const _SH('Payment History'),
                    const Spacer(),
                    _OutBtn('Add Payment', Icons.add_rounded, AppColors.successGreen,
                      () => showDialog(context: context,
                        builder: (_) => _AddPayDlg(coId: widget.coId))),
                  ]),
                  const SizedBox(height: 14),
                  if (pays.isEmpty)
                    const Text('No payments recorded.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                  else
                    ...pays.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _dark, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _bord),
                      ),
                      child: Row(children: [
                        const Icon(Icons.payments_rounded, color: AppColors.successGreen, size: 16),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.date, style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          if (p.reference.isNotEmpty)
                            Text('Ref: ${p.reference}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                        Text(_fmtPrice(p.amount),
                          style: const TextStyle(color: AppColors.successGreen,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                    )),
                ])),
              ),
              const SizedBox(height: 24),
            ]),
          ),
          // Add branch panel
          if (_addBranchOpen)
            _AddBranchPanel(
              coId: widget.coId,
              onClose: () => setState(() => _addBranchOpen = false),
              onDone:  () => setState(() => _addBranchOpen = false),
            ),
        ]);
      },
    );
  }

  Future<void> _saveEdit(_Co co) async {
    setState(() => _saving = true);
    try {
      await ApiService().put('/api/companies/${co.id}', data: {
        'name':          _name.text.trim(),
        'address':       _addr.text.trim(),
        'contactPerson': _cont.text.trim(),
        'hrAdminPhone':  _phone.text.trim(),
        'employeeCount': _emp.text.trim(),
        'monthlyPrice':  _price.text.trim(),
        'tinNumber':     _tin.text.trim(),
      });
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DCard extends StatelessWidget {
  final Widget child;
  const _DCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _card, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _bord),
    ),
    child: child,
  );
}

class _SH extends StatelessWidget {
  final String text;
  const _SH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700));
}

class _OutBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _OutBtn(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final TextEditingController? ctrl;
  final bool editable, isNumber;
  const _InfoRow(this.label, this.value,
    {this.ctrl, this.editable = true, this.isNumber = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        if (ctrl != null)
          TextField(
            controller: ctrl,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true, fillColor: _dark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _bord)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _bord)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
            ),
          )
        else
          Text(value ?? '—', style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]),
    );
  }
}

// ── Add Payment dialog ────────────────────────────────────────────────────────
class _AddPayDlg extends ConsumerStatefulWidget {
  final String coId;
  const _AddPayDlg({required this.coId});
  @override
  ConsumerState<_AddPayDlg> createState() => _AddPayDlgState();
}

class _AddPayDlgState extends ConsumerState<_AddPayDlg> {
  final _date = TextEditingController();
  final _amt  = TextEditingController();
  final _ref  = TextEditingController();
  String _method = 'bank_transfer';
  bool _loading = false;
  String? _err;

  static const _methods = [
    'bank_transfer','mobile_money','cash','cheque','card',
  ];

  @override
  void dispose() { _date.dispose(); _amt.dispose(); _ref.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Payment', style: TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _DF(label: 'Date (YYYY-MM)', ctrl: _date),
          const SizedBox(height: 14),
          _DF(label: 'Amount (RWF)', ctrl: _amt, type: TextInputType.number),
          const SizedBox(height: 14),
          _DF(label: 'Reference', ctrl: _ref),
          const SizedBox(height: 14),
          const _FL('Payment Method'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bord)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _method, isExpanded: true,
                dropdownColor: _card,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _methods.map((m) => DropdownMenuItem(
                  value: m, child: Text(m.replaceAll('_', ' ')))).toList(),
                onChanged: (v) => setState(() => _method = v!),
              ),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _bord), foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
              ),
              child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_date.text.isEmpty || _amt.text.isEmpty) {
      setState(() => _err = 'Date and amount are required');
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      await ApiService().post('/api/companies/${widget.coId}/payment', data: {
        'date': _date.text.trim(), 'amount': _amt.text.trim(),
        'reference': _ref.text.trim(), 'method': _method,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _err = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Add Branch panel ──────────────────────────────────────────────────────────
class _AddBranchPanel extends ConsumerStatefulWidget {
  final String coId;
  final VoidCallback onClose, onDone;
  const _AddBranchPanel({required this.coId, required this.onClose, required this.onDone});
  @override
  ConsumerState<_AddBranchPanel> createState() => _AddBranchPanelState();
}

class _AddBranchPanelState extends ConsumerState<_AddBranchPanel> {
  final _name  = TextEditingController();
  final _loc   = TextEditingController();
  final _code  = TextEditingController();
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _aname = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_name,_loc,_code,_email,_pass,_aname]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black.withAlpha(100)),
        )),
        Container(
          width: 420, color: _card,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _bord))),
              child: Row(children: [
                const Text('Add Branch', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: widget.onClose,
                ),
              ]),
            ),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _DF(label: 'Branch Name *', ctrl: _name),
                const SizedBox(height: 20),
                _DF(label: 'Branch Location', ctrl: _loc),
                const SizedBox(height: 20),
                _DF(label: 'Branch Code', ctrl: _code),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Branch HR Admin (optional)',
                      style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _DF(label: 'Admin Name', ctrl: _aname),
                    const SizedBox(height: 14),
                    _DF(label: 'Admin Email', ctrl: _email, type: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _DF(label: 'Admin Password', ctrl: _pass, obscure: true),
                  ]),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.errorRed.withAlpha(60)),
                    ),
                    child: Text(_err!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                  ),
                ],
              ]),
            )),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: _bord))),
              child: HRNovaButton(
                label: 'Add Branch',
                onPressed: _loading ? null : _save,
                isLoading: _loading, isFullWidth: true,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Branch name is required');
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      await ApiService().post('/api/companies/${widget.coId}/branches', data: {
        'name': _name.text.trim(), 'location': _loc.text.trim(),
        'code': _code.text.trim(),
        if (_email.text.trim().isNotEmpty) ...{
          'branchAdminEmail':    _email.text.trim(),
          'branchAdminPassword': _pass.text,
          'branchAdminName':     _aname.text.trim(),
        },
      });
      if (mounted) widget.onDone();
    } catch (e) {
      setState(() => _err = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Billing view ──────────────────────────────────────────────────────────────
class _BillingView extends ConsumerWidget {
  const _BillingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_cosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      error:   (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
      data: (cos) {
        final active  = cos.where((c) => c.isActive).toList();
        final revenue = active.fold(0, (s, c) => s + c.monthlyPrice);
        final now     = DateTime.now();
        final thisMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Revenue metric
            Row(children: [
              _Metric(
                value: _fmtPrice(revenue),
                label: 'Total Monthly Revenue (Active)',
                icon: Icons.trending_up_rounded,
                color: AppColors.successGreen,
              ),
              const SizedBox(width: 14),
              _Metric(
                value: '${active.length}',
                label: 'Paying Companies',
                icon: Icons.business_rounded,
                color: AppColors.primaryBlue,
              ),
            ]),
            const SizedBox(height: 24),
            // Per-company table
            Container(
              decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _bord),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: Row(children: const [
                    Expanded(flex: 3, child: _TH('Company')),
                    Expanded(flex: 2, child: _TH('Monthly Price')),
                    Expanded(flex: 2, child: _TH('Last Payment')),
                    Expanded(flex: 2, child: _TH('Status')),
                  ]),
                ),
                Divider(height: 1, color: _bord),
                ...cos.map((c) {
                  final paid = c.lastPaymentDate.startsWith(thisMonth);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: (!c.isActive || paid) ? Colors.transparent
                        : AppColors.warningAmber.withAlpha(12),
                      border: Border(bottom: BorderSide(color: _bord.withAlpha(100))),
                    ),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(c.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
                      Expanded(flex: 2, child: Text(_fmtPrice(c.monthlyPrice),
                        style: const TextStyle(color: Colors.white, fontSize: 14))),
                      Expanded(flex: 2, child: Text(
                        c.lastPaymentDate.isEmpty ? '—' : c.lastPaymentDate,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      Expanded(flex: 2, child: !c.isActive
                        ? _StatusBadge(false)
                        : paid
                          ? Row(mainAxisSize: MainAxisSize.min, children: const [
                              Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 14),
                              SizedBox(width: 6),
                              Text('Paid', style: TextStyle(color: AppColors.successGreen,
                                fontSize: 13, fontWeight: FontWeight.w600)),
                            ])
                          : Row(mainAxisSize: MainAxisSize.min, children: const [
                              Icon(Icons.schedule_rounded, color: AppColors.warningAmber, size: 14),
                              SizedBox(width: 6),
                              Text('Pending', style: TextStyle(color: AppColors.warningAmber,
                                fontSize: 13, fontWeight: FontWeight.w600)),
                            ])),
                    ]),
                  );
                }),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
