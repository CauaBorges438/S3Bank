import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/models/user_tier.dart';
import 'package:s3_bank/providers/auth_provider.dart';
import 'package:s3_bank/providers/card_provider.dart';
import 'package:s3_bank/providers/pix_keys_provider.dart';
import 'package:s3_bank/providers/savings_provider.dart';
import 'package:s3_bank/providers/user_provider.dart';
import 'package:s3_bank/providers/wallet_provider.dart';
import 'package:s3_bank/services/account_data_coordinator.dart';
import 'package:s3_bank/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monta o app "sem telas": providers + coordenador sobre o mesmo
/// armazenamento. Criar um [Env] de novo simula fechar e reabrir o app.
/// O login é feito com [AuthProvider.debugLogin], sem falar com o Supabase.
class Env {
  final AuthProvider auth;
  final UserProvider user;
  final WalletProvider wallet;
  final SavingsProvider savings;
  final PixKeysProvider pixKeys;
  final CardProvider card;
  final AccountDataCoordinator coordinator;

  Env._(this.auth, this.user, this.wallet, this.savings, this.pixKeys, this.card,
      this.coordinator);

  static Future<Env> open() async {
    final store = await LocalStore.create();
    final auth = AuthProvider(connect: false);
    final user = UserProvider();
    final wallet = WalletProvider();
    final savings = SavingsProvider();
    final pixKeys = PixKeysProvider();
    final card = CardProvider(holderName: 'Rafaela Souza', initialTier: UserTier.bronze);
    final coordinator = AccountDataCoordinator(
      store: store,
      auth: auth,
      user: user,
      wallet: wallet,
      savings: savings,
      pixKeys: pixKeys,
      card: card,
    );
    return Env._(auth, user, wallet, savings, pixKeys, card, coordinator);
  }
}

const anaAccount = Account(
  id: 'ana@email.com',
  name: 'Ana Teste',
  identifier: 'ana@email.com',
);

const mariaAccount = Account(
  id: 'maria@email.com',
  name: 'Maria Teste',
  identifier: 'maria@email.com',
);

/// Espera o salvamento automático (que tem um pequeno atraso).
Future<void> waitForSave() => Future.delayed(const Duration(milliseconds: 600));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('conta nova começa do zero e o cartão leva o nome dela', () async {
    final env = await Env.open();
    env.auth.debugLogin(mariaAccount);

    expect(env.user.name, 'Maria Teste');
    expect(env.user.tier, UserTier.bronze);
    expect(env.user.consistencyPoints, 0);
    expect(env.wallet.balance, 0);
    expect(env.wallet.transactions, isEmpty);
    expect(env.savings.goals, isEmpty);
    expect(env.pixKeys.keys, isEmpty);
    expect(env.card.card.holderName, 'Maria Teste');
  });

  test('os dados sobrevivem a fechar e reabrir o app', () async {
    final first = await Env.open();
    first.auth.debugLogin(anaAccount);
    first.wallet.receivePix(1000, sender: 'Teste'); // conta começa zerada
    first.wallet.sendPix(100, recipient: 'Padaria');
    first.savings.createGoal(
      name: 'Notebook',
      icon: Icons.school_outlined,
      targetAmount: 4000,
    );
    first.user.registerDeposit(500);
    await waitForSave();

    final reopened = await Env.open();
    reopened.auth.debugLogin(anaAccount); // "reabrir" = logar de novo na mesma conta
    expect(reopened.wallet.balance, 900);
    expect(reopened.wallet.transactions.first.subtitle, 'Padaria');
    expect(reopened.savings.goals.any((g) => g.name == 'Notebook'), isTrue);
    expect(reopened.user.consistencyPoints, first.user.consistencyPoints);
  });

  test('cada conta tem os seus próprios dados', () async {
    final env = await Env.open();

    env.auth.debugLogin(mariaAccount);
    env.wallet.receivePix(250, sender: 'Amigo');
    await waitForSave();
    env.auth.signOut();

    env.auth.debugLogin(anaAccount);
    expect(env.wallet.balance, 0); // nada da Maria vazou para a Ana

    env.auth.signOut();
    env.auth.debugLogin(mariaAccount);
    expect(env.wallet.balance, 250); // e a Maria recuperou o que era dela
    expect(env.user.name, 'Maria Teste');
  });

  test('sair salva as últimas mudanças mesmo antes do atraso do salvamento', () async {
    final env = await Env.open();
    env.auth.debugLogin(mariaAccount);
    env.wallet.receivePix(80, sender: 'Amigo');
    env.auth.signOut(); // sem esperar o atraso do salvamento

    env.auth.debugLogin(mariaAccount);
    expect(env.wallet.balance, 80);
  });
}
