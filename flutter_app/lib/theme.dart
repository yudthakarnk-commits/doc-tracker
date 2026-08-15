import 'package:flutter/material.dart';

const _seed = Color(0xFF2563EB);
const _font = 'Sarabun';

ThemeData _base(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF0F141B) : const Color(0xFFE9EEF6),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isDark ? const Color(0xFF151B24) : Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF101828),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF232B36) : const Color(0xFFE9ECF1),
        ),
      ),
      color: isDark ? const Color(0xFF151B24) : Colors.white,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1B2330) : Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE9ECF1),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE9ECF1),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _seed, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF151B24) : Colors.white,
      indicatorColor: _seed.withOpacity(.14),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
            fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

final lightTheme = _base(Brightness.light);
final darkTheme = _base(Brightness.dark);
