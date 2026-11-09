import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/utils/currency_input_formatter.dart';

TextEditingValue _type(CurrencyInputFormatter f, String old, String next) =>
    f.formatEditUpdate(TextEditingValue(text: old), TextEditingValue(text: next));

void main() {
  group('CurrencyInputFormatter', () {
    final f = CurrencyInputFormatter();

    test('formata a partir dos centavos', () {
      expect(_type(f, '', '5').text, '0,05');
      expect(_type(f, '0,05', '0,055').text, '0,55');
      expect(_type(f, '0,55', '0,555').text, '5,55');
      expect(_type(f, '', '520').text, '5,20');
      expect(_type(f, '', '1500000').text, '15.000,00');
    });

    test('campo vazio continua vazio', () {
      expect(_type(f, '0,05', '').text, '');
    });

    test('respeita o limite de dígitos', () {
      final limited = CurrencyInputFormatter(maxDigits: 3);
      expect(_type(limited, '9,99', '99,999').text, '9,99');
    });

    test('parse converte texto em double', () {
      expect(CurrencyInputFormatter.parse('1.234,56'), 1234.56);
      expect(CurrencyInputFormatter.parse('0,05'), 0.05);
      expect(CurrencyInputFormatter.parse(''), 0);
    });
  });
}