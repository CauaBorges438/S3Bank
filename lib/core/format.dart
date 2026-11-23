/// Valor em reais no padrão brasileiro: R$ 1.234,56
String brl(double value) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final intPart = (cents ~/ 100).toString();
  final decimals = (cents % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
  }
  return '${negative ? '-' : ''}R\$ $buffer,$decimals';
}
