import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Usuário logado, como o resto do app enxerga.
class Account {
  /// UUID do usuário no Supabase Auth (`auth.users.id`).
  final String id;
  final String name;

  /// E-mail de login.
  final String identifier;

  const Account({
    required this.id,
    required this.name,
    required this.identifier,
  });
}

/// Autenticação via Supabase Auth (e-mail + senha). A sessão é salva e
/// restaurada pelo próprio SDK, então o usuário continua logado ao
/// reabrir o app.
///
/// Recuperação de senha (mantém as 3 telas):
///   1. [requestPasswordReset] -> Supabase envia um e-mail com código;
///   2. [verifyResetCode]      -> confere o código;
///   3. [resetPassword]        -> grava a nova senha e encerra a sessão.
/// Para o código chegar por e-mail, o template "Reset Password" no
/// painel do Supabase precisa conter `{{ .Token }}`.
class AuthProvider extends ChangeNotifier {
  static const minPasswordLength = 6; // padrão do Supabase

  /// Início da mensagem devolvida por [signUp] quando a conta foi criada
  /// mas ainda falta confirmar o e-mail (não é um erro).
  static const confirmationNoticePrefix = 'Conta criada! Enviamos um link de confirmação para';

  static bool isConfirmationNotice(String message) =>
      message.startsWith(confirmationNoticePrefix);

  final sb.SupabaseClient _client;
  StreamSubscription<sb.AuthState>? _sub;

  Account? _account;

  // Estado temporário da recuperação de senha.
  String? _resetEmail;
  bool _resetFlow = false;

  AuthProvider({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client {
    _account = _fromUser(_client.auth.currentUser);
    _sub = _client.auth.onAuthStateChange.listen((state) {
      // Durante a recuperação o Supabase abre uma sessão temporária;
      // não devemos mostrar o app por causa dela.
      if (_resetFlow) return;
      final next = _fromUser(state.session?.user);
      if (next?.id == _account?.id && next?.name == _account?.name) return;
      _account = next;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get isLoggedIn => _account != null;
  Account? get currentAccount => _account;
  String? get loginIdentifier => _account?.identifier;

  /// Mantido por compatibilidade com a tela de recuperação: com o
  /// Supabase o código vai por e-mail, então nunca é exibido na tela.
  String? get demoResetCode => null;

  // ------------------------------------------------------------ helpers

  static Account? _fromUser(sb.User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const {};
    final email = user.email ?? '';
    return Account(
      id: user.id,
      name: (meta['nome'] as String?)?.trim().isNotEmpty == true
          ? (meta['nome'] as String).trim()
          : email.split('@').first,
      identifier: email,
    );
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String _normalizeEmail(String raw) => raw.trim().toLowerCase();

  static String _friendly(sb.AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'E-mail ou senha incorretos';
    if (m.contains('email not confirmed')) return 'Confirme seu e-mail antes de entrar';
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Já existe uma conta com esse e-mail';
    }
    if (m.contains('token') && (m.contains('expired') || m.contains('invalid'))) {
      return 'Código incorreto ou expirado';
    }
    if (m.contains('rate limit') || m.contains('seconds')) {
      return 'Muitas tentativas. Aguarde um pouco e tente de novo';
    }
    if (m.contains('password')) return e.message;
    return 'Não foi possível concluir. Tente novamente';
  }

  static const _networkError = 'Sem conexão com o servidor. Tente novamente';

  // ------------------------------------------------------------ login

  Future<String?> signIn({required String identifier, required String password}) async {
    final email = _normalizeEmail(identifier);
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!_emailRegex.hasMatch(email)) return 'Informe um e-mail válido';
    if (password.isEmpty) return 'Informe sua senha';

    try {
      final res = await _client.auth.signInWithPassword(email: email, password: password);
      _account = _fromUser(res.user);
      notifyListeners();
      return null; // null = sucesso
    } on sb.AuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Cria a conta. Se o projeto exige confirmação de e-mail, o usuário
  /// só entra depois de confirmar (e a mensagem de aviso é retornada).
  Future<String?> signUp({
    required String name,
    required String identifier,
    required String password,
  }) async {
    final email = _normalizeEmail(identifier);
    if (name.trim().isEmpty) return 'Informe seu nome completo';
    if (!_emailRegex.hasMatch(email)) return 'Informe um e-mail válido';
    if (password.length < minPasswordLength) {
      return 'A senha precisa ter pelo menos $minPasswordLength caracteres';
    }

    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        // O trigger `handle_new_user` do banco lê a chave `nome`.
        data: {'nome': name.trim()},
      );
      if (res.session == null) {
        return '$confirmationNoticePrefix $email. Confirme e depois entre.';
      }
      _account = _fromUser(res.user);
      notifyListeners();
      return null;
    } on sb.AuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Reenvia o e-mail de confirmação de cadastro (útil se o primeiro
  /// e-mail não chegou, foi pro spam, ou expirou).
  Future<String?> resendConfirmationEmail(String identifier) async {
    final email = _normalizeEmail(identifier);
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!_emailRegex.hasMatch(email)) return 'Informe um e-mail válido';

    try {
      await _client.auth.resend(type: sb.OtpType.signup, email: email);
      return null; // null = sucesso (e-mail reenviado)
    } on sb.AuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return _networkError;
    }
  }

  Future<void> signOut() async {
    _account = null;
    notifyListeners();
    try {
      await _client.auth.signOut();
    } catch (_) {/* sessão local já foi limpa pelo SDK */}
  }

  // ------------------------------------------------- recuperar a senha

  /// Etapa 1: pede o código por e-mail.
  Future<String?> requestPasswordReset(String identifier) async {
    final email = _normalizeEmail(identifier);
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!_emailRegex.hasMatch(email)) return 'Informe um e-mail válido';

    try {
      await _client.auth.resetPasswordForEmail(email);
      _resetEmail = email;
      return null;
    } on sb.AuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Etapa 2: confere o código digitado (abre uma sessão temporária).
  Future<String?> verifyResetCode(String code) async {
    final email = _resetEmail;
    if (email == null) return 'Solicite um novo código';

    _resetFlow = true;
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code.trim(),
        type: sb.OtpType.recovery,
      );
      return null;
    } on sb.AuthException catch (e) {
      _resetFlow = false;
      return _friendly(e);
    } catch (_) {
      _resetFlow = false;
      return _networkError;
    }
  }

  /// Etapa 3: grava a nova senha e encerra a sessão temporária.
  Future<String?> resetPassword(String newPassword) async {
    if (!_resetFlow || _resetEmail == null) {
      return 'A recuperação expirou. Comece de novo.';
    }
    if (newPassword.length < minPasswordLength) {
      return 'A senha precisa ter pelo menos $minPasswordLength caracteres';
    }

    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
      await _client.auth.signOut();
      _resetEmail = null;
      _resetFlow = false;
      return null;
    } on sb.AuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return _networkError;
    }
  }
}
