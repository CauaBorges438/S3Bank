import 'package:shared_preferences/shared_preferences.dart';

/// Preferências de notificação do usuário, guardadas no aparelho.
/// Só registra a escolha: o envio das notificações ainda não está ligado.
class NotificationPrefs {
  final bool transactions;
  final bool levelUp;
  final bool offers;

  const NotificationPrefs({
    this.transactions = true,
    this.levelUp = true,
    this.offers = false,
  });

  NotificationPrefs copyWith({bool? transactions, bool? levelUp, bool? offers}) =>
      NotificationPrefs(
        transactions: transactions ?? this.transactions,
        levelUp: levelUp ?? this.levelUp,
        offers: offers ?? this.offers,
      );

  static Future<NotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      transactions: prefs.getBool('notif_transactions') ?? true,
      levelUp: prefs.getBool('notif_level') ?? true,
      offers: prefs.getBool('notif_offers') ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_transactions', transactions);
    await prefs.setBool('notif_level', levelUp);
    await prefs.setBool('notif_offers', offers);
  }
}
