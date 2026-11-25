import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/card_format.dart';
import 'package:s3_bank/models/card_summary.dart';

void main() {
  test('aceita formato brasileiro e ponto decimal', () {
    expect(parseBrMoney('1.500,50'), 1500.5);
    expect(parseBrMoney('1500.50'), 1500.5);
    expect(parseBrMoney('12,5'), 12.5);
    expect(parseBrMoney('R\$ 20,00'), 20.0);
    expect(parseBrMoney('1.500'), 1500.0);
  });

  test('rejeita valores vazios, inválidos ou não positivos', () {
    expect(parseBrMoney(''), isNull);
    expect(parseBrMoney('abc'), isNull);
    expect(parseBrMoney('0'), isNull);
    expect(parseBrMoney('-5'), isNull);
  });

  test('fatura em atraso e vencimento', () {
    final s = CardSummary.fromRow({
      'has_card': true,
      'card_last4': '4477',
      'card_expiry': '12/30',
      'card_limit_cents': 300000,
      'card_used_cents': 12000,
      'card_available_cents': 288000,
      'invoice_month': '2026-11-01',
      'invoice_total_cents': 0,
      'invoice_due': '2026-12-10',
      'overdue_month': '2026-10-01',
      'overdue_cents': 12000,
    });
    expect(s.hasOverdue, isTrue);
    expect(s.overdueCents, 12000);
    expect(invoiceDueFor(DateTime(2026, 10, 1)), DateTime(2026, 11, 10));
  });
}
