import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ledger_repository.dart';

/// Pede o PIN de transação antes de uma operação que move dinheiro.
///
/// Se a conta ainda não tem PIN, pede para criar um primeiro.
/// Devolve a autorização de uso único, ou null se o usuário cancelar
/// ou se o PIN estiver errado.
Future<String?> obtainPinAuth(BuildContext context) async {
  final ledger = LedgerRepository();
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (!await ledger.hasTransactionPin()) {
      if (!context.mounted) return null;
      final novo = await _createPin(context);
      if (novo == null) return null;
      await ledger.setTransactionPin(novo);
    }
    if (!context.mounted) return null;
    final pin = await _askPin(context);
    if (pin == null) return null;
    final auth = await ledger.authorizeTransactionPin(pin);
    if (auth == null) {
      messenger.showSnackBar(const SnackBar(content: Text('PIN incorreto.')));
    }
    return auth;
  } on LedgerException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

Future<String?> _askPin(BuildContext context) async {
  final controller = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Digite seu PIN'),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: const InputDecoration(labelText: 'PIN de 6 números'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  if (pin == null || !RegExp(r'^\d{6}$').hasMatch(pin)) return null;
  return pin;
}

Future<String?> _createPin(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final first = TextEditingController();
  final second = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Crie seu PIN de transação'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ele confirma Pix, transferências e pagamentos. Não é a senha de entrada.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: first,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(labelText: 'PIN de 6 números'),
          ),
          TextField(
            controller: second,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(labelText: 'Confirme o PIN'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(first.text),
          child: const Text('Criar PIN'),
        ),
      ],
    ),
  );
  if (pin == null) return null;
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
    messenger.showSnackBar(const SnackBar(content: Text('O PIN precisa ter 6 números.')));
    return null;
  }
  if (pin != second.text) {
    messenger.showSnackBar(const SnackBar(content: Text('Os PINs não conferem.')));
    return null;
  }
  return pin;
}
