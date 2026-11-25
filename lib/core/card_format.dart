/// Número do cartão para exibição: só os 4 últimos dígitos aparecem.
String maskedCard(String? last4) =>
    last4 == null ? 'Sem cartão' : '•••• •••• •••• $last4';

/// Nome do mês em português, para o título da fatura.
String monthNamePt(int month) {
  const names = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];
  return names[month - 1];
}

/// Converte o texto digitado em reais.
/// Aceita "1.500,50" (padrão BR), "1500.50" (ponto decimal) e "1.500" (milhar).
/// Retorna null se não for um valor positivo.
double? parseBrMoney(String text) {
  var t = text.trim().replaceAll(RegExp(r'[R$\s]'), '');
  if (t.isEmpty) return null;

  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }

  final v = double.tryParse(t);
  return (v == null || v <= 0) ? null : v;
}
