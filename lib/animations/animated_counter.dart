import 'package:flutter/material.dart';

/// Formata valor em padrão brasileiro: 1234.5 -> 1.234,50
String formatBrl(double v, {int decimals = 2}) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(decimals).split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final rem = intPart.length - i;
    buf.write(intPart[i]);
    if (rem > 1 && rem % 3 == 1) buf.write('.');
  }
  final dec = decimals > 0 ? ',${parts[1]}' : '';
  return '${neg ? '-' : ''}$buf$dec';
}

/// Número que "rola" até o valor. Quando `value` muda, anima do valor atual
/// até o novo (ex.: saldo depois de um Pix).
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = 'R\$ ',
    this.decimals = 2,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
  });

  final double value;
  final TextStyle? style;
  final String prefix;
  final int decimals;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) =>
          Text('$prefix${formatBrl(v, decimals: decimals)}', style: style),
    );
  }
}
