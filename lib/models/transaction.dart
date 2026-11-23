enum TransactionType { pixSent, pixReceived, savingsDeposit, savingsWithdraw }

class Transaction {
  final String id;
  final TransactionType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;

  /// Chave de categoria (ex.: 'alimentacao'), ou null se não categorizada.
  final String? category;

  const Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    this.category,
  });

  Transaction copyWith({String? category}) => Transaction(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        amount: amount,
        date: date,
        category: category ?? this.category,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        type: TransactionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransactionType.pixSent,
        ),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        category: json['category'] as String?,
      );

  /// Indica se o valor deve ser exibido como entrada (verde) ou saída (padrão).
  bool get isCredit =>
      type == TransactionType.pixReceived || type == TransactionType.savingsWithdraw;
}
