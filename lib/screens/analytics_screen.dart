import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/heart_rate_data.dart';
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_result_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.cardBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(2),
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: context.textSecondary,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Trends'),
                    Tab(text: 'Comparison'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _OverviewTab(),
                  _TrendsTab(),
                  _ComparisonTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Overview ----------------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  String _range = 'Week';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final records = List.of(provider.records)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final distribution = provider.distribution;
    final total = provider.totalRecordings;
    final bpmBounds = _niceBounds(records.map((r) => r.bpm));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            for (final r in ['Day', 'Week', 'Month', 'Year']) ...[
              _RangeChip(label: r, selected: _range == r, onTap: () => setState(() => _range = r)),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Avg Heart Rate',
                value: provider.averageBpm.round().toString(),
                unit: 'BPM',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Total Recordings',
                value: total.toString(),
                unit: 'Times',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Normal Rate',
                value: '${provider.normalRatePercent.round()}%',
                unit: '${distribution[AiCondition.normal] ?? 0} / $total',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Heart Rate Trends (BPM)',
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: bpmBounds.interval,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= records.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM d').format(records[i].dateTime),
                            style: TextStyle(fontSize: 9, color: context.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: bpmBounds.min,
                maxY: bpmBounds.max,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < records.length; i++)
                        FlSpot(i.toDouble(), records[i].bpm.toDouble()),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Result Distribution',
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                        sections: [
                          PieChartSectionData(
                            value: (distribution[AiCondition.normal] ?? 0).toDouble(),
                            color: AppColors.normal,
                            showTitle: false,
                            radius: 20,
                          ),
                          PieChartSectionData(
                            value: (distribution[AiCondition.murmur] ?? 0).toDouble(),
                            color: AppColors.murmur,
                            showTitle: false,
                            radius: 20,
                          ),
                          PieChartSectionData(
                            value: (distribution[AiCondition.arrhythmia] ?? 0).toDouble(),
                            color: AppColors.arrhythmia,
                            showTitle: false,
                            radius: 20,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Total', style: TextStyle(fontSize: 10, color: context.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(color: AppColors.normal, label: 'Normal', value: distribution[AiCondition.normal] ?? 0, total: total),
                    const SizedBox(height: 8),
                    _LegendRow(color: AppColors.murmur, label: 'Murmur', value: distribution[AiCondition.murmur] ?? 0, total: total),
                    const SizedBox(height: 8),
                    _LegendRow(color: AppColors.arrhythmia, label: 'Arrhythmia', value: distribution[AiCondition.arrhythmia] ?? 0, total: total),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Time of Day (Records)',
          child: SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString().padLeft(2, '0'),
                        style: TextStyle(fontSize: 9, color: context.textSecondary),
                      ),
                    ),
                  ),
                ),
                barGroups: _hourlyBuckets(provider.records),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _hourlyBuckets(List<HeartRecord> records) {
    final buckets = List.filled(6, 0); // 0,4,8,12,16,20
    for (final r in records) {
      final idx = (r.dateTime.hour / 4).floor().clamp(0, 5);
      buckets[idx]++;
    }
    return [
      for (int i = 0; i < buckets.length; i++)
        BarChartGroupData(
          x: i * 4,
          barRods: [
            BarChartRodData(
              toY: buckets[i].toDouble(),
              color: AppColors.primary,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
    ];
  }
}

// ---------------- Trends ----------------

class _TrendsTab extends StatefulWidget {
  const _TrendsTab();

  @override
  State<_TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<_TrendsTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final records = List.of(provider.records.where((r) => r.dateTime.isAfter(cutoff)))
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final effective = records.isEmpty ? provider.records : records;
    final avg = effective.isEmpty
        ? 0
        : effective.map((r) => r.bpm).reduce((a, b) => a + b) / effective.length;
    final minBpm = effective.isEmpty ? 0 : effective.map((r) => r.bpm).reduce((a, b) => a < b ? a : b);
    final maxBpm = effective.isEmpty ? 0 : effective.map((r) => r.bpm).reduce((a, b) => a > b ? a : b);
    final bpmBounds = _niceBounds(effective.map((r) => r.bpm));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Heart Rate (BPM)', style: TextStyle(fontWeight: FontWeight.w600)),
              Icon(Icons.expand_more, color: context.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final d in [7, 30, 90]) ...[
              _RangeChip(label: '$d Days', selected: _days == d, onTap: () => setState(() => _days = d)),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: '',
          child: SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: bpmBounds.interval,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= effective.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM d').format(effective[i].dateTime),
                            style: TextStyle(fontSize: 9, color: context.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: bpmBounds.min,
                maxY: bpmBounds.max,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < effective.length; i++)
                        FlSpot(i.toDouble(), effective[i].bpm.toDouble()),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Average', value: avg.round().toString(), unit: 'BPM')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Minimum', value: minBpm.toString(), unit: 'BPM')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Maximum', value: maxBpm.toString(), unit: 'BPM')),
          ],
        ),
      ],
    );
  }
}

// ---------------- Comparison ----------------

class _ComparisonTab extends StatefulWidget {
  const _ComparisonTab();

  @override
  State<_ComparisonTab> createState() => _ComparisonTabState();
}

class _ComparisonTabState extends State<_ComparisonTab> {
  final List<String> _selectedIds = [];
  static const _lineColors = [AppColors.normal, AppColors.murmur, AppColors.arrhythmia];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final records = provider.records;
    final selectedRecords = records.where((r) => _selectedIds.contains(r.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Compare Records',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          'Select up to 3 records to compare',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final record in records)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.cardBorder),
            ),
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selectedIds.contains(record.id),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    if (_selectedIds.length < 3) _selectedIds.add(record.id);
                  } else {
                    _selectedIds.remove(record.id);
                  }
                });
              },
              title: Text(
                '${DateFormat('MMM d, yyyy hh:mm a').format(record.dateTime)}  ${record.bpm} BPM',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              secondary: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorForCondition(record.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.statusLabel,
                  style: TextStyle(color: colorForCondition(record.status), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (selectedRecords.isNotEmpty) ...[
          const Text('Comparison Graph', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _ChartCard(
            title: '',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    for (int i = 0; i < selectedRecords.length; i++)
                      LineChartBarData(
                        spots: [
                          for (int j = 0; j < selectedRecords[i].waveform.length; j++)
                            FlSpot(j.toDouble(), selectedRecords[i].waveform[j]),
                        ],
                        isCurved: true,
                        color: _lineColors[i % _lineColors.length],
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (int i = 0; i < selectedRecords.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _lineColors[i % _lineColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('MMM d').format(selectedRecords[i].dateTime)} (${selectedRecords[i].statusLabel})',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------- Shared small widgets ----------------

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : context.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(unit, style: TextStyle(fontSize: 10, color: context.textSecondary)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.value, required this.total});

  final Color color;
  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (value / total * 100).round();
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text('$pct% ($value)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ChartBounds {
  const _ChartBounds({required this.min, required this.max, required this.interval});

  final double min;
  final double max;
  final double interval;
}

/// Computes rounded-to-10 axis bounds with a fixed number of gridlines so
/// fl_chart's left-axis labels don't crowd/overlap for small BPM ranges.
_ChartBounds _niceBounds(Iterable<int> values) {
  if (values.isEmpty) return const _ChartBounds(min: 0, max: 120, interval: 30);
  final lo = (values.reduce((a, b) => a < b ? a : b) / 10).floor() * 10 - 10;
  final hi = (values.reduce((a, b) => a > b ? a : b) / 10).ceil() * 10 + 10;
  final interval = ((hi - lo) / 4).ceilToDouble();
  return _ChartBounds(min: lo.toDouble(), max: hi.toDouble(), interval: interval);
}
