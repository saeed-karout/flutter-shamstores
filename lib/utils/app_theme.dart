import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        background: isDark ? const Color(0xFF121212) : AppColors.background,
        onSurface: isDark ? Colors.white : AppColors.textDark,
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),

      // إصلاح ألوان حقول الإدخال (الفورم)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : AppColors.white,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted),
        hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),

      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.white10 : AppColors.border),
        ),
      ),

      textTheme: TextTheme(
        bodyLarge: TextStyle(color: isDark ? Colors.white : AppColors.textDark),
        bodyMedium: TextStyle(color: isDark ? Colors.white70 : AppColors.textDark),
        titleLarge: TextStyle(color: isDark ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold),
      ),
    );
  }
}
