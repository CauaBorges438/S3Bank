import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/user_tier.dart';

/// Mostra visualmente o quanto falta para o usuário atingir o
/// próximo nível de rendimento.
class LevelProgressBar extends StatelessWidget {
  final UserTier currentTier;
  final UserTier? nextTier;
  final double progress; // 0.0 a 1.0
  final int pointsRemaining;

  const LevelProgressBar({
    super.key,
    required this.currentTier,
    required this.nextTier,
    required this.progress,
    required this.pointsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    if (nextTier == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(currentTier.icon, color: currentTier.primaryColor),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Você atingiu o nível máximo! Seu dinheiro rende o melhor percentual do CDI do S3 Bank.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Faltam $pointsRemaining pontos para ${nextTier!.displayName}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              nextTier!.cdiLabel,
              style: TextStyle(
                color: nextTier!.primaryColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: 12, color: AppColors.surfaceElevated),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: AppColors.loginGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.loginBlueMid.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(progress * 100).toStringAsFixed(0)}% completo',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}