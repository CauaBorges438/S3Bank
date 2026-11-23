import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../animations/animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_input_formatter.dart';
import '../../models/savings_goal.dart';
import '../../models/user_tier.dart';
import '../../providers/savings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/success_dialog.dart';

final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Abre um bottom sheet no padrão do app (cantos arredondados, fundo surface).
Future<void> _showSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => sheet,
  );
}

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final savings = context.watch<SavingsProvider>();
    final user = context.watch<UserProvider>();
    final goals = savings.goals;

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
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.loginGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.loginBlueMid.withValues(alpha: 0.3),
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
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total guardado',
                      value: savings.totalSaved,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Rendimento do mês',
                      value: savings.monthlyYieldEstimate(user.tier),
                      prefix: '+ R\$ ',
                      valueColor: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Suas caixinhas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (goals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Você ainda não criou nenhuma caixinha.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              for (var i = 0; i < goals.length; i++)
                // A key por id faz só a caixinha NOVA animar a entrada.
                FadeSlideIn(
                  key: ValueKey(goals[i].id),
                  delay: Duration(milliseconds: 160 + 70 * (i < 6 ? i : 6)),
                  child: _GoalCard(goal: goals[i]),
                ),
          ],
        ),
      ),
    );
  }

  void _showCreateGoalModal(BuildContext context) {
    final savings = context.read<SavingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    _showSheet(
      context,
      _CreateGoalSheet(
        onCreate: (name, icon, target) async {
          String? error;
          if (savings.isServerBacked) {
            error = await savings.createGoalRemote(name: name, targetAmount: target);
          } else {
            savings.createGoal(name: name, icon: icon, targetAmount: target);
          }
          messenger.showSnackBar(
            SnackBar(content: Text(error ?? 'Caixinha "$name" criada.')),
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final String prefix;
  final Color? valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.prefix = 'R\$ ',
    this.valueColor,
  });

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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: value,
              prefix: prefix,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: valueColor ?? AppColors.textPrimary,
              ),
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
                    Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${_currencyFmt.format(goal.currentAmount)} de ${_currencyFmt.format(goal.targetAmount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(goal.progress * 100).floor()}%',
                style: const TextStyle(
                  color: AppColors.accentLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedProgressBar(progress: goal.progress),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [10, 50, 100].map((v) {
              return TapScale(
                child: _QuickChip(
                  label: 'R\$ $v',
                  onTap: () => _deposit(context, goal, v.toDouble()),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Os dois botões usam o mesmo OutlinedButton (contorno branco vem
          // do tema) e ocupam metade da linha cada.
          Row(
            children: [
              Expanded(
                child: TapScale(
                  child: OutlinedButton(
                    onPressed: () => _showCustomDepositModal(context, goal),
                    child: const Text('Guardar valor'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TapScale(
                  child: OutlinedButton(
                    onPressed: goal.currentAmount <= 0
                        ? null
                        : () => _showWithdrawModal(context, goal),
                    child: const Text('Resgatar'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deposit(BuildContext context, SavingsGoal goal, double amount) async {
    final wallet = context.read<WalletProvider>();
    final savings = context.read<SavingsProvider>();
    final user = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final tierBefore = user.tier;

    if (savings.isServerBacked) {
      final error = await savings.depositRemote(goal.id, amount);
      messenger.hideCurrentSnackBar();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      await wallet.refreshFromServer();
      await user.refreshFromServer();
    } else {
      final debited = wallet.debitForSavings(amount, goalName: goal.name);
      if (!debited) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Saldo insuficiente na conta corrente.')),
        );
        return;
      }
      savings.deposit(goal.id, amount);
    }

    // Cada aporte alimenta a pontuação de constância que impulsiona o
    // usuário rumo ao próximo nível de rendimento.
    user.registerDeposit(amount);

    HapticFeedback.lightImpact();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${_currencyFmt.format(amount)} guardado em "${goal.name}".'),
      ),
    );

    if (!context.mounted) return;
    if (user.tier != tierBefore) {
      showSuccessDialog(
        context,
        title: 'Você subiu de nível!',
        subtitle:
            'Agora você é ${user.tier.displayName} e seu dinheiro rende ${user.tier.cdiLabel}.',
      );
    }
  }

  void _showCustomDepositModal(BuildContext context, SavingsGoal goal) {
    final wallet = context.read<WalletProvider>();
    _showSheet(
      context,
      _AmountSheet(
        title: 'Guardar em "${goal.name}"',
        confirmLabel: 'Confirmar',
        validate: (value) => value > wallet.balance ? 'Saldo insuficiente' : null,
        onConfirm: (amount) => _deposit(context, goal, amount),
      ),
    );
  }

  void _showWithdrawModal(BuildContext context, SavingsGoal goal) {
    final savings = context.read<SavingsProvider>();
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);

    _showSheet(
      context,
      _AmountSheet(
        title: 'Resgatar de "${goal.name}"',
        confirmLabel: 'Confirmar resgate',
        validate: (value) =>
            value > goal.currentAmount ? 'Valor maior que o guardado' : null,
        onConfirm: (amount) async {
          if (savings.isServerBacked) {
            final error = await savings.withdrawRemote(goal.id, amount);
            messenger.hideCurrentSnackBar();
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text(error)));
              return;
            }
            await wallet.refreshFromServer();
            HapticFeedback.lightImpact();
            messenger.showSnackBar(
              SnackBar(
                content: Text('${_currencyFmt.format(amount)} resgatado para a conta.'),
              ),
            );
            return;
          }
          final actual = savings.withdraw(goal.id, amount);
          if (actual <= 0) return;
          wallet.creditFromSavings(actual, goalName: goal.name);
          HapticFeedback.lightImpact();
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text('${_currencyFmt.format(actual)} resgatado para a conta.'),
            ),
          );
        },
      ),
    );
  }
}

/// Sheet de valor (guardar / resgatar). É um StatefulWidget para que o
/// controller seja descartado junto com o sheet (antes ficava solto).
class _AmountSheet extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String? Function(double value) validate;
  final void Function(double amount) onConfirm;

  const _AmountSheet({
    required this.title,
    required this.confirmLabel,
    required this.validate,
    required this.onConfirm,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = CurrencyInputFormatter.parse(_controller.text);
    Navigator.of(context).pop();
    widget.onConfirm(amount);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [CurrencyInputFormatter()],
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  hintText: '0,00',
                  prefixText: 'R\$ ',
                ),
                validator: (v) {
                  final value = CurrencyInputFormatter.parse(v ?? '');
                  if (value <= 0) return 'Informe um valor maior que zero';
                  return widget.validate(value);
                },
              ),
              const SizedBox(height: 20),
              GradientButton(label: widget.confirmLabel, onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGoalSheet extends StatefulWidget {
  final void Function(String name, IconData icon, double target) onCreate;

  const _CreateGoalSheet({required this.onCreate});

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  IconData _selectedIcon = savingsIconOptions.first;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final target = CurrencyInputFormatter.parse(_targetController.text);
    Navigator.of(context).pop();
    widget.onCreate(name, _selectedIcon, target);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nova caixinha',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: savingsIconOptions.map((icon) {
                  final selected = icon == _selectedIcon;
                  return TapScale(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.loginGradient : null,
                        color: selected ? null : AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: selected ? null : Border.all(color: AppColors.border),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome do objetivo'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [CurrencyInputFormatter()],
                onFieldSubmitted: (_) => _submit(),
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
              GradientButton(label: 'Criar caixinha', onTap: _submit),
            ],
          ),
        ),
      ),
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
