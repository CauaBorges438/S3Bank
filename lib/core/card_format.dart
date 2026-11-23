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
