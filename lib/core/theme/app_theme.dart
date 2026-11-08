import 'package:flutter/material.dart';

/// Vaulta palette, taken from the reference UI: deep ink-teal, mid teal and warm sand.
class AppColors {
  static const ink = Color(0xFF0B1E25);        // darkest background
  static const deep = Color(0xFF12303A);       // dark cards
  static const teal = Color(0xFF3D7584);       // hero / accent cards
  static const tealBright = Color(0xFF45808F); // buttons on dark
  static const sand = Color(0xFFD8D1C7);       // beige cards
  static const sandLight = Color(0xFFEFEBE4);  // light-mode background
  static const inkText = Color(0xFF10262E);    // text on sand
  static const ok = Color(0xFF4FA37D);
  static const warn = Color(0xFFE0A93B);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: AppColors.teal, brightness: b);

    final scheme = isDark
        ? base.copyWith(
            primary: AppColors.tealBright,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFF1B4755),
            onPrimaryContainer: const Color(0xFFE6F2F5),
            secondary: AppColors.sand,
            onSecondary: AppColors.inkText,
            secondaryContainer: AppColors.sand,
            onSecondaryContainer: AppColors.inkText,
            surface: AppColors.ink,
            onSurface: const Color(0xFFE9E4DB),
            onSurfaceVariant: const Color(0xFFA9C0C7),
            surfaceContainerLow: AppColors.deep,
            surfaceContainer: AppColors.deep,
            surfaceContainerHigh: const Color(0xFF194250),
            surfaceContainerHighest: const Color(0xFF1E4958),
            outline: const Color(0xFF7FA3AE),
            outlineVariant: const Color(0xFF24505E),
          )
        : base.copyWith(
            primary: const Color(0xFF2F6372),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFCFE3E8),
            onPrimaryContainer: const Color(0xFF0B2A33),
            secondary: const Color(0xFF6F665A),
            onSecondary: Colors.white,
            secondaryContainer: AppColors.sand,
            onSecondaryContainer: AppColors.inkText,
            surface: AppColors.sandLight,
            onSurface: AppColors.inkText,
            onSurfaceVariant: const Color(0xFF4F646C),
            surfaceContainerLow: const Color(0xFFF8F6F1),
            surfaceContainer: const Color(0xFFF8F6F1),
            surfaceContainerHigh: const Color(0xFFE4DED3),
            surfaceContainerHighest: const Color(0xFFDDD6CA),
            outline: const Color(0xFF6B7F86),
            outlineVariant: const Color(0xFFCBC4B8),
          );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'RobotoCondensed',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.deep : const Color(0xFFF8F6F1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}
