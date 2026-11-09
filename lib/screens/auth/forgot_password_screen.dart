import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/gradient_button.dart';

enum _Step { identify, code, newPassword, done }

/// Recuperação de senha em 3 etapas:
/// 1. informa o e-mail  2. digita o código recebido  3. define a nova senha.
///
/// As três etapas usam o [AuthProvider], que confere a conta e grava a
/// nova senha no aparelho. Como não há servidor de e-mail/SMS, o código
/// é exibido na própria tela (modo demonstração).
///
/// TODO(integração-backend): enviar o código por e-mail/SMS de verdade.
class ForgotPasswordScreen extends StatefulWidget {
  /// Pré-preenche o campo com o que o usuário já digitou no login.
  final String? initialIdentifier;

  const ForgotPasswordScreen({super.key, this.initialIdentifier});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  late final TextEditingController _identifierController =
      TextEditingController(text: widget.initialIdentifier?.trim() ?? '');
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.identify;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Timer? _timer;
  int _cooldown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- ações

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_identifierKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await context
        .read<AuthProvider>()
        .requestPasswordReset(_identifierController.text);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = _Step.code;
    });
    _startCooldown();
  }

  Future<void> _verifyCode() async {
    if (!_codeKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error =
        await context.read<AuthProvider>().verifyResetCode(_codeController.text);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = _Step.newPassword;
    });
  }

  Future<void> _resetPassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await context
        .read<AuthProvider>()
        .resetPassword(_passwordController.text);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = _Step.done;
    });
  }

  void _goBack() {
    switch (_step) {
      case _Step.identify:
      case _Step.done:
        Navigator.of(context).pop();
        break;
      case _Step.code:
        setState(() {
          _step = _Step.identify;
          _errorMessage = null;
        });
        break;
      case _Step.newPassword:
        setState(() {
          _step = _Step.code;
          _errorMessage = null;
        });
        break;
    }
  }

  /// Versão mascarada do que o usuário digitou, para a etapa do código.
  String get _maskedIdentifier {
    final value = _identifierController.text.trim();
    if (value.contains('@')) {
      final parts = value.split('@');
      final first = parts.first.isEmpty ? '' : parts.first[0];
      return '$first***@${parts.sublist(1).join('@')}';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      return 'o CPF terminado em ${digits.substring(digits.length - 2)}';
    }
    return 'o seu cadastro';
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _goBack,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: AuthGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_step != _Step.done) ...[
                              _StepIndicator(current: _step.index),
                              const SizedBox(height: 22),
                            ],
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: KeyedSubtree(
                                key: ValueKey(_step),
                                child: _buildStep(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.identify:
        return _identifyStep();
      case _Step.code:
        return _codeStep();
      case _Step.newPassword:
        return _passwordStep();
      case _Step.done:
        return _doneStep();
    }
  }

  Widget _identifyStep() {
    return Form(
      key: _identifierKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StepHeader(
            icon: Icons.lock_reset,
            title: 'Esqueceu sua senha?',
            subtitle:
                'Informe seu e-mail cadastrado. Vamos enviar um código de verificação.',
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _identifierController,
            label: 'E-mail',
            icon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_loading) _sendCode();
            },
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Informe seu e-mail'
                : null,
          ),
          const SizedBox(height: 18),
          if (_errorMessage != null) ...[
            AuthErrorBanner(message: _errorMessage!),
            const SizedBox(height: 10),
          ],
          GradientButton(
            label: _loading ? 'ENVIANDO...' : 'ENVIAR CÓDIGO',
            onTap: _loading ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _codeStep() {
    return Form(
      key: _codeKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepHeader(
            icon: Icons.mark_email_read_outlined,
            title: 'Digite o código',
            subtitle: 'Enviamos um código de 6 dígitos para $_maskedIdentifier.',
          ),
          const SizedBox(height: 16),
          _DemoCodeBox(code: context.read<AuthProvider>().demoResetCode),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _codeController,
            label: 'Código de 6 dígitos',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) {
              if (!_loading) _verifyCode();
            },
            validator: (v) =>
                (v == null || v.length != 6) ? 'Digite os 6 dígitos' : null,
          ),
          const SizedBox(height: 18),
          if (_errorMessage != null) ...[
            AuthErrorBanner(message: _errorMessage!),
            const SizedBox(height: 10),
          ],
          GradientButton(
            label: _loading ? 'VERIFICANDO...' : 'VERIFICAR CÓDIGO',
            onTap: _loading ? null : _verifyCode,
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed:
                  (_cooldown > 0 || _loading) ? null : () => _sendCode(resend: true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentLight,
                disabledForegroundColor: AppColors.textSecondary,
              ),
              child: Text(
                _cooldown > 0 ? 'Reenviar código em ${_cooldown}s' : 'Reenviar código',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordStep() {
    return Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StepHeader(
            icon: Icons.password_outlined,
            title: 'Crie uma nova senha',
            subtitle: 'Escolha uma senha que você ainda não usou neste app.',
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _passwordController,
            label: 'Nova senha',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _confirmController,
            label: 'Confirmar nova senha',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_loading) _resetPassword();
            },
            validator: (v) => (v != _passwordController.text)
                ? 'As senhas não coincidem'
                : null,
          ),
          const SizedBox(height: 18),
          if (_errorMessage != null) ...[
            AuthErrorBanner(message: _errorMessage!),
            const SizedBox(height: 10),
          ],
          GradientButton(
            label: _loading ? 'SALVANDO...' : 'REDEFINIR SENHA',
            onTap: _loading ? null : _resetPassword,
          ),
        ],
      ),
    );
  }

  Widget _doneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _StepHeader(
          icon: Icons.check_circle_outline,
          title: 'Senha redefinida',
          subtitle: 'Tudo certo! Agora é só entrar com a sua nova senha.',
        ),
        const SizedBox(height: 22),
        GradientButton(
          label: 'VOLTAR PARA O LOGIN',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Barrinhas de progresso das etapas (3 no total).
class _StepIndicator extends StatelessWidget {
  final int current;

  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accentLight
                  : Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

/// Ícone + título + descrição do topo de cada etapa.
class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accentLight.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.accentLight, size: 24),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Mostra o código da recuperação na tela (modo demonstração), já que o
/// app não tem como enviar e-mail ou SMS de verdade.
class _DemoCodeBox extends StatelessWidget {
  final String? code;

  const _DemoCodeBox({required this.code});

  @override
  Widget build(BuildContext context) {
    if (code == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentLight.withOpacity(0.25)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
          children: [
            const TextSpan(text: 'Modo demonstração: seu código é '),
            TextSpan(
              text: code,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const TextSpan(
              text: '. Em um app real, ele chegaria por e-mail ou SMS.',
            ),
          ],
        ),
      ),
    );
  }
}
