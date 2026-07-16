import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/tr.dart';
import '../../../shared/widgets/app_icon.dart';

final _n = NumberFormat('#,##0', 'en_US');
String _rwf(num v) => 'RWF ${_n.format(v.round())}';

/// Super-admin cost analytics: live Firestore usage from Cloud Monitoring,
/// estimated cost (Blaze prices minus free tier), earnings from recorded
/// payments, and a monthly profit comparison against 50% of earnings.
/// Auto-refreshes every 60 seconds.
class CostAnalyticsView extends StatefulWidget {
  const CostAnalyticsView({super.key});

  @override
  State<CostAnalyticsView> createState() => _CostAnalyticsViewState();
}

class _CostAnalyticsViewState extends State<CostAnalyticsView> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  DateTime? _fetchedAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiService().get('/api/cost-analytics');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(resp.data as Map);
        _fetchedAt = DateTime.now();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }
    if (_error != null && _data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppIcon(AppIcons.errorOutlineRounded, size: 40, color: AppColors.errorRed),
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: context.appSubtext, fontSize: 14)),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: Text(context.tr('Retry'))),
        ]),
      );
    }

    final d = _data!;
    final today = Map<String, dynamic>.from(d['today'] as Map);
    final free = Map<String, dynamic>.from(d['freeTierDaily'] as Map);
    final monthly = (d['monthly'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList();
    final daily30 = (d['daily30'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList();
    final thisMonth = monthly.isNotEmpty ? monthly.last : null;
    final usdToRwf = (d['usdToRwf'] as num?)?.toDouble() ?? 1450;
    final monitoringUnavailable = d['monitoringUnavailable'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Refresh row ────────────────────────────────────────────────────
        Row(children: [
          Text(context.tr('Live Firebase usage & profitability'),
              style: TextStyle(color: context.appSubtext, fontSize: 14)),
          const Spacer(),
          if (_fetchedAt != null)
            Text(
              context.trp('Updated {time} · refreshes every 60s',
                  {'time': DateFormat('HH:mm:ss').format(_fetchedAt!)}),
              style: TextStyle(color: context.appSubtext, fontSize: 12),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _load,
            tooltip: context.tr('Refresh'),
            icon: AppIcon(AppIcons.refreshRounded, size: 16, color: context.appSubtext),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Monitoring unavailable notice ──────────────────────────────────
        if (monitoringUnavailable != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warningAmber.withAlpha(80)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AppIcon(AppIcons.warningAmberRounded, size: 18, color: AppColors.warningAmber),
              const SizedBox(width: 10),
              Expanded(child: Text(
                monitoringUnavailable == 'billing_required'
                    ? context.tr('Live usage requires billing to be enabled on the Google Cloud project (Blaze plan). Earnings below are still live; usage and cost will activate automatically once billing is enabled.')
                    : context.trp('Usage metrics unavailable: {reason}', {'reason': monitoringUnavailable}),
                style: const TextStyle(color: AppColors.warningAmber, fontSize: 13, height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Today usage cards ──────────────────────────────────────────────
        Row(children: [
          Expanded(child: _UsageCard(
            label: context.tr('Reads today'),
            value: today['reads'] as int? ?? 0,
            freeLimit: free['reads'] as int? ?? 50000,
            color: AppColors.primaryBlue,
          )),
          const SizedBox(width: 12),
          Expanded(child: _UsageCard(
            label: context.tr('Writes today'),
            value: today['writes'] as int? ?? 0,
            freeLimit: free['writes'] as int? ?? 20000,
            color: AppColors.successGreen,
          )),
          const SizedBox(width: 12),
          Expanded(child: _UsageCard(
            label: context.tr('Deletes today'),
            value: today['deletes'] as int? ?? 0,
            freeLimit: free['deletes'] as int? ?? 20000,
            color: AppColors.warningAmber,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label: context.tr('Est. cost today'),
            value: '\$${((today['estCostUsd'] as num?) ?? 0).toStringAsFixed(4)}',
            sub: context.tr('after daily free tier'),
            color: AppColors.errorRed,
          )),
        ]),
        const SizedBox(height: 12),

        if (thisMonth != null)
          Row(children: [
            Expanded(child: _StatCard(
              label: context.tr('Est. cost this month'),
              value: '\$${((thisMonth['estCostUsd'] as num?) ?? 0).toStringAsFixed(2)}',
              sub: _rwf((thisMonth['estCostRwf'] as num?) ?? 0),
              color: AppColors.errorRed,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: context.tr('Earnings this month'),
              value: _rwf((thisMonth['earningsRwf'] as num?) ?? 0),
              sub: context.trp('50% = {amount}', {'amount': _rwf((thisMonth['halfEarningsRwf'] as num?) ?? 0)}),
              color: AppColors.successGreen,
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _ProfitBanner(month: thisMonth)),
          ]),
        const SizedBox(height: 20),

        // ── Daily est. cost bars (30 days) ─────────────────────────────────
        _Card(
          title: context.tr('Daily estimated cost — last 30 days'),
          child: SizedBox(height: 200, child: _DailyCostBars(daily30: daily30)),
        ),
        const SizedBox(height: 16),

        // ── Profit line chart ──────────────────────────────────────────────
        _Card(
          title: context.tr('Project cost vs 50% of earnings — monthly'),
          trailing: _Legend(items: [
            (context.tr('Est. project cost'), AppColors.errorRed),
            (context.tr('50% of earnings'), AppColors.successGreen),
          ]),
          child: SizedBox(height: 240, child: _ProfitLineChart(monthly: monthly)),
        ),
        const SizedBox(height: 12),

        // ── Note ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.pillBlueBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppIcon(AppIcons.infoOutlineRounded, size: 15, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Expanded(child: Text(
              context.trp(
                'Usage is live from Cloud Monitoring (minutes of delay). Cost is estimated at Blaze prices after the daily free tier — on the current Spark plan the real bill is \$0. Conversion: 1 USD = {rate} RWF.',
                {'rate': _n.format(usdToRwf)},
              ),
              style: const TextStyle(fontSize: 13, color: AppColors.primaryBlue, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Cards ──────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: context.cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText))),
        if (trailing != null) trailing!,
      ]),
      const SizedBox(height: 16),
      child,
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: context.cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, color: context.appSubtext)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(sub, style: TextStyle(fontSize: 12, color: context.appSubtext)),
    ]),
  );
}

class _UsageCard extends StatelessWidget {
  final String label;
  final int value, freeLimit;
  final Color color;
  const _UsageCard({required this.label, required this.value, required this.freeLimit, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = freeLimit > 0 ? (value / freeLimit).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: context.appSubtext)),
        const SizedBox(height: 6),
        Text(_n.format(value),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appText)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 5,
            backgroundColor: context.appBorder,
            valueColor: AlwaysStoppedAnimation(pct >= 0.9 ? AppColors.errorRed : color),
          ),
        ),
        const SizedBox(height: 4),
        Text(context.trp('{pct}% of free tier ({limit}/day)',
                {'pct': '${(pct * 100).round()}', 'limit': _n.format(freeLimit)}),
            style: TextStyle(fontSize: 11, color: context.appSubtext)),
      ]),
    );
  }
}

class _ProfitBanner extends StatelessWidget {
  final Map<String, dynamic> month;
  const _ProfitBanner({required this.month});

  @override
  Widget build(BuildContext context) {
    final profit = (month['profitRwf'] as num?) ?? 0;
    final profitable = profit >= 0;
    final color = profitable ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(children: [
        AppIcon(profitable ? AppIcons.trendingUpRounded : AppIcons.trendingDownRounded,
            size: 26, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            profitable ? context.tr('Profitable this month') : context.tr('Cost exceeds 50% of earnings'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            context.trp('{sign}{amount} after Firebase cost vs 50% of earnings',
                {'sign': profitable ? '+' : '−', 'amount': _rwf(profit.abs())}),
            style: TextStyle(fontSize: 12, color: context.appSubtext),
          ),
        ])),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<(String, Color)> items;
  const _Legend({required this.items});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    for (final (label, color) in items) ...[
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: context.appSubtext)),
      const SizedBox(width: 12),
    ],
  ]);
}

// ── Charts ────────────────────────────────────────────────────────────────────

class _DailyCostBars extends StatelessWidget {
  final List<Map<String, dynamic>> daily30;
  const _DailyCostBars({required this.daily30});

  @override
  Widget build(BuildContext context) {
    if (daily30.isEmpty) {
      return Center(child: Text(context.tr('No data'),
          style: TextStyle(color: context.appSubtext, fontSize: 13)));
    }
    final maxCost = daily30
        .map((r) => ((r['estCostUsd'] as num?) ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final ceiling = maxCost <= 0 ? 0.01 : maxCost * 1.2;
    return BarChart(BarChartData(
      maxY: ceiling,
      minY: 0,
      barGroups: daily30.asMap().entries.map((e) {
        final cost = ((e.value['estCostUsd'] as num?) ?? 0).toDouble().clamp(0.0, ceiling);
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: cost,
            color: cost > 0 ? AppColors.errorRed.withAlpha(220) : AppColors.successGreen.withAlpha(120),
            width: 8,
            borderRadius: BorderRadius.circular(3),
            backDrawRodData: BackgroundBarChartRodData(
                show: true, toY: ceiling, color: context.appBorder.withAlpha(50)),
          ),
        ]);
      }).toList(),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 18,
          getTitlesWidget: (val, _) {
            final i = val.toInt();
            if (i < 0 || i >= daily30.length || i % 5 != 0) return const SizedBox.shrink();
            return Text((daily30[i]['date'] as String).substring(5),
                style: TextStyle(fontSize: 9, color: context.appSubtext));
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 42,
          getTitlesWidget: (val, _) => Text('\$${val.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 9, color: context.appSubtext)),
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }
}

class _ProfitLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  const _ProfitLineChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Center(child: Text(context.tr('No data'),
          style: TextStyle(color: context.appSubtext, fontSize: 13)));
    }
    final costs = monthly.map((m) => ((m['estCostRwf'] as num?) ?? 0).toDouble()).toList();
    final halves = monthly.map((m) => ((m['halfEarningsRwf'] as num?) ?? 0).toDouble()).toList();
    final maxV = [...costs, ...halves].fold(0.0, (a, b) => a > b ? a : b);
    final ceiling = maxV <= 0 ? 1000.0 : maxV * 1.25;

    LineChartBarData line(List<double> vals, Color color) => LineChartBarData(
      spots: vals.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withAlpha(18)),
    );

    return LineChart(LineChartData(
      minY: 0,
      maxY: ceiling,
      lineBarsData: [
        line(costs, AppColors.errorRed),
        line(halves, AppColors.successGreen),
      ],
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: context.appBorder, strokeWidth: 0.5),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20, interval: 1,
          getTitlesWidget: (val, _) {
            final i = val.toInt();
            if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
            final m = monthly[i]['month'] as String;
            final label = DateFormat('MMM').format(DateTime.parse('$m-01'));
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(label, style: TextStyle(fontSize: 10, color: context.appSubtext)),
            );
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 52,
          getTitlesWidget: (val, _) {
            if (val == 0) return const SizedBox.shrink();
            final label = val >= 1000000
                ? '${(val / 1000000).toStringAsFixed(1)}M'
                : val >= 1000
                    ? '${(val / 1000).toStringAsFixed(0)}K'
                    : val.toStringAsFixed(0);
            return Text(label, style: TextStyle(fontSize: 9, color: context.appSubtext));
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) {
            final isCost = s.barIndex == 0;
            return LineTooltipItem(
              '${isCost ? context.tr('Cost') : context.tr('50% earnings')}: ${_rwf(s.y)}',
              TextStyle(color: isCost ? AppColors.errorRed : AppColors.successGreen,
                  fontSize: 12, fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
      ),
    ));
  }
}
