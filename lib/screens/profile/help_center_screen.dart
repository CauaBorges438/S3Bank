import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Central de ajuda: perguntas frequentes e canal de atendimento.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // Contato de atendimento. Troque pelo canal real antes de publicar.
  static const supportEmail = 'suporte@s3bank.com';

  static const _faq = [
    (
      'Como faço um Pix?',
      'Na tela Pix, toque em Enviar, escaneie o QR Code ou digite a chave. Confira o nome e o valor antes de confirmar.'
    ),
    (
      'Por que meu Pix foi recusado?',
      'Os motivos mais comuns são saldo insuficiente, chave não cadastrada ou cobrança já paga ou expirada.'
    ),
    (
      'Qual o limite de saídas?',
      'O limite diário é de R\$ 5.000,00 e vale para transferências para outro banco e boletos pagos. Pix entre contas do S3 Bank não entra no limite.'
    ),
    (
      'Como funcionam as caixinhas?',
      'Você guarda dinheiro da conta em uma caixinha e pode resgatar quando quiser. O valor guardado não sai do seu saldo total.'
    ),
    (
      'Como sobe de nível?',
      'Guardando dinheiro com regularidade. Aportes em meses seguidos aumentam seus pontos. Se passar um mês sem guardar, o bônus de constância zera, mas você não perde o nível.'
    ),
    (
      'Esqueci minha senha. E agora?',
      'Na tela de entrada, toque em "Esqueci minha senha". Enviaremos um código de 6 dígitos para o seu e-mail.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Central de ajuda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                'Perguntas frequentes',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final (question, answer) in _faq)
              Card(
                child: ExpansionTile(
                  title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Fale conosco'),
                subtitle: const Text(supportEmail),
                trailing: IconButton(
                  tooltip: 'Copiar e-mail',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: supportEmail));
                    messenger.showSnackBar(const SnackBar(content: Text('E-mail copiado.')));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
