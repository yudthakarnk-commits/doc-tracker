/// Row in the `doc_records` table (same schema as the web app).
/// `total_ordered` / `total_actual` are generated columns — read-only.
///
/// PostgREST may return numbers as int, double, or String depending on the
/// column type, so every field is parsed defensively.
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _toStr(dynamic v) => v?.toString();

class DocRecord {
  /// bigint or uuid depending on schema — kept opaque and passed back as-is.
  final Object? id;
  final String? userId;
  final int weekNo;
  final String recordDate; // yyyy-MM-dd
  final String? dayName;
  final String hatchery;
  final String customerType;
  final String customerName;
  final String? customerCode;
  final String? breed;
  final String? externalSource;
  final int? mOrdered, fOrdered, uOrdered;
  final int? mActual, fActual, uActual;
  final int totalOrdered, totalActual;
  final String? doNumber, truckPlate, notes;

  DocRecord({
    this.id,
    this.userId,
    required this.weekNo,
    required this.recordDate,
    this.dayName,
    required this.hatchery,
    required this.customerType,
    required this.customerName,
    this.customerCode,
    this.breed,
    this.externalSource,
    this.mOrdered,
    this.fOrdered,
    this.uOrdered,
    this.mActual,
    this.fActual,
    this.uActual,
    this.totalOrdered = 0,
    this.totalActual = 0,
    this.doNumber,
    this.truckPlate,
    this.notes,
  });

  factory DocRecord.fromJson(Map<String, dynamic> j) => DocRecord(
        id: j['id'],
        userId: _toStr(j['user_id']),
        weekNo: _toInt(j['week_no']) ?? 0,
        recordDate: _toStr(j['record_date']) ?? '',
        dayName: _toStr(j['day_name']),
        hatchery: _toStr(j['hatchery']) ?? '',
        customerType: _toStr(j['customer_type']) ?? '',
        customerName: _toStr(j['customer_name']) ?? '',
        customerCode: _toStr(j['customer_code']),
        breed: _toStr(j['breed']),
        externalSource: _toStr(j['external_source']),
        mOrdered: _toInt(j['m_ordered']),
        fOrdered: _toInt(j['f_ordered']),
        uOrdered: _toInt(j['u_ordered']),
        mActual: _toInt(j['m_actual']),
        fActual: _toInt(j['f_actual']),
        uActual: _toInt(j['u_actual']),
        totalOrdered: _toInt(j['total_ordered']) ?? 0,
        totalActual: _toInt(j['total_actual']) ?? 0,
        doNumber: _toStr(j['do_number']),
        truckPlate: _toStr(j['truck_plate']),
        notes: _toStr(j['notes']),
      );

  /// Payload for insert/update — only the fields this app edits, so an
  /// update never wipes columns the mobile form doesn't include.
  Map<String, dynamic> toPayload() => {
        'week_no': weekNo,
        'record_date': recordDate,
        'day_name': dayName,
        'hatchery': hatchery,
        'customer_type': customerType,
        'customer_name': customerName,
        'customer_code': customerCode,
        'breed': breed,
        'external_source': externalSource,
        'm_ordered': mOrdered,
        'f_ordered': fOrdered,
        'u_ordered': uOrdered,
        'm_actual': mActual,
        'f_actual': fActual,
        'u_actual': uActual,
        'do_number': doNumber,
        'truck_plate': truckPlate,
        'notes': notes,
      };
}
