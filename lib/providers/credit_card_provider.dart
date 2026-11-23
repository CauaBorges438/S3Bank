import 'package:flutter/foundation.dart';

import '../models/card_summary.dart';
import '../services/ledger_repository.dart';

/// Estado do cartão de crédito. Vive enquanto a tela de cartão está aberta,
/// então os dados de uma conta não ficam na memória depois de sair.
class CreditCardProvider extends ChangeNotifier {
  final LedgerRepository _ledger;
  CardSummary? _summary;
  List<CardPurchase> _purchases = const [];
  String? _error;
  bool _disposed = false;

  CreditCardProvider(this._ledger);

  CardSummary? get summary => _summary;
  List<CardPurchase> get purchases => List.unmodifiable(_purchases);
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _summary = await _ledger.fetchCardSummary();
      _purchases = await _ledger.fetchCardPurchases();
      _error = null;
    } on LedgerException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Não foi possível carregar o cartão';
    }
    _notify();
  }

  /// Cria o cartão virtual. Lança LedgerException se já existir ou falhar.
  Future<({String number, String expiry, String cvv})> createVirtualCard() async {
    final card = await _ledger.createVirtualCard();
    await refresh();
    return card;
  }

  /// Retorna null em sucesso ou a mensagem de erro.
  Future<String?> purchase({
    required String merchant,
    required int amountCents,
    required String category,
  }) async {
    try {
      await _ledger.makeCardPurchase(
        merchant: merchant,
        amountCents: amountCents,
        category: category,
      );
      await refresh();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  /// Paga a fatura do mês atual. Retorna null em sucesso ou o erro.
  Future<String?> payInvoice(String auth) async {
    final s = _summary;
    if (s == null || s.invoiceTotalCents == 0) return 'Não há nada a pagar nesta fatura.';
    try {
      await _ledger.payCardInvoice(s.invoiceMonth, auth);
      await refresh();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
