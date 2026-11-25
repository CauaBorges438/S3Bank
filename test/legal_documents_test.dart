import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/legal/legal_documents.dart';

void main() {
  test('termos e privacidade têm versão e conteúdo', () {
    expect(LegalDocuments.termsVersion, isNotEmpty);
    expect(LegalDocuments.privacyVersion, isNotEmpty);
    expect(LegalDocuments.terms, isNotEmpty);
    expect(LegalDocuments.privacy, isNotEmpty);
  });

  test('os termos deixam claro que o app não é instituição financeira', () {
    final texto = LegalDocuments.terms.map((s) => s.body).join(' ');
    expect(texto.contains('não é uma instituição financeira'), isTrue);
  });
}
