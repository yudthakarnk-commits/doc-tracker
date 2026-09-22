# DOC Tracker — Hatchery Management System

ระบบติดตามการสั่ง/ส่งลูกไก่ (DOC = Day-Old Chick) ของโรงฟัก มี 2 frontend ใช้ Supabase ตัวเดียวกัน:

## Repo layout

| Path | คืออะไร | Deploy |
|---|---|---|
| `index.html`, `sw.js`, `manifest.json` | **DOC Tracker** — ปลายน้ำ (ออร์เดอร์/ส่งมอบ/ขนส่ง) Web PWA single-file, vanilla JS + Chart.js | GitHub Pages: yudthakarnk-commits.github.io/doc-tracker/ |
| `hatchery-os.html` | **HatcheryOS** — ต้นน้ำ (รับไข่ → cool room → ตู้ฟัก → ส่องไข่ → ประเมิน DOC) single-file เหมือนกัน | หน้าเดียวกันบน GitHub Pages: `/hatchery-os.html` |
| `flutter_app/` | แอพมือถือ Flutter (Material 3, TH/EN, light/dark) | GitHub Actions build APK → release tag `apk-latest` |
| `.github/workflows/build-apk.yml` | CI: build Android APK ทุกครั้งที่ push แก้ `flutter_app/**` | — |
| `db/` | บันทึกกฎ/การเปลี่ยนแปลงใน Supabase ที่มองไม่เห็นจากโค้ด (ไม่ใช่ schema dump เต็ม) | รันมือใน Supabase SQL editor |

## สองแอพบน origin เดียวกัน (DOC Tracker ↔ HatcheryOS)

- อยู่ **origin เดียวกัน** → Supabase เก็บ session ไว้ใน localStorage ร่วมกัน **ล็อกอินครั้งเดียวใช้ได้ทั้งคู่** อย่าแยก origin ไม่งั้นต้องล็อกอินสองรอบ
- สลับไปมาผ่าน: sidebar (จอใหญ่) + bottom nav ปุ่ม "Hatchery" (จอมือถือ) ฝั่ง DOC Tracker / nav group "Downstream" ฝั่ง HatcheryOS
- ⚠️ **master data ต้องตรงกัน** ไม่งั้น join ข้ามแอพไม่ได้:
  - โรงฟัก — `HATCH` ใน hatchery-os.html ต้องตรงกับ `AppConfig.hatcheries` ยกเว้น `External` (ไม่ใช่โรงฟัก ไม่ต้องมีใน HatcheryOS) · `Kota` ยังไม่ได้ตั้งค่า weekly capacity (`wc:0` → หน้า Capacity แสดง "not configured" แทนตัวเลขมั่ว)
  - สายพันธุ์ — HatcheryOS ใช้ชื่อสายเต็ม (`Ross 308`) เพราะตาราง `STD` ผูกกับสายพันธุ์ ส่วน DOC Tracker เก็บโค้ดสั้น (`ROSS`) **แปลงที่ขอบด้วย `toDocBreed()` / `fromDocBreed()`** อย่าไปแบนฝั่งใดฝั่งหนึ่ง
- **ข้อมูลไหลสองทาง:**
  - เข้า — HatcheryOS อ่าน `doc_targets` มาเป็น Sales Demand
  - ออก — ตอน **Complete Hatch** จะสร้าง `doc_records` 1 แถวให้ลูกค้าที่ผูกไว้ตั้งแต่ตอนตั้งไข่ (`pushHatchToDocTracker()`) โดย `forecast_doc` → `u_ordered` และ `actual_doc` → `u_actual` ทำให้หน้า Order vs Actual ของ DOC Tracker อ่านได้ว่า "ตู้ฟักสัญญาไว้เท่าไร ได้จริงเท่าไร"
  - กัน**สร้างซ้ำ**ด้วย `egg_settings.doc_record_id` — ถ้ามีค่าแล้วจะข้าม · ถ้าชน `doc_records_unique_idx` (23505) จะแจ้งว่ามีออร์เดอร์อยู่แล้วและไม่สร้างซ้ำ
  - ลูกค้าเป็น **optional** ถ้าไม่ผูก batch นั้นอยู่แค่ใน HatcheryOS · คอลัมน์ลูกค้าถูกส่งไปเฉพาะตอนมีค่า เพื่อให้แอพยังตั้งไข่ได้แม้ยังไม่ได้รัน migration
- HatcheryOS ธีมมืด/อังกฤษล้วน/re-render ทั้งหน้า ส่วน DOC Tracker ธีมสว่าง/TH-EN/แก้ DOM ตรงๆ — คนละแนว ตั้งใจแยกไว้ก่อน ค่อยยุบรวมทีหลัง

## Backend (Supabase)

- URL/anon key ฝังใน `flutter_app/lib/config.dart`, `index.html` และ `hatchery-os.html`
- ตาราง HatcheryOS: `egg_lots`, `egg_settings`, `farm_egg_plan`, `cool_room_opening_stock` (อยู่ project เดียวกับ DOC Tracker)
- ตารางหลัก `doc_records`: week_no, record_date, hatchery, customer_type, customer_name, breed, m/f/u_ordered, m/f/u_actual, total_ordered/total_actual (generated — ห้าม insert), do_number, truck_plate, departure_time, location, distance_km, doa_count, delivery_status, driver_token, unit_price, vaccine_*, avg_weight_*
- id อาจเป็น bigint หรือ uuid — โค้ด Flutter เก็บเป็น `Object?` ส่งกลับตรงๆ
- PostgREST จำกัด 1000 แถว/ครั้ง → ต้อง paginate ด้วย `.range()` (ทำแล้วทั้งสองแอพ)
- ⚠️ `doc_records` มี unique index `doc_records_unique_idx` ที่ **ไม่ปรากฏในโค้ดเลย** — insert ที่ชนจะได้ SQLSTATE 23505 คีย์รวม **ยอดสั่ง m/f/u_ordered** + `do_number` + `truck_plate` ด้วย รายละเอียดและวิธีตรวจอยู่ใน `db/`
- Auth: email/password (บัญชีเดียวกันทั้งเว็บและแอพ)
- Driver mode (เว็บ): ลิงก์ `?drv={id}&tk={driver_token}` ให้คนขับอัปเดตสถานะโดยไม่ login — QR ในแอพมือถือใช้ format เดียวกัน

## Flutter app — สิ่งที่ต้องรู้

- `android/`, `ios/` **ไม่ commit** — CI รัน `flutter create . --platforms android` สร้างใหม่ทุก build แล้ว sed ฉีด `INTERNET` permission เข้า AndroidManifest (release build ไม่ได้ permission นี้อัตโนมัติ!)
- ฟอนต์ Sarabun ฝังใน `assets/fonts/` (google_fonts ใช้ไม่ได้ — โหลดฟอนต์ runtime พังตอนออฟไลน์)
- i18n: `lib/i18n.dart` — `tr('key')` + `lang` ValueNotifier; HomeShell ฟัง lang แล้ว rebuild หน้าลูกแบบ non-const (const instance จะไม่ rebuild ตอนสลับภาษา — เคยเป็นบั๊ก)
- `toPayload()` ใน model ส่งเฉพาะฟิลด์ที่ฟอร์มมือถือแก้ — กันไม่ให้ update ไปลบค่าฟิลด์ที่กรอกจากเว็บ (วัคซีน/น้ำหนัก/ราคา)
- CI Flutter = latest stable → ใช้ type ใหม่ (`CardThemeData` ไม่ใช่ `CardTheme`)

## iOS build (ทำบน macOS)

1. ติดตั้ง Xcode (App Store) + Flutter SDK แล้ว `flutter doctor`
2. `git clone https://github.com/yudthakarnk-commits/doc-tracker && cd doc-tracker/flutter_app`
3. `flutter create . --platforms ios --org com.hatchery --project-name doc_tracker`
4. `flutter pub get && flutter run` (เลือก iOS Simulator ได้เลย)
5. ลงเครื่องจริง: เปิด `ios/Runner.xcworkspace` ใน Xcode → Signing & Capabilities → เลือก Team (Apple ID ฟรีได้ 7 วัน/เครื่องตัวเอง, แจกจริงต้อง Apple Developer $99/ปี)
6. อย่าลืมตั้ง `flutter_launcher_icons` เป็น `ios: true` ใน pubspec แล้ว `dart run flutter_launcher_icons` ก่อน build จริง

## Environment ฝั่ง Windows (เครื่องหลัก)

- เครือข่ายบริษัทบล็อก `cdn.jsdelivr.net` — เว็บใช้ cdnjs/unpkg เท่านั้น
- ไม่มี Node/Java/Android SDK ในเครื่อง → build ทุกอย่างผ่าน GitHub Actions
- เว็บ: แก้ที่ `...\PS Hatchery Management System Project\Edit location\index.html` แล้วคัดลอกมา repo นี้ก่อน push
