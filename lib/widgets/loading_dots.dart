import 'package:flutter/material.dart';

/// Três pontinhos que pulsam em sequência — indicador de carregamento
/// usado dentro do botão que vira "pílula" no login.
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key, this.color = Colors.white, this.dotSize = 7});

  final Color color;
  final double dotSize;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.16) % 1.0;
            final wave = phase < 0.5
                ? Curves.easeInOut.transform(phase / 0.5)
                : Curves.easeInOut.transform(1 - (phase - 0.5) / 0.5);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.scale(
                scale: 0.7 + 0.5 * wave,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.4 + 0.6 * wave),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
