import '../models/transaction.dart';

/// Entradas, saídas ou tudo.
enum StatementDirection { all, inflow, outflow }

/// Período a partir de agora. [all] não filtra por data.
enum StatementPeriod { days7, days30, days90, all }

extension StatementPeriodX on StatementPeriod {
  String get label {
    switch (this) {
      case StatementPeriod.days7:
        return '7 dias';
      case StatementPeriod.days30:
        return '30 dias';
      case StatementPeriod.days90:
        return '90 dias';
      case StatementPeriod.all:
        return 'Tudo';
    }
  }

  /// Data mínima do período, ou null para "tudo".
  DateTime? since(DateTime now) {
    switch (this) {
      case StatementPeriod.days7:
        return now.subtract(const Duration(days: 7));
      case StatementPeriod.days30:
        return now.subtract(const Duration(days: 30));
      case StatementPeriod.days90:
        return now.subtract(const Duration(days: 90));
      case StatementPeriod.all:
        return null;
    }
  }
}

/// Categorias de gasto (chave do banco -> nome exibido).
const Map<String, String> kTxCategories = {
  'alimentacao': 'Alimentação',
  'moradia': 'Moradia',
  'transporte': 'Transporte',
  'lazer': 'Lazer',
  'saude': 'Saúde',
  'compras': 'Compras',
  'poupanca': 'Poupança',
  'outros': 'Outros',
};

const String kSemCategoria = 'Sem categoria';

/// Nome exibido da categoria de uma movimentação.
String categoryLabel(Transaction t) {
  final key = t.category;
  if (key == null) return kSemCategoria;
  return kTxCategories[key] ?? kSemCategoria;
}

List<Transaction> filterTransactions(
  List<Transaction> all, {
  required StatementDirection direction,
  required StatementPeriod period,
  DateTime? now,
}) {
  final since = period.since(now ?? DateTime.now());
  return all.where((t) {
    if (direction == StatementDirection.inflow && !t.isCredit) return false;
    if (direction == StatementDirection.outflow && t.isCredit) return false;
    if (since != null && t.date.isBefore(since)) return false;
    return true;
  }).toList();
}

class CategoryTotal {
  final String label;
  final double amount;

  const CategoryTotal({required this.label, required this.amount});
}

/// Total de saídas por categoria, do maior para o menor.
/// Entradas não entram: o gráfico mostra para onde o dinheiro foi.
List<CategoryTotal> outflowByCategory(List<Transaction> list) {
  final totals = <String, double>{};
  for (final t in list) {
    if (t.isCredit) continue;
    final label = categoryLabel(t);
    totals[label] = (totals[label] ?? 0) + t.amount;
  }
  final result = totals.entries
      .map((e) => CategoryTotal(label: e.key, amount: e.value))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return result;
}
