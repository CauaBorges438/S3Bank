import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Botão de ação principal com o gradiente da marca — mesmo padrão do
/// botão "ENTRAR" da tela de login. Compartilhado entre Pix, Guardar
/// Dinheiro e qualquer outra confirmação importante do app, pra manter
/// a mesma linguagem visual em todo lugar.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const GradientButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: AppColors.loginGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.loginBlueMid.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}