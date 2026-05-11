import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract class AppTheme {
  // ── Text Theme ───────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 57, fontWeight: FontWeight.w300, color: primary),
      displayMedium: GoogleFonts.inter(
          fontSize: 45, fontWeight: FontWeight.w300, color: primary),
      displaySmall: GoogleFonts.inter(
          fontSize: 36, fontWeight: FontWeight.w400, color: primary),
      headlineLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w600, color: primary),
      headlineMedium: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w600, color: primary),
      headlineSmall: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w600, color: primary),
      titleLarge: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w500, color: primary),
      titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w500, color: primary),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: primary),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500, color: secondary),
    );
  }

  // ── DARK THEME (primary) ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark().copyWith(
      primary: AppColors.prismPurple,
      primaryContainer: AppColors.prismPurpleDark,
      secondary: AppColors.agentMarcus,
      secondaryContainer: AppColors.agentMarcusBg,
      surface: AppColors.bgDarkSurface,
      surfaceContainerHighest: AppColors.bgDarkCard,
      background: AppColors.bgDark,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryDark,
      onBackground: AppColors.textPrimaryDark,
      onError: Colors.white,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.dividerDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: _buildTextTheme(
          AppColors.textPrimaryDark, AppColors.textSecondaryDark),

      // ── AppBar ─────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
        iconTheme:
            const IconThemeData(color: AppColors.textPrimaryDark, size: 24),
      ),

      // ── Card ───────────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: AppColors.bgDarkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),

      // ── Input ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgDarkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.prismPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        labelStyle: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textSecondaryDark),
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiaryDark),
      ),

      // ── ElevatedButton ─────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.prismPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.prismPurple,
          side: const BorderSide(color: AppColors.prismPurple, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.prismPurple,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── BottomNavBar ───────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgDarkSurface,
        selectedItemColor: AppColors.prismPurple,
        unselectedItemColor: AppColors.textTertiaryDark,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── NavigationBar (M3) ─────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgDarkSurface,
        indicatorColor: AppColors.prismPurpleDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.prismPurple);
          }
          return const IconThemeData(color: AppColors.textTertiaryDark);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.prismPurple);
          }
          return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiaryDark);
        }),
      ),

      // ── Divider ────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 0.5,
        space: 1,
      ),

      // ── Chip ───────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgDarkElevated,
        selectedColor: AppColors.prismPurpleDark,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimaryDark),
        side: const BorderSide(color: AppColors.borderDark, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── SnackBar ───────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgDarkElevated,
        contentTextStyle: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textPrimaryDark),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Progress Indicator ─────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.prismPurple,
        linearTrackColor: AppColors.borderDark,
      ),
    );
  }

  // ── LIGHT THEME ──────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light().copyWith(
      primary: AppColors.prismPurple,
      primaryContainer: AppColors.prismPurpleLight,
      secondary: AppColors.agentMarcus,
      surface: AppColors.bgLightSurface,
      surfaceContainerHighest: AppColors.bgLightCard,
      background: AppColors.bgLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
      onBackground: AppColors.textPrimaryLight,
      outline: AppColors.borderLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: _buildTextTheme(
          AppColors.textPrimaryLight, AppColors.textSecondaryLight),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.bgLightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
    );
  }
}
