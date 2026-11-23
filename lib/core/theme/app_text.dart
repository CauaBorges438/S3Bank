import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Escala tipográfica única do app. Use estes estilos em vez de TextStyle
/// solto, para que todas as telas tenham o mesmo ritmo.
class AppText {
  AppText._();

  /// Rótulos pequenos e legendas.
  static const label = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Texto corrido.
  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.4,
  );

  /// Título de seção ou de cartão.
  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// Valor destacado em uma linha (ex.: nome de compra, valor de lista).
  static const value = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// Número principal de uma tela (saldo, limite, fatura).
  static const hero = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// Cabeçalho de seção em caixa-alta.
  static const section = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
}
