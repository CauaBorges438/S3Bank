import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Segurança: trocar a senha. Pede a senha atual antes de trocar.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final localError = AuthProvider.passwordError(_newCtrl.text) ??
        (_newCtrl.text != _confirmCtrl.text ? 'As senhas não conferem' : null);
    if (_currentCtrl.text.isEmpty) {
      setState(() => _error = 'Informe sua senha atual');
      return;
    }
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await auth.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso.')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(labelText: label);
    const keyboard = TextInputType.number;

    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'Alterar senha',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'A nova senha tem 6 números, como no app do banco.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _currentCtrl,
              obscureText: true,
              keyboardType: keyboard,
              inputFormatters: AuthProvider.passwordFormatters,
              decoration: deco('Senha atual'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              keyboardType: keyboard,
              inputFormatters: AuthProvider.passwordFormatters,
              decoration: deco('Nova senha (6 números)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              keyboardType: keyboard,
              inputFormatters: AuthProvider.passwordFormatters,
              decoration: deco('Confirmar nova senha'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _changePassword,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Alterar senha'),
            ),
          ],
        ),
      ),
    );
  }
}
