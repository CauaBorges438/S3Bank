/// CPF mascarado para exibição: ***.456.789-**
/// Mostra só o miolo, porque o CPF completo não precisa aparecer na tela.
String maskCpf(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return 'Não informado';
  return '***.${digits.substring(3, 6)}.${digits.substring(6, 9)}-**';
}
