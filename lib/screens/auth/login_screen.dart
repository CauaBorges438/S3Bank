import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../animations/animations.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/morph_button.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

/// Tela de login: fundo escuro com brilhos da paleta da marca, logo e
/// mensagem de boas-vindas no topo, e uma ficha de acesso em vidro fosco
/// ancorada na base da tela.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().signIn(
          identifier: _loginController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorMessage = error;
    });
    // Em caso de sucesso, o AuthGate reage sozinho (via Provider) e
    // troca a tela — não precisa navegar manualmente daqui.
  }

  void _toggleObscurePassword() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _goToSignup() {
    Navigator.of(context).push(fadeSlideRoute(const SignupScreen()));
  }

  void _goToForgotPassword() {
    Navigator.of(context).push(
      fadeSlideRoute(
        ForgotPasswordScreen(initialIdentifier: _loginController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackdrop(),
          SafeArea(
            bottom: false,
            // LayoutBuilder: limita a ficha de acesso a 85% da área útil.
            // Se ela não couber (tela pequena, fonte grande, teclado
            // aberto), rola por dentro em vez de estourar a tela.
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          28, keyboardOpen ? 16 : 40, 28, 0),
                      child: _Hero(compact: keyboardOpen),
                    ),
                  ),
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: constraints.maxHeight * 0.85),
                    child: FadeSlideIn(
                      offset: const Offset(0, 0.12),
                      child: _AccessSheet(
                      formKey: _formKey,
                      loginController: _loginController,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      loading: _loading,
                      errorMessage: _errorMessage,
                      onToggleObscurePassword: _toggleObscurePassword,
                      onSubmit: _submit,
                      onForgotPassword: _goToForgotPassword,
                      onGoToSignup: _goToSignup,
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parte de cima: logo centralizado e, embaixo dele, a mensagem de
/// boas-vindas alinhada à esquerda (some quando o teclado abre).
class _Hero extends StatelessWidget {
  final bool compact;

  const _Hero({required this.compact});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + scroll: em telas baixas (ou com fonte grande) o
    // conteúdo rola em vez de estourar ("BOTTOM OVERFLOWED").
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: compact ? 130 : 170,
                    fit: BoxFit.contain,
                  ),
                ),
                if (!compact) ...[
                  const Spacer(),
                  const Text(
                    'Que bom te ver\nde novo.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Acesse sua conta e acompanhe sua evolução, aporte a aporte.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ficha de acesso ancorada na base da tela, com vidro fosco.
class _AccessSheet extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController loginController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoToSignup;

  const _AccessSheet({
    required this.formKey,
    required this.loginController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.errorMessage,
    required this.onToggleObscurePassword,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onGoToSignup,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            keyboardOpen ? 20 : MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.86),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Acesse sua conta',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthTextField(
                    controller: loginController,
                    label: 'E-mail',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe seu e-mail'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: passwordController,
                    label: 'Senha',
                    icon: Icons.lock_outline,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!loading) onSubmit();
                    },
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: onToggleObscurePassword,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onForgotPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentLight,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Esqueci minha senha',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: errorMessage == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AuthErrorBanner(message: errorMessage!),
                          ),
                  ),
                  MorphButton(
                    label: 'ENTRAR',
                    loading: loading,
                    onTap: onSubmit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: onGoToSignup,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          children: [
                            TextSpan(text: 'Ainda não é cliente? '),
                            TextSpan(
                              text: 'Abra sua conta',
                              // Mesmo roxo/peso dos outros links da tela.
                              style: TextStyle(
                                color: AppColors.accentLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}