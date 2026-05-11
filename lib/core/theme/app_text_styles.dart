// lib/core/theme/app_text_styles.dart
// Phase 11 — Prism Design System
// Centralised text style helpers used everywhere in the UI.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTextStyles {
  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 36, fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark, height: 1.15, letterSpacing: -0.5);

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark, height: 1.2);

  // ── Headings ──────────────────────────────────────────────────────────────
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark, height: 1.25);

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark, height: 1.3);

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark, height: 1.35);

  static TextStyle get h4 => GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark, height: 1.4);

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: AppColors.textPrimaryDark, height: 1.55);

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: AppColors.textSecondaryDark, height: 1.55);

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: AppColors.textSecondaryDark, height: 1.5);

  // ── Labels ────────────────────────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark, letterSpacing: 0.1);

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: AppColors.textSecondaryDark, letterSpacing: 0.2);

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: AppColors.textTertiaryDark, letterSpacing: 0.3);

  // ── Mono (code / analysis text) ───────────────────────────────────────────
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: AppColors.textPrimaryDark, height: 1.6);

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 11, fontWeight: FontWeight.w400,
        color: AppColors.textSecondaryDark, height: 1.5);

  // ── Agent output streaming text ───────────────────────────────────────────
  static TextStyle get agentOutput => GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w400,
        color: AppColors.textPrimaryDark, height: 1.65);

  // ── Spectrum / gradient label ─────────────────────────────────────────────
  static TextStyle get spectrumLabel => GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.8, color: AppColors.textTertiaryDark);
}

// ── Design Tokens ─────────────────────────────────────────────────────────────
abstract class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

abstract class AppRadius {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double full = 999;
}

abstract class AppShadows {
  static List<BoxShadow> get cardGlow => [
        BoxShadow(
          color: AppColors.prismPurple.withOpacity(0.08),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> agentGlow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];
}
