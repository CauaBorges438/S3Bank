import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/providers/pix_keys_provider.dart';
import 'package:s3_bank/providers/savings_provider.dart';
import 'package:s3_bank/providers/user_provider.dart';
import 'package:s3_bank/providers/wallet_provider.dart';
import 'package:s3_bank/services/ledger_repository.dart';

// Regressão: ao ligar ao banco, os dados de exemplo não podem aparecer.
// Antes, a chave de exemplo bloqueava o cadastro com "Chave já cadastrada"
// e o saldo de exemplo aparecia até o servidor responder.
void main() {
  test('modo banco: carteira começa zerada, sem saldo de exemplo', () {
    final wallet = WalletProvider();
    expect(wallet.balance, greaterThan(0)); // exemplo no modo local

    wallet.attachLedger(LedgerRepository());

    expect(wallet.isServerBacked, isTrue);
    expect(wallet.balance, 0);
    expect(wallet.transactions, isEmpty);
  });

  test('modo banco: não há chaves Pix de exemplo bloqueando o cadastro', () {
    final keys = PixKeysProvider();
    expect(keys.keys, isNotEmpty); // exemplo no modo local

    keys.attachLedger(LedgerRepository());

    expect(keys.isServerBacked, isTrue);
    expect(keys.keys, isEmpty);
    expect(keys.validateInput(PixKeyType.email, 'rafaela@email.com'), isNull);
  });

  test('modo banco: o aparelho não soma pontos de constância', () {
    final user = UserProvider(initialPoints: 0);
    user.attachLedger(LedgerRepository());

    user.registerDeposit(100);

    expect(user.isServerBacked, isTrue);
    expect(user.consistencyPoints, 0);
  });

  test('modo banco: não há caixinhas de exemplo', () {
    final savings = SavingsProvider();
    expect(savings.goals, isNotEmpty); // exemplo no modo local

    savings.attachLedger(LedgerRepository());

    expect(savings.isServerBacked, isTrue);
    expect(savings.goals, isEmpty);
  });
}
