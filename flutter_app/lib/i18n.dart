import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current language: 'th' or 'en'. Persisted in shared_preferences.
final lang = ValueNotifier<String>('th');

Future<void> loadLang() async {
  final prefs = await SharedPreferences.getInstance();
  lang.value = prefs.getString('lang') ?? 'th';
}

Future<void> setLang(String code) async {
  lang.value = code;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lang', code);
}

const _strings = <String, Map<String, String>>{
  // Login
  'appSubtitle': {
    'th': 'ระบบจัดการโรงฟักลูกไก่',
    'en': 'Hatchery Management System'
  },
  'email': {'th': 'อีเมล', 'en': 'Email'},
  'password': {'th': 'รหัสผ่าน', 'en': 'Password'},
  'signIn': {'th': 'เข้าสู่ระบบ', 'en': 'Sign In'},
  // Shell
  'dashboard': {'th': 'แดชบอร์ด', 'en': 'Dashboard'},
  'entry': {'th': 'บันทึกออเดอร์', 'en': 'Order Entry'},
  'summary': {'th': 'สรุปผล', 'en': 'Summarize'},
  'signOut': {'th': 'ออกจากระบบ', 'en': 'Sign Out'},
  'signOutConfirm': {'th': 'ออกจากระบบ?', 'en': 'Sign out?'},
  'cancel': {'th': 'ยกเลิก', 'en': 'Cancel'},
  // Dashboard
  'kpiDelivered': {'th': 'ส่งแล้ว (ตัว)', 'en': 'DOC Delivered'},
  'kpiOrdered': {'th': 'ยอดสั่ง (ตัว)', 'en': 'DOC Ordered'},
  'kpiFulfillment': {'th': 'Fulfillment', 'en': 'Fulfillment'},
  'kpiCustomers': {'th': 'ลูกค้า', 'en': 'Customers'},
  'chartTrend': {
    'th': '📈 เทรนด์รายสัปดาห์ (13 สัปดาห์ล่าสุด)',
    'en': '📈 Weekly Trend (last 13 weeks)'
  },
  'chartTypeRatio': {
    'th': '🏷️ สัดส่วนประเภทลูกค้า',
    'en': '🏷️ Customer Type Ratio'
  },
  'chartHatchery': {
    'th': '🏭 ยอดส่งจริงรายโรงฟัก',
    'en': '🏭 Actual by Hatchery'
  },
  'noData': {'th': 'ไม่มีข้อมูล', 'en': 'No data'},
  'retry': {'th': 'ลองใหม่', 'en': 'Retry'},
  'filterYear': {'th': 'ปี', 'en': 'Year'},
  'filterMonth': {'th': 'เดือน', 'en': 'Month'},
  'filterWeek': {'th': 'สัปดาห์', 'en': 'Week'},
  'allHatcheries': {'th': 'ทุกโรงฟัก', 'en': 'All hatcheries'},
  // Entry
  'searchHint': {
    'th': 'ค้นหา ลูกค้า / โรงฟัก / DO#',
    'en': 'Search customer / hatchery / DO#'
  },
  'allWeeks': {'th': 'ทุกสัปดาห์', 'en': 'All weeks'},
  'items': {'th': 'รายการ', 'en': 'records'},
  'addRecord': {'th': 'เพิ่ม Record', 'en': 'Add Record'},
  'ordered': {'th': 'สั่ง', 'en': 'Order'},
  'actual': {'th': 'ส่งจริง', 'en': 'Actual'},
  'diff': {'th': 'ต่าง', 'en': 'Diff'},
  // Form
  'editRecord': {'th': '✏️ แก้ไข Record', 'en': '✏️ Edit Record'},
  'newRecord': {'th': '➕ เพิ่ม Record', 'en': '➕ New Record'},
  'date': {'th': 'วันที่ *', 'en': 'Date *'},
  'hatchery': {'th': 'โรงฟัก *', 'en': 'Hatchery *'},
  'chooseHatchery': {'th': 'เลือกโรงฟัก', 'en': 'Choose hatchery'},
  'externalSource': {
    'th': 'แหล่งภายนอก (External)',
    'en': 'External source'
  },
  'customerType': {'th': 'ประเภทลูกค้า *', 'en': 'Customer type *'},
  'chooseType': {'th': 'เลือกประเภท', 'en': 'Choose type'},
  'customerName': {'th': 'ชื่อลูกค้า *', 'en': 'Customer name *'},
  'enterCustomer': {'th': 'กรอกชื่อลูกค้า', 'en': 'Enter customer name'},
  'breed': {'th': 'สายพันธุ์', 'en': 'Breed'},
  'notSpecified': {'th': '— ไม่ระบุ —', 'en': '— none —'},
  'orderedSection': {'th': '📋 ยอดสั่ง (Ordered)', 'en': '📋 Ordered'},
  'actualSection': {'th': '✅ ยอดส่งจริง (Actual)', 'en': '✅ Actual'},
  'deliverySection': {'th': '🚚 ข้อมูลจัดส่ง', 'en': '🚚 Delivery info'},
  'truckPlate': {'th': 'ทะเบียนรถ', 'en': 'Truck plate'},
  'notes': {'th': 'หมายเหตุ', 'en': 'Notes'},
  'save': {'th': 'บันทึก', 'en': 'Save'},
  'saveChanges': {'th': 'บันทึกการแก้ไข', 'en': 'Save changes'},
  'saved': {'th': '✅ บันทึกแล้ว', 'en': '✅ Saved'},
  'updated': {'th': '✅ อัปเดตแล้ว', 'en': '✅ Updated'},
  'deleted': {'th': '🗑️ ลบแล้ว', 'en': '🗑️ Deleted'},
  'deleteConfirm': {'th': 'ลบรายการนี้?', 'en': 'Delete this record?'},
  'delete': {'th': 'ลบ', 'en': 'Delete'},
  // Transport
  'transport': {'th': 'ขนส่ง', 'en': 'Transport'},
  'kpiTrips': {'th': 'เที่ยวรถ', 'en': 'Trips'},
  'kpiDOA': {'th': 'DOA (ตาย)', 'en': 'DOA'},
  'kpiDoaRate': {'th': '% DOA', 'en': 'DOA rate'},
  'depTime': {'th': 'เวลาออก', 'en': 'Departure'},
  'locationLbl': {'th': 'ปลายทาง', 'en': 'Destination'},
  'distance': {'th': 'ระยะทาง', 'en': 'Distance'},
  'statusPending': {'th': 'รอออกเดินทาง', 'en': 'Pending'},
  'statusDeparted': {'th': 'ออกเดินทางแล้ว', 'en': 'Departed'},
  'statusArrived': {'th': 'ถึงแล้ว', 'en': 'Arrived'},
  'noTruckData': {
    'th': 'ไม่มีข้อมูลขนส่งในสัปดาห์นี้',
    'en': 'No transport data this week'
  },
  // Driver QR
  'driverQr': {'th': 'QR คนขับ', 'en': 'Driver QR'},
  'driverQrHint': {
    'th': 'ให้คนขับสแกนเพื่ออัปเดตสถานะ ออกเดินทาง/ถึงแล้ว โดยไม่ต้อง login',
    'en': 'Driver scans this to update departed/arrived status — no login needed'
  },
  'noDriverToken': {
    'th': 'record นี้ยังไม่มี driver token',
    'en': 'This record has no driver token yet'
  },
  'close': {'th': 'ปิด', 'en': 'Close'},
  // Summary
  'orderVsActual': {'th': '📊 สั่ง vs ส่งจริง', 'en': '📊 Order vs Actual'},
  'noDataWeek': {
    'th': 'ไม่มีข้อมูลในสัปดาห์นี้',
    'en': 'No data for this week'
  },
  'grandTotal': {'th': 'ยอดรวมทั้งหมด', 'en': 'GRAND TOTAL'},
  'gap': {'th': '% ต่าง', 'en': '% Gap'},
};

/// Translate a key using the current language.
String tr(String key) => _strings[key]?[lang.value] ?? key;

const _monthsTh = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];
const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// 'yyyy-MM' -> localized label, e.g. 'ก.ค. 2026' / 'Jul 2026'.
String monthLabel(String ym) {
  final parts = ym.split('-');
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  final names = lang.value == 'th' ? _monthsTh : _monthsEn;
  return '${names[(m - 1).clamp(0, 11)]} ${parts[0]}';
}
