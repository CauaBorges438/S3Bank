import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'main_navigation_screen.dart';
 
/// Troca entre a tela de login e o app principal com base em
/// [AuthProvider.isLoggedIn]. Sem nenhuma verificação de sessão salva
/// em disco — é só estado em memória, então todo restart do app volta
/// pro login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
 
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return isLoggedIn ? const MainNavigationScreen() : const LoginScreen();
  }
}
 