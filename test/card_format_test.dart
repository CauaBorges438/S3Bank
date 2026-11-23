import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/card_format.dart';
import 'package:s3_bank/models/card_summary.dart';

void main() {
  test('cartão mostra só os 4 últimos dígitos', () {
    expect(maskedCard('4477'), '•••• •••• •••• 4477');
    expect(maskedCard(null), 'Sem cartão');
  });

  test('nome do mês em português', () {
    expect(monthNamePt(1), 'Janeiro');
    expect(monthNamePt(11), 'Novembro');
    expect(monthNamePt(12), 'Dezembro');
  });

  test('resumo lê o retorno do banco', () {
    final s = CardSummary.fromRow({
      'has_card': true,
      'card_last4': '4477',
      'card_expiry': '12/30',
      'card_limit_cents': 300000,
      'card_used_cents': 50000,
      'card_available_cents': 250000,
      'invoice_month': '2026-11-01',
      'invoice_total_cents': 50000,
      'invoice_due': '2026-12-10',
    });
    expect(s.hasCard, isTrue);
    expect(s.availableCents, 250000);
    expect(s.invoiceDue, DateTime(2026, 12, 10));
  });

  test('compra paga é marcada como paga', () {
    final c = CardPurchase.fromRow({
      'id': 'x',
      'merchant': 'Padaria',
      'category': 'alimentacao',
      'amount_cents': 1200,
      'purchased_at': '2026-11-10T12:00:00Z',
      'paid_at': '2026-11-11T09:00:00Z',
    });
    expect(c.paid, isTrue);
    expect(c.amountCents, 1200);
  });
}
