import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_dropdown.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../models/company_settings_model.dart';
import '../../../l10n/tr.dart';

/// Editable list of company deduction rules — shared by Settings and
/// Onboarding. PAYE is statutory and intentionally not part of this list.
class DeductionsEditor extends StatelessWidget {
  const DeductionsEditor({
    super.key,
    required this.deductions,
    required this.onChanged,
    this.sampleSalary = 500000,
  });

  final List<DeductionRule> deductions;
  final ValueChanged<List<DeductionRule>> onChanged;
  final double sampleSalary;

  static String pct(double p) =>
      p % 1 == 0 ? '${p.toStringAsFixed(0)}%' : '$p%';

  @override
  Widget build(BuildContext context) {
    final employeeTotal = deductions
        .where((d) => d.active && d.side == DeductionRule.sideEmployee)
        .fold(0.0, (s, d) => s + d.percent);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        context.tr('Percentage deductions applied on each employee\'s adjusted gross during payroll. PAYE tax is set by law and applied automatically — it is not listed here.'),
        style: TextStyle(color: context.appSubtext, fontSize: 14, height: 1.4),
      ),
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: () => onChanged(List.of(DeductionRule.rssbDefaults)),
        icon: const AppIcon(AppIcons.refreshRounded, size: 14, color: AppColors.primaryBlue),
        label: Text(context.tr('Reset to standard RSSB rates'),
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 13)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
      ),
      const SizedBox(height: 8),
      if (deductions.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.pillAmberBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warningAmber.withAlpha(80)),
          ),
          child: Text(
            context.tr('No deductions configured — payroll will only deduct PAYE, loans and manual adjustments.'),
            style: TextStyle(color: AppColors.warningAmber, fontSize: 14),
          ),
        ),
      ...deductions.asMap().entries.map((e) => _DeductionRow(
            key: ValueKey('${e.key}-${e.value.title}-${e.value.side}'),
            rule: e.value,
            sampleSalary: sampleSalary,
            onChanged: (r) {
              final next = List.of(deductions);
              next[e.key] = r;
              onChanged(next);
            },
            onRemove: () {
              final next = List.of(deductions)..removeAt(e.key);
              onChanged(next);
            },
          )),
      const SizedBox(height: 10),
      _AddDeductionRow(onAdd: (rule) => onChanged([...deductions, rule])),
      if (employeeTotal > 50) ...[
        const SizedBox(height: 10),
        Row(children: [
          const AppIcon(AppIcons.warningAmberRounded, size: 14, color: AppColors.warningAmber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Employee-side deductions total ${pct(employeeTotal)} — verify this is intended.',
              style: const TextStyle(color: AppColors.warningAmber, fontSize: 13),
            ),
          ),
        ]),
      ],
    ]);
  }
}

class _DeductionRow extends StatefulWidget {
  const _DeductionRow({
    super.key,
    required this.rule,
    required this.sampleSalary,
    required this.onChanged,
    required this.onRemove,
  });

  final DeductionRule rule;
  final double sampleSalary;
  final ValueChanged<DeductionRule> onChanged;
  final VoidCallback onRemove;

  @override
  State<_DeductionRow> createState() => _DeductionRowState();
}

class _DeductionRowState extends State<_DeductionRow> {
  late final _titleCtrl = TextEditingController(text: widget.rule.title);
  late final _pctCtrl = TextEditingController(
      text: widget.rule.percent % 1 == 0
          ? widget.rule.percent.toStringAsFixed(0)
          : widget.rule.percent.toString());

  @override
  void dispose() {
    _titleCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final sample = (widget.sampleSalary * r.percent / 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            flex: 4,
            child: HRNovaTextField(
              label: context.tr('Deduction Title'),
              controller: _titleCtrl,
              hint: context.tr('e.g. Employee Insurance'),
              onChanged: (v) => widget.onChanged(r.copyWith(title: v.trim())),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: HRNovaTextField(
              label: context.tr('Rate'),
              controller: _pctCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text('%', style: TextStyle(color: context.appSubtext, fontSize: 15)),
                ),
              ),
              onChanged: (v) {
                final p = double.tryParse(v);
                if (p != null) widget.onChanged(r.copyWith(percent: p));
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: HRNovaDropdown<String>(
              label: context.tr('Paid By'),
              value: r.side,
              items: [
                DropdownMenuItem(value: DeductionRule.sideEmployee, child: Text(context.tr('Employee'))),
                DropdownMenuItem(value: DeductionRule.sideEmployer, child: Text(context.tr('Employer'))),
              ],
              onChanged: (v) => widget.onChanged(r.copyWith(side: v)),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: r.active ? 'Active — tap to disable' : 'Disabled — tap to enable',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Switch(
                value: r.active,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (v) => widget.onChanged(r.copyWith(active: v)),
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const AppIcon(AppIcons.removeCircleOutlineRounded,
                size: 20, color: AppColors.errorRed),
            tooltip: context.tr('Remove'),
          ),
        ]),
        if (r.active && r.percent > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              'e.g. on a ${_fmtNum(widget.sampleSalary)} RWF salary this '
              '${r.side == DeductionRule.sideEmployee ? 'deducts' : 'adds (employer cost)'} '
              '${_fmtNum(sample.toDouble())} RWF',
              style: TextStyle(color: context.appSubtext, fontSize: 12),
            ),
          ),
      ]),
    );
  }

  static String _fmtNum(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _AddDeductionRow extends StatefulWidget {
  const _AddDeductionRow({required this.onAdd});
  final ValueChanged<DeductionRule> onAdd;

  @override
  State<_AddDeductionRow> createState() => _AddDeductionRowState();
}

class _AddDeductionRowState extends State<_AddDeductionRow> {
  final _titleCtrl = TextEditingController();
  final _pctCtrl = TextEditingController();
  String _side = DeductionRule.sideEmployee;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final title = _titleCtrl.text.trim();
    final pctVal = double.tryParse(_pctCtrl.text) ?? 0;
    if (title.isEmpty || pctVal <= 0) return;
    widget.onAdd(DeductionRule(title: title, percent: pctVal, side: _side));
    _titleCtrl.clear();
    _pctCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        flex: 4,
        child: HRNovaTextField(
          label: context.tr('New Deduction'),
          controller: _titleCtrl,
          hint: context.tr('e.g. Medical Insurance'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: HRNovaTextField(
          label: context.tr('Rate'),
          controller: _pctCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          hint: '6',
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text('%', style: TextStyle(color: context.appSubtext, fontSize: 15)),
            ),
          ),
        ),
      ),
      SizedBox(width: 10),
      Expanded(
        flex: 3,
        child: HRNovaDropdown<String>(
          label: context.tr('Paid By'),
          value: _side,
          items: [
            DropdownMenuItem(value: DeductionRule.sideEmployee, child: Text(context.tr('Employee'))),
            DropdownMenuItem(value: DeductionRule.sideEmployer, child: Text(context.tr('Employer'))),
          ],
          onChanged: (v) => setState(() => _side = v ?? DeductionRule.sideEmployee),
        ),
      ),
      const SizedBox(width: 10),
      HRNovaButton(
        label: context.tr('Add'),
        icon: AppIcons.addRounded,
        isFullWidth: false,
        onPressed: _add,
      ),
    ]);
  }
}
