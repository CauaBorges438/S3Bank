import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Máscara de moeda pt-BR para campos de valor.
///
/// O usuário digita só números e o campo vai formatando a partir dos
/// centavos: 5 -> 0,05 | 555 -> 5,55 | 55500 -> 555,00 | 1500000 -> 15.000,00
///
/// [maxDigits] limita a quantidade de dígitos (padrão 11 = até 999.999.999,99),
/// evitando valores absurdos ou "infinitos".
class CurrencyInputFormatter extends TextInputFormatter {
  final int maxDigits;

  CurrencyInputFormatter({this.maxDigits = 11});

  static final NumberFormat _format = NumberFormat('#,##0.00', 'pt_BR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return TextEditingValue.empty;

    // Passou do limite: ignora o dígito extra e mantém o texto anterior.
    if (digits.length > maxDigits) return oldValue;

    final text = _format.format(int.parse(digits) / 100);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Converte o texto do campo (ex.: "1.234,56") em double (1234.56).
  /// Retorna 0 se estiver vazio.
  static double parse(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / 100;
  }
}