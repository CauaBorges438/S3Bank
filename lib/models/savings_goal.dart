import 'package:flutter/material.dart';

/// Ícones disponíveis para as caixinhas. A lista é fixa de propósito:
/// para salvar no disco guardamos só o índice do ícone, o que evita criar
/// `IconData` dinamicamente (isso quebra o tree-shaking de ícones no build
/// de release).
const List<IconData> savingsIconOptions = [
  Icons.savings_outlined,
  Icons.flight_takeoff,
  Icons.shield_outlined,
  Icons.directions_car_outlined,
  Icons.home_outlined,
  Icons.school_outlined,
];

/// Representa uma "caixinha" / objetivo de economia criado pelo usuário,
/// inspirado no "Guardar Dinheiro" do Itaú e nas "Caixinhas" do C6 Bank.
class SavingsGoal {
  final String id;
  final String name;
  final IconData icon;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.icon,
    required this.targetAmount,
    required this.currentAmount,
    required this.createdAt,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  Map<String, dynamic> toJson() {
    final iconIndex = savingsIconOptions.indexWhere((i) => i.codePoint == icon.codePoint);
    return {
      'id': id,
      'name': name,
      'iconIndex': iconIndex < 0 ? 0 : iconIndex,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    final index = (json['iconIndex'] as num?)?.toInt() ?? 0;
    return SavingsGoal(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      icon: savingsIconOptions[index.clamp(0, savingsIconOptions.length - 1).toInt()],
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  SavingsGoal copyWith({
    String? name,
    IconData? icon,
    double? targetAmount,
    double? currentAmount,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      createdAt: createdAt,
    );
  }
}
