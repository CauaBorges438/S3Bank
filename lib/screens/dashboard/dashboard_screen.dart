import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../animations/animations.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_tier.dart';
import '../../providers/savings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/level_progress_bar.dart';
import '../../widgets/quick_access_button.dart';
import '../../widgets/tier_badge.dart';
import '../../widgets/transaction_tile.dart';
import '../profile/profile_screen.dart';
import '../statement/statement_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final wallet = context.watch<WalletProvider>();
    final savings = context.watch<SavingsProvider>();

    // O cartão acompanha o nível do usuário via AccountDataCoordinator
    // (antes isso era chamado aqui, dentro do build, o que notificava
    // ouvintes durante a construção da tela).

    // Número fixo de blocos: o índice de cada um define o atraso da
    // animação de entrada (efeito cascata).
    final blocks = <Widget>[
      _Header(userName: user.name, tier: user.tier),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: LevelProgressBar(
          currentTier: user.tier,
          nextTier: user.nextTier,
          progress: user.progressToNextTier,
          pointsRemaining: user.pointsRemainingForNext,
        ),
      ),
      BalanceCard(
        balance: wallet.balance,
        visible: wallet.balanceVisible,
        onToggleVisibility: () => wallet.toggleBalanceVisibility(),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acesso rápido',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          // Os atalhos trocam de aba (em vez de empilhar uma segunda cópia
          // da tela por cima, sem a barra de navegação).
          Row(
            children: [
              Expanded(
                child: TapScale(
                  child: QuickAccessButton(
                    icon: Icons.qr_code,
                    iconSize: 26,
                    label: 'Área Pix',
                    onTap: () => onNavigateToTab(1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TapScale(
                  child: QuickAccessButton(
                    icon: Icons.savings_outlined,
                    label: 'Guardar\nDinheiro',
                    onTap: () => onNavigateToTab(2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TapScale(
                  child: QuickAccessButton(
                    icon: Icons.credit_card,
                    label: 'Cartão\nDigital',
                    onTap: () => onNavigateToTab(3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total guardado',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCounter(
                      value: savings.totalSaved,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 36, color: Colors.white24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rendimento do mês',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCounter(
                      value: savings.monthlyYieldEstimate(user.tier),
                      prefix: '+ R\$ ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Últimas movimentações',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              // "Ver tudo" abre o extrato completo (a aba Pix só mostra Pix).
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(fadeSlideRoute(const StatementScreen())),
                child: const Text('Ver tudo'),
              ),
            ],
          ),
          if (wallet.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhuma movimentação ainda.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ...wallet.transactions
              .take(3)
              .map((t) => TransactionTile(key: ValueKey(t.id), transaction: t)),
        ],
      ),
    ];

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: blocks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 22),
        itemBuilder: (context, i) => FadeSlideIn(
          delay: Duration(milliseconds: 70 * i),
          child: blocks[i],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final UserTier tier;

  const _Header({required this.userName, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Toque no avatar abre o perfil (a tela existia, mas não era
        // acessível por lugar nenhum).
        TapScale(
          onTap: () => Navigator.of(context)
              .push(fadeSlideRoute(const ProfileScreen())),
          child: Hero(
            tag: 'profile-avatar',
            // Material transparente: evita o texto "sublinhado amarelo"
            // durante a animação do Hero.
            child: Material(
              type: MaterialType.transparency,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Olá,',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
        TierBadge(tier: tier, large: true),
      ],
    );
  }
}
