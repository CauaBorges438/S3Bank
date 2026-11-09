import 'package:flutter/foundation.dart';

import '../providers/auth_provider.dart';
import '../providers/card_provider.dart';
import '../providers/pix_keys_provider.dart';
import '../providers/savings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/wallet_provider.dart';
import 'bank_service.dart';

/// Liga a conta logada aos dados do app. O servidor (Supabase) é a
/// fonte da verdade:
///  - ao entrar numa conta, busca perfil, saldo, extrato, caixinhas,
///    chaves Pix e cartão e entrega aos providers;
///  - ao sair, limpa os providers (nada da conta anterior fica na tela);
///  - [refresh] busca tudo de novo (chamado depois de cada operação).
class AccountDataCoordinator {
  final BankService service;
  final AuthProvider auth;
  final UserProvider user;
  final WalletProvider wallet;
  final SavingsProvider savings;
  final PixKeysProvider pixKeys;
  final CardProvider card;

  String? _loadedId;
  int _seq = 0;

  AccountDataCoordinator({
    required this.service,
    required this.auth,
    required this.user,
    required this.wallet,
    required this.savings,
    required this.pixKeys,
    required this.card,
  }) {
    auth.addListener(_onAuthChanged);
    _onAuthChanged(); // sessão restaurada
  }

  void _onAuthChanged() {
    final account = auth.currentAccount;
    if (account?.id == _loadedId) return;

    _seq++; // invalida qualquer busca em andamento
    _loadedId = account?.id;

    // Limpa antes de buscar: não mostra dados da conta anterior nem os
    // valores de exemplo dos providers enquanto a rede responde.
    user.startNewProfile(account?.name ?? '');
    wallet.resetForNewAccount();
    savings.resetForNewAccount();
    pixKeys.resetForNewAccount();

    if (account != null) refresh();
  }

  /// Busca tudo no servidor. Retorna uma mensagem de erro ou `null`.
  Future<String?> refresh() async {
    final account = auth.currentAccount;
    if (account == null) return 'Sessão expirada';
    final seq = ++_seq;

    try {
      final snap = await service.load(account.id);
      // Trocou de conta (ou outra busca mais nova começou) durante a espera.
      if (seq != _seq || auth.currentAccount?.id != account.id) return null;

      user.restore(snap.user);
      wallet.restore({
        'balance': snap.balance,
        'balanceVisible': wallet.balanceVisible, // preferência local
        'transactions': snap.transactions,
      });
      savings.restore(snap.savings);
      pixKeys.restore(snap.pixKeys);

      final c = snap.card;
      if (c != null) {
        card.applyDetails(
          holderName: c['holderName']!,
          cardNumber: c['cardNumber']!,
          expiry: c['expiry']!,
          cvv: c['cvv']!,
        );
      }
      card.syncTier(user.tier);
      return null;
    } catch (e) {
      debugPrint('Falha ao carregar do Supabase: $e');
      return 'Não foi possível carregar seus dados. Verifique a conexão.';
    }
  }
}
