import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/br_validators.dart';

/// Conta do usuário logado. O [id] é o UUID do Supabase Auth, que é a
/// mesma chave usada no banco (profiles, accounts, ledger_entries).
class Account {
  final String id;
  final String name;
  final String identifier;

  const Account({
    required this.id,
    required this.name,
    required this.identifier,
  });
}

/// Autenticação via Supabase Auth.
///
/// A sessão é persistida pelo próprio supabase_flutter, então o usuário
/// continua logado ao reabrir o app. A API pública (signIn, signUp,
/// signOut, recuperação de senha) não mudou, então as telas continuam
/// iguais.
///
/// Login é feito por e-mail: o Supabase Auth exige e-mail, e aceitar CPF
/// exigiria um endpoint público que converte CPF em e-mail (vazamento).
class AuthProvider extends ChangeNotifier {
  static const _networkError = 'Sem conexão com o servidor. Tente de novo';
  static const _genericError = 'Não foi possível concluir. Tente de novo';

  StreamSubscription<AuthState>? _sub;
  Account? _account;

  // Estado temporário da recuperação de senha (só em memória).
  String? _resetEmail;
  String? _resetCode;

  /// [connect] = false cria o provider sem tocar no Supabase (usado nos
  /// testes de widget e de dados locais). Nesse modo ele começa deslogado.
  AuthProvider({bool connect = true}) {
    if (!connect) return;
    _sub = _auth.onAuthStateChange.listen((state) => _onSession(state.session));
    _onSession(_auth.currentSession);
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;

  bool get isLoggedIn => _account != null;
  Account? get currentAccount => _account;
  String? get loginIdentifier => _account?.identifier;

  // ------------------------------------------------------------ helpers

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String raw) => _emailRegex.hasMatch(raw.trim());

  /// Senha: exatamente 6 números (como no app dos bancos). Sem letras.
  static final _pinRegex = RegExp(r'^\d{6}$');

  static const passwordMessage = 'A senha precisa ter 6 números';

  static bool isValidPassword(String raw) => _pinRegex.hasMatch(raw);

  /// Validador de formulário para criar ou trocar a senha.
  static String? passwordError(String? raw) =>
      isValidPassword(raw ?? '') ? null : passwordMessage;

  /// Só aceita dígitos, no máximo 6, para o teclado da senha.
  static List<TextInputFormatter> get passwordFormatters => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ];

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static String _mapError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha incorretos';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Já existe uma conta com esse e-mail';
    }
    if (m.contains('not confirmed')) {
      return 'Confirme seu e-mail antes de entrar';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Muitas tentativas. Aguarde um pouco';
    }
    if (m.contains('database error')) {
      // O banco recusa CPF repetido e o Supabase oculta o motivo exato.
      return 'Não foi possível criar a conta. Verifique seus dados ou se o CPF já tem cadastro.';
    }
    if (m.contains('token') || m.contains('otp')) {
      return 'Código incorreto ou expirado';
    }
    return _genericError;
  }

  // ------------------------------------------------------------ sessão

  Future<void> _onSession(Session? session) async {
    final user = session?.user;
    if (user == null) {
      if (_account != null) {
        _account = null;
        notifyListeners();
      }
      return;
    }
    if (_account?.id == user.id) return;

    // Entra já com os dados da própria sessão salva. Não espera a rede: sem
    // internet, a tela de login não pode aparecer no lugar da conta salva.
    final fallbackName = (user.userMetadata?['full_name'] as String?) ?? 'Cliente';
    _account = Account(
      id: user.id,
      name: fallbackName,
      identifier: user.email ?? '',
    );
    notifyListeners();

    // Depois busca o nome real no banco e atualiza, se for diferente.
    final name = await _loadName(user);
    if (_auth.currentUser?.id != user.id) return;
    if (_account?.id == user.id && _account?.name != name) {
      _account = Account(
        id: user.id,
        name: name,
        identifier: user.email ?? '',
      );
      notifyListeners();
    }
  }

  Future<String> _loadName(User user) async {
    final fallback = (user.userMetadata?['full_name'] as String?) ?? 'Cliente';
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      return (row?['full_name'] as String?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  // ------------------------------------------------------------ login

  Future<String?> signIn({required String identifier, required String password}) async {
    final email = normalizeEmail(identifier);
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!isValidEmail(email)) return 'Informe um e-mail válido';
    if (password.isEmpty) return 'Informe sua senha';

    try {
      await _auth.signInWithPassword(email: email, password: password);
      return null; // a sessão chega pelo onAuthStateChange
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Cria a conta. Se o projeto exigir confirmação por e-mail, o usuário
  /// precisa confirmar antes de entrar.
  Future<String?> signUp({
    required String name,
    required String identifier,
    required String password,
    required String cpf,
    required String celular,
  }) async {
    if (name.trim().length < 2) return 'Informe seu nome completo';
    final cpfError = BrValidators.cpfError(cpf);
    if (cpfError != null) return cpfError;
    final celularError = BrValidators.celularError(celular);
    if (celularError != null) return celularError;
    final email = normalizeEmail(identifier);
    if (!isValidEmail(email)) return 'Informe um e-mail válido';
    if (!isValidPassword(password)) return passwordMessage;

    try {
      final res = await _auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name.trim(),
          'cpf': BrValidators.digits(cpf),
          'phone': BrValidators.celularForStorage(celular),
        },
      );
      if (res.session == null) {
        return 'Confirme seu e-mail pelo link que enviamos e depois entre';
      }
      return null;
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Atualiza o nome exibido na sessão (depois de salvar no banco).
  void setDisplayName(String name) {
    final acc = _account;
    if (acc == null) return;
    _account = Account(id: acc.id, name: name, identifier: acc.identifier);
    notifyListeners();
  }

  /// Troca a senha. Confere a senha atual antes. Retorna null ou o erro.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _account?.identifier ?? '';
    if (email.isEmpty) return 'Sessão expirada. Entre de novo.';
    if (!isValidPassword(newPassword)) return passwordMessage;
    if (currentPassword == newPassword) return 'A nova senha precisa ser diferente da atual';

    try {
      // confere a senha atual: se estiver errada, o Supabase recusa aqui
      await _auth.signInWithPassword(email: email, password: currentPassword);
      await _auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login')) {
        return 'Senha atual incorreta';
      }
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  void signOut() {
    debugPrint('[auth] logout pedido pelo usuário');
    // Zera a conta já, para o coordenador salvar os dados desta conta.
    _account = null;
    notifyListeners();
    try {
      _auth.signOut().catchError((_) {});
    } catch (_) {
      // Supabase não inicializado (testes): nada a encerrar no servidor.
    }
  }

  /// Só para testes: entra com uma conta fabricada, sem falar com o Supabase.
  @visibleForTesting
  void debugLogin(Account account) {
    _account = account;
    notifyListeners();
  }

  // ------------------------------------------------- recuperar a senha
  //
  // O código é enviado e conferido pelas Edge Functions do Supabase
  // (send-reset-code e verify-reset-code), que usam o Resend para o e-mail.
  // A resposta é sempre a mesma para e-mails sem conta, de propósito.

  /// Etapa 1: pede o envio do código de 6 dígitos para o e-mail.
  Future<String?> requestPasswordReset(String identifier) async {
    final email = normalizeEmail(identifier);
    if (!isValidEmail(email)) return 'Informe um e-mail válido';

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'send-reset-code',
        body: {'email': email},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data?['ok'] != true) {
        return (data?['error'] as String?) ?? _genericError;
      }
      _resetEmail = email;
      _resetCode = null;
      return null;
    } catch (e) {
      debugPrint('[auth] send-reset-code falhou: $e');
      return _networkError;
    }
  }

  /// Etapa 2: guarda o código digitado. Ele é conferido no último passo,
  /// junto com a nova senha, para não precisar de uma terceira função.
  Future<String?> verifyResetCode(String code) async {
    if (_resetEmail == null) return 'Solicite um novo código';
    final c = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(c)) return 'Código inválido';
    _resetCode = c;
    return null;
  }

  /// Etapa 3: confere o código e troca a senha no servidor.
  Future<String?> resetPassword(String newPassword) async {
    final email = _resetEmail;
    final code = _resetCode;
    if (email == null || code == null) {
      return 'Solicite um novo código';
    }
    if (!isValidPassword(newPassword)) return passwordMessage;

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'verify-reset-code',
        body: {'email': email, 'code': code, 'password': newPassword},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data?['ok'] != true) {
        return (data?['error'] as String?) ?? _genericError;
      }
      _resetEmail = null;
      _resetCode = null;
      return null;
    } catch (e) {
      debugPrint('[auth] verify-reset-code falhou: $e');
      return _networkError;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
