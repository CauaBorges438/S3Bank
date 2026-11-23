import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/br_validators.dart';

void main() {
  group('CPF', () {
    test('aceita CPFs válidos, com ou sem máscara', () {
      expect(BrValidators.isValidCpf('52998224725'), isTrue);
      expect(BrValidators.isValidCpf('529.982.247-25'), isTrue);
    });

    test('recusa dígito verificador errado', () {
      expect(BrValidators.isValidCpf('52998224724'), isFalse);
      expect(BrValidators.isValidCpf('52998224715'), isFalse);
    });

    test('recusa sequência repetida, mesmo que a conta bata', () {
      for (var d = 0; d <= 9; d++) {
        expect(BrValidators.isValidCpf('$d' * 11), isFalse);
      }
    });

    test('recusa tamanho errado', () {
      expect(BrValidators.isValidCpf('5299822472'), isFalse);
      expect(BrValidators.isValidCpf('529982247250'), isFalse);
      expect(BrValidators.isValidCpf(''), isFalse);
    });

    test('mensagens de erro do formulário', () {
      expect(BrValidators.cpfError(''), 'Informe seu CPF');
      expect(BrValidators.cpfError('11111111111'), 'CPF inválido');
      expect(BrValidators.cpfError('52998224725'), isNull);
    });
  });

  group('celular', () {
    test('aceita celular com DDD válido e nono dígito 9', () {
      expect(BrValidators.isValidCelular('11912345678'), isTrue);
      expect(BrValidators.isValidCelular('(21) 98765-4321'), isTrue);
    });

    test('recusa fixo (sem o 9) e DDD inexistente', () {
      expect(BrValidators.isValidCelular('1134567890'), isFalse);
      expect(BrValidators.isValidCelular('01912345678'), isFalse);
      expect(BrValidators.isValidCelular('11812345678'), isFalse);
    });

    test('guarda no formato +55 + DDD + número', () {
      expect(BrValidators.celularForStorage('(11) 91234-5678'), '+5511912345678');
    });
  });
}
