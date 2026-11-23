import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/card_provider.dart';
import '../providers/pix_keys_provider.dart';
import '../providers/savings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/wallet_provider.dart';
import 'local_store.dart';

/// Liga a conta logada aos dados do app:
///  - ao entrar numa conta, carrega os dados salvos dela nos providers
///    (conta sem dados salvos começa do zero);
///  - a cada mudança nos providers, salva tudo no disco (com um pequeno
///    atraso para agrupar várias mudanças seguidas);
///  - ao sair, salva a conta que estava aberta.
///
/// Cada conta tem o seu próprio bloco de dados (`data.<id da conta>`).
class AccountDataCoordinator with WidgetsBindingObserver {
  final LocalStore store;
  final AuthProvider auth;
  final UserProvider user;
  final WalletProvider wallet;
  final SavingsProvider savings;
  final PixKeysProvider pixKeys;
  final CardProvider card;

  String? _loadedId;
  bool _busy = false;
  Timer? _debounce;

  AccountDataCoordinator({
    required this.store,
    required this.auth,
    required this.user,
    required this.wallet,
    required this.savings,
    required this.pixKeys,
    required this.card,
  }) {
    auth.addListener(_onAuthChanged);
    // O cartão acompanha o perfil (nome e nível). Antes isso era feito dentro
    // do build do Dashboard, o que notificava ouvintes durante o build.
    user.addListener(_syncCard);
    final List<ChangeNotifier> watched = [user, wallet, savings, pixKeys];
    for (final provider in watched) {
      provider.addListener(_scheduleSave);
    }
    _onAuthChanged(); // sessão restaurada do disco
  }

  String _dataKey(String id) => 'data.$id';

  void _syncCard() {
    card.updateHolderName(user.name);
    card.syncTier(user.tier);
  }

  /// Registra o salvamento imediato quando o app vai para segundo plano
  /// (sem isso, a última alteração feita nos 300 ms antes de fechar o app
  /// podia se perder). Chame uma vez, depois de `ensureInitialized`.
  void attachLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Salva agora, sem esperar o atraso do salvamento automático.
  void flush() {
    final id = _loadedId;
    if (id == null) return;
    _debounce?.cancel();
    _saveNow(id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      flush();
    }
  }

  void _onAuthChanged() {
    final account = auth.currentAccount;
    if (account?.id == _loadedId) return;

    _debounce?.cancel();
    final previous = _loadedId;
    if (previous != null) _saveNow(previous); // conta que está saindo
    _loadedId = null;

    if (account == null) {
      // Não deixa os dados de quem saiu aparecerem para o próximo usuário.
      wallet.clearSession();
      savings.clearSession();
      pixKeys.clearSession();
      user.clearSession();
      return;
    }
    _load(account);
    _loadedId = account.id;
    // No modo banco, busca tudo do servidor.
    wallet.refreshFromServer();
    savings.refreshFromServer();
    pixKeys.refreshFromServer();
    user.refreshFromServer();
  }

  void _load(Account account) {
    _busy = true;
    try {
      var restored = false;
      final raw = store.getString(_dataKey(account.id));
      if (raw != null) {
        try {
          final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          user.restore(Map<String, dynamic>.from(data['user'] as Map? ?? {}));
          wallet.restore(Map<String, dynamic>.from(data['wallet'] as Map? ?? {}));
          savings.restore(Map<String, dynamic>.from(data['savings'] as Map? ?? {}));
          pixKeys.restore(Map<String, dynamic>.from(data['pixKeys'] as Map? ?? {}));
          restored = true;
        } catch (_) {
          restored = false; // dado corrompido: cai no caso "sem dados"
        }
      }

      if (!restored) {
        user.startNewProfile(account.name);
        wallet.resetForNewAccount();
        savings.resetForNewAccount();
        pixKeys.resetForNewAccount();
      }

      // O cartão é derivado do perfil (nome e nível).
      card.updateHolderName(user.name);
      card.syncTier(user.tier);
    } finally {
      _busy = false;
    }
  }

  void _scheduleSave() {
    final id = _loadedId;
    if (_busy || id == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _saveNow(id));
  }

  void _saveNow(String id) {
    store.setString(
      _dataKey(id),
      jsonEncode({
        'version': 1,
        'user': user.toJson(),
        'wallet': wallet.toJson(),
        'savings': savings.toJson(),
        'pixKeys': pixKeys.toJson(),
      }),
    );
  }
}
