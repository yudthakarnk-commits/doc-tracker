import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../i18n.dart';
import '../models/doc_record.dart';
import '../services/data_service.dart';
import 'entry_form_screen.dart';
import 'widgets/driver_qr_dialog.dart';

final _numFmt = NumberFormat('#,##0');

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  String _search = '';
  int? _week;

  @override
  Widget build(BuildContext context) {
    final svc = DataService.instance;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        final weeks = svc.weeksByRecency();
        var rows = svc.records;
        if (_week != null) {
          rows = rows.where((r) => r.weekNo == _week).toList();
        }
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          rows = rows
              .where((r) =>
                  r.customerName.toLowerCase().contains(q) ||
                  r.hatchery.toLowerCase().contains(q) ||
                  (r.doNumber ?? '').toLowerCase().contains(q) ||
                  (r.notes ?? '').toLowerCase().contains(q) ||
                  r.recordDate.contains(q))
              .toList();
        }

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: tr('searchHint'),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int?>(
                    value: _week,
                    hint: const Text('Week'),
                    onChanged: (v) => setState(() => _week = v),
                    items: [
                      DropdownMenuItem<int?>(
                          value: null, child: Text(tr('allWeeks'))),
                      ...weeks.map((w) => DropdownMenuItem<int?>(
                          value: w, child: Text('Week $w'))),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('moreActions'),
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'copy') _copyWeekDialog(context, svc, weeks);
                      if (v == 'sync') _syncTypesDialog(context, svc);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'copy', child: Text(tr('copyWeek'))),
                      PopupMenuItem(value: 'sync', child: Text(tr('syncTypes'))),
                    ],
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_numFmt.format(rows.length)} ${tr('items')}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ),
              ),
              Expanded(
                child: svc.loading && svc.records.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => svc.loadAll(force: true),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _RecordCard(record: rows[i]),
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EntryFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: Text(tr('addRecord')),
          ),
        );
      },
    );
  }

  // ── Copy Week ──
  Future<void> _copyWeekDialog(
      BuildContext context, DataService svc, List<int> weeks) async {
    if (weeks.isEmpty) return;
    int source = weeks.first;
    int offset = 1;
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(tr('copyWeekTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${tr('cwSource')}: '),
                const Spacer(),
                DropdownButton<int>(
                  value: source,
                  onChanged: (v) => setD(() => source = v!),
                  items: weeks
                      .map((w) => DropdownMenuItem(
                          value: w, child: Text('Week $w')))
                      .toList(),
                ),
              ]),
              Row(children: [
                Text('${tr('cwOffset')}: '),
                const Spacer(),
                DropdownButton<int>(
                  value: offset,
                  onChanged: (v) => setD(() => offset = v!),
                  items: [1, 2, 3, 4]
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text('+$n')))
                      .toList(),
                ),
              ]),
              const SizedBox(height: 8),
              Text(tr('cwHint'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: Text(tr('cancel'))),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setD(() => busy = true);
                      try {
                        final res = await svc.copyWeek(source, offset);
                        if (c.mounted) Navigator.pop(c);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '✅ +${res['created']} / skip ${res['skipped']}')));
                        }
                      } catch (e) {
                        setD(() => busy = false);
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text('❌ $e')));
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('cwRun')),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sync Customer Types ──
  Future<void> _syncTypesDialog(BuildContext context, DataService svc) async {
    showDialog<void>(
      context: context,
      builder: (c) => FutureBuilder<Map<String, int>>(
        future: svc.syncCustomerTypes(apply: false),
        builder: (c, snap) {
          final preview = snap.data;
          var busy = false;
          return StatefulBuilder(
            builder: (c, setD) => AlertDialog(
              title: Text(tr('syncTypesTitle')),
              content: preview == null
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${tr('syncMatched')}: ${preview['matched']}   ·   ${tr('syncChanges')}: ${preview['changes']} (${preview['farms']} ${tr('fcSortFarm')})'),
                        const SizedBox(height: 8),
                        Text(tr('syncHint'),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(tr('cancel'))),
                FilledButton(
                  onPressed: (preview == null ||
                          (preview['changes'] ?? 0) == 0 ||
                          busy)
                      ? null
                      : () async {
                          setD(() => busy = true);
                          try {
                            final res =
                                await svc.syncCustomerTypes(apply: true);
                            if (c.mounted) Navigator.pop(c);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '✅ ${tr('done')} · ${res['changes']}')));
                            }
                          } catch (e) {
                            setD(() => busy = false);
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                  SnackBar(content: Text('❌ $e')));
                            }
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tr('syncApply')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final DocRecord record;
  const _RecordCard({required this.record});

  static const _typeColors = {
    'Customer': Color(0xFF1E40AF),
    'Contract Farm': Color(0xFF9A3412),
    'Company Farm': Color(0xFF166534),
  };
  static const _typeBg = {
    'Customer': Color(0xFFDBEAFE),
    'Contract Farm': Color(0xFFFED7AA),
    'Company Farm': Color(0xFFBBF7D0),
  };

  @override
  Widget build(BuildContext context) {
    final r = record;
    final diff = r.totalActual - r.totalOrdered;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EntryFormScreen(record: r)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(r.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeBg[r.customerType] ?? Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(r.customerType,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _typeColors[r.customerType] ??
                              Colors.grey.shade700)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                  '📅 ${r.recordDate} (W${r.weekNo})   🏭 ${r.hatchery}${r.breed != null ? '   🐔 ${r.breed}' : ''}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(children: [
                _Stat(tr('ordered'), _numFmt.format(r.totalOrdered),
                    const Color(0xFF2563EB)),
                const SizedBox(width: 16),
                _Stat(tr('actual'), _numFmt.format(r.totalActual),
                    const Color(0xFF059669)),
                const SizedBox(width: 16),
                _Stat(
                    tr('diff'),
                    '${diff > 0 ? '+' : ''}${_numFmt.format(diff)}',
                    diff == 0
                        ? Colors.grey
                        : diff > 0
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('driverQr'),
                  icon: Icon(Icons.qr_code_2,
                      size: 22, color: Colors.grey.shade600),
                  onPressed: () => showDriverQrDialog(context, r),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}
