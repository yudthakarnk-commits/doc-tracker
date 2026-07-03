# DOC Tracker — Hatchery Management System

ระบบติดตามการสั่ง/ส่งลูกไก่ (DOC = Day-Old Chick) ของโรงฟัก มี 2 frontend ใช้ Supabase ตัวเดียวกัน:

## Repo layout

| Path | คืออะไร | Deploy |
|---|---|---|
| `index.html`, `sw.js`, `manifest.json` | Web PWA (single-file, vanilla JS + Chart.js) | GitHub Pages: yudthakarnk-commits.github.io/doc-tracker/ |
| `flutter_app/` | แอพมือถือ Flutter (Material 3, TH/EN, light/dark) | GitHub Actions build APK → release tag `apk-latest` |
| `.github/workflows/build-apk.yml` | CI: build Android APK ทุกครั้งที่ push แก้ `flutter_app/**` | — |

## Backend (Supabase)

- URL/anon key ฝังใน `flutter_app/lib/config.dart` และใน `index.html`
- ตารางหลัก `doc_records`: week_no, record_date, hatchery, customer_type, customer_name, breed, m/f/u_ordered, m/f/u_actual, total_ordered/total_actual (generated — ห้าม insert), do_number, truck_plate, departure_time, location, distance_km, doa_count, delivery_status, driver_token, unit_price, vaccine_*, avg_weight_*
- id อาจเป็น bigint หรือ uuid — โค้ด Flutter เก็บเป็น `Object?` ส่งกลับตรงๆ
- PostgREST จำกัด 1000 แถว/ครั้ง → ต้อง paginate ด้วย `.range()` (ทำแล้วทั้งสองแอพ)
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
