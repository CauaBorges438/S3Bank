import 'package:flutter/services.dart';

/// Validações de documentos e contatos brasileiros.
class BrValidators {
  BrValidators._();

  /// Só dígitos (ex.: "529.982.247-25" -> "52998224725").
  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Teclado numérico com limite de 11 dígitos (CPF e celular).
  static List<TextInputFormatter> get elevenDigits => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ];

  /// CPF válido: 11 dígitos, sem sequência repetida e com os dois
  /// dígitos verificadores corretos (algoritmo oficial da Receita Federal).
  static bool isValidCpf(String raw) {
    final d = digits(raw);
    if (d.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;

    int check(int length) {
      var sum = 0;
      for (var i = 0; i < length; i++) {
        sum += int.parse(d[i]) * (length + 1 - i);
      }
      final rest = (sum * 10) % 11;
      return rest == 10 ? 0 : rest;
    }

    return check(9) == int.parse(d[9]) && check(10) == int.parse(d[10]);
  }

  /// Celular: DDD (11 a 99) + número com nono dígito 9. Ex.: 11 91234-5678.
  static bool isValidCelular(String raw) {
    final d = digits(raw);
    if (d.length != 11) return false;
    final ddd = int.parse(d.substring(0, 2));
    if (ddd < 11 || ddd > 99) return false;
    return d[2] == '9';
  }

  /// Formato guardado no banco: +55 + DDD + número.
  static String celularForStorage(String raw) => '+55${digits(raw)}';

  static String? cpfError(String? raw) {
    if (raw == null || digits(raw).isEmpty) return 'Informe seu CPF';
    return isValidCpf(raw) ? null : 'CPF inválido';
  }

  static String? celularError(String? raw) {
    if (raw == null || digits(raw).isEmpty) return 'Informe seu celular';
    return isValidCelular(raw) ? null : 'Celular inválido (DDD + número com 9)';
  }
}
