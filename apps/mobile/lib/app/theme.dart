import 'package:flutter/material.dart';

import 'design_system.dart';

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
          primary: Color(dark ? 0xFF3B82F6 : 0xFF1677FF),
          surface: Color(dark ? 0xFF151E28 : 0xFFFFFFFF),
          surfaceContainerHigh: Color(dark ? 0xFF202B38 : 0xFFEAF0F7),
          onSurface: Color(dark ? 0xFFF3F6FA : 0xFF111827),
          onSurfaceVariant: Color(dark ? 0xFF98A7B9 : 0xFF536174),
          outlineVariant: Color(dark ? 0xFF2B3745 : 0xFFDCE3EC),
        );
    final background = Color(dark ? 0xFF0B1118 : 0xFFF6F8FB);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      fontFamilyFallback: const [
        'NotoSansArmenian',
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
      ],
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          side: BorderSide(color: scheme.primary.withValues(alpha: .55)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: const ['NotoSansArmenian'],
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
          borderRadius: BorderRadius.circular(ShannonSpace.cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1677FF),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(ShannonSpace.control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
