import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_input_formatter.dart';
import '../../models/savings_goal.dart';
import '../../models/user_tier.dart';
import '../../providers/savings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/bank_actions.dart';
import '../../widgets/gradient_button.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final savings = context.watch<SavingsProvider>();
    final user = context.watch<UserProvider>();
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Guardar Dinheiro')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGoalModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova caixinha'),
        backgroundColor: AppColors.loginBlueMid,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // Gamificação integrada: mostra o rendimento atual com base no nível.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.loginGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.loginBlueMid.withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(user.tier.icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seu dinheiro está rendendo ${user.tier.cdiLabel} no nível ${user.tier.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Total guardado',
                    value: currencyFmt.format(savings.totalSaved),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Rendimento do mês',
                    value:
                        '+ ${currencyFmt.format(savings.monthlyYieldEstimate(user.tier))}',
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Suas caixinhas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (savings.goals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Você ainda não criou nenhuma caixinha.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...savings.goals.map(
                (goal) => _GoalCard(goal: goal),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateGoalModal(BuildContext context) {
    final actions = context.read<BankActions>();
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    IconData selectedIcon = Icons.savings_outlined;

    const iconOptions = savingsIconOptions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nova caixinha',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      children: iconOptions.map((icon) {
                        final selected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = icon),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: selected ? AppColors.loginGradient : null,
                              color: selected ? null : AppColors.surfaceElevated,
                              shape: BoxShape.circle,
                              border: selected
                                  ? null
                                  : Border.all(color: AppColors.border),
                            ),
                            child: Icon(icon, color: Colors.white, size: 20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nome do objetivo'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Valor alvo (R\$)',
                        hintText: '0,00',
                        prefixText: 'R\$ ',
                      ),
                      validator: (v) {
                        final value = CurrencyInputFormatter.parse(v ?? '');
                        if (value <= 0) return 'Informe um valor maior que zero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Criar caixinha',
                      onTap: () async {
                        if (!formKey.currentState!.validate()) return;
                        final error = await actions.createGoal(
                          name: nameController.text.trim(),
                          iconIndex: iconOptions.indexOf(selectedIcon),
                          targetAmount:
                              CurrencyInputFormatter.parse(targetController.text),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (error != null) {
                          messenger.showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: AppColors.loginGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(goal.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${currencyFmt.format(goal.currentAmount)} de ${currencyFmt.format(goal.targetAmount)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.surfaceElevated),
                FractionallySizedBox(
                  widthFactor: goal.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(gradient: AppColors.loginGradient),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [10, 50, 100].map((v) {
                    return _QuickChip(
                      label: 'R\$ $v',
                      onTap: () => _deposit(context, goal, v.toDouble()),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showCustomDepositModal(context, goal),
                  child: const Text('Guardar valor'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: goal.currentAmount <= 0
                      ? null
                      : () => _showWithdrawModal(context, goal),
                  child: const Text('Resgatar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deposit(BuildContext context, SavingsGoal goal, double amount) async {
    final actions = context.read<BankActions>();
    final messenger = ScaffoldMessenger.of(context);

    // O servidor valida o saldo, move o dinheiro, registra no extrato e
    // soma os pontos de constância (e sobe de nível, se for o caso).
    final error = await actions.deposit(goal.id, amount);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _showCustomDepositModal(BuildContext context, SavingsGoal goal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final wallet = context.read<WalletProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guardar em "${goal.name}"',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                  ),
                  validator: (v) {
                    final value = CurrencyInputFormatter.parse(v ?? '');
                    if (value <= 0) return 'Informe um valor maior que zero';
                    if (value > wallet.balance) return 'Saldo insuficiente';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Confirmar',
                  onTap: () {
                    if (!formKey.currentState!.validate()) return;
                    final amount = CurrencyInputFormatter.parse(controller.text);
                    Navigator.of(ctx).pop();
                    _deposit(context, goal, amount);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWithdrawModal(BuildContext context, SavingsGoal goal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final actions = context.read<BankActions>();
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resgatar de "${goal.name}"',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                  ),
                  validator: (v) {
                    final value = CurrencyInputFormatter.parse(v ?? '');
                    if (value <= 0) return 'Informe um valor maior que zero';
                    if (value > goal.currentAmount) return 'Valor maior que o guardado';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Confirmar resgate',
                  onTap: () async {
                    if (!formKey.currentState!.validate()) return;
                    final amount = CurrencyInputFormatter.parse(controller.text);
                    final error = await actions.withdraw(goal.id, amount);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      onPressed: onTap,
    );
  }
}