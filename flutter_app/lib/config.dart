/// App-wide constants — same Supabase backend as the web app.
class AppConfig {
  /// Keep in sync with pubspec.yaml `version:` — shown in the avatar menu.
  static const appVersion = '1.2.7';

  static const supabaseUrl = 'https://ncnppcmlxdaabuwkcbtm.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jbnBwY21seGRhYWJ1d2tjYnRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxNjg3NTEsImV4cCI6MjA5Mjc0NDc1MX0.bfUzVo4WvMdjAtZl9NdCf8Q7CScghg-oWTRFLlhHaTs';

  static const hatcheries = [
    'Chengkau',
    'Kluang',
    'K.Kangsar',
    'Sg. Sayong',
    'Kota',
    'External',
  ];

  static const customerTypes = ['Customer', 'Contract Farm', 'Company Farm'];

  static const breeds = ['COBB', 'ROSS'];
}

/// ISO-8601 week number (matches getISOWeek() in the web app).
int isoWeek(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final dayNr = (d.weekday + 6) % 7; // Mon = 0
  final thursday =
      d.subtract(Duration(days: dayNr)).add(const Duration(days: 3));
  final firstThursdayRef = DateTime.utc(thursday.year, 1, 4);
  final firstDayNr = (firstThursdayRef.weekday + 6) % 7;
  final firstThursday = firstThursdayRef
      .subtract(Duration(days: firstDayNr))
      .add(const Duration(days: 3));
  return 1 + (thursday.difference(firstThursday).inDays / 7).round();
}
