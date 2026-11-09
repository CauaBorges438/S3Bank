import 'package:flutter/material.dart';
import '../models/user_tier.dart';

/// Badge compacto exibido no header do Dashboard com o nível atual.
class TierBadge extends StatelessWidget {
  final UserTier tier;
  final bool large;

  const TierBadge({super.key, required this.tier, this.large = false});

  @override
  Widget build(BuildContext context) {
    final gradientColors = tier.cardGradient;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: large ? 18 : 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            tier.displayName,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: large ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}