import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profile_format.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/ledger_repository.dart';
import '../../widgets/state_view.dart';

/// Dados pessoais: nome editável. CPF e e-mail aparecem, mas não mudam aqui.
class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _email = '';
  String? _cpf;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = context.read<AuthProvider>().loginIdentifier ?? '';
    try {
      final row = await LedgerRepository().fetchProfile();
      if (!mounted) return;
      setState(() {
        _email = email;
        _nameCtrl.text = (row?['full_name'] as String?) ?? '';
        _cpf = row?['cpf'] as String?;
        _phone = row?['phone'] as String?;
        _loading = false;
      });
    } on LedgerException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.length < 2) {
      messenger.showSnackBar(const SnackBar(content: Text('Informe seu nome completo.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await LedgerRepository().updateFullName(name);
      if (!mounted) return;
      context.read<AuthProvider>().setDisplayName(name);
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(content: Text('Dados atualizados.')));
    } on LedgerException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _readOnly(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados pessoais')),
      body: SafeArea(
        child: _loading
            ? StateView.loading()
            : _error != null
                ? StateView.error(message: _error!, onAction: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome completo'),
                      ),
                      const SizedBox(height: 20),
                      _readOnly('E-mail', _email.isEmpty ? 'Não informado' : _email),
                      _readOnly('CPF', maskCpf(_cpf)),
                      _readOnly('Celular', (_phone == null || _phone!.isEmpty) ? 'Não informado' : _phone!),
                      const SizedBox(height: 8),
                      const Text(
                        'Para alterar CPF, e-mail ou celular, fale com o suporte.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
