import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('padrão: transações e nível ligados, ofertas desligadas', () async {
    final p = await NotificationPrefs.load();
    expect(p.transactions, isTrue);
    expect(p.levelUp, isTrue);
    expect(p.offers, isFalse);
  });

  test('a escolha é guardada e volta ao reabrir', () async {
    final escolha = const NotificationPrefs().copyWith(levelUp: false, offers: true);
    await escolha.save();

    final lida = await NotificationPrefs.load();
    expect(lida.levelUp, isFalse);
    expect(lida.offers, isTrue);
    expect(lida.transactions, isTrue);
  });
}
