import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/models/transaction.dart';
import 'package:s3_bank/providers/wallet_provider.dart';

void main() {
  group('sendPix', () {
    test('debita o saldo e registra a transação', () {
      final wallet = WalletProvider(initialBalance: 100);
      expect(wallet.sendPix(30, recipient: 'Loja'), isTrue);
      expect(wallet.balance, 70);
      expect(wallet.transactions.first.type, TransactionType.pixSent);
      expect(wallet.transactions.first.subtitle, 'Loja');
    });

    test('recusa valor maior que o saldo', () {
      final wallet = WalletProvider(initialBalance: 50);
      expect(wallet.sendPix(50.01, recipient: 'Loja'), isFalse);
      expect(wallet.balance, 50);
    });

    test('recusa valor zero ou negativo', () {
      final wallet = WalletProvider(initialBalance: 50);
      expect(wallet.sendPix(0, recipient: 'Loja'), isFalse);
      expect(wallet.sendPix(-10, recipient: 'Loja'), isFalse);
      expect(wallet.balance, 50);
    });

    test('não acumula erro de ponto flutuante nos centavos', () {
      final wallet = WalletProvider(initialBalance: 3482.17);
      wallet.sendPix(68.9, recipient: 'Mercado');
      expect(wallet.balance, 3413.27);
    });
  });

  group('receivePix', () {
    test('credita o saldo', () {
      final wallet = WalletProvider(initialBalance: 10);
      expect(wallet.receivePix(5.5, sender: 'João'), isTrue);
      expect(wallet.balance, 15.5);
      expect(wallet.transactions.first.isCredit, isTrue);
    });

    test('valor negativo não debita o saldo', () {
      final wallet = WalletProvider(initialBalance: 10);
      expect(wallet.receivePix(-5, sender: 'João'), isFalse);
      expect(wallet.balance, 10);
    });
  });

  group('conta nova e persistência', () {
    test('resetForNewAccount zera saldo e extrato', () {
      final wallet = WalletProvider()..resetForNewAccount();
      expect(wallet.balance, 0);
      expect(wallet.transactions, isEmpty);
    });

    test('toJson e restore preservam saldo e extrato', () {
      final original = WalletProvider(initialBalance: 200)
        ..sendPix(20.5, recipient: 'Padaria')
        ..receivePix(100, sender: 'Ana');

      // Passa por JSON de verdade, como acontece ao salvar no disco.
      final decoded = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final copy = WalletProvider()..restore(decoded);

      expect(copy.balance, original.balance);
      expect(copy.transactions.length, original.transactions.length);
      expect(copy.transactions.first.title, 'Pix recebido');
      expect(copy.transactions.first.amount, 100);
    });
  });
}
