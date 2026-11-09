import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../models/transaction.dart';

// Criados uma vez só, em vez de a cada build de cada item da lista.
final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFmt = DateFormat('dd/MM • HH:mm');

class TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const TransactionTile({super.key, required this.transaction});

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.pixSent:
        return Icons.arrow_upward;
      case TransactionType.pixReceived:
        return Icons.arrow_downward;
      case TransactionType.savingsDeposit:
        return Icons.savings_outlined;
      case TransactionType.savingsWithdraw:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = transaction.isCredit ? AppColors.success : AppColors.textPrimary;
    final sign = transaction.isCredit ? '+ ' : '- ';
    final iconColor = transaction.isCredit ? AppColors.success : AppColors.accentLight;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          // withAlpha(36) ≈ 14% de opacidade. Funciona em qualquer versão
          // do Flutter; withOpacity está deprecated nas mais novas.
          color: iconColor.withAlpha(36),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_icon, color: iconColor, size: 20),
      ),
      title: Text(
        transaction.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      // O destinatário pode ser uma chave longa ou um "Copia e Cola"
      // inteiro; sem limite de linhas ele ocuparia a tela toda.
      subtitle: Text(
        '${transaction.subtitle} • ${_dateFmt.format(transaction.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        '$sign${_currencyFmt.format(transaction.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }
}