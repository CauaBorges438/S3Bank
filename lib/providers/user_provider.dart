import 'package:flutter/material.dart';
import '../models/user_tier.dart';

/// Gerencia o perfil do usuário e a lógica de progressão de nível.
///
/// A "constância nos aportes" é modelada aqui como [consistencyPoints]:
/// pontos acumulados a cada aporte feito na área "Guardar Dinheiro".
/// TODO(integração-backend): substituir o acúmulo local por um cálculo
/// vindo da API, que deve considerar frequência e regularidade real dos
/// aportes (ex: streak semanal), não apenas soma simples de eventos.
class UserProvider extends ChangeNotifier {
  String name;
  String profileImageUrl;
  UserTier _tier;
  int _consistencyPoints;

  UserProvider({
    this.name = 'Rafaela Souza',
    this.profileImageUrl = '',
    UserTier initialTier = UserTier.bronze,
    int initialPoints = 120,
  })  : _tier = initialTier,
        _consistencyPoints = initialPoints;

  UserTier get tier => _tier;
  int get consistencyPoints => _consistencyPoints;

  UserTier? get nextTier => _tier.next;

  /// Pontos necessários para alcançar o próximo nível (0 se já é o máximo).
  int get pointsRequiredForNext => _tier.pointsRequiredForNext;

  /// Progresso de 0.0 a 1.0 até o próximo nível.
  double get progressToNextTier {
    if (nextTier == null) return 1.0;
    return (_consistencyPoints / pointsRequiredForNext).clamp(0.0, 1.0);
  }

  int get pointsRemainingForNext {
    if (nextTier == null) return 0;
    final remaining = pointsRequiredForNext - _consistencyPoints;
    return remaining < 0 ? 0 : remaining;
  }

  /// Atualiza o nome do usuário (ex: ao concluir o cadastro).
  void updateName(String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == name) return;
    name = trimmed;
    notifyListeners();
  }

  /// Começa um perfil novo do zero: nome informado, nível Bronze e
  /// nenhum ponto de constância (usado logo após o cadastro).
  void startNewProfile(String newName) {
    name = newName.trim();
    profileImageUrl = '';
    _tier = UserTier.bronze;
    _consistencyPoints = 0;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'profileImageUrl': profileImageUrl,
        'tier': _tier.name,
        'points': _consistencyPoints,
      };

  /// Carrega os dados salvos de uma conta (campos ausentes viram padrão).
  void restore(Map<String, dynamic> json) {
    name = json['name'] as String? ?? name;
    profileImageUrl = json['profileImageUrl'] as String? ?? '';
    _tier = UserTier.values.firstWhere(
      (t) => t.name == json['tier'],
      orElse: () => UserTier.bronze,
    );
    _consistencyPoints = (json['points'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  /// Dados de exemplo da conta de demonstração.
  void loadDemoData() {
    name = 'Rafaela Souza';
    profileImageUrl = '';
    _tier = UserTier.bronze;
    _consistencyPoints = 120;
    notifyListeners();
  }

  /// Chamado sempre que o usuário faz um aporte na área "Guardar Dinheiro".
  /// Cada real guardado gera pontos de constância; aportes recorrentes
  /// pesam mais do que um único aporte grande (incentivo a hábito, não
  /// apenas volume) — aqui simplificado como pontos fixos por aporte
  /// somados a uma fração do valor.
  void registerDeposit(double amount) {
    final gainedPoints = 15 + (amount / 10).floor();
    _consistencyPoints += gainedPoints;
    _tryLevelUp();
    notifyListeners();
  }

  void _tryLevelUp() {
    while (nextTier != null && _consistencyPoints >= pointsRequiredForNext) {
      final overflow = _consistencyPoints - pointsRequiredForNext;
      _tier = nextTier!;
      _consistencyPoints = overflow;
    }
  }
}