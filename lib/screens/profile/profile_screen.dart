import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/tier_badge.dart';

/// Tela de perfil do usuário: dados da conta, nível atual e opções
/// gerais do app. Hoje tudo estático além do nome/nível (que vêm dos
/// providers) — os itens de menu ainda não abrem telas próprias.
/// TODO(próximos passos): Dados pessoais, Segurança e Ajuda podem virar
/// telas de verdade quando fizer sentido pro projeto.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.loginGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.loginBlueMid.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  if (auth.loginIdentifier != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      auth.loginIdentifier!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TierBadge(tier: user.tier, large: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Conta'),
            _ProfileTile(
              icon: Icons.person_outline,
              label: 'Dados pessoais',
              onTap: () => _showComingSoon(context),
            ),
            _ProfileTile(
              icon: Icons.shield_outlined,
              label: 'Segurança',
              onTap: () => _showComingSoon(context),
            ),
            _ProfileTile(
              icon: Icons.notifications_outlined,
              label: 'Notificações',
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Suporte'),
            _ProfileTile(
              icon: Icons.help_outline,
              label: 'Central de ajuda',
              onTap: () => _showComingSoon(context),
            ),
            _ProfileTile(
              icon: Icons.info_outline,
              label: 'Sobre o S3 Bank',
              onTap: () => _showAboutDialog(context),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                label: const Text('Sair da conta',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Em breve.')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sobre o S3 Bank'),
        content: const Text(
          'Protótipo de conta digital gamificada, com progressão de '
          'nível atrelada ao CDI. Versão 1.0.0 — dados mockados, sem backend.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.accentLight, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}