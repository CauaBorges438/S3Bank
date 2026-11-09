import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/gradient_button.dart';

/// Tela de cadastro — mesma linguagem visual do login e da recuperação
/// de senha (fundo com brilhos da paleta + cartão de vidro fosco).
///
/// Ao criar a conta com sucesso, a conta fica salva no aparelho e o
/// [AccountDataCoordinator] já começa o app do zero para o novo usuário
/// (perfil Bronze, sem pontos, saldo zerado, sem caixinhas nem chaves
/// Pix). O AuthGate troca de tela sozinho.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Captura antes do await para não usar o context depois do gap
    // assíncrono.
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final error = await authProvider.signUp(
      name: _nameController.text,
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error == null) {
      // Fecha a tela de cadastro (e o login, se estiver empilhado) para
      // revelar o AuthGate, que já mostra a home por causa do isLoggedIn.
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _loading = false;
      _errorMessage = error;
    });
  }

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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Criar sua conta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Leva menos de um minuto.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: AuthGlassCard(child: _buildForm()),
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthTextField(
            controller: _nameController,
            label: 'Nome completo',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _identifierController,
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
            controller: _passwordController,
            label: 'Senha',
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
            label: 'Confirmar senha',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_loading) _submit();
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
            label: _loading ? 'CRIANDO CONTA...' : 'CRIAR CONTA',
            onTap: _loading ? null : _submit,
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  children: [
                    TextSpan(text: 'Já tem conta? '),
                    TextSpan(
                      text: 'Entrar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
