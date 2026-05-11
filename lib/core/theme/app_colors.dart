import 'package:flutter/material.dart';

/// The Prism — Brand Color System
/// Every colour used in the app lives here. Never hardcode hex elsewhere.
abstract class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────
  static const prismPurple = Color(0xFF7F77DD);
  static const prismPurpleLight = Color(0xFFEEEDFE);
  static const prismPurpleDark = Color(0xFF3C3489);
  static const prismPurpleDarker = Color(0xFF26215C);

  // ── Background (Dark theme primary) ─────────────────────────────────
  static const bgDark = Color(0xFF0D0C1A);
  static const bgDarkSurface = Color(0xFF151425);
  static const bgDarkCard = Color(0xFF1C1B30);
  static const bgDarkElevated = Color(0xFF232238);

  // ── Background (Light theme) ─────────────────────────────────────────
  static const bgLight = Color(0xFFF8F7FF);
  static const bgLightSurface = Color(0xFFFFFFFF);
  static const bgLightCard = Color(0xFFF2F1FC);

  // ── Text ─────────────────────────────────────────────────────────────
  static const textPrimaryDark = Color(0xFFF0EFFF);
  static const textSecondaryDark = Color(0xFFABA9CC);
  static const textTertiaryDark = Color(0xFF6E6C8A);
  static const textPrimaryLight = Color(0xFF1A1A2E);
  static const textSecondaryLight = Color(0xFF444441);
  static const textTertiaryLight = Color(0xFF888780);

  // ── Agent Spectrum Colors ────────────────────────────────────────────
  static const agentPriya = Color(0xFF7F77DD);   // Purple — Research
  static const agentMarcus = Color(0xFF1D9E75);  // Teal — Gaps
  static const agentZara = Color(0xFFBA7517);    // Amber — Future
  static const agentLeon = Color(0xFFD85A30);    // Coral — Risk
  static const agentAiko = Color(0xFF378ADD);    // Blue — Patterns
  static const agentSofia = Color(0xFFD4537E);   // Pink — Innovation
  static const agentRavi = Color(0xFF639922);    // Green — Domain
  static const agentVex = Color(0xFFE24B4A);     // Red — Competitor
  static const agentMorgan = Color(0xFF888780);  // Gray — Monetisation
  static const agentChen = Color(0xFF3C3489);    // Deep Purple — Synthesis

  // ── Agent Light Backgrounds ──────────────────────────────────────────
  static const agentPriyaBg = Color(0xFF1A1830);
  static const agentMarcusBg = Color(0xFF0D2420);
  static const agentZaraBg = Color(0xFF251A0A);
  static const agentLeonBg = Color(0xFF251208);
  static const agentAikoBg = Color(0xFF0C1E30);
  static const agentSofiaBg = Color(0xFF2A101C);
  static const agentRaviBg = Color(0xFF131F06);
  static const agentVexBg = Color(0xFF2A0C0C);
  static const agentMorganBg = Color(0xFF1C1C1C);
  static const agentChenBg = Color(0xFF130F2A);

  // ── Spectrum Gradient (for hero animations) ──────────────────────────
  static const List<Color> spectrumGradient = [
    Color(0xFF7F77DD), // violet
    Color(0xFF378ADD), // blue
    Color(0xFF1D9E75), // teal
    Color(0xFF639922), // green
    Color(0xFFBA7517), // amber
    Color(0xFFD85A30), // orange
    Color(0xFFE24B4A), // red
    Color(0xFFD4537E), // pink
  ];

  // ── Semantic ─────────────────────────────────────────────────────────
  static const success = Color(0xFF1D9E75);
  static const warning = Color(0xFFBA7517);
  static const error = Color(0xFFE24B4A);
  static const info = Color(0xFF378ADD);

  // ── Borders ──────────────────────────────────────────────────────────
  static const borderDark = Color(0xFF2A2840);
  static const borderLight = Color(0xFFD8D6F0);

  // ── Dividers ─────────────────────────────────────────────────────────
  static const dividerDark = Color(0xFF222035);
  static const dividerLight = Color(0xFFE8E6FF);
}
