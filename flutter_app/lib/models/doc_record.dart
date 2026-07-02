/// Row in the `doc_records` table (same schema as the web app).
/// `total_ordered` / `total_actual` are generated columns — read-only.
class DocRecord {
  final int? id;
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
        id: j['id'] as int?,
        userId: j['user_id'] as String?,
        weekNo: (j['week_no'] as num?)?.toInt() ?? 0,
        recordDate: j['record_date'] as String? ?? '',
        dayName: j['day_name'] as String?,
        hatchery: j['hatchery'] as String? ?? '',
        customerType: j['customer_type'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '',
        customerCode: j['customer_code'] as String?,
        breed: j['breed'] as String?,
        externalSource: j['external_source'] as String?,
        mOrdered: (j['m_ordered'] as num?)?.toInt(),
        fOrdered: (j['f_ordered'] as num?)?.toInt(),
        uOrdered: (j['u_ordered'] as num?)?.toInt(),
        mActual: (j['m_actual'] as num?)?.toInt(),
        fActual: (j['f_actual'] as num?)?.toInt(),
        uActual: (j['u_actual'] as num?)?.toInt(),
        totalOrdered: (j['total_ordered'] as num?)?.toInt() ?? 0,
        totalActual: (j['total_actual'] as num?)?.toInt() ?? 0,
        doNumber: j['do_number'] as String?,
        truckPlate: j['truck_plate'] as String?,
        notes: j['notes'] as String?,
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
