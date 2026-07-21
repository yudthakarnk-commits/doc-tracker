import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../i18n.dart';
import '../models/doc_record.dart';
import '../services/data_service.dart';

class EntryFormScreen extends StatefulWidget {
  final DocRecord? record;
  const EntryFormScreen({super.key, this.record});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  String? _hatchery, _ctype, _breed;
  final _customer = TextEditingController();
  final _externalSource = TextEditingController();
  final _mOrd = TextEditingController();
  final _fOrd = TextEditingController();
  final _uOrd = TextEditingController();
  final _mAct = TextEditingController();
  final _fAct = TextEditingController();
  final _uAct = TextEditingController();
  final _doNumber = TextEditingController();
  final _truckPlate = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _date = r != null && r.recordDate.isNotEmpty
        ? DateTime.parse(r.recordDate)
        : DateTime.now();
    if (r != null) {
      _hatchery = r.hatchery.isNotEmpty ? r.hatchery : null;
      _ctype = r.customerType.isNotEmpty ? r.customerType : null;
      _breed = r.breed;
      _customer.text = r.customerName;
      _externalSource.text = r.externalSource ?? '';
      _mOrd.text = r.mOrdered?.toString() ?? '';
      _fOrd.text = r.fOrdered?.toString() ?? '';
      _uOrd.text = r.uOrdered?.toString() ?? '';
      _mAct.text = r.mActual?.toString() ?? '';
      _fAct.text = r.fActual?.toString() ?? '';
      _uAct.text = r.uActual?.toString() ?? '';
      _doNumber.text = r.doNumber ?? '';
      _truckPlate.text = r.truckPlate ?? '';
      _notes.text = r.notes ?? '';
    }
  }

  int? _int(TextEditingController c) =>
      c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  /// Mirrors validateRecordWarnings() in the web app — non-blocking checks.
  List<String> _anomalyWarnings() {
    final th = lang.value == 'th';
    final w = <String>[];
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final tOrd = (_int(_mOrd) ?? 0) + (_int(_fOrd) ?? 0) + (_int(_uOrd) ?? 0);
    final tAct = (_int(_mAct) ?? 0) + (_int(_fAct) ?? 0) + (_int(_uAct) ?? 0);
    final name = _customer.text.trim().toLowerCase();
    final dup = DataService.instance.records.any((r) =>
        (widget.record?.id == null || '${r.id}' != '${widget.record!.id}') &&
        r.recordDate == dateStr &&
        r.hatchery == (_hatchery ?? '') &&
        r.customerType == (_ctype ?? '') &&
        (r.breed ?? '') == (_breed ?? '') &&
        r.customerName.trim().toLowerCase() == name);
    if (dup) {
      w.add(th
          ? 'อาจซ้ำซ้อน — "${_customer.text.trim()}" มีรายการวันที่ $dateStr ที่ $_hatchery อยู่แล้ว'
          : 'Possible duplicate — "${_customer.text.trim()}" already has a record on $dateStr at $_hatchery');
    }
    final fmt = NumberFormat('#,##0');
    if (tOrd > 0 && tAct > tOrd) {
      final pct = (tAct / tOrd * 100 - 100).toStringAsFixed(1);
      w.add(th
          ? 'ยอดส่งจริง (${fmt.format(tAct)}) มากกว่ายอดสั่ง (${fmt.format(tOrd)}) อยู่ $pct%'
          : 'Actual (${fmt.format(tAct)}) exceeds Order (${fmt.format(tOrd)}) by $pct%');
    }
    if (tOrd > 0 && tAct > 0 && tAct < tOrd * 0.5) {
      w.add(th
          ? 'ยอดส่งจริง (${fmt.format(tAct)}) ต่ำกว่าครึ่งหนึ่งของยอดสั่ง (${fmt.format(tOrd)})'
          : 'Actual (${fmt.format(tAct)}) is below 50% of Order (${fmt.format(tOrd)})');
    }
    return w;
  }

  Future<bool?> _confirmWarnings(List<String> warns) {
    final th = lang.value == 'th';
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(th ? '⚠️ ตรวจสอบข้อมูล' : '⚠️ Please review'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < warns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${i + 1}. ${warns[i]}'),
                ),
              const SizedBox(height: 4),
              Text(th ? 'ยืนยันบันทึกต่อหรือไม่?' : 'Save anyway?',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(th ? 'บันทึกต่อ' : 'Save anyway')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final warns = _anomalyWarnings();
    if (warns.isNotEmpty) {
      final ok = await _confirmWarnings(warns);
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final rec = DocRecord(
        id: widget.record?.id,
        weekNo: isoWeek(_date),
        recordDate: DateFormat('yyyy-MM-dd').format(_date),
        dayName: days[_date.weekday - 1],
        hatchery: _hatchery!,
        customerType: _ctype!,
        customerName: _customer.text.trim(),
        customerCode: widget.record?.customerCode,
        breed: _breed,
        externalSource: _hatchery == 'External'
            ? (_externalSource.text.trim().isEmpty
                ? null
                : _externalSource.text.trim())
            : null,
        mOrdered: _int(_mOrd),
        fOrdered: _int(_fOrd),
        uOrdered: _int(_uOrd),
        mActual: _int(_mAct),
        fActual: _int(_fAct),
        uActual: _int(_uAct),
        doNumber:
            _doNumber.text.trim().isEmpty ? null : _doNumber.text.trim(),
        truckPlate:
            _truckPlate.text.trim().isEmpty ? null : _truckPlate.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      await DataService.instance.save(rec);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? tr('updated') : tr('saved'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('deleteConfirm')),
        content: Text(widget.record!.customerName),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await DataService.instance.delete(widget.record!.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('deleted'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? tr('editRecord') : tr('newRecord')),
        actions: [
          if (_isEdit)
            IconButton(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline, color: Colors.red)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Date ──
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: tr('date'),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18)),
                child: Text(
                    '${DateFormat('yyyy-MM-dd').format(_date)}  (Week ${isoWeek(_date)})'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _hatchery,
              decoration: InputDecoration(labelText: tr('hatchery')),
              items: AppConfig.hatcheries
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) => setState(() => _hatchery = v),
              validator: (v) => v == null ? tr('chooseHatchery') : null,
            ),
            if (_hatchery == 'External') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _externalSource,
                decoration:
                    InputDecoration(labelText: tr('externalSource')),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _ctype,
              decoration: InputDecoration(labelText: tr('customerType')),
              items: AppConfig.customerTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _ctype = v),
              validator: (v) => v == null ? tr('chooseType') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customer,
              decoration: InputDecoration(labelText: tr('customerName')),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('enterCustomer') : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _breed,
              decoration: InputDecoration(labelText: tr('breed')),
              items: [
                DropdownMenuItem<String>(
                    value: null, child: Text(tr('notSpecified'))),
                ...AppConfig.breeds
                    .map((b) => DropdownMenuItem(value: b, child: Text(b))),
              ],
              onChanged: (v) => setState(() => _breed = v),
            ),
            const SizedBox(height: 18),
            _sectionLabel(context, tr('orderedSection')),
            Row(children: [
              Expanded(child: _numField(_mOrd, 'Male')),
              const SizedBox(width: 8),
              Expanded(child: _numField(_fOrd, 'Female')),
              const SizedBox(width: 8),
              Expanded(child: _numField(_uOrd, 'Unsexed')),
            ]),
            const SizedBox(height: 16),
            _sectionLabel(context, tr('actualSection')),
            Row(children: [
              Expanded(child: _numField(_mAct, 'Male')),
              const SizedBox(width: 8),
              Expanded(child: _numField(_fAct, 'Female')),
              const SizedBox(width: 8),
              Expanded(child: _numField(_uAct, 'Unsexed')),
            ]),
            const SizedBox(height: 16),
            _sectionLabel(context, tr('deliverySection')),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _doNumber,
                      decoration:
                          const InputDecoration(labelText: 'DO Number'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                      controller: _truckPlate,
                      decoration:
                          InputDecoration(labelText: tr('truckPlate')))),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(labelText: tr('notes')),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isEdit ? tr('saveChanges') : tr('save')),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600)),
      );

  Widget _numField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
      );
}
