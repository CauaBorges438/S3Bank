import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/card_format.dart';
import '../../core/format.dart';
import '../../core/statement_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/card_summary.dart';
import '../../providers/credit_card_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/ledger_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/pin_gate.dart';
import '../../widgets/state_view.dart';

/// Seção de crédito dentro de "Meus cartões".
class CreditCardSection extends StatelessWidget {
  /// false = dados ocultos (padrão, como nos bancos).
  final bool revealed;

  const CreditCardSection({super.key, this.revealed = false});

  @override
  Widget build(BuildContext context) {
    final cc = context.watch<CreditCardProvider>();
    final s = cc.summary;

    if (s == null) {
      return cc.error != null
          ? StateView.error(message: cc.error!, onAction: cc.refresh)
          : StateView.loading();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CreditVisual(summary: s, revealed: revealed),
        const SizedBox(height: 14),
        _LimitCard(summary: s, revealed: revealed),
        const SizedBox(height: 14),
        if (s.hasOverdue) ...[
          _OverdueCard(summary: s, revealed: revealed),
          const SizedBox(height: 14),
        ],
        _InvoiceCard(summary: s, revealed: revealed),
        const SizedBox(height: 26),
        _PurchasesSection(purchases: cc.purchases, canBuy: s.hasCard, revealed: revealed),
      ],
    );
  }
}

/// Valor em reais, ou bolinhas quando os dados estão ocultos.
String _money(double value, bool revealed) => revealed ? brl(value) : 'R\$ ••••';

String _dateBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Pede confirmação e PIN, paga a fatura e atualiza o saldo.
Future<void> _payInvoice(
  BuildContext context, {
  required DateTime month,
  required int cents,
  required String description,
}) async {
  final cc = context.read<CreditCardProvider>();
  final wallet = context.read<WalletProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pagar fatura'),
      content: Text('Pagar ${brl(cents / 100)} $description agora? O valor sai da sua conta.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Pagar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final auth = await obtainPinAuth(context);
  if (auth == null || !context.mounted) return;

  final error = await cc.payInvoice(auth, month: month, totalCents: cents);
  if (error == null) await wallet.refreshFromServer();
  messenger.showSnackBar(SnackBar(content: Text(error ?? 'Fatura paga com sucesso.')));
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => AppCard(child: child);
}

class _LimitCard extends StatelessWidget {
  final CardSummary summary;
  final bool revealed;

  const _LimitCard({required this.summary, required this.revealed});

  @override
  Widget build(BuildContext context) {
    final ratio = summary.limitCents == 0
        ? 0.0
        : (summary.usedCents / summary.limitCents).clamp(0.0, 1.0);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Limite disponível',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _money(summary.availableCents / 100, revealed),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: AppColors.accentLight,
              backgroundColor: AppColors.surfaceElevated,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Usado ${_money(summary.usedCents / 100, revealed)} de ${_money(summary.limitCents / 100, revealed)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final CardSummary summary;
  final bool revealed;

  const _OverdueCard({required this.summary, required this.revealed});

  @override
  Widget build(BuildContext context) {
    final m = summary.overdueMonth;
    if (m == null) return const SizedBox.shrink();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Fatura em atraso · ${monthNamePt(m.month)}/${m.year}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _money(summary.overdueCents / 100, revealed),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Venceu em ${_dateBr(invoiceDueFor(m))}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _payInvoice(
              context,
              month: m,
              cents: summary.overdueCents,
              description: 'da fatura em atraso',
            ),
            child: const Text('Pagar fatura em atraso'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final CardSummary summary;
  final bool revealed;

  const _InvoiceCard({required this.summary, required this.revealed});

  @override
  Widget build(BuildContext context) {
    final m = summary.invoiceMonth;
    final open = summary.invoiceTotalCents > 0;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fatura de ${monthNamePt(m.month)}/${m.year}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _money(summary.invoiceTotalCents / 100, revealed),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Vence em ${_dateBr(summary.invoiceDue)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (open)
            FilledButton(
              onPressed: () => _payInvoice(
                context,
                month: m,
                cents: summary.invoiceTotalCents,
                description: 'da fatura',
              ),
              child: const Text('Pagar fatura'),
            )
          else
            const Text(
              'Nenhuma compra nesta fatura.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _CreditVisual extends StatelessWidget {
  final CardSummary summary;
  final bool revealed;

  const _CreditVisual({required this.summary, required this.revealed});

  static String _grouped(String number) => [
        for (var i = 0; i < number.length; i += 4)
          number.substring(i, i + 4 > number.length ? number.length : i + 4),
      ].join(' ');

  Future<void> _create(BuildContext context) async {
    final cc = context.read<CreditCardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final card = await cc.createVirtualCard();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Seu cartão virtual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _grouped(card.number),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Validade ${card.expiry}'),
              const SizedBox(height: 4),
              Text('CVV ${card.cvv}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Anote o CVV agora. Ele não será mostrado de novo.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } on LedgerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível criar o cartão. Tente de novo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = summary.hasCard;
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: has ? AppColors.accentGradient : null,
        color: has ? null : AppColors.surface,
        border: Border.all(
          color: has ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
        ),
        boxShadow: has
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: has ? _filled() : _empty(context),
    );
  }

  Widget _filled() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'S3 BANK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Crédito',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _CardChip(),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              maskedCard(summary.last4),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disponível',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      _money(summary.availableCents / 100, revealed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Validade',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    revealed ? (summary.expiry ?? '--/--') : '••/••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  Widget _empty(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_card_outlined, size: 34, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          const Text(
            'Você ainda não tem cartão de crédito',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _create(context),
            child: const Text('Criar cartão virtual'),
          ),
        ],
      );
}

class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.chipSilver, AppColors.chipSilverDark],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.wifi, color: Colors.white.withValues(alpha: 0.9), size: 20),
        ],
      );
}

class _PurchasesSection extends StatelessWidget {
  final List<CardPurchase> purchases;
  final bool canBuy;
  final bool revealed;

  const _PurchasesSection({
    required this.purchases,
    required this.canBuy,
    required this.revealed,
  });

  Future<void> _newPurchase(BuildContext context) async {
    final cc = context.read<CreditCardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var category = 'outros';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Nova compra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: merchantCtrl,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Onde foi a compra'),
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final e in kTxCategories.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setDialog(() => category = v ?? category),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    final merchant = merchantCtrl.text.trim();
    final amountText = amountCtrl.text;
    merchantCtrl.dispose();
    amountCtrl.dispose();
    if (ok != true) return;

    if (merchant.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Informe onde foi a compra.')));
      return;
    }
    final amount = parseBrMoney(amountText);
    if (amount == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    final error = await cc.purchase(
      merchant: merchant,
      amountCents: (amount * 100).round(),
      category: category,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Compra de ${brl(amount)} registrada na fatura.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Compras',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            TextButton.icon(
              onPressed: canBuy ? () => _newPurchase(context) : null,
              icon: const Icon(Icons.add),
              label: const Text('Nova compra'),
            ),
          ],
        ),
        if (!canBuy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Crie seu cartão virtual para registrar compras.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else if (purchases.isEmpty)
          StateView.empty(
            icon: Icons.shopping_bag_outlined,
            title: 'Nenhuma compra ainda',
            message: 'As compras aparecem aqui e entram na fatura do mês.',
          )
        else
          for (final p in purchases) _PurchaseTile(purchase: p, revealed: revealed),
      ],
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final CardPurchase purchase;
  final bool revealed;

  const _PurchaseTile({required this.purchase, required this.revealed});

  @override
  Widget build(BuildContext context) {
    final category = kTxCategories[purchase.category] ?? kSemCategoria;
    final d = purchase.purchasedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  purchase.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$category · ${_dateBr(d)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(purchase.amountCents / 100, revealed),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                purchase.paid ? 'Paga' : 'Na fatura',
                style: TextStyle(
                  color: purchase.paid ? AppColors.success : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
