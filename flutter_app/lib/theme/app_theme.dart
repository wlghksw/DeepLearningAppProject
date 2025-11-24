import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFFFF7A34);
  static const Color accent = Color(0xFF2FB16D);
  static const Color neutral = Color(0xFF44413C);
  static const Color surface = Color(0xFFFFF7ED);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      surface: surface,
      onSurface: neutral,
    );

    final textTheme = GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.notoSans(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: neutral,
      ),
      titleMedium: GoogleFonts.notoSans(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: neutral,
      ),
      bodyLarge: GoogleFonts.notoSans(
        fontSize: 16,
        color: neutral.withValues(alpha: 0.9),
      ),
      bodyMedium: GoogleFonts.notoSans(
        fontSize: 14,
        color: neutral.withValues(alpha: 0.75),
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        foregroundColor: neutral,
        titleTextStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: neutral,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle:
              GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: neutral.withValues(alpha: 0.8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.notoSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
