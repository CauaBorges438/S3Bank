import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/ledger_repository.dart';

/// Arredonda para centavos. Somar/subtrair `double` acumula erro
/// (3482.17 - 68.9 vira 3413.2700000000004), e isso pode fazer
/// comparações de saldo falharem por uma fração de centavo.
double _round2(double value) => (value * 100).round() / 100;

/// Saldo da conta corrente e extrato.
///
/// Dois modos:
///  - **Banco** (após [attachLedger]): saldo e extrato vêm do Supabase.
///    Pix e depósitos passam pelas funções do banco ([payPix] e
///    [receiveSimulatedPix]). Guardar Dinheiro fica desativado neste modo.
///  - **Local** (sem banco): mantém os dados em memória e no disco, como
///    antes. Usado pelos testes e pelo modo offline.
class WalletProvider extends ChangeNotifier {
  double _balance;
  bool _balanceVisible = true;
  int _idSeq = 0;
  final List<Transaction> _transactions;
  LedgerRepository? _ledger;
  String? _syncError;

  WalletProvider({double initialBalance = 3482.17})
      : _balance = _round2(initialBalance),
        _transactions = _seedTransactions();

  double get balance => _balance;
  bool get balanceVisible => _balanceVisible;
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  bool get isServerBacked => _ledger != null;
  String? get syncError => _syncError;

  /// Liga a carteira ao banco. Chame depois do Supabase inicializado.
  void attachLedger(LedgerRepository ledger) {
    _ledger = ledger;
    // Descarta o saldo e o extrato de exemplo: no modo banco, só vale o servidor.
    _balance = 0;
    _transactions.clear();
  }

  /// Busca saldo e extrato no banco. Sem efeito no modo local.
  Future<void> refreshFromServer() async {
    final ledger = _ledger;
    if (ledger == null) return;
    try {
      final cents = await ledger.fetchBalanceCents();
      final statement = await ledger.fetchStatement();
      final categories = await ledger.fetchCategories();
      _balance = _round2(cents / 100);
      _transactions
        ..clear()
        ..addAll(statement.map((t) => t.copyWith(category: categories[t.id])));
      _syncError = null;
    } on LedgerException catch (e) {
      _syncError = e.message;
    } catch (_) {
      _syncError = 'Não foi possível atualizar o saldo';
    }
    notifyListeners();
  }

  /// Cria uma cobrança com valor e validade (só no modo banco).
  Future<ChargeCreated> createCharge({required double amount, String? description}) {
    final ledger = _ledger;
    if (ledger == null) {
      throw const LedgerException('Cobranças exigem conexão com o banco');
    }
    return ledger.createCharge(
      amountCents: (_round2(amount) * 100).round(),
      description: description,
    );
  }

  /// Dados de uma cobrança antes de pagar. Só no modo banco.
  Future<Map<String, dynamic>> getCharge(String txid) {
    final ledger = _ledger;
    if (ledger == null) {
      throw const LedgerException('Cobranças exigem conexão com o banco');
    }
    return ledger.getCharge(txid);
  }

  /// Paga uma cobrança. Retorna null em sucesso ou a mensagem de erro.
  Future<String?> payCharge(String txid, String auth) async {
    final ledger = _ledger;
    if (ledger == null) return 'Indisponível no momento';
    try {
      await ledger.payCharge(txid, auth);
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  /// Transferência para outro banco (simulada). Retorna null ou o erro.
  Future<String?> withdrawToBank(
    double amount, {
    required String bank,
    required String auth,
    String? accountInfo,
  }) async {
    final ledger = _ledger;
    if (ledger == null) return 'Disponível só com conexão com o banco';
    final cents = (_round2(amount) * 100).round();
    if (cents <= 0) return 'Valor inválido';
    try {
      await ledger.withdrawToBank(
        amountCents: cents,
        bank: bank,
        auth: auth,
        accountInfo: accountInfo,
      );
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  Future<({int limitCents, int usedCents})> moneyOutSummary() {
    final ledger = _ledger;
    if (ledger == null) {
      throw const LedgerException('Disponível só com conexão com o banco');
    }
    return ledger.fetchMoneyOutSummary();
  }

  /// Emite um boleto para receber. Lança LedgerException se falhar.
  Future<({String code, DateTime due})> createBoleto(double amount, {String? description}) {
    final ledger = _ledger;
    if (ledger == null) {
      throw const LedgerException('Disponível só com conexão com o banco');
    }
    return ledger.createBoleto(
      amountCents: (_round2(amount) * 100).round(),
      description: description,
    );
  }

  Future<Map<String, dynamic>> getBoleto(String code) {
    final ledger = _ledger;
    if (ledger == null) {
      throw const LedgerException('Disponível só com conexão com o banco');
    }
    return ledger.getBoleto(code);
  }

  /// Paga um boleto. Retorna null em sucesso ou o erro.
  Future<String?> payBoleto(String code, String auth) async {
    final ledger = _ledger;
    if (ledger == null) return 'Disponível só com conexão com o banco';
    try {
      await ledger.payBoleto(code, auth);
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  /// Marca a categoria de uma saída. No modo banco, grava no servidor.
  /// Retorna null em sucesso ou a mensagem de erro.
  Future<String?> setCategory(String transactionId, String category) async {
    final ledger = _ledger;
    if (ledger != null) {
      try {
        await ledger.setCategory(transactionId, category);
      } on LedgerException catch (e) {
        return e.message;
      }
    }
    final i = _transactions.indexWhere((t) => t.id == transactionId);
    if (i >= 0) {
      _transactions[i] = _transactions[i].copyWith(category: category);
      notifyListeners();
    }
    return null;
  }

  /// Esvazia a carteira quando alguém sai, para os dados não aparecerem
  /// para o próximo usuário.
  void clearSession() {
    _balance = 0;
    _transactions.clear();
    notifyListeners();
  }

  /// Zera a conta (saldo e extrato) para um cadastro novo, em vez de
  /// herdar os dados de exemplo da conta demo. No modo banco o estado
  /// vem do servidor, então não faz nada.
  void resetForNewAccount() {
    if (_ledger != null) return;
    _balance = 0;
    _transactions.clear();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'balance': _balance,
        'balanceVisible': _balanceVisible,
        'transactions': _transactions.map((t) => t.toJson()).toList(),
      };

  void restore(Map<String, dynamic> json) {
    _balance = _round2((json['balance'] as num?)?.toDouble() ?? 0);
    _balanceVisible = json['balanceVisible'] as bool? ?? true;
    final list = (json['transactions'] as List?) ?? const [];
    _transactions
      ..clear()
      ..addAll(list.map((e) => Transaction.fromJson(Map<String, dynamic>.from(e as Map))));
    notifyListeners();
  }

  /// Dados de exemplo da conta de demonstração (modo local).
  void loadDemoData() {
    if (_ledger != null) return;
    _balance = _round2(3482.17);
    _balanceVisible = true;
    _transactions
      ..clear()
      ..addAll(_seedTransactions());
    notifyListeners();
  }

  void toggleBalanceVisibility() {
    _balanceVisible = !_balanceVisible;
    notifyListeners();
  }

  /// Id único: o contador evita colisão se duas transações forem
  /// criadas no mesmo microssegundo.
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

  /// Pix no modo local (síncrono, usado pelos testes e pelo modo offline).
  bool sendPix(double amount, {required String recipient}) {
    final value = _round2(amount);
    if (value <= 0 || value > _balance) return false;
    _balance = _round2(_balance - value);
    _transactions.insert(
      0,
      Transaction(
        id: _newId(),
        type: TransactionType.pixSent,
        title: 'Pix enviado',
        subtitle: recipient,
        amount: value,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  /// Antes não validava o valor: um valor negativo debitava o saldo.
  bool receivePix(double amount, {required String sender}) {
    final value = _round2(amount);
    if (value <= 0) return false;
    _balance = _round2(_balance + value);
    _transactions.insert(
      0,
      Transaction(
        id: _newId(),
        type: TransactionType.pixReceived,
        title: 'Pix recebido',
        subtitle: sender,
        amount: value,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  /// Pix enviado. No modo banco, o servidor valida saldo e chave.
  /// Retorna null em sucesso, ou a mensagem de erro para mostrar.
  Future<String?> payPix(double amount, {required String recipient, required String auth}) async {
    final value = _round2(amount);
    if (value <= 0) return 'Valor inválido';
    final ledger = _ledger;
    if (ledger == null) {
      return sendPix(value, recipient: recipient) ? null : 'Não foi possível enviar o Pix.';
    }
    try {
      await ledger.sendPix(
        keyValue: recipient,
        amountCents: (value * 100).round(),
        auth: auth,
        description: recipient,
      );
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  /// Recebimento simulado (depósito de teste). Retorna null em sucesso.
  Future<String?> receiveSimulatedPix(double amount, {required String sender}) async {
    final value = _round2(amount);
    if (value <= 0) return 'Valor inválido';
    final ledger = _ledger;
    if (ledger == null) {
      return receivePix(value, sender: sender) ? null : 'Valor inválido';
    }
    try {
      await ledger.simulateDeposit(
        amountCents: (value * 100).round(),
        description: 'Pix recebido de $sender',
      );
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  /// Usado pela área "Guardar Dinheiro" para debitar da conta corrente.
  /// Desativado no modo banco até existir movimento de caixinha no servidor.
  bool debitForSavings(double amount, {required String goalName}) {
    if (_ledger != null) return false;
    final value = _round2(amount);
    if (value <= 0 || value > _balance) return false;
    _balance = _round2(_balance - value);
    _transactions.insert(
      0,
      Transaction(
        id: _newId(),
        type: TransactionType.savingsDeposit,
        title: 'Guardado em $goalName',
        subtitle: 'Guardar Dinheiro',
        amount: value,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  /// Usado quando o usuário resgata uma caixinha de volta para a conta.
  /// Desativado no modo banco (mesmo motivo de [debitForSavings]).
  bool creditFromSavings(double amount, {required String goalName}) {
    if (_ledger != null) return false;
    final value = _round2(amount);
    if (value <= 0) return false;
    _balance = _round2(_balance + value);
    _transactions.insert(
      0,
      Transaction(
        id: _newId(),
        type: TransactionType.savingsWithdraw,
        title: 'Resgatado de $goalName',
        subtitle: 'Guardar Dinheiro',
        amount: value,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  static List<Transaction> _seedTransactions() {
    final now = DateTime.now();
    return [
      Transaction(
        id: '1',
        type: TransactionType.pixReceived,
        title: 'Pix recebido',
        subtitle: 'João Pedro',
        amount: 250,
        date: now.subtract(const Duration(hours: 3)),
      ),
      Transaction(
        id: '2',
        type: TransactionType.savingsDeposit,
        title: 'Guardado em Reserva de Emergência',
        subtitle: 'Guardar Dinheiro',
        amount: 100,
        date: now.subtract(const Duration(days: 1)),
      ),
      Transaction(
        id: '3',
        type: TransactionType.pixSent,
        title: 'Pix enviado',
        subtitle: 'Mercado Bom Preço',
        amount: 68.9,
        date: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
