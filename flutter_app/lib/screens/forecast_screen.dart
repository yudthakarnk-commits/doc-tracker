import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../i18n.dart';
import '../models/doc_record.dart';
import '../services/data_service.dart';

final _nf = NumberFormat('#,##0');

/// One projected future placement.
class _FRow {
  final String farm, ctype, hatchery, breed, anchorDate, forecastDate;
  final int week, cycle, qty;
  _FRow(this.farm, this.ctype, this.hatchery, this.breed, this.anchorDate,
      this.forecastDate, this.week, this.cycle, this.qty);
}

/// Projects future chick placements: every placement in the last [cycleDays]
/// days is rolled forward one cycle at a time (weekend → next Monday),
/// starting [leadWeeks] weeks out. Mirrors the web app's forecast model.
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  int _cycleDays = 60, _leadWeeks = 5, _horizonWeeks = 12;
  int? _week; // null = all weeks
  String _typeFilter = '';
  String _sort = 'date'; // date | qty | farm

  static const _typeColors = {
    'Company Farm': Color(0xFF15803D),
    'Contract Farm': Color(0xFFB45309),
    'Customer': Color(0xFF1E40AF),
  };

  String _ds(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _weekendAdjust(DateTime d) {
    if (d.weekday == DateTime.saturday) return d.add(const Duration(days: 2));
    if (d.weekday == DateTime.sunday) return d.add(const Duration(days: 1));
    return d;
  }

  DateTime _mondayOf(DateTime d) =>
      _dayOnly(d).subtract(Duration(days: d.weekday - 1));

  List<_FRow> _build(List<DocRecord> records) {
    final t0 = _dayOnly(DateTime.now());
    final startDate = _mondayOf(t0).add(Duration(days: _leadWeeks * 7));
    final horizonEnd = startDate.add(Duration(days: _horizonWeeks * 7 - 1));
    final srcStartStr = _ds(t0.subtract(Duration(days: _cycleDays)));
    final todayStr = _ds(t0);

    // aggregate placements per farm+date within the source window
    final events = <String, Map<String, dynamic>>{};
    for (final r in records) {
      if (r.recordDate.isEmpty ||
          r.recordDate.compareTo(srcStartStr) < 0 ||
          r.recordDate.compareTo(todayStr) > 0) continue;
      final q = r.totalActual > 0 ? r.totalActual : r.totalOrdered;
      if (q <= 0) continue;
      final key = '${r.customerName.trim().toLowerCase()}|${r.recordDate}';
      final e = events.putIfAbsent(
          key,
          () => {
                'farm': r.customerName,
                'date': r.recordDate,
                'qty': 0,
                'type': <String, int>{},
                'hatch': <String, int>{},
                'breeds': <String>{},
              });
      e['qty'] = (e['qty'] as int) + q;
      if (r.customerType.isNotEmpty) {
        final m = e['type'] as Map<String, int>;
        m[r.customerType] = (m[r.customerType] ?? 0) + q;
      }
      if (r.hatchery.isNotEmpty) {
        final m = e['hatch'] as Map<String, int>;
        m[r.hatchery] = (m[r.hatchery] ?? 0) + q;
      }
      final b = r.breed;
      if (b != null && b.isNotEmpty) (e['breeds'] as Set<String>).add(b);
    }

    String dom(Map<String, int> m) => m.isEmpty
        ? ''
        : (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    final rows = <_FRow>[];
    for (final e in events.values) {
      final type = dom(e['type'] as Map<String, int>);
      final hatch = dom(e['hatch'] as Map<String, int>);
      if (_typeFilter.isNotEmpty && type != _typeFilter) continue;
      final base = DateTime.parse(e['date'] as String);
      for (int c = 1; c <= 52; c++) {
        var d = _dayOnly(_weekendAdjust(base.add(Duration(days: _cycleDays * c))));
        if (d.isAfter(horizonEnd)) break;
        if (d.isBefore(startDate)) continue;
        rows.add(_FRow(
            e['farm'] as String,
            type,
            hatch,
            (e['breeds'] as Set<String>).join(', '),
            e['date'] as String,
            _ds(d),
            isoWeek(d),
            c,
            e['qty'] as int));
      }
    }
    rows.sort((a, b) => a.forecastDate.compareTo(b.forecastDate));
    return rows;
  }

  Future<void> _openSettings() async {
    final cycle = TextEditingController(text: '$_cycleDays');
    final lead = TextEditingController(text: '$_leadWeeks');
    final horizon = TextEditingController(text: '$_horizonWeeks');
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('fcSettings')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numField(cycle, tr('fcCycleDays')),
            const SizedBox(height: 12),
            _numField(lead, tr('fcLeadWeeks')),
            const SizedBox(height: 12),
            _numField(horizon, tr('fcHorizonWeeks')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () {
              setState(() {
                _cycleDays = (int.tryParse(cycle.text) ?? 60).clamp(1, 365).toInt();
                _leadWeeks = (int.tryParse(lead.text) ?? 5).clamp(0, 20).toInt();
                _horizonWeeks =
                    (int.tryParse(horizon.text) ?? 12).clamp(1, 52).toInt();
                _week = null;
              });
              Navigator.pop(c);
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final svc = DataService.instance;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        if (svc.loading && svc.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final allRows = _build(svc.records);
        // weeks available (for the dropdown), earliest date first
        final weekFirst = <int, String>{};
        for (final r in allRows) {
          final m = _ds(_mondayOf(DateTime.parse(r.forecastDate)));
          if (!weekFirst.containsKey(r.week) ||
              m.compareTo(weekFirst[r.week]!) < 0) weekFirst[r.week] = m;
        }
        final weeks = weekFirst.keys.toList()
          ..sort((a, b) => weekFirst[a]!.compareTo(weekFirst[b]!));
        final rows =
            _week == null ? allRows : allRows.where((r) => r.week == _week).toList();

        // sort detail
        final sorted = [...rows];
        sorted.sort((a, b) {
          switch (_sort) {
            case 'qty':
              return b.qty.compareTo(a.qty);
            case 'farm':
              return a.farm.toLowerCase().compareTo(b.farm.toLowerCase());
            default:
              return a.forecastDate.compareTo(b.forecastDate);
          }
        });

        // type totals for the selected scope
        final byType = <String, int>{
          'Company Farm': 0,
          'Contract Farm': 0,
          'Customer': 0
        };
        for (final r in rows) {
          if (byType.containsKey(r.ctype)) byType[r.ctype] = byType[r.ctype]! + r.qty;
        }
        final total = rows.fold<int>(0, (s, r) => s + r.qty);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── controls ──
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int?>(
                    value: _week,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem<int?>(
                          value: null, child: Text('📅 ${tr('fcAllWeeks')}')),
                      ...weeks.map((w) {
                        final d = DateTime.parse(weekFirst[w]!);
                        return DropdownMenuItem<int?>(
                            value: w,
                            child: Text('Week $w · ${d.day}/${d.month}'));
                      }),
                    ],
                    onChanged: (v) => setState(() => _week = v),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('fcSettings'),
                icon: const Icon(Icons.tune),
                onPressed: _openSettings,
              ),
            ]),
            const SizedBox(height: 10),
            // ── type filter chips ──
            Wrap(
              spacing: 6,
              children: [
                _typeChip('', tr('allTypes')),
                for (final t in const ['Company Farm', 'Contract Farm', 'Customer'])
                  _typeChip(t, t),
              ],
            ),
            const SizedBox(height: 12),
            // ── KPI cards ──
            if (allRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text(tr('fcNoData'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600))),
              )
            else ...[
              Row(children: [
                Expanded(
                    child: _kpi(tr('fcTotal'), total, const Color(0xFF2563EB),
                        big: true)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _kpi('🏭 Company', byType['Company Farm']!,
                        _typeColors['Company Farm']!)),
                const SizedBox(width: 8),
                Expanded(
                    child: _kpi('📄 Contract', byType['Contract Farm']!,
                        _typeColors['Contract Farm']!)),
                const SizedBox(width: 8),
                Expanded(
                    child: _kpi('👤 Customer', byType['Customer']!,
                        _typeColors['Customer']!)),
              ]),
              const SizedBox(height: 18),
              // ── weekly bars (overview, all weeks) ──
              Text(tr('fcWeeklyTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _WeeklyBars(
                rows: allRows,
                weeks: weeks,
                weekFirst: weekFirst,
                mondayOf: _mondayOf,
                typeColors: _typeColors,
                selectedWeek: _week,
                onTapWeek: (w) => setState(() => _week = _week == w ? null : w),
              ),
              const SizedBox(height: 18),
              // ── detail ──
              Row(children: [
                Text(tr('fcDetailTitle'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${sorted.length}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sort,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: 'date', child: Text(tr('fcSortDate'))),
                    DropdownMenuItem(value: 'qty', child: Text(tr('fcSortQty'))),
                    DropdownMenuItem(value: 'farm', child: Text(tr('fcSortFarm'))),
                  ],
                  onChanged: (v) => setState(() => _sort = v ?? 'date'),
                ),
              ]),
              const SizedBox(height: 6),
              ...sorted.map(_detailTile),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }

  Widget _typeChip(String value, String label) {
    final sel = _typeFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: sel,
      onSelected: (_) => setState(() {
        _typeFilter = value;
        _week = null;
      }),
    );
  }

  Widget _kpi(String label, int value, Color color, {bool big = false}) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(color.withOpacity(.13), surface), surface],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 3),
                Text(_nf.format(value),
                    style: TextStyle(
                        fontSize: big ? 24 : 16,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(_FRow r) {
    final color = _typeColors[r.ctype] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.forecastDate, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Wk ${r.week} · +${r.cycle}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.farm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(4)),
                  child: Text(r.ctype,
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                      '${r.hatchery}${r.breed.isNotEmpty ? ' · ${r.breed}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Text(_nf.format(r.qty),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2563EB))),
        ]),
      ),
    );
  }
}

/// Weekly stacked bars (by customer type) — overview of all forecast weeks.
class _WeeklyBars extends StatelessWidget {
  final List<_FRow> rows;
  final List<int> weeks;
  final Map<int, String> weekFirst;
  final DateTime Function(DateTime) mondayOf;
  final Map<String, Color> typeColors;
  final int? selectedWeek;
  final void Function(int) onTapWeek;
  const _WeeklyBars({
    required this.rows,
    required this.weeks,
    required this.weekFirst,
    required this.mondayOf,
    required this.typeColors,
    required this.selectedWeek,
    required this.onTapWeek,
  });

  @override
  Widget build(BuildContext context) {
    final totals = <int, int>{};
    final byType = <int, Map<String, int>>{};
    for (final r in rows) {
      totals[r.week] = (totals[r.week] ?? 0) + r.qty;
      final m = byType.putIfAbsent(r.week, () => {});
      m[r.ctype] = (m[r.ctype] ?? 0) + r.qty;
    }
    final maxTotal =
        totals.values.fold<int>(1, (m, v) => v > m ? v : m);
    const order = ['Company Farm', 'Contract Farm', 'Customer'];

    return Column(
      children: weeks.map((w) {
        final d = DateTime.parse(weekFirst[w]!);
        final end = d.add(const Duration(days: 6));
        final tot = totals[w] ?? 0;
        final types = byType[w] ?? {};
        final sel = selectedWeek == w;
        return InkWell(
          onTap: () => onTapWeek(w),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            decoration: BoxDecoration(
              color: sel
                  ? Theme.of(context).colorScheme.primary.withOpacity(.08)
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              SizedBox(
                width: 66,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wk $w',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('${d.day}/${d.month}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 20,
                    color: Theme.of(context).dividerColor.withOpacity(.15),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (tot / maxTotal).clamp(0.0, 1.0).toDouble(),
                      child: Row(
                        children: order
                            .where((t) => (types[t] ?? 0) > 0)
                            .map((t) => Expanded(
                                  flex: types[t]!,
                                  child: Container(color: typeColors[t]),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(_nf.format(tot),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
