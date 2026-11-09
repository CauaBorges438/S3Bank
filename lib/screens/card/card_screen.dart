import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/card_provider.dart';
import '../../widgets/digital_card_widget.dart';

class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final cardProvider = context.watch<CardProvider>();
    final card = cardProvider.card;

    return Scaffold(
      appBar: AppBar(title: const Text('Cartão Digital')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            DigitalCardWidget(card: card, showDetails: _showDetails),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 17,
                  color: AppColors.accentLight,
                ),
                label: Text(
                  _showDetails ? 'Ocultar dados' : 'Mostrar dados',
                  style: const TextStyle(color: AppColors.accentLight, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Faixa fina com o gradiente da marca — mesma
                    // assinatura visual usada no site.
                    Container(height: 3, decoration: const BoxDecoration(gradient: AppColors.loginGradient)),
                    _CopyRow(
                      label: 'Número do cartão',
                      value: card.groupedNumber,
                      onCopy: () => _copyToClipboard(context, card.groupedNumber, 'Número'),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _CopyRow(
                      label: 'Validade',
                      value: card.expiry,
                      onCopy: () => _copyToClipboard(context, card.expiry, 'Validade'),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _CopyRow(
                      label: 'CVV',
                      value: card.cvv,
                      onCopy: () => _copyToClipboard(context, card.cvv, 'CVV'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: AppColors.loginGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline, color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Função: Apenas Débito. O visual do cartão é atualizado automaticamente conforme seu nível de rendimento evolui.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado.')),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: IconButton(
        icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.accentLight),
        onPressed: onCopy,
      ),
    );
  }
}