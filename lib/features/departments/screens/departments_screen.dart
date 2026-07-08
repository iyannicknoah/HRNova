import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../settings/providers/settings_provider.dart';

class DepartmentsScreen extends ConsumerStatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  ConsumerState<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends ConsumerState<DepartmentsScreen> {
  List<String>? _depts;
  bool _saving = false;

  void _sync(List<String> fromSettings) {
    if (_depts == null) _depts = List.from(fromSettings);
  }

  Future<void> _persist(List<String> updated) async {
    setState(() { _depts = updated; _saving = true; });
    try {
      await ref.read(settingsNotifierProvider.notifier)
          .updateSettings({'departments': updated});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAdd() => showDialog(
    context: context,
    builder: (_) => _DeptDialog(
      title: 'Add Department',
      existing: _depts ?? [],
      onConfirm: (name) => _persist([...(_depts ?? []), name]),
    ),
  );

  void _showEdit(int i) => showDialog(
    context: context,
    builder: (_) => _DeptDialog(
      title: 'Edit Department',
      initial: _depts![i],
      existing: (_depts ?? []).where((d) => d != _depts![i]).toList(),
      onConfirm: (name) async {
        final copy = List<String>.from(_depts!);
        copy[i] = name;
        await _persist(copy);
      },
    ),
  );

  void _confirmDelete(int i) {
    final name = _depts![i];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Department',
            style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "$name"?\n\nEmployees already assigned to this department will keep their current assignment — update them manually in the Employees section.',
          style: TextStyle(color: context.appSubtext, fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.appSubtext)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final copy = List<String>.from(_depts!);
              copy.removeAt(i);
              _persist(copy);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.errorRed)))),
      data: (settings) {
        final rawDepts = settings?.departments ?? [];
        _sync(rawDepts);
        final depts = _depts ?? rawDepts;

        return Scaffold(
          backgroundColor: context.appBg,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Departments',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      depts.isEmpty
                          ? 'No departments yet'
                          : '${depts.length} department${depts.length == 1 ? '' : 's'}',
                      style: TextStyle(color: context.appSubtext, fontSize: 15),
                    ),
                  ]),
                  const Spacer(),
                  if (_saving)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.appSubtext),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _showAdd,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Department', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Body ───────────────────────────────────────────────────
                if (depts.isEmpty)
                  Expanded(child: _EmptyState(onAdd: _showAdd))
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: depts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _DeptTile(
                        name: depts[i],
                        index: i + 1,
                        onEdit: () => _showEdit(i),
                        onDelete: () => _confirmDelete(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Department tile ───────────────────────────────────────────────────────────
class _DeptTile extends StatelessWidget {
  const _DeptTile({
    required this.name,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.pillBlueBg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: context.appText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _IconBtn(
          icon: Icons.edit_outlined,
          color: AppColors.primaryBlue,
          bg: AppColors.pillBlueBg,
          tooltip: 'Edit',
          onTap: onEdit,
        ),
        const SizedBox(width: 8),
        _IconBtn(
          icon: Icons.delete_outline_rounded,
          color: AppColors.errorRed,
          bg: AppColors.pillRedBg,
          tooltip: 'Delete',
          onTap: onDelete,
        ),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color, bg;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.category_outlined, size: 64, color: context.appSubtext.withAlpha(80)),
        const SizedBox(height: 16),
        Text('No departments yet',
            style: TextStyle(
              color: context.appText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        Text(
          'Add your company\'s departments to organise employees.',
          style: TextStyle(color: context.appSubtext, fontSize: 15),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add First Department', style: TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
        ),
      ]),
    );
  }
}

// ── Add / Edit dialog ─────────────────────────────────────────────────────────
class _DeptDialog extends StatefulWidget {
  const _DeptDialog({
    required this.title,
    required this.existing,
    required this.onConfirm,
    this.initial,
  });

  final String title;
  final String? initial;
  final List<String> existing;
  final Future<void> Function(String name) onConfirm;

  @override
  State<_DeptDialog> createState() => _DeptDialogState();
}

class _DeptDialogState extends State<_DeptDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Department name is required.');
      return;
    }
    final lower = name.toLowerCase();
    if (widget.existing.any((d) => d.toLowerCase() == lower)) {
      setState(() => _error = '"$name" already exists.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onConfirm(name);
      if (mounted) Navigator.pop(context);
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
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.pillBlueBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.category_outlined, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title,
                  style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: context.appSubtext),
              ),
            ]),
            const SizedBox(height: 24),

            // Field
            Text('Department Name *',
                style: TextStyle(color: context.appSubtext, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: context.appText, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Human Resources',
                hintStyle: TextStyle(color: context.appSubtext),
                filled: true,
                fillColor: context.appField,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.appBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.appBorder)),
                focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                errorText: _error,
                errorStyle: const TextStyle(color: AppColors.errorRed),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.appBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text('Cancel', style: TextStyle(color: context.appText, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  disabledBackgroundColor: AppColors.primaryBlue.withAlpha(100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.initial == null ? 'Add' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}
