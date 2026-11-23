import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'main_navigation_screen.dart';
 
/// Troca entre a tela de login e o app principal com base em
/// [AuthProvider.isLoggedIn]. A sessão fica salva no aparelho (ver
/// [AuthProvider]), então ao reabrir o app o usuário continua logado.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
 
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: isLoggedIn
          ? const MainNavigationScreen(key: ValueKey('main'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}
 