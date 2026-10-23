import 'package:flutter/material.dart';

abstract final class ShannonTheme {
  static ThemeData get dark => build(Brightness.dark);
  static ThemeData get light => build(Brightness.light);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: brightness,
        ).copyWith(
          primary: Color(dark ? 0xFF60A5FA : 0xFF2563EB),
          surface: Color(dark ? 0xFF0B1218 : 0xFFFFFFFF),
          onSurface: Color(dark ? 0xFFF3F6FA : 0xFF111827),
          onSurfaceVariant: Color(dark ? 0xFF98A7B9 : 0xFF536174),
          outlineVariant: Color(dark ? 0xFF263341 : 0xFFDCE3EC),
        );
    final background = Color(dark ? 0xFF050B10 : 0xFFF8FAFC);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
