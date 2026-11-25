import 'package:flutter/material.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/theme/app_colors.dart';

/// Exibe termos ou política de privacidade, com a versão no fim.
class LegalScreen extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;
  final String version;

  const LegalScreen({
    super.key,
    required this.title,
    required this.sections,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            for (final s in sections) ...[
              Text(
                s.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                s.body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Versão $version',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
