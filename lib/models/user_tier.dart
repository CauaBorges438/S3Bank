import 'package:flutter/material.dart';
 
/// Representa os 4 níveis de gamificação do S3 Bank.
/// Cada nível define o percentual de rendimento sobre o CDI
/// e a identidade visual do cartão digital.
enum UserTier {
  bronze,
  prata,
  ouro,
  diamante,
}
 
/// Extensão com todas as regras de negócio do sistema de níveis.
extension UserTierX on UserTier {
  /// Percentual do CDI que o usuário recebe neste nível.
  double get cdiPercentage {
    switch (this) {
      case UserTier.bronze:
        return 1.00; // 100% do CDI
      case UserTier.prata:
        return 1.15; // 115% do CDI
      case UserTier.ouro:
        return 1.30; // 130% do CDI
      case UserTier.diamante:
        return 1.40; // 140% do CDI
    }
  }
 
  String get cdiLabel => '${(cdiPercentage * 100).toStringAsFixed(0)}% do CDI';
 
  String get displayName {
    switch (this) {
      case UserTier.bronze:
        return 'Bronze';
      case UserTier.prata:
        return 'Prata';
      case UserTier.ouro:
        return 'Ouro';
      case UserTier.diamante:
        return 'Diamante';
    }
  }
 
  /// Próximo nível na progressão. Retorna null se já é o nível máximo.
  UserTier? get next {
    switch (this) {
      case UserTier.bronze:
        return UserTier.prata;
      case UserTier.prata:
        return UserTier.ouro;
      case UserTier.ouro:
        return UserTier.diamante;
      case UserTier.diamante:
        return null;
    }
  }
 
  /// Pontuação de constância (aportes consecutivos/streak) necessária
  /// para avançar para o próximo nível.
  /// TODO(integração-backend): substituir por regra vinda da API,
  /// que provavelmente calculará constância com base em histórico real
  /// de aportes (frequência + regularidade), não apenas um número fixo.
  int get pointsRequiredForNext {
    switch (this) {
      case UserTier.bronze:
        return 300; // pontos de constância para chegar a Prata
      case UserTier.prata:
        return 700; // pontos de constância para chegar a Ouro
      case UserTier.ouro:
        return 1500; // pontos de constância para chegar a Diamante
      case UserTier.diamante:
        return 0; // nível máximo, sem próxima meta
    }
  }
 
  /// Cor sólida principal usada em badges e textos de destaque.
  Color get primaryColor {
    switch (this) {
      case UserTier.bronze:
        return const Color(0xFFEC4899);
      case UserTier.prata:
        return const Color(0xFFC0C0C8);
      case UserTier.ouro:
        return const Color(0xFFD4AF37);
      case UserTier.diamante:
        return const Color(0xFF7B61FF);
    }
  }
 
  /// Gradiente usado no cartão digital, refletindo o material/acabamento
  /// de cada nível (bronze em rosa, prata escovada, ouro metálico,
  /// diamante em degradê azul-violeta).
  List<Color> get cardGradient {
    switch (this) {
      case UserTier.bronze:
        return const [Color(0xFFDB2777), Color(0xFFF472B6), Color(0xFF9D174D)];
      case UserTier.prata:
        return const [Color(0xFF8E8E96), Color(0xFFE2E2E8), Color(0xFF6B6B72)];
      case UserTier.ouro:
        return const [Color(0xFF9C7B23), Color(0xFFE8CB77), Color(0xFFB8912F)];
      case UserTier.diamante:
        return const [Color(0xFF2A1D6E), Color(0xFF6A4CE0), Color(0xFFB98CFF)];
    }
  }
 
  IconData get icon {
    switch (this) {
      case UserTier.bronze:
        return Icons.workspace_premium_outlined;
      case UserTier.prata:
        return Icons.workspace_premium;
      case UserTier.ouro:
        return Icons.emoji_events_outlined;
      case UserTier.diamante:
        return Icons.diamond;
    }
  }
}
 