import 'package:flutter/material.dart';
import '../animations/animations.dart';
import '../core/theme/app_colors.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final bool visible;
  final VoidCallback onToggleVisibility;

  static const _valueStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  const BalanceCard({
    super.key,
    required this.balance,
    required this.visible,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.loginGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Conta corrente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: visible ? 'Ocultar saldo' : 'Mostrar saldo',
                child: TapScale(
                  onTap: onToggleVisibility,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        visible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        key: ValueKey(visible),
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Saldo disponível',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          // O valor "rola" até o saldo; ao ocultar, troca por bolinhas com fade.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: FittedBox(
              key: ValueKey(visible),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: visible
                  ? AnimatedCounter(value: balance, style: _valueStyle)
                  : const Text('R\$ ••••••', style: _valueStyle),
            ),
          ),
        ],
      ),
    );
  }
}