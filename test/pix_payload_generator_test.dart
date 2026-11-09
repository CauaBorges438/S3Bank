import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/pix_payload_generator.dart';

/// CRC16-CCITT (0x1021, inicial 0xFFFF), escrito de forma independente
/// do código do app para conferir o checksum do payload.
String crc16(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Lê um texto no formato EMV (id de 2 dígitos + tamanho de 2 dígitos +
/// valor) e garante que os tamanhos declarados batem com o conteúdo.
Map<String, String> parseTlv(String source) {
  final fields = <String, String>{};
  var i = 0;
  while (i < source.length) {
    final id = source.substring(i, i + 2);
    final length = int.parse(source.substring(i + 2, i + 4));
    fields[id] = source.substring(i + 4, i + 4 + length);
    i += 4 + length;
  }
  expect(i, source.length, reason: 'tamanhos declarados não fecham com o texto');
  return fields;
}

String gen({
  String key = 'teste@email.com',
  String name = 'Maria Souza',
  String city = 'Sao Paulo',
  double? amount,
  String? description,
  String txId = '***',
}) {
  return PixPayloadGenerator.generate(
    pixKey: key,
    merchantName: name,
    merchantCity: city,
    amount: amount,
    description: description,
    txId: txId,
  );
}

void main() {
  test('o CRC16 de referência confere (vetor padrão "123456789" = 29B1)', () {
    expect(crc16('123456789'), '29B1');
  });

  group('estrutura do payload', () {
    test('começa com os campos obrigatórios do BR Code estático', () {
      final payload = gen();
      expect(payload.startsWith('000201'), isTrue);
      expect(payload.contains('010211'), isTrue); // QR estático
      expect(payload.contains('br.gov.bcb.pix'), isTrue);
      expect(payload.contains('5303986'), isTrue); // moeda BRL
      expect(payload.contains('5802BR'), isTrue);
    });

    test('o checksum CRC16 do final está correto', () {
      final payload = gen(amount: 25.9, description: 'Almoço');
      final body = payload.substring(0, payload.length - 4);
      expect(body.endsWith('6304'), isTrue);
      expect(payload.substring(payload.length - 4), crc16(body));
    });

    test('todos os campos têm o tamanho declarado correto', () {
      final fields = parseTlv(gen(amount: 10, description: 'Teste'));
      expect(fields['63']!.length, 4);

      final account = parseTlv(fields['26']!);
      expect(account['00'], 'br.gov.bcb.pix');
      expect(account['01'], 'teste@email.com');
      expect(account['02'], 'Teste');
    });
  });

  group('valor', () {
    test('inclui o valor com duas casas decimais', () {
      final fields = parseTlv(gen(amount: 10.5));
      expect(fields['54'], '10.50');
    });

    test('sem valor, o campo 54 não existe', () {
      final fields = parseTlv(gen());
      expect(fields.containsKey('54'), isFalse);
    });

    test('valor acima do limite do Pix dá erro', () {
      expect(() => gen(amount: 10000000000), throwsArgumentError);
    });
  });

  group('chave', () {
    test('chave vazia dá erro', () {
      expect(() => gen(key: '   '), throwsArgumentError);
    });

    test('chave com mais de 77 caracteres dá erro', () {
      expect(() => gen(key: 'a' * 78), throwsArgumentError);
    });
  });

  group('textos', () {
    test('nome e cidade perdem acentos e ficam em maiúsculas', () {
      final fields = parseTlv(gen(name: 'José da Conceição', city: 'São Paulo'));
      expect(fields['59'], 'JOSE DA CONCEICAO');
      expect(fields['60'], 'SAO PAULO');
    });

    test('nome e cidade são cortados no limite do padrão', () {
      final fields = parseTlv(gen(name: 'A' * 40, city: 'B' * 30));
      expect(fields['59']!.length, 25);
      expect(fields['60']!.length, 15);
    });

    test('descrição muito longa não estoura o limite do campo 26', () {
      final fields = parseTlv(gen(key: 'k' * 60, description: 'x' * 100));
      expect(fields['26']!.length, lessThanOrEqualTo(99));
    });

    test('txid só aceita letras e números', () {
      final fields = parseTlv(gen(txId: 'PED-123/abc'));
      final additional = parseTlv(fields['62']!);
      expect(additional['05'], 'PED123abc');
    });
  });
}
