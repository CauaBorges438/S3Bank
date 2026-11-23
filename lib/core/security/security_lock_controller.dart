import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

/// Controla o bloqueio do app.
///
/// - Bloqueia na abertura quando já existe sessão salva (`lockOnLaunch`).
/// - Bloqueia ao voltar para o app depois de [inactivityTimeout] em segundo plano.
/// - Oculta o conteúdo enquanto o app está em segundo plano, para que a
///   prévia no seletor de apps não mostre o saldo ([isObscured]).
/// - Pede biometria ou senha do aparelho para desbloquear e para confirmar
///   ações sensíveis ([confirmSensitiveAction]).
///
/// O prompt do sistema (Face ID, digital) também gera eventos de ciclo de
/// vida. Enquanto a autenticação está em andamento, esses eventos são
/// ignorados, senão o app se bloquearia de novo logo após desbloquear.
class SecurityLockController extends ChangeNotifier with WidgetsBindingObserver {
  SecurityLockController({
    this.inactivityTimeout = const Duration(minutes: 3),
    DateTime Function() now = DateTime.now,
    LocalAuthentication? localAuth,
  })  : _now = now,
        _localAuth = localAuth ?? LocalAuthentication();

  final Duration inactivityTimeout;
  final DateTime Function() _now;
  final LocalAuthentication _localAuth;

  bool _locked = false;
  bool _obscured = false;
  bool _authenticating = false;
  bool _attached = false;
  DateTime? _backgroundedAt;

  bool get isLocked => _locked;
  bool get isObscured => _obscured;

  /// Começa a observar o ciclo de vida do app. Chame uma vez no main().
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Só mexe no observador se ele foi adicionado. Sem isso, dispose() sem
  /// attach() (como nos testes) estoura, porque o binding não existe.
  @override
  void dispose() {
    if (_attached) {
      WidgetsBinding.instance.removeObserver(this);
      _attached = false;
    }
    super.dispose();
  }

  /// Chamar na abertura do app quando a sessão foi restaurada do armazenamento.
  void lockOnLaunch() {
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  void lockNow() {
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authenticating) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= _now();
        _setObscured(true);
        break;
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        _setObscured(false);
        if (since != null && _now().difference(since) >= inactivityTimeout) {
          lockNow();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _setObscured(bool value) {
    if (_obscured == value) return;
    _obscured = value;
    notifyListeners();
  }

  /// Tela de bloqueio: pede biometria/senha do aparelho. Retorna true se liberou.
  Future<bool> unlock() async {
    final ok = await authenticate('Desbloqueie para acessar sua conta');
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Confirmação para ações sensíveis (Pix, cartão virtual, pagamento de
  /// fatura). Não altera o estado de bloqueio.
  Future<bool> confirmSensitiveAction(String reason) => authenticate(reason);

  /// Retorna false quando o aparelho não tem biometria nem senha de tela,
  /// ou quando o usuário cancela. Nesses casos a tela de bloqueio oferece
  /// sair da conta para entrar de novo com e-mail e senha.
  Future<bool> authenticate(String reason) async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Aceita a senha/padrão do aparelho quando a biometria falha.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    } finally {
      _authenticating = false;
    }
  }
}
