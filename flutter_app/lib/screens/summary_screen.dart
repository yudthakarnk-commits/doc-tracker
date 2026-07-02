import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../i18n.dart';
import '../services/data_service.dart';

final _numFmt = NumberFormat('#,##0');

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int? _week; // null = pick current/most recent on first build

  static const _typeColors = {
    'Customer': Color(0xFF1E40AF),
    'Contract Farm': Color(0xFFB45309),
    'Company Farm': Color(0xFF15803D),
  };

  @override
  Widget build(BuildContext context) {
    final svc = DataService.instance;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        if (svc.loading && svc.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final weeks = svc.weeksByRecency();
        if (weeks.isEmpty) return Center(child: Text(tr('noData')));

        final currentWeek = isoWeek(DateTime.now());
        final selected = _week ??
            (weeks.contains(currentWeek) ? currentWeek : weeks.first);
        final rows =
            svc.records.where((r) => r.weekNo == selected).toList();

        // pivot: type -> hatchery -> [ordered, actual]
        final pivot = {
          for (final t in AppConfig.customerTypes)
            t: {
              for (final h in AppConfig.hatcheries) h: [0, 0]
            }
        };
        for (final r in rows) {
          final cell = pivot[r.customerType]?[r.hatchery];
          if (cell != null) {
            cell[0] += r.totalOrdered;
            cell[1] += r.totalActual;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Text(tr('orderVsActual'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              DropdownButton<int>(
                value: selected,
                onChanged: (v) => setState(() => _week = v),
                items: weeks
                    .map((w) => DropdownMenuItem(
                        value: w, child: Text('Week $w')))
                    .toList(),
              ),
            ]),
            const SizedBox(height: 12),
            for (final type in AppConfig.customerTypes) ...[
              _TypeSection(
                type: type,
                color: _typeColors[type]!,
                data: pivot[type]!,
              ),
              const SizedBox(height: 12),
            ],
            _GrandTotal(pivot: pivot),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _TypeSection extends StatelessWidget {
  final String type;
  final Color color;
  final Map<String, List<int>> data; // hatchery -> [ordered, actual]
  const _TypeSection(
      {required this.type, required this.color, required this.data});

  @override
  Widget build(BuildContext context) {
    final ordTotal =
        data.values.fold<int>(0, (s, v) => s + v[0]);
    final actTotal =
        data.values.fold<int>(0, (s, v) => s + v[1]);
    final diff = actTotal - ordTotal;
    final pct = ordTotal > 0 ? diff / ordTotal * 100 : null;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              Text(type.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6)),
              const Spacer(),
              if (pct != null)
                Text('${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _row(context, tr('ordered'), ordTotal, const Color(0xFF2563EB)),
              _row(context, tr('actual'), actTotal, const Color(0xFF059669)),
              _diffRow(context, diff),
              const Divider(height: 18),
              // per-hatchery breakdown (only hatcheries with data)
              ...data.entries.where((e) => e.value[0] != 0 || e.value[1] != 0).map(
                (e) {
                  final d = e.value[1] - e.value[0];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(
                          width: 86,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      Expanded(
                          child: Text(_numFmt.format(e.value[0]),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB)))),
                      Expanded(
                          child: Text(_numFmt.format(e.value[1]),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w600))),
                      Expanded(
                          child: Text(
                              d == 0
                                  ? '-'
                                  : '${d > 0 ? '+' : ''}${_numFmt.format(d)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: d == 0
                                      ? Colors.grey
                                      : d > 0
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFDC2626)))),
                    ]),
                  );
                },
              ),
              if (data.values.every((v) => v[0] == 0 && v[1] == 0))
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(tr('noDataWeek'),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int value, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Text(_numFmt.format(value),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _diffRow(BuildContext context, int diff) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(tr('diff'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Text(
              diff == 0 ? '0' : '${diff > 0 ? '+' : ''}${_numFmt.format(diff)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: diff == 0
                      ? Colors.grey
                      : diff > 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626))),
        ]),
      );
}

class _GrandTotal extends StatelessWidget {
  final Map<String, Map<String, List<int>>> pivot;
  const _GrandTotal({required this.pivot});

  @override
  Widget build(BuildContext context) {
    var ord = 0, act = 0;
    for (final byH in pivot.values) {
      for (final v in byH.values) {
        ord += v[0];
        act += v[1];
      }
    }
    final diff = act - ord;
    final pct = ord > 0 ? diff / ord * 100 : null;

    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(tr('grandTotal'),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _cell(tr('ordered'), _numFmt.format(ord), const Color(0xFF93C5FD)),
              _cell(tr('actual'), _numFmt.format(act), const Color(0xFF6EE7B7)),
              _cell(
                  tr('diff'),
                  '${diff > 0 ? '+' : ''}${_numFmt.format(diff)}',
                  diff >= 0
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFFFCA5A5)),
              if (pct != null)
                _cell(
                    tr('gap'),
                    '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    pct >= 0
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFFFCA5A5)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _cell(String label, String value, Color color) =>
      Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ]);
}
