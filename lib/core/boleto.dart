/// Só os dígitos, para aceitar o boleto digitado com espaços e pontos.
String boletoDigits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// Boleto válido: exatamente 47 dígitos.
bool isValidBoletoCode(String raw) => RegExp(r'^\d{47}$').hasMatch(boletoDigits(raw));
