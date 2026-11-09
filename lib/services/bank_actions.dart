import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/pix_keys_provider.dart';
import 'account_data_coordinator.dart';
import 'bank_service.dart';

/// Ações do usuário que mexem no servidor. Cada método devolve uma
/// mensagem de erro (para mostrar na tela) ou `null` se deu certo; em
/// caso de sucesso, os dados são recarregados do servidor.
class BankActions {
  final BankService service;
  final AccountDataCoordinator coordinator;
  final AuthProvider auth;

  BankActions({
    required this.service,
    required this.coordinator,
    required this.auth,
  });

  static const _genericError = 'Não foi possível concluir. Tente novamente.';

  Future<String?> _run(Future<void> Function(String uid) op) async {
    final uid = auth.currentAccount?.id;
    if (uid == null) return 'Sessão expirada. Entre novamente.';
    try {
      await op(uid);
    } on PostgrestException catch (e) {
      debugPrint('Supabase: ${e.code} ${e.message}');
      // P0001 = erro levantado pelas funções do banco (mensagens já em
      // português, como "Saldo insuficiente").
      if (e.code == 'P0001') return e.message;
      if (e.code == '23505') return 'Essa chave já está cadastrada.';
      return _genericError;
    } catch (e) {
      debugPrint('Falha de rede: $e');
      return 'Sem conexão com o servidor. Tente novamente.';
    }
    await coordinator.refresh();
    return null;
  }

  Future<String?> sendPix(double amount, String recipient) =>
      _run((_) => service.enviarPix(amount, recipient));

  /// "Simular pagamento" da cobrança: credita o valor na conta.
  Future<String?> receivePix(double amount, String sender) =>
      _run((_) => service.receberPix(amount, sender));

  Future<String?> deposit(String goalId, double amount) =>
      _run((_) => service.depositarCaixinha(goalId, amount));

  Future<String?> withdraw(String goalId, double amount) =>
      _run((_) => service.resgatarCaixinha(goalId, amount));

  Future<String?> createGoal({
    required String name,
    required int iconIndex,
    required double targetAmount,
  }) =>
      _run((uid) => service.criarCaixinha(
            uid: uid,
            nome: name,
            iconIndex: iconIndex,
            valorMeta: targetAmount,
          ));

  /// `value` já deve estar normalizado (veja `PixKeyTypeX.normalize`).
  Future<String?> addPixKey(PixKeyType type, String value) => _run((uid) =>
      service.adicionarChavePix(uid: uid, tipo: type, valor: value));

  Future<String?> addRandomPixKey() => addPixKey(
        PixKeyType.random,
        PixKeysProvider.newRandomKeyValue(),
      );

  Future<String?> removePixKey(String id) =>
      _run((_) => service.removerChavePix(id));
}
