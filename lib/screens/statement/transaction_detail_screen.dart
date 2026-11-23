import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/statement_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/transaction.dart';
import '../../providers/wallet_provider.dart';

/// Detalhe de uma movimentação. Saídas podem receber uma categoria.
class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String? _category = widget.transaction.category;
  bool _saving = false;

  Future<void> _pickCategory(String key) async {
    if (_saving) return;
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    final error = await wallet.setCategory(widget.transaction.id, key);
    if (!mounted) return;

    setState(() {
      _saving = false;
      if (error == null) _category = key;
    });
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year} às ${_two(d.hour)}:${_two(d.minute)}';

  static String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.pixSent:
        return 'Pix enviado';
      case TransactionType.pixReceived:
        return 'Pix recebido';
      case TransactionType.savingsDeposit:
        return 'Guardado em caixinha';
      case TransactionType.savingsWithdraw:
        return 'Resgatado da caixinha';
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final credit = t.isCredit;
    final color = credit ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final sign = credit ? '+' : '-';
    final currentLabel = _category == null
        ? kSemCategoria
        : (kTxCategories[_category] ?? kSemCategoria);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    '$sign ${brl(t.amount)}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _row('Descrição', t.subtitle),
            _row('Data', _formatDate(t.date.toLocal())),
            _row('Tipo', _typeLabel(t.type)),
            _row('Código', t.id.length > 8 ? t.id.substring(0, 8) : t.id),
            if (!credit) ...[
              const SizedBox(height: 24),
              const Text(
                'Categoria',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Atual: $currentLabel',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kTxCategories.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _category == e.key,
                      onSelected: _saving ? null : (_) => _pickCategory(e.key),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
