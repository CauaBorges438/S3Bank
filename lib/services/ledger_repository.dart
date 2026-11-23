import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card_summary.dart';
import '../models/transaction.dart';

/// Erro com mensagem já pronta para o usuário.
class LedgerException implements Exception {
  final String message;
  const LedgerException(this.message);

  @override
  String toString() => message;
}

/// Cobrança criada: txid e chave para montar o QR Code.
class ChargeCreated {
  final String txid;
  final String pixKey;
  final DateTime expiresAt;

  const ChargeCreated({
    required this.txid,
    required this.pixKey,
    required this.expiresAt,
  });
}

/// Acesso ao banco (Supabase).
///
/// Regras: saldos são lidos de views (somas do livro-razão) e nunca
/// editados. Toda escrita financeira passa por funções do banco, que
/// validam saldo e regras. As chaves Pix são gravadas na tabela `pix_keys`
/// (com RLS), que é a única escrita direta permitida.
class LedgerRepository {
  final SupabaseClient? _injected;

  LedgerRepository([this._injected]);

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  // ------------------------------------------------------------ saldo e extrato

  Future<int> fetchBalanceCents() => _run(() async {
        final row = await _client
            .from('account_balances')
            .select('balance_cents')
            .maybeSingle();
        return row == null ? 0 : (row['balance_cents'] as num).toInt();
      });

  Future<List<Transaction>> fetchStatement({int limit = 100}) => _run(() async {
        final rows = await _client
            .from('ledger_entries')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map((r) => toTransaction(Map<String, dynamic>.from(r))).toList();
      });

  /// Pix com PIN: `auth` é a autorização gerada por authorizeTransactionPin.
  Future<void> sendPix({
    required String keyValue,
    required int amountCents,
    required String auth,
    String? description,
  }) =>
      _run(() async {
        await _client.rpc('pix_transfer_pin', params: {
          'p_key_value': keyValue,
          'p_amount_cents': amountCents,
          'p_description': description,
          'p_auth': auth,
        });
      });

  Future<void> simulateDeposit({required int amountCents, String? description}) =>
      _run(() async {
        await _client.rpc('simulate_deposit', params: {
          'p_amount_cents': amountCents,
          'p_description': description,
        });
      });

  // ------------------------------------------------------------ caixinhas

  /// Linhas da view savings_goal_balances: goal_id, name, target_cents,
  /// saved_cents, created_at.
  Future<List<Map<String, dynamic>>> fetchGoals() => _run(() async {
        final rows = await _client
            .from('savings_goal_balances')
            .select()
            .order('created_at', ascending: true);
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });

  Future<void> createGoal({required String name, required int targetCents}) =>
      _run(() async {
        await _client.rpc('create_savings_goal', params: {
          'p_name': name,
          'p_target_cents': targetCents,
        });
      });

  /// direction: 'in' guarda (sai da conta), 'out' resgata (volta para a conta).
  Future<void> moveSavings({
    required String goalId,
    required int amountCents,
    required String direction,
  }) =>
      _run(() async {
        await _client.rpc('savings_move', params: {
          'p_goal_id': goalId,
          'p_amount_cents': amountCents,
          'p_direction': direction,
        });
      });

  // ------------------------------------------------------------ chaves Pix

  Future<List<Map<String, dynamic>>> fetchPixKeys() => _run(() async {
        final rows = await _client
            .from('pix_keys')
            .select('id, key_type, key_value')
            .order('created_at', ascending: true);
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });

  /// Cadastro pela função `register_pix_key` (migração 0003).
  Future<void> insertPixKey({required String keyType, required String keyValue}) =>
      _run(() async {
        await _client.rpc('register_pix_key', params: {
          'p_key_type': keyType,
          'p_key_value': keyValue,
        });
      });

  Future<void> deletePixKey(String id) => _run(() async {
        await _client.from('pix_keys').delete().eq('id', id);
      });

  /// Progresso de gamificação da conta (nível, pontos, constância), ou null.
  Future<Map<String, dynamic>?> fetchProgress() => _run(() async {
        final row = await _client
            .from('user_progress')
            .select('tier, points, streak_months')
            .maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  // ------------------------------------------------------------ cobranças

  Future<ChargeCreated> createCharge({
    required int amountCents,
    String? description,
    int expiresMinutes = 30,
  }) =>
      _run(() async {
        final rows = (await _client.rpc('create_charge', params: {
          'p_amount_cents': amountCents,
          'p_description': description,
          'p_expires_minutes': expiresMinutes,
        })) as List;
        final row = Map<String, dynamic>.from(rows.first as Map);
        return ChargeCreated(
          txid: row['charge_txid'] as String,
          pixKey: row['charge_pix_key'] as String,
          expiresAt: DateTime.parse(row['charge_expires_at'] as String),
        );
      });

  Future<Map<String, dynamic>> getCharge(String txid) => _run(() async {
        final rows = (await _client.rpc('get_charge', params: {'p_txid': txid})) as List;
        return Map<String, dynamic>.from(rows.first as Map);
      });

  /// Paga a cobrança. Devolve o valor pago em centavos.
  Future<int> payCharge(String txid, String auth) => _run(() async {
        final result = await _client.rpc('pay_charge_pin', params: {
          'p_txid': txid,
          'p_auth': auth,
        });
        return (result as num).toInt();
      });

  // ------------------------------------------------------------ categorias

  /// Categorias já escolhidas: id da movimentação -> categoria.
  Future<Map<String, String>> fetchCategories() => _run(() async {
        final rows = await _client
            .from('transaction_categories')
            .select('ledger_entry_id, category');
        return {
          for (final r in rows) r['ledger_entry_id'] as String: r['category'] as String,
        };
      });

  Future<void> setCategory(String ledgerEntryId, String category) => _run(() async {
        await _client.rpc('set_transaction_category', params: {
          'p_ledger_entry_id': ledgerEntryId,
          'p_category': category,
        });
      });

  // ------------------------------------------------------------ saídas e boletos

  /// Limite diário e quanto já foi usado hoje (fuso de São Paulo).
  Future<({int limitCents, int usedCents})> fetchMoneyOutSummary() => _run(() async {
        final rows = (await _client.rpc('get_money_out_summary')) as List;
        final row = Map<String, dynamic>.from(rows.first as Map);
        return (
          limitCents: (row['limit_cents'] as num).toInt(),
          usedCents: (row['used_cents'] as num).toInt(),
        );
      });

  Future<void> withdrawToBank({
    required int amountCents,
    required String bank,
    required String auth,
    String? accountInfo,
  }) =>
      _run(() async {
        await _client.rpc('withdraw_to_bank_pin', params: {
          'p_amount_cents': amountCents,
          'p_bank': bank,
          'p_account_info': accountInfo,
          'p_auth': auth,
        });
      });

  Future<({String code, DateTime due})> createBoleto({
    required int amountCents,
    String? description,
    int dueDays = 3,
  }) =>
      _run(() async {
        final rows = (await _client.rpc('create_boleto', params: {
          'p_amount_cents': amountCents,
          'p_description': description,
          'p_due_days': dueDays,
        })) as List;
        final row = Map<String, dynamic>.from(rows.first as Map);
        return (
          code: row['boleto_code'] as String,
          due: DateTime.parse(row['boleto_due'] as String),
        );
      });

  Future<Map<String, dynamic>> getBoleto(String code) => _run(() async {
        final rows = (await _client.rpc('get_boleto', params: {'p_code': code})) as List;
        return Map<String, dynamic>.from(rows.first as Map);
      });

  Future<int> payBoleto(String code, String auth) => _run(() async {
        final result = await _client.rpc('pay_boleto_pin', params: {
          'p_code': code,
          'p_auth': auth,
        });
        return (result as num).toInt();
      });

  // ------------------------------------------------------------ perfil

  /// Dados do próprio perfil (nome, CPF, celular).
  Future<Map<String, dynamic>?> fetchProfile() => _run(() async {
        final uid = _client.auth.currentUser!.id;
        final row = await _client
            .from('profiles')
            .select('full_name, cpf, phone')
            .eq('id', uid)
            .maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  /// Só o nome pode ser alterado pelo app (RLS: só o próprio perfil).
  Future<void> updateFullName(String name) => _run(() async {
        final uid = _client.auth.currentUser!.id;
        await _client.from('profiles').update({'full_name': name}).eq('id', uid);
      });

  // ------------------------------------------------------------ cartão de crédito

  Future<CardSummary> fetchCardSummary() => _run(() async {
        final rows = (await _client.rpc('get_card_summary')) as List;
        return CardSummary.fromRow(Map<String, dynamic>.from(rows.first as Map));
      });

  /// Cria o cartão virtual. O CVV vem só nesta chamada.
  Future<({String number, String expiry, String cvv})> createVirtualCard() => _run(() async {
        final rows = (await _client.rpc('create_virtual_card')) as List;
        final row = Map<String, dynamic>.from(rows.first as Map);
        return (
          number: row['card_number'] as String,
          expiry: row['card_expiry'] as String,
          cvv: row['card_cvv'] as String,
        );
      });

  Future<void> makeCardPurchase({
    required String merchant,
    required int amountCents,
    required String category,
  }) =>
      _run(() async {
        await _client.rpc('make_card_purchase', params: {
          'p_merchant': merchant,
          'p_amount_cents': amountCents,
          'p_category': category,
        });
      });

  Future<List<CardPurchase>> fetchCardPurchases({int limit = 50}) => _run(() async {
        final rows = await _client
            .from('card_purchases')
            .select('id, merchant, category, amount_cents, purchased_at, paid_at')
            .order('purchased_at', ascending: false)
            .limit(limit);
        return rows.map((r) => CardPurchase.fromRow(Map<String, dynamic>.from(r))).toList();
      });

  /// Paga a fatura do mês informado (primeiro dia do mês).
  Future<int> payCardInvoice(DateTime month, String auth) => _run(() async {
        final first = DateTime(month.year, month.month, 1);
        final iso = '${first.year.toString().padLeft(4, '0')}-'
            '${first.month.toString().padLeft(2, '0')}-01';
        final result = await _client.rpc('pay_card_invoice_pin', params: {
          'p_month': iso,
          'p_auth': auth,
        });
        return (result as num).toInt();
      });

  // ------------------------------------------------------------ PIN de transação

  Future<bool> hasTransactionPin() => _run(() async {
        final r = await _client.rpc('has_transaction_pin');
        return r == true;
      });

  /// Cria o PIN, ou troca o atual (nesse caso, `current` é obrigatório).
  Future<void> setTransactionPin(String pin, {String? current}) => _run(() async {
        await _client.rpc('set_transaction_pin', params: {
          'p_pin': pin,
          'p_current_pin': current,
        });
      });

  /// Devolve a autorização de uso único, ou null se o PIN estiver errado.
  Future<String?> authorizeTransactionPin(String pin) => _run(() async {
        final r = await _client.rpc('authorize_transaction_pin', params: {'p_pin': pin});
        return r as String?;
      });

  // ------------------------------------------------------------ mapeamento

  /// Converte uma linha de `ledger_entries` no modelo que as telas usam.
  /// Amount sempre positivo; o tipo define se é entrada ou saída.
  static Transaction toTransaction(Map<String, dynamic> row) {
    final kind = row['kind'] as String;
    final cents = (row['amount_cents'] as num).toInt();
    final description = (row['description'] as String?)?.trim() ?? '';
    final date = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

    TransactionType type;
    String title;
    switch (kind) {
      case 'pix_in':
        type = TransactionType.pixReceived;
        title = 'Pix recebido';
      case 'pix_out':
        type = TransactionType.pixSent;
        title = 'Pix enviado';
      case 'deposit':
        type = TransactionType.pixReceived;
        title = 'Depósito';
      case 'transfer_in':
        type = TransactionType.pixReceived;
        title = 'Transferência recebida';
      case 'transfer_out':
        type = TransactionType.pixSent;
        title = 'Transferência enviada';
      case 'withdrawal':
        type = TransactionType.pixSent;
        title = 'Transferência para outro banco';
      case 'boleto_out':
        type = TransactionType.pixSent;
        title = 'Boleto pago';
      case 'boleto_in':
        type = TransactionType.pixReceived;
        title = 'Boleto recebido';
      case 'card_payment':
        type = TransactionType.pixSent;
        title = 'Pagamento da fatura do cartão';
      case 'fee':
        type = TransactionType.pixSent;
        title = 'Tarifa';
      case 'savings_in':
        type = TransactionType.savingsDeposit;
        title = 'Guardado em caixinha';
      case 'savings_out':
        type = TransactionType.savingsWithdraw;
        title = 'Resgatado da caixinha';
      default:
        type = cents >= 0 ? TransactionType.pixReceived : TransactionType.pixSent;
        title = 'Ajuste';
    }

    return Transaction(
      id: row['id'] as String,
      type: type,
      title: title,
      subtitle: description.isEmpty ? title : description,
      amount: cents.abs() / 100,
      date: date,
    );
  }

  // ------------------------------------------------------------ erros

  /// Executa uma operação do banco e traduz erros para o usuário.
  Future<T> _run<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      // Aparece no console (flutter run) para diagnosticar a causa real.
      debugPrint('[banco] ${e.code}: ${e.message} ${e.details ?? ''}');
      throw LedgerException(_friendly(e.message));
    } catch (e) {
      debugPrint('[banco] erro de conexão: $e');
      throw const LedgerException('Sem conexão com o servidor. Tente de novo');
    }
  }

  static String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('saldo insuficiente')) return 'Saldo insuficiente';
    if (m.contains('chave pix não encontrada')) return 'Chave Pix não encontrada';
    if (m.contains('própria conta')) return 'Não é possível enviar para a própria conta';
    if (m.contains('valor inválido')) return 'Valor inválido';
    if (m.contains('valor maior que o guardado')) return 'Valor maior que o guardado';
    if (m.contains('caixinha não encontrada')) return 'Caixinha não encontrada';
    if (m.contains('nome inválido')) return 'Informe um nome para a caixinha';
    if (m.contains('conta não encontrada')) return 'Conta não encontrada';
    // Chave duplicada ou de outra pessoa: mensagem genérica, para não
    // revelar se uma chave existe em outra conta.
    if (m.contains('chave já em uso') || m.contains('duplicate key')) {
      return 'Esta chave já está em uso';
    }
    if (m.contains('tipo inválido')) return 'Tipo de chave inválido';
    if (m.contains('categoria inválida')) return 'Categoria inválida';
    if (m.contains('só é possível categorizar saídas')) return 'Só dá para categorizar saídas';
    if (m.contains('lançamento não encontrado')) return 'Movimentação não encontrada';
    if (m.contains('cobrança já foi paga')) return 'Esta cobrança já foi paga';
    if (m.contains('cobrança expirada')) return 'Esta cobrança expirou';
    if (m.contains('cobrança indisponível')) return 'Cobrança indisponível';
    if (m.contains('cobrança não encontrada')) return 'Cobrança não encontrada';
    if (m.contains('própria cobrança')) return 'Você não pode pagar a sua própria cobrança';
    if (m.contains('cadastre uma chave pix')) return 'Cadastre uma chave Pix antes de cobrar';
    if (m.contains('limite diário de saídas atingido')) {
      return r'Você atingiu o limite diário de saídas (R$ 5.000,00)';
    }
    if (m.contains('boleto não encontrado')) return 'Boleto não encontrado';
    if (m.contains('boleto já foi pago')) return 'Este boleto já foi pago';
    if (m.contains('boleto vencido')) return 'Este boleto está vencido';
    if (m.contains('boleto indisponível')) return 'Boleto indisponível';
    if (m.contains('próprio boleto')) return 'Você não pode pagar o seu próprio boleto';
    if (m.contains('informe o banco de destino')) return 'Informe o banco de destino';
    if (m.contains('prazo inválido')) return 'Prazo inválido';
    if (m.contains('cartão já criado')) return 'Você já tem um cartão virtual';
    if (m.contains('crie seu cartão virtual')) return 'Crie seu cartão virtual antes de comprar';
    if (m.contains('limite do cartão insuficiente')) {
      return 'Limite do cartão insuficiente para esta compra';
    }
    if (m.contains('não há nada a pagar')) return 'Não há nada a pagar nesta fatura';
    if (m.contains('informe onde foi a compra')) return 'Informe onde foi a compra';
    if (m.contains('confirmação de pin')) return 'A confirmação do PIN expirou. Tente de novo';
    if (m.contains('pin bloqueado')) return 'PIN bloqueado por tentativas erradas. Tente em 15 minutos';
    if (m.contains('crie seu pin')) return 'Crie seu PIN de transação antes de continuar';
    if (m.contains('o pin precisa ter 6 números')) return 'O PIN precisa ter 6 números';
    if (m.contains('pin atual incorreto')) return 'PIN atual incorreto';
    if (m.contains('could not find the function') || m.contains('schema cache')) {
      return 'Banco desatualizado: execute a migração 0003 no Supabase';
    }
    if (m.contains('row-level security')) {
      return 'Não foi possível cadastrar esta chave';
    }
    return 'Não foi possível concluir a operação';
  }
}
