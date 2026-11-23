import 'package:flutter/material.dart';

/// Entrada com fade + leve deslize. Use `delay` para escalonar itens.
///
/// O atraso é feito com um [Interval] dentro do mesmo controller (sem
/// `Timer`), então não deixa nada pendente se a tela for fechada antes.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = const Offset(0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    final start = widget.delay.inMilliseconds / total.inMilliseconds;
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(_curved),
        child: widget.child,
      ),
    );
  }
}
