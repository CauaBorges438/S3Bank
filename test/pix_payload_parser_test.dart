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
}
