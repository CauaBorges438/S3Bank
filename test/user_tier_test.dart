import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/models/user_tier.dart';
import 'package:s3_bank/providers/user_provider.dart';

void main() {
  group('UserTier', () {
    test('percentual do CDI de cada nível', () {
      expect(UserTier.bronze.cdiPercentage, 1.00);
      expect(UserTier.prata.cdiPercentage, 1.15);
      expect(UserTier.ouro.cdiPercentage, 1.30);
      expect(UserTier.diamante.cdiPercentage, 1.40);
    });

    test('rótulo do CDI', () {
      expect(UserTier.bronze.cdiLabel, '100% do CDI');
      expect(UserTier.diamante.cdiLabel, '140% do CDI');
    });

    test('ordem da progressão e nível máximo', () {
      expect(UserTier.bronze.next, UserTier.prata);
      expect(UserTier.prata.next, UserTier.ouro);
      expect(UserTier.ouro.next, UserTier.diamante);
      expect(UserTier.diamante.next, isNull);
    });

    test('pontos para o próximo nível (nível máximo não tem meta)', () {
      expect(UserTier.bronze.pointsRequiredForNext, 300);
      expect(UserTier.prata.pointsRequiredForNext, 700);
      expect(UserTier.ouro.pointsRequiredForNext, 1500);
      expect(UserTier.diamante.pointsRequiredForNext, 0);
    });
  });

  group('UserProvider - pontos de constância', () {
    test('aporte soma 15 pontos fixos + 1 ponto a cada R\$ 10', () {
      final user = UserProvider(initialPoints: 100);
      user.registerDeposit(50); // 15 + 5
      expect(user.consistencyPoints, 120);
      expect(user.tier, UserTier.bronze);
    });

    test('sobe de nível e aproveita o excedente de pontos', () {
      final user = UserProvider(initialPoints: 290);
      user.registerDeposit(100); // 15 + 10 = 25 -> 315
      expect(user.tier, UserTier.prata);
      expect(user.consistencyPoints, 15);
    });

    test('bater exatamente a meta também sobe de nível', () {
      final user = UserProvider(initialPoints: 285);
      user.registerDeposit(0); // +15 -> 300
      expect(user.tier, UserTier.prata);
      expect(user.consistencyPoints, 0);
    });

    test('um aporte grande pode subir mais de um nível', () {
      final user = UserProvider(initialPoints: 0);
      user.registerDeposit(10000); // 15 + 1000 = 1015
      // 1015 - 300 (bronze) = 715; 715 - 700 (prata) = 15 no ouro
      expect(user.tier, UserTier.ouro);
      expect(user.consistencyPoints, 15);
    });

    test('no nível máximo o progresso é 100% e o nível não passa disso', () {
      final user = UserProvider(
        initialTier: UserTier.diamante,
        initialPoints: 10,
      );
      user.registerDeposit(1000);
      expect(user.tier, UserTier.diamante);
      expect(user.nextTier, isNull);
      expect(user.progressToNextTier, 1.0);
      expect(user.pointsRemainingForNext, 0);
    });

    test('progresso e pontos restantes até o próximo nível', () {
      final user = UserProvider(initialPoints: 150);
      expect(user.progressToNextTier, 0.5);
      expect(user.pointsRemainingForNext, 150);
    });

    test('notifica os ouvintes a cada aporte', () {
      final user = UserProvider(initialPoints: 0);
      var calls = 0;
      user.addListener(() => calls++);
      user.registerDeposit(20);
      expect(calls, 1);
    });
  });

  group('UserProvider - perfil', () {
    test('updateName ignora nome vazio e remove espaços', () {
      final user = UserProvider(initialPoints: 0);
      user.updateName('   ');
      expect(user.name, 'Rafaela Souza');
      user.updateName('  Maria Silva  ');
      expect(user.name, 'Maria Silva');
    });

    test('startNewProfile zera nível e pontos', () {
      final user = UserProvider(
        initialTier: UserTier.ouro,
        initialPoints: 500,
      );
      user.startNewProfile('Novo Usuário');
      expect(user.name, 'Novo Usuário');
      expect(user.tier, UserTier.bronze);
      expect(user.consistencyPoints, 0);
    });

    test('toJson e restore preservam os dados', () {
      final original = UserProvider(
        initialTier: UserTier.prata,
        initialPoints: 42,
      )..updateName('Ana Teste');

      final copy = UserProvider()..restore(original.toJson());
      expect(copy.name, 'Ana Teste');
      expect(copy.tier, UserTier.prata);
      expect(copy.consistencyPoints, 42);
    });
  });
}
