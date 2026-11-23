import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/format.dart';
import 'package:s3_bank/core/statement_filter.dart';
import 'package:s3_bank/models/transaction.dart';

Transaction tx({
  required String id,
  required TransactionType type,
  required double amount,
  required DateTime date,
  String? category,
}) =>
    Transaction(
      id: id,
      type: type,
      title: 'Teste',
      subtitle: 'Teste',
      amount: amount,
      date: date,
      category: category,
    );

void main() {
  final now = DateTime(2026, 11, 13, 12);
  final list = [
    tx(id: 'a', type: TransactionType.pixReceived, amount: 100, date: now.subtract(const Duration(days: 2))),
    tx(id: 'b', type: TransactionType.pixSent, amount: 40, date: now.subtract(const Duration(days: 1)), category: 'alimentacao'),
    tx(id: 'c', type: TransactionType.pixSent, amount: 60, date: now.subtract(const Duration(days: 20))),
    tx(id: 'd', type: TransactionType.savingsWithdraw, amount: 30, date: now.subtract(const Duration(days: 60))),
    tx(id: 'e', type: TransactionType.savingsDeposit, amount: 50, date: now.subtract(const Duration(days: 3)), category: 'poupanca'),
  ];

  group('filtro de entrada e saída', () {
    test('entradas incluem recebimentos e resgates', () {
      final r = filterTransactions(list, direction: StatementDirection.inflow, period: StatementPeriod.all, now: now);
      expect(r.map((t) => t.id), containsAll(['a', 'd']));
      expect(r.every((t) => t.isCredit), isTrue);
    });

    test('saídas incluem Pix enviado e depósitos em caixinha', () {
      final r = filterTransactions(list, direction: StatementDirection.outflow, period: StatementPeriod.all, now: now);
      expect(r.map((t) => t.id), containsAll(['b', 'c', 'e']));
      expect(r.any((t) => t.isCredit), isFalse);
    });
  });

  group('filtro de período', () {
    test('7 dias deixa de fora o que tem mais de uma semana', () {
      final r = filterTransactions(list, direction: StatementDirection.all, period: StatementPeriod.days7, now: now);
      expect(r.map((t) => t.id), containsAll(['a', 'b', 'e']));
      expect(r.map((t) => t.id), isNot(contains('c')));
      expect(r.map((t) => t.id), isNot(contains('d')));
    });

    test('30 dias inclui o de 20 dias e exclui o de 60', () {
      final r = filterTransactions(list, direction: StatementDirection.all, period: StatementPeriod.days30, now: now);
      expect(r.map((t) => t.id), contains('c'));
      expect(r.map((t) => t.id), isNot(contains('d')));
    });

    test('tudo não filtra por data', () {
      final r = filterTransactions(list, direction: StatementDirection.all, period: StatementPeriod.all, now: now);
      expect(r.length, list.length);
    });

    test('direção e período combinam', () {
      final r = filterTransactions(list, direction: StatementDirection.outflow, period: StatementPeriod.days7, now: now);
      expect(r.map((t) => t.id), unorderedEquals(['b', 'e']));
    });
  });

  group('gráfico de saídas por categoria', () {
    test('soma só as saídas, por categoria, do maior para o menor', () {
      final totals = outflowByCategory(list);
      expect(totals.map((t) => t.label), ['Sem categoria', 'Poupança', 'Alimentação']);
      expect(totals.first.amount, 60);
      expect(totals.last.amount, 40);
    });

    test('entradas nunca entram no gráfico', () {
      final totals = outflowByCategory(list);
      final soma = totals.fold<double>(0, (s, t) => s + t.amount);
      expect(soma, 150); // 40 + 60 + 50, sem as entradas de 100 e 30
    });

    test('lista vazia não quebra', () {
      expect(outflowByCategory([]), isEmpty);
    });
  });

  group('formatação de valor', () {
    test('padrão brasileiro com separador de milhar', () {
      expect(brl(1234.5), 'R\$ 1.234,50');
      expect(brl(0), 'R\$ 0,00');
      expect(brl(1000000), 'R\$ 1.000.000,00');
    });

    test('valores negativos mostram o sinal antes do R\$', () {
      expect(brl(-12.3), '-R\$ 12,30');
    });
  });

  test('categoria desconhecida cai em "Sem categoria"', () {
    final t = tx(id: 'x', type: TransactionType.pixSent, amount: 1, date: now, category: 'inexistente');
    expect(categoryLabel(t), kSemCategoria);
  });
}
