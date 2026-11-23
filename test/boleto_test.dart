import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/boleto.dart';

void main() {
  const code = '12345678901234567890123456789012345678901234567';

  test('aceita 47 dígitos', () {
    expect(isValidBoletoCode(code), isTrue);
  });

  test('aceita o código digitado com espaços e pontos', () {
    const formatado = '12345.67890 12345.678901 23456.789012 3 45678901234567';
    expect(boletoDigits(formatado).length, 47);
    expect(isValidBoletoCode(formatado), isTrue);
  });

  test('recusa tamanho errado e letras', () {
    expect(isValidBoletoCode(code.substring(1)), isFalse);
    expect(isValidBoletoCode('$code'
        '0'), isFalse);
    expect(isValidBoletoCode('abc${code.substring(3)}'), isFalse);
    expect(isValidBoletoCode(''), isFalse);
  });
}
