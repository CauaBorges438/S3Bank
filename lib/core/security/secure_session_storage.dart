import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Guarda a sessão do Supabase (access token e refresh token) no cofre do
/// sistema: Keystore no Android e Keychain no iOS.
///
/// Por padrão o supabase_flutter grava a sessão em SharedPreferences, que
/// no Android é um arquivo XML legível em aparelhos com root. Esta classe
/// troca esse armazenamento sem mudar mais nada no app.
///
/// Efeito colateral: quem já estava logado precisa entrar uma vez de novo.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  static const _sessionKey = 'supabase.session';

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _sessionKey)) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);
}
