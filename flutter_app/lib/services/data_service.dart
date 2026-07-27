import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/doc_record.dart';

/// Loads and caches doc_records; notifies listeners on changes.
class DataService extends ChangeNotifier {
  DataService._();
  static final instance = DataService._();

  final _sb = Supabase.instance.client;
  List<DocRecord> records = [];
  bool loading = false;
  String? error;

  Future<void> loadAll({bool force = false}) async {
    if (loading) return;
    if (records.isNotEmpty && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      const page = 1000;
      var from = 0;
      final all = <DocRecord>[];
      while (true) {
        final rows = await _sb
            .from('doc_records')
            .select()
            .order('record_date', ascending: false)
            .order('id', ascending: false)
            .range(from, from + page - 1);
        all.addAll((rows as List).map(
            (r) => DocRecord.fromJson(Map<String, dynamic>.from(r as Map))));
        if (rows.length < page) break;
        from += page;
      }
      records = all;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(DocRecord r) async {
    final payload = r.toPayload();
    if (r.id == null) {
      payload['user_id'] = _sb.auth.currentUser!.id;
      await _sb.from('doc_records').insert(payload);
    } else {
      await _sb.from('doc_records').update(payload).eq('id', r.id!);
    }
    await loadAll(force: true);
  }

  Future<void> delete(Object id) async {
    await _sb.from('doc_records').delete().eq('id', id);
    records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // ── Customer reference (for type sync) ──
  List<Map<String, dynamic>> customers = [];
  Future<void> loadCustomers() async {
    try {
      final rows = await _sb
          .from('customers')
          .select('customer_name,customer_type,customer_code');
      customers = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      customers = [];
    }
  }

  /// Copy the order plan from [sourceWeek] forward by [offsetWeeks] weeks.
  /// Copies order fields only (not actuals); skips rows that already exist.
  /// Returns {created, skipped}.
  Future<Map<String, int>> copyWeek(int sourceWeek, int offsetWeeks) async {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final src = records
        .where((r) => r.weekNo == sourceWeek && r.recordDate.isNotEmpty)
        .toList();
    final payloads = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final r in src) {
      final nd =
          DateTime.parse(r.recordDate).add(Duration(days: offsetWeeks * 7));
      final ds = DateFormat('yyyy-MM-dd').format(nd);
      final dup = records.any((x) =>
          x.recordDate == ds &&
          x.hatchery == r.hatchery &&
          x.customerType == r.customerType &&
          (x.breed ?? '') == (r.breed ?? '') &&
          _norm(x.customerName) == _norm(r.customerName));
      if (dup) {
        skipped++;
        continue;
      }
      payloads.add({
        'user_id': _sb.auth.currentUser!.id,
        'record_date': ds,
        'week_no': isoWeek(nd),
        'day_name': days[nd.weekday - 1],
        'hatchery': r.hatchery,
        'external_source': r.externalSource,
        'customer_type': r.customerType,
        'customer_name': r.customerName,
        'customer_code': r.customerCode,
        'breed': r.breed,
        'm_ordered': r.mOrdered,
        'f_ordered': r.fOrdered,
        'u_ordered': r.uOrdered,
      });
    }
    for (var i = 0; i < payloads.length; i += 100) {
      final end = (i + 100) < payloads.length ? i + 100 : payloads.length;
      await _sb.from('doc_records').insert(payloads.sublist(i, end));
    }
    if (payloads.isNotEmpty) await loadAll(force: true);
    return {'created': payloads.length, 'skipped': skipped};
  }

  /// Sync each record's customer_type to the customers reference (matched by
  /// farm name, case-insensitive). [apply] false = preview only.
  /// Returns {matched, changes, farms}.
  Future<Map<String, int>> syncCustomerTypes({bool apply = false}) async {
    if (customers.isEmpty) await loadCustomers();
    final ref = <String, String>{};
    for (final c in customers) {
      final name = (c['customer_name'] ?? '').toString();
      final type = (c['customer_type'] ?? '').toString();
      if (name.isEmpty || type.isEmpty) continue;
      ref.putIfAbsent(_norm(name), () => type);
    }
    final byType = <String, List<Object>>{};
    var matched = 0;
    final farms = <String>{};
    for (final r in records) {
      final t = ref[_norm(r.customerName)];
      if (t == null) continue;
      matched++;
      if (r.customerType != t && r.id != null) {
        byType.putIfAbsent(t, () => []).add(r.id!);
        farms.add(_norm(r.customerName));
      }
    }
    final changes = byType.values.fold<int>(0, (s, l) => s + l.length);
    if (apply && changes > 0) {
      for (final e in byType.entries) {
        for (var i = 0; i < e.value.length; i += 200) {
          final end =
              (i + 200) < e.value.length ? i + 200 : e.value.length;
          await _sb
              .from('doc_records')
              .update({'customer_type': e.key}).inFilter(
                  'id', e.value.sublist(i, end));
        }
      }
      await loadAll(force: true);
    }
    return {'matched': matched, 'changes': changes, 'farms': farms.length};
  }

  /// Distinct week numbers sorted by most recent record date.
  List<int> weeksByRecency() {
    final latest = <int, String>{};
    for (final r in records) {
      if (r.recordDate.isEmpty) continue;
      if ((latest[r.weekNo] ?? '').compareTo(r.recordDate) < 0) {
        latest[r.weekNo] = r.recordDate;
      }
    }
    final weeks = latest.keys.toList()
      ..sort((a, b) => (latest[b] ?? '').compareTo(latest[a] ?? ''));
    return weeks;
  }
}
