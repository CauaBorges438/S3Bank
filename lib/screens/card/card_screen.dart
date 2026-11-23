import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../animations/animations.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/card_provider.dart';
import '../../providers/credit_card_provider.dart';
import '../../services/ledger_repository.dart';
import '../../widgets/digital_card_widget.dart';
import 'credit_card_screen.dart';

/// Meus cartões: débito e crédito na mesma tela.
class CardScreen extends StatelessWidget {
  const CardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreditCardProvider(LedgerRepository())..refresh(),
      child: const _CardsView(),
    );
  }
}

class _CardsView extends StatefulWidget {
  const _CardsView();

  @override
  State<_CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<_CardsView> {
  bool _showDetails = false;

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = context.watch<CardProvider>().card;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus cartões')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<CreditCardProvider>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const _SectionLabel('Débito'),
              const SizedBox(height: 10),
              DigitalCardWidget(card: card, showDetails: _showDetails),
              const SizedBox(height: 12),
              Center(
                child: TapScale(
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
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 3,
                        decoration: const BoxDecoration(gradient: AppColors.loginGradient),
                      ),
                      _CopyRow(
                        label: 'Número do cartão',
                        value: _showDetails ? card.groupedNumber : card.maskedNumber,
                        onCopy: () => _copy(context, card.groupedNumber, 'Número'),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _CopyRow(
                        label: 'Validade',
                        value: _showDetails ? card.expiry : '••/••',
                        onCopy: () => _copy(context, card.expiry, 'Validade'),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _CopyRow(
                        label: 'CVV',
                        value: _showDetails ? card.cvv : '•••',
                        onCopy: () => _copy(context, card.cvv, 'CVV'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const _SectionLabel('Crédito'),
              const SizedBox(height: 10),
              CreditCardSection(revealed: _showDetails),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
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
