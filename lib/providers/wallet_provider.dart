import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Arredonda para centavos. Somar/subtrair `double` acumula erro
/// (3482.17 - 68.9 vira 3413.2700000000004), e isso pode fazer
/// comparações de saldo falharem por uma fração de centavo.
double _round2(double value) => (value * 100).round() / 100;

/// Gerencia o saldo da conta corrente e o histórico geral de transações
/// (Pix + movimentações de caixinhas refletidas na conta).
/// TODO(integração-backend): substituir por chamadas reais a uma API
/// de extrato/saldo (ex: GET /account/balance, GET /account/statement).
class WalletProvider extends ChangeNotifier {
  double _balance;
  bool _balanceVisible = true;
  int _idSeq = 0;
  final List<Transaction> _transactions;

  WalletProvider({double initialBalance = 3482.17})
      : _balance = _round2(initialBalance),
        _transactions = _seedTransactions();

  double get balance => _balance;
  bool get balanceVisible => _balanceVisible;
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  /// Zera a conta (saldo e extrato) para um cadastro novo, em vez de
  /// herdar os dados de exemplo da conta demo.
  void resetForNewAccount() {
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

  /// Dados de exemplo da conta de demonstração.
  void loadDemoData() {
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

  /// Usado pela área "Guardar Dinheiro" para debitar da conta corrente
  /// quando o usuário faz um aporte em uma caixinha.
  bool debitForSavings(double amount, {required String goalName}) {
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
  bool creditFromSavings(double amount, {required String goalName}) {
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