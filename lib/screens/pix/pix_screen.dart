import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/pin_gate.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/pix_payload_parser.dart';
import '../../services/ledger_repository.dart';
import 'qr_scanner_screen.dart';
import '../../animations/animations.dart';
import '../../core/pix_payload_generator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_input_formatter.dart';
import '../../providers/pix_keys_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/success_dialog.dart';
import '../../widgets/transaction_tile.dart';
import '../../models/transaction.dart';

// Dados usados na geração da cobrança. O nome do recebedor vem do usuário
// logado (UserProvider.name) e a chave Pix de "Minhas Chaves"
// (PixKeysProvider.primaryKey). A cidade ainda é fixa porque o cadastro não
// coleta esse dado.
const _kMerchantCity = 'SAO PAULO';

final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class PixScreen extends StatelessWidget {
  const PixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final pixTransactions = wallet.transactions
        .where((t) =>
            t.type == TransactionType.pixSent || t.type == TransactionType.pixReceived)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Área Pix')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // 1.45 (antes 1.7) evita overflow do texto em telas estreitas.
              childAspectRatio: 1.45,
              children: [
                _PixActionCard(
                  icon: Icons.arrow_upward,
                  title: 'Pagar / Transferir',
                  subtitle: 'Chave, Copia e Cola ou QR Code',
                  onTap: () => _showPayModal(context),
                ),
                _PixActionCard(
                  icon: Icons.arrow_downward,
                  title: 'Receber / Cobrar',
                  subtitle: 'Gerar QR Code ou chave',
                  onTap: () => _showReceiveModal(context),
                ),
                _PixActionCard(
                  icon: Icons.vpn_key_outlined,
                  title: 'Minhas Chaves',
                  subtitle: 'Gerenciar chaves Pix',
                  onTap: () => _showKeysModal(context),
                ),
                _PixActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'QR Code',
                  subtitle: 'Escanear para pagar',
                  onTap: () => _scanQr(context),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Histórico Pix',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (pixTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nenhuma transação Pix ainda.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...pixTransactions.map((t) => TransactionTile(transaction: t)),
          ],
        ),
      ),
    );
  }

  /// Abre a câmera, lê o QR Code do Pix e abre o pagamento já preenchido.
  Future<void> _scanQr(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (raw == null || !context.mounted) return;

    final parsed = PixPayloadParser.tryParse(raw);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este QR Code não é um Pix válido.')),
      );
      return;
    }
    if (parsed.txid != null) {
      await _payChargeFromQr(context, parsed.txid!);
      return;
    }
    _showPayModal(context, prefill: parsed);
  }

  /// Cobrança com valor e validade: mostra quem recebe e quanto, e só paga
  /// se a pessoa confirmar.
  Future<void> _payChargeFromQr(BuildContext context, String txid) async {
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (!wallet.isServerBacked) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cobranças exigem conexão com o banco.')),
      );
      return;
    }

    Map<String, dynamic> info;
    try {
      info = await wallet.getCharge(txid);
    } on LedgerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    final amount = (info['charge_amount_cents'] as num).toInt() / 100;
    final name = info['receiver_name'] as String? ?? 'Destinatário';
    final description = info['charge_description'] as String?;
    final status = info['charge_status'] as String;
    final expiresAt = DateTime.parse(info['charge_expires_at'] as String);

    if (status != 'open' || expiresAt.isBefore(DateTime.now())) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Esta cobrança não está mais disponível.')),
      );
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pagamento'),
        content: Text(
          'Pagar ${_brl(amount)} para $name?'
          '${description == null ? '' : '\n$description'}',
        ),
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

    if (!context.mounted) return;
    final auth = await obtainPinAuth(context);
    if (auth == null) return;
    final error = await wallet.payCharge(txid, auth);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Pagamento de ${_brl(amount)} enviado!')),
    );
  }

  static String _brl(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Valor no formato do campo (ex.: 25,50).
  static String _amountField(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  void _showPayModal(BuildContext context, {PixPayload? prefill}) {
    final wallet = context.read<WalletProvider>();
    final recipientController = TextEditingController(text: prefill?.key ?? '');
    final amountController = TextEditingController(
      text: prefill?.amount != null ? _amountField(prefill!.amount!) : '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                  const Text('Pagar / Transferir',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: recipientController,
                    readOnly: prefill != null,
                    decoration: const InputDecoration(
                      labelText: 'Chave Pix, e-mail ou "Copia e Cola"',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o destinatário' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    readOnly: prefill?.amount != null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter(maxDigits: 12)],
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                    ),
                    validator: (v) {
                      final value = _parseAmount(v);
                      if (value == null || value <= 0) return 'Valor inválido';
                      if (value > wallet.balance) return 'Saldo insuficiente';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Confirmar pagamento',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      // Aceita chave, e-mail ou o "Copia e Cola" inteiro do QR.
                      final typed = recipientController.text.trim();
                      final parsed = PixPayloadParser.tryParse(typed);
                      if (parsed?.txid != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Para pagar uma cobrança, use a câmera (QR Code).'),
                          ),
                        );
                        return;
                      }
                      final recipient = parsed?.key ?? typed;
                      final amount = parsed?.amount ?? _parseAmount(amountController.text)!;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Informe um valor maior que zero.')),
                        );
                        return;
                      }
                      if (amount > wallet.balance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saldo insuficiente para este Pix.')),
                        );
                        return;
                      }
                      // Fecha o painel antes de pedir o PIN: o diálogo do PIN não
                      // pode nascer por cima de um painel que está sendo fechado.
                      Navigator.of(ctx).pop();
                      if (!context.mounted) return;
                      final auth = await obtainPinAuth(context);
                      if (auth == null) return;
                      final error = await wallet.payPix(amount, recipient: recipient, auth: auth);
                      if (!context.mounted) return;
                      if (error == null) {
                        HapticFeedback.mediumImpact();
                        // O "Copia e Cola" pode ser enorme: encurta no aviso.
                        final shown = recipient.length > 40
                            ? '${recipient.substring(0, 37)}...'
                            : recipient;
                        showSuccessDialog(
                          context,
                          title: 'Pix enviado!',
                          subtitle: '${_currencyFmt.format(amount)} para $shown',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Só descarta depois da animação de fechamento do painel.
      Future.delayed(const Duration(milliseconds: 500), () {
        recipientController.dispose();
        amountController.dispose();
      });
    });
  }

  void _showReceiveModal(BuildContext context) {
    final wallet = context.read<WalletProvider>();
    final receiveKey = context.read<PixKeysProvider>().primaryKey;
    final merchantName = context.read<UserProvider>().name;
    if (receiveKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre uma chave Pix em "Minhas Chaves" para receber.'),
        ),
      );
      return;
    }
    final senderController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // O payload só existe depois que a cobrança é "gerada" — antes
    // disso mostramos o formulário; depois, o QR Code real.
    // Fica FORA do builder para não resetar se o builder for reconstruído
    // (ex.: teclado fechando ao trocar de formulário para o QR).
    String? generatedPayload;

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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: generatedPayload == null
                    ? _buildChargeForm(
                        formKey: formKey,
                        senderController: senderController,
                        amountController: amountController,
                        onGenerate: () async {
                          if (!formKey.currentState!.validate()) return;
                          final amount = _parseAmount(amountController.text)!;
                          final sender = senderController.text.trim();
                          final description = sender.isEmpty ? null : 'Cobranca de $sender';
                          String payload;
                          if (wallet.isServerBacked) {
                            try {
                              final charge = await wallet.createCharge(
                                amount: amount,
                                description: description,
                              );
                              payload = PixPayloadGenerator.generate(
                                pixKey: charge.pixKey,
                                merchantName: merchantName,
                                merchantCity: _kMerchantCity,
                                amount: amount,
                                description: description,
                                txId: charge.txid,
                              );
                            } on LedgerException catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                              return;
                            }
                          } else {
                            payload = PixPayloadGenerator.generate(
                              pixKey: receiveKey.payloadValue,
                              merchantName: merchantName,
                              merchantCity: _kMerchantCity,
                              amount: amount,
                              description: description,
                            );
                          }
                          if (!ctx.mounted) return;
                          setState(() => generatedPayload = payload);
                        },
                      )
                    : _buildQrResult(
                        payload: generatedPayload!,
                        amount: _parseAmount(amountController.text)!,
                        onSimulatePayment: () async {
                          final amount = _parseAmount(amountController.text)!;
                          final sender = senderController.text.trim().isEmpty
                              ? 'Recebimento Pix'
                              : senderController.text.trim();
                          final error = await wallet.receiveSimulatedPix(amount, sender: sender);
                          if (!ctx.mounted || !context.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error ?? 'Pagamento simulado com sucesso!'),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      senderController.dispose();
      amountController.dispose();
    });
  }

  Widget _buildChargeForm({
    required GlobalKey<FormState> formKey,
    required TextEditingController senderController,
    required TextEditingController amountController,
    required VoidCallback onGenerate,
  }) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Receber / Cobrar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          TextFormField(
            controller: senderController,
            decoration: const InputDecoration(labelText: 'De quem (opcional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter(maxDigits: 12)],
            decoration: const InputDecoration(
              labelText: 'Valor a cobrar (R\$)',
              hintText: '0,00',
              prefixText: 'R\$ ',
            ),
            validator: (v) {
              final value = _parseAmount(v);
              if (value == null || value <= 0) return 'Valor inválido';
              return null;
            },
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Gerar QR Code', onTap: onGenerate),
        ],
      ),
    );
  }

  Widget _buildQrResult({
    required String payload,
    required double amount,
    required VoidCallback onSimulatePayment,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Cobrança Pix gerada',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          _currencyFmt.format(amount),
          style: const TextStyle(
            color: AppColors.accentLight,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 16),
        // Moldura com o gradiente da marca em volta do QR Code — o
        // miolo continua branco puro, que é o que garante a leitura
        // do código por qualquer leitor de QR.
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: AppColors.loginGradient,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  payload,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              _CopyIconButton(text: payload),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Peça para quem vai te pagar escanear o QR Code ou colar o\n'
          'código "copia e cola" no app do banco dele.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        // Só em modo de desenvolvimento: este botão credita dinheiro sem
        // pagador. Em produção ele não pode aparecer.
        if (kDebugMode) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSimulatePayment,
              child: const Text('Simular pagamento recebido (teste)'),
            ),
          ),
        ],
      ],
    );
  }

  void _showKeysModal(BuildContext context) {
    final keysProvider = context.read<PixKeysProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: keysProvider,
          builder: (ctx, _) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Minhas Chaves Pix',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 12),
                    if (keysProvider.keys.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Nenhuma chave cadastrada ainda.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...keysProvider.keys.map(
                        (k) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              gradient: AppColors.loginGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.vpn_key_outlined,
                                color: Colors.white, size: 17),
                          ),
                          title: Text(k.type.label),
                          subtitle: Text(k.displayValue,
                              style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: IconButton(
                            tooltip: 'Remover chave',
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: AppColors.textSecondary),
                            onPressed: () => keysProvider.removeKey(k.id),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showAddKeyModal(context, keysProvider),
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar nova chave'),
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

  void _showAddKeyModal(BuildContext context, PixKeysProvider keysProvider) {
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    PixKeyType selectedType = PixKeyType.email;

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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                      const Text('Nova chave Pix',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PixKeyType>(
                        initialValue: selectedType,
                        items: PixKeyType.values
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                            .toList(),
                        // CORREÇÃO: removido formKey.currentState?.reset(), que
                        // resetava o próprio dropdown de volta para "E-mail".
                        // O campo de texto abaixo é recriado via ValueKey, o que
                        // já limpa o erro de validação ao trocar o tipo.
                        onChanged: (v) {
                          if (v == null) return;
                          valueController.clear();
                          setState(() => selectedType = v);
                        },
                        decoration: const InputDecoration(labelText: 'Tipo de chave'),
                      ),
                      const SizedBox(height: 12),
                      if (selectedType == PixKeyType.random)
                        const Text(
                          'Uma chave aleatória será gerada automaticamente ao salvar.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        )
                      else
                        TextFormField(
                          key: ValueKey(selectedType),
                          controller: valueController,
                          keyboardType: selectedType.keyboardType,
                          decoration: InputDecoration(
                            labelText: 'Valor da chave',
                            hintText: selectedType.hint,
                          ),
                          validator: (v) =>
                              keysProvider.validateInput(selectedType, v ?? ''),
                        ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: 'Salvar chave',
                        onTap: () async {
                          if (!formKey.currentState!.validate()) return;
                          String? error;
                          if (keysProvider.isServerBacked) {
                            error = selectedType == PixKeyType.random
                                ? await keysProvider.addRandomKeyRemote()
                                : await keysProvider.addKeyRemote(
                                    type: selectedType,
                                    value: valueController.text.trim(),
                                  );
                          } else if (selectedType == PixKeyType.random) {
                            keysProvider.addRandomKey();
                          } else {
                            keysProvider.addKey(
                              type: selectedType,
                              value: valueController.text.trim(),
                            );
                          }
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (error != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      valueController.dispose();
    });
  }
}

class _PixActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PixActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Material + InkWell: o efeito de toque (ripple) fica visível.
    // Com Container decorado dentro do InkWell, a cor cobria o ripple.
    return TapScale(
      child: Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: AppColors.loginGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Botão de copiar com feedback visual. Antes usava SnackBar, mas ele
/// aparecia ATRÁS do bottom sheet e o usuário não via nada.
class _CopyIconButton extends StatefulWidget {
  final String text;
  const _CopyIconButton({required this.text});

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _copied ? 'Copiado!' : 'Copiar código Pix',
      icon: Icon(
        _copied ? Icons.check : Icons.copy_outlined,
        size: 18,
        color: AppColors.accentLight,
      ),
      onPressed: _copy,
    );
  }
}

/// Converte "5.000,50" -> 5000.5 (arredondado para centavos).
double? _parseAmount(String? v) {
  if (v == null) return null;
  var s = v.trim().replaceAll('.', '').replaceAll(',', '.');
  if (s.isEmpty) return null;
  if (s.endsWith('.')) s = '${s}0'; // "5," -> "5.0"
  final parsed = double.tryParse(s);
  if (parsed == null) return null;
  return (parsed * 100).round() / 100;
}