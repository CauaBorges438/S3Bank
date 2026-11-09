import 'user_tier.dart';

/// Modelo do cartão de débito digital. O "skin" visual do cartão
/// é derivado do [tier] do usuário — não é um campo independente —
/// para garantir que o cartão sempre reflita o nível atual.
class CardModel {
  final String holderName;
  final String cardNumber; // formato completo, mascarado na UI
  final String expiry; // MM/AA
  final String cvv;
  final UserTier tier;

  const CardModel({
    required this.holderName,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.tier,
  });

  String get maskedNumber {
    final digitsOnly = cardNumber.replaceAll(' ', '');
    final last4 = digitsOnly.substring(digitsOnly.length - 4);
    return '•••• •••• •••• $last4';
  }

  String get groupedNumber {
    final digitsOnly = cardNumber.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i += 4) {
      final end = (i + 4 < digitsOnly.length) ? i + 4 : digitsOnly.length;
      buffer.write(digitsOnly.substring(i, end));
      if (end != digitsOnly.length) buffer.write('  ');
    }
    return buffer.toString();
  }

  CardModel copyWith({UserTier? tier, String? holderName}) {
    return CardModel(
      holderName: holderName ?? this.holderName,
      cardNumber: cardNumber,
      expiry: expiry,
      cvv: cvv,
      tier: tier ?? this.tier,
    );
  }
}