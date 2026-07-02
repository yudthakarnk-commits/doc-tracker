import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../i18n.dart';
import '../models/doc_record.dart';
import '../services/data_service.dart';

final _numFmt = NumberFormat('#,##0');

String _short(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return _numFmt.format(n);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _mode = 'year'; // 'year' | 'month' | 'week'
  String? _year; // null -> latest year available
  String? _month; // 'yyyy-MM'
  int? _week;
  String? _hatchery; // null = all

  @override
  Widget build(BuildContext context) {
    final svc = DataService.instance;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        if (svc.loading && svc.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (svc.error != null && svc.records.isEmpty) {
          return _ErrorView(message: svc.error!);
        }

        // Available filter values from data
        final years = svc.records
            .map((r) => r.recordDate.length >= 4
                ? r.recordDate.substring(0, 4)
                : '')
            .where((y) => y.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        final months = svc.records
            .map((r) => r.recordDate.length >= 7
                ? r.recordDate.substring(0, 7)
                : '')
            .where((m) => m.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        final weeks = svc.weeksByRecency();

        final selYear =
            (_year != null && years.contains(_year)) ? _year! : (years.isNotEmpty ? years.first : '');
        final selMonth =
            (_month != null && months.contains(_month)) ? _month! : (months.isNotEmpty ? months.first : '');
        final selWeek =
            (_week != null && weeks.contains(_week)) ? _week! : (weeks.isNotEmpty ? weeks.first : 0);

        // Hatchery filter applies to everything (including trend)
        var base = svc.records;
        if (_hatchery != null) {
          base = base.where((r) => r.hatchery == _hatchery).toList();
        }
        // Period filter for KPIs / donut / bars
        var rows = base;
        if (_mode == 'year' && selYear.isNotEmpty) {
          rows = rows.where((r) => r.recordDate.startsWith(selYear)).toList();
        } else if (_mode == 'month' && selMonth.isNotEmpty) {
          rows = rows.where((r) => r.recordDate.startsWith(selMonth)).toList();
        } else if (_mode == 'week') {
          rows = rows.where((r) => r.weekNo == selWeek).toList();
        }

        final totalAct =
            rows.fold<int>(0, (s, r) => s + r.totalActual);
        final totalOrd =
            rows.fold<int>(0, (s, r) => s + r.totalOrdered);
        final fulfill = totalOrd > 0 ? totalAct / totalOrd * 100 : 0.0;
        final customers =
            rows.map((r) => r.customerName).where((n) => n.isNotEmpty).toSet();

        return RefreshIndicator(
          onRefresh: () => svc.loadAll(force: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Filter bar ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                              value: 'year', label: Text(tr('filterYear'))),
                          ButtonSegment(
                              value: 'month', label: Text(tr('filterMonth'))),
                          ButtonSegment(
                              value: 'week', label: Text(tr('filterWeek'))),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStatePropertyAll(const TextStyle(
                              fontFamily: 'Sarabun',
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _mode == 'year'
                              ? _dd<String>(
                                  value: selYear.isEmpty ? null : selYear,
                                  items: [
                                    for (final y in years)
                                      DropdownMenuItem(
                                          value: y, child: Text(y)),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _year = v),
                                )
                              : _mode == 'month'
                                  ? _dd<String>(
                                      value: selMonth.isEmpty
                                          ? null
                                          : selMonth,
                                      items: [
                                        for (final m in months)
                                          DropdownMenuItem(
                                              value: m,
                                              child: Text(monthLabel(m))),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _month = v),
                                    )
                                  : _dd<int>(
                                      value: selWeek == 0 ? null : selWeek,
                                      items: [
                                        for (final w in weeks)
                                          DropdownMenuItem(
                                              value: w,
                                              child: Text('Week $w')),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _week = v),
                                    ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dd<String?>(
                            value: _hatchery,
                            items: [
                              DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(tr('allHatcheries'))),
                              for (final h in AppConfig.hatcheries)
                                DropdownMenuItem<String?>(
                                    value: h, child: Text(h)),
                            ],
                            onChanged: (v) =>
                                setState(() => _hatchery = v),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _KpiGrid(cards: [
                _Kpi('📦', tr('kpiDelivered'), _short(totalAct),
                    const Color(0xFF2563EB)),
                _Kpi('📋', tr('kpiOrdered'), _short(totalOrd),
                    const Color(0xFF7C3AED)),
                _Kpi('🎯', tr('kpiFulfillment'),
                    '${fulfill.toStringAsFixed(1)}%', const Color(0xFF059669)),
                _Kpi('👥', tr('kpiCustomers'), _numFmt.format(customers.length),
                    const Color(0xFFF59E0B)),
              ]),
              const SizedBox(height: 16),
              _ChartCard(
                title: tr('chartTrend'),
                child: SizedBox(height: 220, child: _TrendChart(rows: base)),
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: tr('chartTypeRatio'),
                child: SizedBox(height: 220, child: _TypeDonut(rows: rows)),
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: tr('chartHatchery'),
                child: _HatcheryBars(rows: rows),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact dropdown used in the filter bar.
  Widget _dd<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _Kpi {
  final String emoji, label, value;
  final Color color;
  _Kpi(this.emoji, this.label, this.value, this.color);
}

class _KpiGrid extends StatelessWidget {
  final List<_Kpi> cards;
  const _KpiGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: cards
          .map((k) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: k.color.withOpacity(.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(k.emoji,
                              style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(k.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                        ),
                      ]),
                      const Spacer(),
                      Text(k.value,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: k.color)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Weekly ordered vs actual line chart (grouped by Monday of each week).
class _TrendChart extends StatelessWidget {
  final List<DocRecord> rows;
  const _TrendChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final byWeek = <String, List<num>>{}; // monday -> [ordered, actual, weekNo]
    for (final r in rows) {
      if (r.recordDate.isEmpty) continue;
      final d = DateTime.tryParse(r.recordDate);
      if (d == null) continue;
      final monday = d.subtract(Duration(days: (d.weekday + 6) % 7));
      final key = DateFormat('yyyy-MM-dd').format(monday);
      final e = byWeek.putIfAbsent(key, () => [0, 0, r.weekNo]);
      e[0] += r.totalOrdered;
      e[1] += r.totalActual;
    }
    final keys = byWeek.keys.toList()..sort();
    final recent = keys.length > 13 ? keys.sublist(keys.length - 13) : keys;
    if (recent.isEmpty) return Center(child: Text(tr('noData')));

    final ordSpots = <FlSpot>[];
    final actSpots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      ordSpots.add(FlSpot(i.toDouble(), byWeek[recent[i]]![0].toDouble()));
      actSpots.add(FlSpot(i.toDouble(), byWeek[recent[i]]![1].toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.grey.withOpacity(.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(_short(v),
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (recent.length / 5).ceilToDouble().clamp(1, 99),
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= recent.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('W${byWeek[recent[i]]![2].toInt()}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: ordSpots,
            isCurved: true,
            color: const Color(0xFF2563EB),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF2563EB).withOpacity(.08)),
          ),
          LineChartBarData(
            spots: actSpots,
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF10B981).withOpacity(.08)),
          ),
        ],
      ),
    );
  }
}

/// Customer / Contract Farm / Company Farm donut.
class _TypeDonut extends StatelessWidget {
  final List<DocRecord> rows;
  const _TypeDonut({required this.rows});

  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981)
  ];

  @override
  Widget build(BuildContext context) {
    final totals = {for (final t in AppConfig.customerTypes) t: 0};
    for (final r in rows) {
      if (totals.containsKey(r.customerType)) {
        totals[r.customerType] = totals[r.customerType]! + r.totalActual;
      }
    }
    final grand = totals.values.fold<int>(0, (a, b) => a + b);
    if (grand == 0) return Center(child: Text(tr('noData')));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 42,
              sectionsSpace: 3,
              sections: [
                for (var i = 0; i < AppConfig.customerTypes.length; i++)
                  PieChartSectionData(
                    value: totals[AppConfig.customerTypes[i]]!.toDouble(),
                    color: _colors[i],
                    radius: 46,
                    title:
                        '${(totals[AppConfig.customerTypes[i]]! / grand * 100).toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < AppConfig.customerTypes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _colors[i], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                      '${AppConfig.customerTypes[i]}\n${_numFmt.format(totals[AppConfig.customerTypes[i]])}',
                      style: const TextStyle(fontSize: 11)),
                ]),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal bars: actual per hatchery.
class _HatcheryBars extends StatelessWidget {
  final List<DocRecord> rows;
  const _HatcheryBars({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totals = {for (final h in AppConfig.hatcheries) h: 0};
    for (final r in rows) {
      if (totals.containsKey(r.hatchery)) {
        totals[r.hatchery] = totals[r.hatchery]! + r.totalActual;
      }
    }
    final max = totals.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: AppConfig.hatcheries.map((h) {
        final v = totals[h]!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
                width: 82,
                child: Text(h,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v / max,
                  minHeight: 14,
                  backgroundColor: Colors.grey.withOpacity(.12),
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
                width: 62,
                child: Text(_numFmt.format(v),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        );
      }).toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => DataService.instance.loadAll(force: true),
                child: Text(tr('retry'))),
          ],
        ),
      ),
    );
  }
}
