import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Barra de progresso que preenche suavemente até [progress] (0..1) e,
/// quando o valor muda, anima do ponto atual até o novo.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.glow = false,
    this.duration = const Duration(milliseconds: 800),
  });

  final double progress;
  final double height;
  final bool glow;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.surfaceElevated),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0).toDouble()),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: AppColors.loginGradient,
                  boxShadow: glow
                      ? [
                          BoxShadow(
                            color: AppColors.loginBlueMid.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
