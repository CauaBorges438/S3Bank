import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../animations/animations.dart';
import '../../core/format.dart';
import '../../core/statement_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/state_view.dart';
import '../../widgets/transaction_tile.dart';
import '../transfers/transfers_screen.dart';
import 'transaction_detail_screen.dart';

/// Extrato da conta: filtros de entrada/saída e período, gráfico de saídas
/// por categoria, e detalhe de cada movimentação ao tocar.
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  StatementDirection _direction = StatementDirection.all;
  StatementPeriod _period = StatementPeriod.all;

  String _directionLabel(StatementDirection d) {
    switch (d) {
      case StatementDirection.all:
        return 'Todas';
      case StatementDirection.inflow:
        return 'Entradas';
      case StatementDirection.outflow:
        return 'Saídas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final all = wallet.transactions;
    final list = filterTransactions(all, direction: _direction, period: _period);
    final totals = outflowByCategory(
      filterTransactions(all, direction: StatementDirection.outflow, period: _period),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato'),
        actions: [
          IconButton(
            tooltip: 'Transferências e boletos',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransfersScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in StatementDirection.values)
                  ChoiceChip(
                    label: Text(_directionLabel(d)),
                    selected: _direction == d,
                    onSelected: (_) => setState(() => _direction = d),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in StatementPeriod.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _period == p,
                    onSelected: (_) => setState(() => _period = p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (totals.isNotEmpty) ...[
              _SpendingChart(totals: totals),
              const SizedBox(height: 16),
            ],
            if (list.isEmpty && all.isEmpty && wallet.syncError != null)
              StateView.error(
                message: wallet.syncError!,
                onAction: wallet.refreshFromServer,
              )
            else if (list.isEmpty)
              StateView.empty(
                icon: Icons.receipt_long_outlined,
                title: all.isEmpty ? 'Sem movimentações ainda' : 'Nada com esses filtros',
                message: all.isEmpty
                    ? 'Suas entradas e saídas aparecem aqui.'
                    : 'Tente outro período ou tipo de movimentação.',
              )
            else
              for (var i = 0; i < list.length; i++)
                FadeSlideIn(
                  key: ValueKey(list[i].id),
                  delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(transaction: list[i]),
                      ),
                    ),
                    child: TransactionTile(transaction: list[i]),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Barras horizontais: quanto saiu em cada categoria no período.
class _SpendingChart extends StatelessWidget {
  final List<CategoryTotal> totals;

  const _SpendingChart({required this.totals});

  @override
  Widget build(BuildContext context) {
    final top = totals.first.amount;
    final total = totals.fold<double>(0, (sum, t) => sum + t.amount);
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Para onde foi o dinheiro',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Total de saídas: ${brl(total)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final t in totals) ...[
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(t.label, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          height: 10,
                          width: constraints.maxWidth * (t.amount / top),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(brl(t.amount), style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
