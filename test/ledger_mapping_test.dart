import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/models/transaction.dart';
import 'package:s3_bank/services/ledger_repository.dart';

Map<String, dynamic> row({
  required String kind,
  required int cents,
  String? description,
}) =>
    {
      'id': 'abc',
      'kind': kind,
      'amount_cents': cents,
      'description': description,
      'created_at': '2026-11-12T10:00:00Z',
    };

void main() {
  group('LedgerRepository.toTransaction', () {
    test('pix_out vira saída com valor positivo em reais', () {
      final t = LedgerRepository.toTransaction(
        row(kind: 'pix_out', cents: -2500, description: 'Padaria'),
      );
      expect(t.type, TransactionType.pixSent);
      expect(t.title, 'Pix enviado');
      expect(t.subtitle, 'Padaria');
      expect(t.amount, 25.0);
    });

    test('pix_in vira entrada e é marcado como crédito', () {
      final t = LedgerRepository.toTransaction(row(kind: 'pix_in', cents: 1000));
      expect(t.type, TransactionType.pixReceived);
      expect(t.amount, 10.0);
      expect(t.isCredit, isTrue);
    });

    test('sem descrição, o subtítulo cai no título', () {
      final t = LedgerRepository.toTransaction(row(kind: 'deposit', cents: 5000));
      expect(t.subtitle, 'Depósito');
    });

    test('tipos desconhecidos seguem o sinal do valor', () {
      final entrada = LedgerRepository.toTransaction(row(kind: 'adjustment', cents: 100));
      final saida = LedgerRepository.toTransaction(row(kind: 'adjustment', cents: -100));
      expect(entrada.type, TransactionType.pixReceived);
      expect(saida.type, TransactionType.pixSent);
    });

    test('guardar em caixinha vira depósito em caixinha (saída da conta)', () {
      final t = LedgerRepository.toTransaction(row(kind: 'savings_in', cents: -4000));
      expect(t.type, TransactionType.savingsDeposit);
      expect(t.title, 'Guardado em caixinha');
      expect(t.amount, 40.0);
      expect(t.isCredit, isFalse);
    });

    test('resgatar da caixinha vira entrada na conta', () {
      final t = LedgerRepository.toTransaction(row(kind: 'savings_out', cents: 4000));
      expect(t.type, TransactionType.savingsWithdraw);
      expect(t.isCredit, isTrue);
    });
  });
}
