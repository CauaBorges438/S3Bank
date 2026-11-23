import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/security/security_lock_controller.dart';
import '../../providers/auth_provider.dart';

/// Sobrepõe o app inteiro quando:
/// - o app está bloqueado (mostra a tela de desbloqueio), ou
/// - o app está em segundo plano (mostra uma capa sem saldo).
///
/// Fica acima do Navigator (usado no `MaterialApp.builder`), então cobre
/// qualquer tela aberta, inclusive diálogos e o extrato.
class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({
    super.key,
    required this.child,
    required this.onSignOut,
  });

  final Widget child;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    final lock = context.watch<SecurityLockController>();

    Widget? cover;
    if (loggedIn && lock.isLocked) {
      cover = _LockView(lock: lock, onSignOut: onSignOut);
    } else if (loggedIn && lock.isObscured) {
      cover = ColoredBox(color: Theme.of(context).colorScheme.surface);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (cover != null) Positioned.fill(child: cover),
      ],
    );
  }
}

class _LockView extends StatefulWidget {
  const _LockView({required this.lock, required this.onSignOut});

  final SecurityLockController lock;
  final VoidCallback onSignOut;

  @override
  State<_LockView> createState() => _LockViewState();
}

class _LockViewState extends State<_LockView> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Já dispara o prompt biométrico ao aparecer, como os apps de banco fazem.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.lock.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Não foi possível confirmar sua identidade.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text('S3 Bank bloqueado', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Confirme sua identidade para continuar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: _busy ? null : widget.onSignOut,
                  child: const Text('Sair da conta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
