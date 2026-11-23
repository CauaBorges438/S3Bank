import 'package:flutter/material.dart';
import '../../widgets/pin_gate.dart';
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
import '../../widgets/state_view.dart';

/// Seção de crédito dentro de "Meus cartões". Usa o CreditCardProvider
/// que a tela de cartões já fornece na árvore.
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

/// "1.500,00" ou "1500" -> 1500.0. Null se não for um valor positivo.
double? _parseMoney(String text) {
  final v = double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.'));
  return (v == null || v <= 0) ? null : v;
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
          LinearProgressIndicator(value: ratio, minHeight: 8),
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

class _InvoiceCard extends StatelessWidget {
  final CardSummary summary;
  final bool revealed;

  const _InvoiceCard({required this.summary, required this.revealed});

  Future<void> _pay(BuildContext context) async {
    final cc = context.read<CreditCardProvider>();
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final total = summary.invoiceTotalCents / 100;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar fatura'),
        content: Text('Pagar ${brl(total)} agora? O valor sai da sua conta.'),
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
    if (ok != true) return;

    if (!context.mounted) return;
    final auth = await obtainPinAuth(context);
    if (auth == null) return;
    final error = await cc.payInvoice(auth);
    if (error == null) await wallet.refreshFromServer();
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Fatura paga com sucesso.')));
  }

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
              onPressed: () => _pay(context),
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

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14142B), Color(0xFF3B2A7A), Color(0xFF6A4CE0)],
  );

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = summary.hasCard;
    return AspectRatio(
      aspectRatio: 1.7,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: has ? _gradient : null,
          color: has ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: has ? null : Border.all(color: AppColors.border),
        ),
        child: has ? _filled() : _empty(context),
      ),
    );
  }

  Widget _filled() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'S3 BANK',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Crédito',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            maskedCard(summary.last4),
            style: const TextStyle(fontSize: 17, letterSpacing: 2, fontWeight: FontWeight.w500),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Validade', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    revealed ? (summary.expiry ?? '--/--') : '••/••',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: merchantCtrl,
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
    if (ok != true) return;

    final amount = _parseMoney(amountCtrl.text);
    if (amount == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }
    final error = await cc.purchase(
      merchant: merchantCtrl.text,
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
                Text(purchase.merchant,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$category · ${_dateBr(d)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(purchase.amountCents / 100, revealed),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
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
