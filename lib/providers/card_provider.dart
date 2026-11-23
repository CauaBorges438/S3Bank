import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/user_tier.dart';

/// Gerencia o cartão de débito digital. O "skin" visual do cartão é
/// sempre derivado do nível atual do usuário (ver [CardModel.tier]),
/// então este provider deve ser mantido em sincronia com [UserProvider]
/// chamando [syncTier] sempre que o nível mudar.
/// TODO(integração-backend): número, validade e CVV reais devem vir de
/// um endpoint seguro (ex: GET /card/details) e nunca ficar hardcoded.
class CardProvider extends ChangeNotifier {
  CardModel _card;

  CardProvider({required String holderName, required UserTier initialTier})
      : _card = CardModel(
          holderName: holderName,
          cardNumber: '5412 7534 8821 4477',
          expiry: '09/30',
          cvv: '482',
          tier: initialTier,
        );

  CardModel get card => _card;

  /// Chamado quando o usuário sobe (ou, em tese, desce) de nível, para que
  /// o cartão digital atualize sua cor/skin automaticamente.
  void syncTier(UserTier tier) {
    if (_card.tier == tier) return;
    _card = _card.copyWith(tier: tier);
    notifyListeners();
  }

  /// Mantém o nome impresso no cartão em sincronia com [UserProvider]
  /// (ex: depois do cadastro). Nomes vazios ou iguais são ignorados.
  void updateHolderName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _card.holderName) return;
    _card = _card.copyWith(holderName: trimmed);
    notifyListeners();
  }
}
