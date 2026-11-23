import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Estados padrão de tela: carregando, lista vazia e erro com nova tentativa.
/// Use sempre que uma tela depender de dados que podem demorar ou falhar.
class StateView extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  const StateView._({
    this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  /// Carregando: indicador discreto com texto.
  factory StateView.loading({String title = 'Carregando...'}) =>
      StateView._(title: title, loading: true);

  /// Lista vazia: explica o que vai aparecer ali.
  factory StateView.empty({
    required String title,
    String? message,
    IconData icon = Icons.inbox_outlined,
  }) =>
      StateView._(icon: icon, title: title, message: message);

  /// Erro: diz o que aconteceu e oferece nova tentativa.
  factory StateView.error({
    String title = 'Não foi possível carregar',
    required String message,
    VoidCallback? onAction,
  }) =>
      StateView._(
        icon: Icons.cloud_off_outlined,
        title: title,
        message: message,
        actionLabel: 'Tentar de novo',
        onAction: onAction,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else if (icon != null)
              Icon(icon, size: 44, color: AppColors.textDisabled),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
