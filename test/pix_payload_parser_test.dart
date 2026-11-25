import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/pix_payload_generator.dart';
import 'package:s3_bank/core/pix_payload_parser.dart';

void main() {
  test('lê o QR que o próprio app gera (com valor)', () {
    final qr = PixPayloadGenerator.generate(
      pixKey: 'maria@email.com',
      merchantName: 'Maria Teste',
      merchantCity: 'SAO PAULO',
      amount: 25.5,
    );
    final parsed = PixPayloadParser.tryParse(qr);
    expect(parsed, isNotNull);
    expect(parsed!.key, 'maria@email.com');
    expect(parsed.amount, 25.5);
  });

  test('QR sem valor: o valor fica nulo para quem paga digitar', () {
    final qr = PixPayloadGenerator.generate(
      pixKey: 'maria@email.com',
      merchantName: 'Maria Teste',
      merchantCity: 'SAO PAULO',
    );
    final parsed = PixPayloadParser.tryParse(qr);
    expect(parsed, isNotNull);
    expect(parsed!.amount, isNull);
  });

  test('CRC adulterado é recusado', () {
    final qr = PixPayloadGenerator.generate(
      pixKey: 'maria@email.com',
      merchantName: 'Maria Teste',
      merchantCity: 'SAO PAULO',
      amount: 10,
    );
    final last = qr[qr.length - 1];
    final adulterado = qr.substring(0, qr.length - 1) + (last == '0' ? '1' : '0');
    expect(PixPayloadParser.tryParse(adulterado), isNull);
  });

  test('texto que não é Pix é recusado', () {
    expect(PixPayloadParser.tryParse('https://exemplo.com'), isNull);
    expect(PixPayloadParser.tryParse(''), isNull);
  });

  test('lê o identificador da cobrança (txid) do QR gerado pelo banco', () {
    const txid = 'a1b2c3d4e5f6a7b8c9d0e1f2a'; // 25 caracteres, como o banco gera
    final qr = PixPayloadGenerator.generate(
      pixKey: 'maria@email.com',
      merchantName: 'Maria Teste',
      merchantCity: 'SAO PAULO',
      amount: 12.34,
      txId: txid,
    );
    final parsed = PixPayloadParser.tryParse(qr);
    expect(parsed, isNotNull);
    expect(parsed!.txid, txid);
    expect(parsed.amount, 12.34);
  });

  test('QR sem cobrança (txid padrão ***) não tem txid', () {
    final qr = PixPayloadGenerator.generate(
      pixKey: 'maria@email.com',
      merchantName: 'Maria Teste',
      merchantCity: 'SAO PAULO',
    );
    expect(PixPayloadParser.tryParse(qr)!.txid, isNull);
  });

  // --- regressões da auditoria (BUG-001 e BUG-002) ---

  String crcHex(String s) {
    var crc = 0xFFFF;
    for (final b in s.codeUnits) {
      crc ^= (b << 8);
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  String comCrc(String corpo) {
    final semCrc = '${corpo}6304';
    return semCrc + crcHex(semCrc);
  }

  test('BUG-001: tamanho negativo de campo é recusado, sem estourar exceção', () {
    final payload = comCrc('000201' '26-1' 'xxxxxxxxxx');
    expect(() => PixPayloadParser.tryParse(payload), returnsNormally);
    expect(PixPayloadParser.tryParse(payload), isNull);
  });

  test('BUG-002: valor NaN é recusado', () {
    final payload = comCrc(
      '000201' '2633' '0014BR.GOV.BCB.PIX' '0111maria@a.com' '5403NaN',
    );
    expect(PixPayloadParser.tryParse(payload), isNull);
  });
}
