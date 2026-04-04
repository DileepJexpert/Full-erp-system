import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color secondaryColor = Color(0xFF7C3AED);
  static const Color sidebarBg = Color(0xFF1A1D27);
  static const Color sidebarText = Color(0xFFE2E8F0);
  static const Color contentBg = Color(0xFFF8F9FA);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFEAB308);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color infoColor = Color(0xFF0EA5E9);

  // Sync status colors
  static const Color syncedColor = Color(0xFF16A34A);
  static const Color pendingColor = Color(0xFFEAB308);
  static const Color offlineColor = Color(0xFFDC2626);

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: contentBg,
        error: errorColor,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          fontSize: 13,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      scaffoldBackgroundColor: contentBg,
    );
  }
}
