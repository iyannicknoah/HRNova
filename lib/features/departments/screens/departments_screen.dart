import 'package:flutter/material.dart';
import '../../../shared/widgets/language_switcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../l10n/tr.dart';

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

  void _showAdd() => AppDialogShell.show(
    context: context,
    alignment: Alignment.center,
    child: _DeptDialog(
      title: context.tr('Add Department'),
      existing: _depts ?? [],
      onConfirm: (name) => _persist([...(_depts ?? []), name]),
    ),
  );

  void _showEdit(int i) => AppDialogShell.show(
    context: context,
    alignment: Alignment.center,
    child: _DeptDialog(
      title: context.tr('Edit Department'),
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
    AppDialogShell.show(
      context: context,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Delete Department'),
                style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 15),
            Text(
              'Remove "$name"?\n\nEmployees already assigned to this department will keep their current assignment — update them manually in the Employees section.',
              style: TextStyle(color: context.appSubtext, fontSize: 14, height: 1.6),
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
                  label: context.tr('Delete'),
                  isFullWidth: false,
                  backgroundColor: AppColors.errorRed,
                  onPressed: () {
                    Navigator.pop(context);
                    final copy = List<String>.from(_depts!);
                    copy.removeAt(i);
                    _persist(copy);
                  },
                ),
              ],
            ),
          ],
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.section, vertical: AppSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Departments'),
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
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
                  HRNovaButton(
                    label: context.tr('Add Department'),
                    icon: AppIcons.addRounded,
                    isFullWidth: false,
                    onPressed: _showAdd,
                  ),
                  const SizedBox(width: 12),
                  const LanguageSwitcher(size: 36),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: context.cardDeco(),
      child: Row(children: [
        SizedBox(
          width: 36, height: 36,
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        RowActionsMenu(actions: [
          RowAction(label: context.tr('Edit'), icon: AppIcons.editOutlined, onTap: onEdit),
          RowAction(label: context.tr('Delete'), icon: AppIcons.deleteOutlineRounded, onTap: onDelete, danger: true),
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AppIcon(AppIcons.categoryOutlined, size: 64, color: context.appSubtext.withAlpha(80)),
        const SizedBox(height: 16),
        Text(context.tr('No departments yet'),
            style: TextStyle(
              color: context.appText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 8),
        Text(
          context.tr('Add your company\'s departments to organise employees.'),
          style: TextStyle(color: context.appSubtext, fontSize: 15),
        ),
        const SizedBox(height: 24),
        HRNovaButton(
          label: context.tr('Add First Department'),
          icon: AppIcons.addRounded,
          isFullWidth: false,
          onPressed: onAdd,
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: context.pillBlueBg, borderRadius: BorderRadius.circular(12)),
                child: const AppIcon(AppIcons.categoryOutlined, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title,
                  style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: AppIcon(AppIcons.closeRounded, color: context.appSubtext),
              ),
            ]),
            const SizedBox(height: 20),

            // Field
            HRNovaTextField(
              label: context.tr('Department Name *'),
              controller: _ctrl,
              autofocus: true,
              onFieldSubmitted: (_) => _submit(),
              hint: context.tr('e.g. Human Resources'),
              errorText: _error,
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(children: [
              Expanded(child: HRNovaButton(
                label: context.tr('Cancel'),
                outlined: true,
                onPressed: _saving ? null : () => Navigator.pop(context),
              )),
              const SizedBox(width: 12),
              Expanded(child: HRNovaButton(
                label: widget.initial == null ? 'Add' : 'Save Changes',
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              )),
            ]),
      ]),
    );
  }
}
