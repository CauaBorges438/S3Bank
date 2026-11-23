import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import 'loading_dots.dart';
import 'pressable_scale.dart';

/// Botão principal que, ao entrar em [loading], encolhe e vira uma
/// pílula pequena com três pontinhos pulsando (como no vídeo de
/// referência); quando termina, volta a ocupar a largura toda.
class MorphButton extends StatelessWidget {
  const MorphButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
    this.height = 52,
    this.collapsedWidth = 68,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final double height;
  final double collapsedWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && onTap != null;
    final radius = BorderRadius.circular(loading ? height / 2 : 14);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
        return Semantics(
          button: true,
          enabled: enabled,
          label: loading ? 'Carregando' : label,
          excludeSemantics: true,
          child: Align(
            child: PressableScale(
              enabled: enabled,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                width: loading ? collapsedWidth : fullWidth,
                height: height,
                decoration: BoxDecoration(
                  gradient: AppColors.loginGradient,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.loginBlueMid
                          .withValues(alpha: loading ? 0.25 : 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: enabled
                        ? () {
                            HapticFeedback.lightImpact();
                            onTap!();
                          }
                        : null,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: loading
                            ? const LoadingDots(key: ValueKey('dots'))
                            : Text(
                                label,
                                key: const ValueKey('label'),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
