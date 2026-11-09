import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/card_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/level_progress_bar.dart';
import '../../widgets/quick_access_button.dart';
import '../../widgets/tier_badge.dart';
import '../../widgets/transaction_tile.dart';
import '../card/card_screen.dart';
import '../pix/pix_screen.dart';
import '../savings/savings_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final wallet = context.watch<WalletProvider>();
    final savings = context.watch<SavingsProvider>();

    // Mantém o cartão sincronizado com o nível atual do usuário.
    context.read<CardProvider>().syncTier(user.tier);

    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _Header(userName: user.name, tier: user.tier),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          BalanceCard(
            balance: wallet.balance,
            visible: wallet.balanceVisible,
            onToggleVisibility: () => wallet.toggleBalanceVisibility(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Acesso rápido',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QuickAccessButton(
                  icon: Icons.qr_code,
                  iconSize: 26,
                  label: 'Área Pix',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PixScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuickAccessButton(
                  icon: Icons.savings_outlined,
                  label: 'Guardar\nDinheiro',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavingsScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuickAccessButton(
                  icon: Icons.credit_card,
                  label: 'Cartão\nDigital',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CardScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                      Text(
                        currencyFmt.format(savings.totalSaved),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
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
                      Text(
                        '+ ${currencyFmt.format(savings.monthlyYieldEstimate(user.tier))}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Últimas movimentações',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              TextButton(
                onPressed: () => onNavigateToTab(1),
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
              .map((t) => TransactionTile(transaction: t)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final dynamic tier;

  const _Header({required this.userName, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.surfaceElevated,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
        TierBadge(tier: tier, large: true),
        const SizedBox(width: 4),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
            tooltip: 'Sair',
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ),
      ],
    );
  }
}