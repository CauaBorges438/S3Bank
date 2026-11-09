import 'package:shared_preferences/shared_preferences.dart';

/// Pequena camada sobre o [SharedPreferences] para guardar texto no
/// aparelho (no navegador, vira localStorage). Todas as chaves do app
/// ficam sob o prefixo `s3bank.` para não colidir com outros dados.
///
/// TODO(integração-backend): quando existir API, isto vira só um cache
/// local — a fonte da verdade passa a ser o servidor.
class LocalStore {
  static const _prefix = 's3bank.';

  final SharedPreferences _prefs;

  LocalStore._(this._prefs);

  static Future<LocalStore> create() async {
    return LocalStore._(await SharedPreferences.getInstance());
  }

  String? getString(String key) => _prefs.getString('$_prefix$key');

  Future<void> setString(String key, String value) =>
      _prefs.setString('$_prefix$key', value);

  Future<void> remove(String key) => _prefs.remove('$_prefix$key');
}
