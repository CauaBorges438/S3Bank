import 'package:flutter/material.dart';
import '../../widgets/pin_gate.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/boleto.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/wallet_provider.dart';
import '../../services/ledger_repository.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/state_view.dart';

/// Saídas e boletos: transferência para outro banco, boleto para receber,
/// pagamento de boleto, e o limite diário.
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  int? _limitCents;
  int? _usedCents;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    final wallet = context.read<WalletProvider>();
    try {
      final s = await wallet.moneyOutSummary();
      if (!mounted) return;
      setState(() {
        _limitCents = s.limitCents;
        _usedCents = s.usedCents;
        _summaryError = null;
      });
    } on LedgerException catch (e) {
      if (mounted) setState(() => _summaryError = e.message);
    }
  }

  /// "1.500,00" ou "1500" -> 1500.0. Null se não for um valor positivo.
  static double? _parseMoney(String text) {
    final value = double.tryParse(
      text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    return (value == null || value <= 0) ? null : value;
  }

  static String _dateBr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ transferência

  Future<void> _withdraw() async {
    final wallet = context.read<WalletProvider>();
    final amountCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final infoCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transferir para outro banco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
            TextField(
              controller: bankCtrl,
              decoration: const InputDecoration(labelText: 'Banco'),
            ),
            TextField(
              controller: infoCtrl,
              decoration: const InputDecoration(labelText: 'Agência e conta'),
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
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final amount = _parseMoney(amountCtrl.text);
    if (amount == null) {
      _snack('Informe um valor válido');
      return;
    }
    final info = infoCtrl.text.trim();
    if (!mounted) return;
    final auth = await obtainPinAuth(context);
    if (auth == null) return;
    final error = await wallet.withdrawToBank(
      amount,
      bank: bankCtrl.text,
      auth: auth,
      accountInfo: info.isEmpty ? null : info,
    );
    _snack(error ?? 'Transferência de ${brl(amount)} enviada.');
    if (error == null) _loadSummary();
  }

  // ------------------------------------------------------------ boleto para receber

  Future<void> _createBoleto() async {
    final wallet = context.read<WalletProvider>();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerar boleto para receber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
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
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final amount = _parseMoney(amountCtrl.text);
    if (amount == null) {
      _snack('Informe um valor válido');
      return;
    }
    final desc = descCtrl.text.trim();
    try {
      final boleto = await wallet.createBoleto(amount, description: desc.isEmpty ? null : desc);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Boleto gerado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valor: ${brl(amount)}'),
              Text('Vence em: ${_dateBr(boleto.due)}'),
              const SizedBox(height: 12),
              SelectableText(
                boleto.code,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: boleto.code));
                _snack('Código copiado.');
              },
              child: const Text('Copiar código'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } on LedgerException catch (e) {
      _snack(e.message);
    }
  }

  // ------------------------------------------------------------ pagar boleto

  Future<void> _payBoleto() async {
    final wallet = context.read<WalletProvider>();
    final codeCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar boleto'),
        content: TextField(
          controller: codeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Código do boleto',
            hintText: '47 números',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (!isValidBoletoCode(codeCtrl.text)) {
      _snack('O boleto tem 47 números.');
      return;
    }
    final digits = boletoDigits(codeCtrl.text);

    Map<String, dynamic> info;
    try {
      info = await wallet.getBoleto(digits);
    } on LedgerException catch (e) {
      _snack(e.message);
      return;
    }

    final amount = (info['boleto_amount_cents'] as num).toInt() / 100;
    final beneficiary = info['beneficiary_name'] as String? ?? 'Beneficiário';
    final status = info['boleto_status'] as String;
    if (status == 'paid') {
      _snack('Este boleto já foi pago.');
      return;
    }
    if (status == 'overdue') {
      _snack('Este boleto está vencido.');
      return;
    }
    if (status != 'open') {
      _snack('Boleto indisponível.');
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pagamento'),
        content: Text('Pagar ${brl(amount)} para $beneficiary?'),
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
    if (confirmed != true) return;

    if (!mounted) return;
    final auth = await obtainPinAuth(context);
    if (auth == null) return;
    final error = await wallet.payBoleto(digits, auth);
    _snack(error ?? 'Boleto de ${brl(amount)} pago.');
    if (error == null) _loadSummary();
  }

  // ------------------------------------------------------------ interface

  Widget _limitCard() {
    if (_summaryError != null) {
      return StateView.error(message: _summaryError!, onAction: _loadSummary);
    }
    final limit = _limitCents;
    final used = _usedCents;
    if (limit == null || used == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    final ratio = (used / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Limite diário de saídas',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Usado hoje: ${brl(used / 100)} de ${brl(limit / 100)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: ratio, minHeight: 8),
          const SizedBox(height: 6),
          const Text(
            'Vale para transferências para outro banco e boletos pagos.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      PressableScale(
        child: Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transferências e boletos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _limitCard(),
            const SizedBox(height: 16),
            _action(
              icon: Icons.account_balance_outlined,
              title: 'Transferir para outro banco',
              subtitle: 'Simulado: o dinheiro sai da sua conta',
              onTap: _withdraw,
            ),
            _action(
              icon: Icons.receipt_long_outlined,
              title: 'Gerar boleto para receber',
              subtitle: 'Crie um código para alguém pagar',
              onTap: _createBoleto,
            ),
            _action(
              icon: Icons.qr_code_2_outlined,
              title: 'Pagar boleto',
              subtitle: 'Digite o código de 47 números',
              onTap: _payBoleto,
            ),
          ],
        ),
      ),
    );
  }
}
