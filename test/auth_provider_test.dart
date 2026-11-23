import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/providers/auth_provider.dart';

// Os fluxos que chamam o Supabase precisam de um projeto real (ou de um
// mock do GoTrueClient) para serem testados de ponta a ponta. Aqui ficam
// as regras puras, que não dependem de rede.
void main() {
  group('validação de e-mail', () {
    test('aceita e-mails válidos', () {
      expect(AuthProvider.isValidEmail('nome@email.com'), isTrue);
      expect(AuthProvider.isValidEmail('  a.b@dominio.com.br '), isTrue);
    });

    test('rejeita CPF e textos sem formato de e-mail', () {
      expect(AuthProvider.isValidEmail('52998224725'), isFalse);
      expect(AuthProvider.isValidEmail('sem-arroba'), isFalse);
      expect(AuthProvider.isValidEmail(''), isFalse);
    });

    test('normaliza para minúsculas e sem espaços', () {
      expect(AuthProvider.normalizeEmail('  Nome@Email.COM '), 'nome@email.com');
    });
  });


  group('senha de 6 números', () {
    test('aceita exatamente 6 dígitos', () {
      expect(AuthProvider.isValidPassword('123456'), isTrue);
      expect(AuthProvider.isValidPassword('000000'), isTrue);
    });

    test('recusa letras, símbolos, espaços e tamanho diferente de 6', () {
      expect(AuthProvider.isValidPassword('12345'), isFalse);
      expect(AuthProvider.isValidPassword('1234567'), isFalse);
      expect(AuthProvider.isValidPassword('12345a'), isFalse);
      expect(AuthProvider.isValidPassword('abcdef'), isFalse);
      expect(AuthProvider.isValidPassword('123 56'), isFalse);
      expect(AuthProvider.isValidPassword('12345!'), isFalse);
      expect(AuthProvider.isValidPassword(''), isFalse);
    });

    test('passwordError devolve a mensagem certa', () {
      expect(AuthProvider.passwordError('123456'), isNull);
      expect(AuthProvider.passwordError('12ab56'), AuthProvider.passwordMessage);
      expect(AuthProvider.passwordError(null), AuthProvider.passwordMessage);
    });
  });
}
