/// Resumo do cartão de crédito: limite, uso e fatura do mês.
class CardSummary {
  final bool hasCard;
  final String? last4;
  final String? expiry;
  final int limitCents;
  final int usedCents;
  final int availableCents;
  final DateTime invoiceMonth;
  final int invoiceTotalCents;
  final DateTime invoiceDue;

  const CardSummary({
    required this.hasCard,
    this.last4,
    this.expiry,
    required this.limitCents,
    required this.usedCents,
    required this.availableCents,
    required this.invoiceMonth,
    required this.invoiceTotalCents,
    required this.invoiceDue,
  });

  factory CardSummary.fromRow(Map<String, dynamic> row) => CardSummary(
        hasCard: row['has_card'] as bool? ?? false,
        last4: row['card_last4'] as String?,
        expiry: row['card_expiry'] as String?,
        limitCents: (row['card_limit_cents'] as num).toInt(),
        usedCents: (row['card_used_cents'] as num).toInt(),
        availableCents: (row['card_available_cents'] as num).toInt(),
        invoiceMonth: DateTime.parse(row['invoice_month'] as String),
        invoiceTotalCents: (row['invoice_total_cents'] as num).toInt(),
        invoiceDue: DateTime.parse(row['invoice_due'] as String),
      );
}

/// Uma compra feita no cartão.
class CardPurchase {
  final String id;
  final String merchant;
  final String category;
  final int amountCents;
  final DateTime purchasedAt;
  final bool paid;

  const CardPurchase({
    required this.id,
    required this.merchant,
    required this.category,
    required this.amountCents,
    required this.purchasedAt,
    required this.paid,
  });

  factory CardPurchase.fromRow(Map<String, dynamic> row) => CardPurchase(
        id: row['id'] as String,
        merchant: row['merchant'] as String,
        category: row['category'] as String,
        amountCents: (row['amount_cents'] as num).toInt(),
        purchasedAt:
            (DateTime.tryParse(row['purchased_at'] as String? ?? '') ?? DateTime.now()).toLocal(),
        paid: row['paid_at'] != null,
      );
}
