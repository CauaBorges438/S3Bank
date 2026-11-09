import 'package:flutter/material.dart';

/// Paleta base do app. O fundo é dark/moderno; a cor vibrante de
/// destaque (accent) é o roxo-azulado usado no branding do S3 Bank,
/// mantendo consistência com o cartão Diamante.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B0B12);
  static const Color surface = Color(0xFF16161F);
  static const Color surfaceElevated = Color(0xFF1F1F2C);
  static const Color border = Color(0xFF2A2A3A);

  static const Color accent = Color(0xFF6A4CE0);
  static const Color accentLight = Color(0xFFB98CFF);

  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFA3A3B2);
  static const Color textDisabled = Color(0xFF5C5C6E);

  static const Color success = Color(0xFF35D07F);
  static const Color danger = Color(0xFFFF5C6C);

  // Gradiente da tela de login, inspirado no cartão premium.
  static const Color loginPurpleTop = Color(0xFF6F42C1);
  static const Color loginBlueMid = Color(0xFF3355D3);
  static const Color loginBlueDark = Color(0xFF1E2B88);
  static const Color chipSilver = Color(0xFFC0C0C0);
  static const Color chipSilverDark = Color(0xFF8E8E93);

  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [loginPurpleTop, loginBlueMid, loginBlueDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1D6E), Color(0xFF6A4CE0), Color(0xFFB98CFF)],
  );
}
