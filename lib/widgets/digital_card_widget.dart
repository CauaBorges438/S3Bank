import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/card_model.dart';
import '../models/user_tier.dart';

/// Componente visual do cartão de débito digital. A cor/skin do cartão
/// é 100% derivada de [card.tier] (ver [UserTierX.cardGradient]) — ou
/// seja, ao subir de nível, basta o provider atualizar o tier do cartão
/// para que este widget mude de aparência automaticamente, sem lógica
/// adicional aqui.
class DigitalCardWidget extends StatelessWidget {
  final CardModel card;
  final bool showDetails;

  const DigitalCardWidget({
    super.key,
    required this.card,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = card.tier.cardGradient;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'S3 BANK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Icon(card.tier.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    card.tier.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _ChipAndContactless(),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: FittedBox(
              key: ValueKey(showDetails),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                showDetails ? card.groupedNumber : card.maskedNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible + ellipsis: nome comprido não estoura mais a linha.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.holderName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Apenas débito',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                showDetails ? '${card.expiry}  •  CVV ${card.cvv}' : '••/••',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipAndContactless extends StatelessWidget {
  const _ChipAndContactless();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.chipSilver, AppColors.chipSilverDark],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.wifi, color: Colors.white.withValues(alpha: 0.9), size: 20),
      ],
    );
  }
}