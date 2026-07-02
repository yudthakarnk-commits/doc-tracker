import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
