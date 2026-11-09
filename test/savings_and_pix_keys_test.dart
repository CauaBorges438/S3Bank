import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/models/savings_goal.dart';
import 'package:s3_bank/models/user_tier.dart';
import 'package:s3_bank/providers/pix_keys_provider.dart';
import 'package:s3_bank/providers/savings_provider.dart';

void main() {
  group('SavingsProvider', () {
    test('rendimento mensal estimado usa o percentual do CDI do nível', () {
      final savings = SavingsProvider()..loadDemoData(); // total guardado: 2460
      expect(savings.totalSaved, 2460);
      // 2460 * (12,15% a.a. * 100%) / 12
      expect(savings.monthlyYieldEstimate(UserTier.bronze), closeTo(24.9075, 0.0001));
      expect(
        savings.monthlyYieldEstimate(UserTier.prata),
        greaterThan(savings.monthlyYieldEstimate(UserTier.bronze)),
      );
    });

    test('criar caixinha, guardar e resgatar', () {
      final savings = SavingsProvider()..resetForNewAccount();
      savings.createGoal(name: 'Viagem', icon: Icons.flight_takeoff, targetAmount: 1000);
      final id = savings.goals.single.id;

      savings.deposit(id, 300);
      expect(savings.goals.single.currentAmount, 300);
      expect(savings.goals.single.progress, 0.3);

      // Resgatar mais do que existe devolve só o que tem na caixinha.
      expect(savings.withdraw(id, 500), 300);
      expect(savings.goals.single.currentAmount, 0);
    });

    test('toJson e restore preservam as caixinhas e os ícones', () {
      final original = SavingsProvider()..loadDemoData();
      final decoded = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final copy = SavingsProvider()..restore(decoded);

      expect(copy.goals.length, original.goals.length);
      expect(copy.goals.first.name, 'Reserva de Emergência');
      expect(copy.goals.first.icon.codePoint, Icons.shield_outlined.codePoint);
      expect(copy.totalSaved, original.totalSaved);
    });
  });

  group('SavingsGoal', () {
    test('progresso nunca passa de 100%', () {
      final goal = SavingsGoal(
        id: '1',
        name: 'Meta',
        icon: Icons.home_outlined,
        targetAmount: 100,
        currentAmount: 250,
        createdAt: DateTime(2026),
      );
      expect(goal.progress, 1.0);
    });

    test('índice de ícone inválido cai em um ícone válido', () {
      final goal = SavingsGoal.fromJson({
        'id': '1',
        'name': 'Meta',
        'iconIndex': 99,
        'targetAmount': 10,
        'currentAmount': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      expect(savingsIconOptions.contains(goal.icon), isTrue);
    });
  });

  group('Chaves Pix - validação', () {
    test('CPF válido é normalizado para só dígitos', () {
      expect(PixKeyType.cpf.normalize('529.982.247-25'), '52998224725');
    });

    test('CPF inválido é recusado', () {
      expect(PixKeyType.cpf.normalize('529.982.247-24'), isNull); // dígito errado
      expect(PixKeyType.cpf.normalize('111.111.111-11'), isNull); // repetido
      expect(PixKeyType.cpf.normalize('123'), isNull);
    });

    test('e-mail vira minúsculo e precisa ter formato válido', () {
      expect(PixKeyType.email.normalize('  Nome@Email.COM '), 'nome@email.com');
      expect(PixKeyType.email.normalize('sem-arroba'), isNull);
    });

    test('celular vira +55DDDNÚMERO', () {
      expect(PixKeyType.phone.normalize('(11) 91234-5678'), '+5511912345678');
      expect(PixKeyType.phone.normalize('+55 11 91234-5678'), '+5511912345678');
      expect(PixKeyType.phone.normalize('1234'), isNull);
    });

    test('chave aleatória precisa ser um UUID', () {
      expect(
        PixKeyType.random.normalize('123E4567-E89B-12D3-A456-426614174000'),
        '123e4567-e89b-12d3-a456-426614174000',
      );
      expect(PixKeyType.random.normalize('qualquer-coisa'), isNull);
    });
  });

  group('PixKeysProvider', () {
    test('não cadastra chave duplicada nem inválida', () {
      final keys = PixKeysProvider()..resetForNewAccount();
      expect(keys.addKey(type: PixKeyType.email, value: 'a@b.com'), isTrue);
      expect(keys.addKey(type: PixKeyType.email, value: 'A@B.com'), isFalse);
      expect(keys.addKey(type: PixKeyType.cpf, value: '000'), isFalse);
      expect(keys.keys.length, 1);
      expect(keys.primaryKey!.value, 'a@b.com');
    });

    test('chave aleatória gerada tem formato de UUID v4', () {
      final keys = PixKeysProvider()..resetForNewAccount();
      keys.addRandomKey();
      final value = keys.keys.single.value;
      expect(PixKeyType.random.normalize(value), value);
    });

    test('toJson e restore preservam as chaves', () {
      final original = PixKeysProvider()..loadDemoData();
      final decoded = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final copy = PixKeysProvider()..restore(decoded);
      expect(copy.keys.map((k) => k.value), original.keys.map((k) => k.value));
      expect(copy.keys.map((k) => k.type), original.keys.map((k) => k.type));
    });
  });
}
