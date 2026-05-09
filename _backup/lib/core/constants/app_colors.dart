import 'package:flutter/material.dart';

class AppColors {
  // ── Dark Background ──
  static const Color background    = Color(0xFF0D0F17);
  static const Color surface       = Color(0xFF1A1D2E);
  static const Color card          = Color(0xFF252836);
  static const Color divider       = Color(0xFF2E3148);

  // ── Brand ──
  static const Color primary       = Color(0xFF6C63FF);
  static const Color primaryLight  = Color(0xFF9D97FF);
  static const Color primaryDark   = Color(0xFF4A42E0);
  static const Color secondary     = Color(0xFF03DAC6);
  static const Color accent        = Color(0xFFFF6B6B);

  // ── Text ──
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3CC);
  static const Color textHint      = Color(0xFF6B6B8A);

  // ── Status ──
  static const Color online        = Color(0xFF4CAF50);
  static const Color offline       = Color(0xFF757575);
  static const Color typing        = Color(0xFF03DAC6);
  static const Color unread        = Color(0xFF6C63FF);

  // ── Messages ──
  static const Color sentBubble    = Color(0xFF6C63FF);
  static const Color receivedBubble= Color(0xFF252836);

  // ── Call ──
  static const Color callGreen     = Color(0xFF4CAF50);
  static const Color callRed       = Color(0xFFE53935);
  static const Color callBg        = Color(0xFF0A0C14);

  // ── Light Theme ──
  static const Color lightBackground= Color(0xFFF0F2FF);
  static const Color lightSurface   = Color(0xFFFFFFFF);
  static const Color lightCard      = Color(0xFFEEEFFB);
  static const Color lightDivider   = Color(0xFFDDE0F5);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF03DAC6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient callGradient = LinearGradient(
    colors: [Color(0xFF0D0F17), Color(0xFF1A1D2E), Color(0xFF252836)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient onboardingGradient = LinearGradient(
    colors: [Color(0xFF0D0F17), Color(0xFF1A1D2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
