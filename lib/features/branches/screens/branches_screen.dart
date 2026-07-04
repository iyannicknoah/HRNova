import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../models/branch_model.dart';
import '../providers/branches_provider.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  String _search = '';

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddBranchDialog(
      onAdd: ({required name, location, branchCode, adminEmail, adminPassword}) async {
        await ref.read(branchesNotifierProvider.notifier).addBranch(
          name: name,
          location: location ?? '',
          branchCode: branchCode ?? '',
          adminEmail: adminEmail,
          adminPassword: adminPassword,
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesStreamProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.errorRed))),
        data: (branches) {
          final filtered = _search.isEmpty
              ? branches
              : branches.where((b) {
                  final q = _search.toLowerCase();
                  return b.name.toLowerCase().contains(q) ||
                      b.location.toLowerCase().contains(q) ||
                      b.branchCode.toLowerCase().contains(q);
                }).toList();

          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Branches', style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Manage your company branches', style: TextStyle(color: context.appSubtext, fontSize: 15)),
                    ]),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Branch'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats
                Row(children: [
                  _StatChip('${branches.length} Total', Icons.business_rounded, AppColors.primaryBlue, AppColors.pillBlueBg),
                  const SizedBox(width: 10),
                  _StatChip('${branches.where((b) => b.isActive).length} Active', Icons.check_circle_rounded, AppColors.successGreen, AppColors.pillGreenBg),
                  const SizedBox(width: 10),
                  _StatChip('${branches.fold(0, (s, b) => s + b.employeeCount)} Employees', Icons.people_rounded, AppColors.warningAmber, AppColors.pillAmberBg),
                ]),
                const SizedBox(height: 20),
                // Search
                Container(
                  decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.appBorder)),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(color: context.appText, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search branches...',
                      hintStyle: TextStyle(color: context.appSubtext),
                      prefixIcon: Icon(Icons.search_rounded, color: context.appSubtext, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Grid
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.business_outlined, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              branches.isEmpty ? 'No branches yet — add one to get started' : 'No branches match your search',
                              style: TextStyle(color: context.appSubtext, fontSize: 16),
                            ),
                          ]),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380, childAspectRatio: 1.5,
                            crossAxisSpacing: 14, mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _BranchCard(
                            branch: filtered[i],
                            onToggleActive: (active) async {
                              await ref.read(branchesNotifierProvider.notifier)
                                  .setActive(filtered[i].id, isActive: active);
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.icon, this.color, this.bg);
  final String label;
  final IconData icon;
  final Color color, bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Branch card ───────────────────────────────────────────────────────────────
class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.onToggleActive});
  final BranchModel branch;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.appCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.appBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.gradientForName(branch.name), begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(branch.name[0], style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(branch.name, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                if (branch.branchCode.isNotEmpty)
                  Text(branch.branchCode, style: TextStyle(color: context.appSubtext, fontSize: 13)),
              ])),
              GestureDetector(
                onTap: () => onToggleActive(!branch.isActive),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: branch.isActive ? AppColors.pillGreenBg : AppColors.pillRedBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    branch.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: branch.isActive ? AppColors.pillGreenText : AppColors.pillRedText, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: 10),
          _row(Icons.location_on_rounded, branch.location.isEmpty ? 'No location set' : branch.location),
          const SizedBox(height: 6),
          _row(Icons.people_rounded, '${branch.employeeCount} employees'),
          const SizedBox(height: 6),
          _row(Icons.email_outlined, branch.branchHrAdminEmail ?? 'No HR Admin assigned'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Builder(builder: (context) => Row(children: [
    Icon(icon, size: 14, color: context.appSubtext),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: TextStyle(color: context.appSubtext, fontSize: 14), overflow: TextOverflow.ellipsis)),
  ]));
}

// ── Add Branch dialog ─────────────────────────────────────────────────────────
class _AddBranchDialog extends StatefulWidget {
  const _AddBranchDialog({required this.onAdd});

  final Future<void> Function({
    required String name,
    String? location,
    String? branchCode,
    String? adminEmail,
    String? adminPassword,
  }) onAdd;

  @override
  State<_AddBranchDialog> createState() => _AddBranchDialogState();
}

class _AddBranchDialogState extends State<_AddBranchDialog> {
  final _nameCtrl    = TextEditingController();
  final _locCtrl     = TextEditingController();
  final _codeCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  bool _addAdmin = false;
  bool _obscure  = true;
  bool _saving   = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _locCtrl.dispose(); _codeCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Branch name is required');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onAdd(
        name: _nameCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        branchCode: _codeCtrl.text.trim(),
        adminEmail: _addAdmin ? _emailCtrl.text.trim() : null,
        adminPassword: _addAdmin ? _passCtrl.text : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${_nameCtrl.text.trim()}" branch added successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_business_rounded, color: AppColors.primaryBlue, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Add New Branch', style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: context.appSubtext)),
                ],
              ),
              const SizedBox(height: 24),
              _dlgField('Branch Name *', _nameCtrl, hint: 'e.g. Musanze Branch'),
              const SizedBox(height: 14),
              _dlgField('Location', _locCtrl, hint: 'e.g. Musanze District'),
              const SizedBox(height: 14),
              _dlgField('Branch Code', _codeCtrl, hint: 'e.g. MSZ-001'),
              const SizedBox(height: 20),
              // Toggle: create HR Admin account
              InkWell(
                onTap: () => setState(() => _addAdmin = !_addAdmin),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.appField,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _addAdmin ? AppColors.primaryBlue : context.appBorder, width: _addAdmin ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Icon(_addAdmin ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: _addAdmin ? AppColors.primaryBlue : context.appSubtext, size: 20),
                    const SizedBox(width: 10),
                    Text('Create Branch HR Admin account', style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              if (_addAdmin) ...[
                const SizedBox(height: 14),
                _dlgField('Admin Email', _emailCtrl, hint: 'hr@company.rw', type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Temporary Password', style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: TextStyle(color: context.appText, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Min 8 characters',
                      hintStyle: TextStyle(color: context.appSubtext),
                      filled: true, fillColor: context.appField,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: context.appSubtext),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                    ),
                  ),
                ]),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.pillRedBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 15))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: context.appText)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      disabledBackgroundColor: AppColors.primaryBlue.withAlpha(100),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dlgField(String label, TextEditingController ctrl, {String? hint, TextInputType? type}) =>
      Builder(builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type,
          style: TextStyle(color: context.appText, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.appSubtext),
            filled: true, fillColor: context.appField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.appBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
        ),
      ]));
}
