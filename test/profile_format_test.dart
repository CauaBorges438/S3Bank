import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/profile_format.dart';

void main() {
  test('CPF mostra só o miolo', () {
    expect(maskCpf('12345678901'), '***.456.789-**');
    expect(maskCpf('123.456.789-01'), '***.456.789-**');
  });

  test('CPF ausente ou inválido não quebra', () {
    expect(maskCpf(null), 'Não informado');
    expect(maskCpf(''), 'Não informado');
    expect(maskCpf('123'), 'Não informado');
  });
}
