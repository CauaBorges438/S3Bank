import 'package:flutter/material.dart';

import '../../core/notification_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/state_view.dart';

/// Escolha das notificações. Salva no aparelho ao alterar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationPrefs? _prefs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await NotificationPrefs.load();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar as preferências.');
    }
  }

  Future<void> _update(NotificationPrefs next) async {
    setState(() => _prefs = next);
    await next.save();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: SafeArea(
        child: prefs == null
            ? (_error != null
                ? StateView.error(message: _error!, onAction: _load)
                : StateView.loading())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                children: [
                  SwitchListTile(
                    title: const Text('Transações'),
                    subtitle: const Text('Pix, boletos, caixinhas e saques'),
                    value: prefs.transactions,
                    onChanged: (v) => _update(prefs.copyWith(transactions: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Mudança de nível'),
                    subtitle: const Text('Quando você sobe de nível'),
                    value: prefs.levelUp,
                    onChanged: (v) => _update(prefs.copyWith(levelUp: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Novidades e ofertas'),
                    subtitle: const Text('Dicas e promoções do S3 Bank'),
                    value: prefs.offers,
                    onChanged: (v) => _update(prefs.copyWith(offers: v)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Segurança é sempre avisada: alterações de senha e acessos novos.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
