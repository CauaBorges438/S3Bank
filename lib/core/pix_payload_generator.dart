/// Gera um payload no formato "Pix Copia e Cola" (BR Code / EMV QR Code),
/// seguindo a mesma estrutura de campos que os bancos usam de verdade
/// (Banco Central — Manual de Padrões para Iniciação do Pix). O código
/// resultante é estruturalmente válido (inclusive o checksum CRC16).
///
/// ATENÇÃO: este é um Pix ESTÁTICO. Se a chave informada existir de
/// verdade, qualquer banco consegue pagar esse QR Code e o dinheiro cai
/// na conta dona da chave. Em demonstração/portfólio, use uma chave
/// fictícia (como o e-mail de exemplo) para ninguém pagar por engano.
///
/// TODO(integração real): para cobranças dinâmicas (com txid único,
/// vencimento, conciliação), a cobrança precisa ser criada na API de um
/// PSP autorizado pelo Banco Central.
class PixPayloadGenerator {
  PixPayloadGenerator._();

  static String generate({
    required String pixKey,
    required String merchantName,
    required String merchantCity,
    double? amount,
    String? description,
    String txId = '***',
  }) {
    final key = pixKey.trim();
    if (key.isEmpty || key.length > 77) {
      throw ArgumentError('Chave Pix vazia ou maior que 77 caracteres.');
    }

    final buffer = StringBuffer();

    buffer.write(_field('00', '01')); // Payload Format Indicator
    buffer.write(_field('01', '11')); // Point of Initiation: QR estático

    // Merchant Account Information — dados específicos do Pix.
    // O campo 26 inteiro tem limite de 99 caracteres, então a descrição
    // só recebe o espaço que sobrar depois da chave.
    final gui = _field('00', 'br.gov.bcb.pix');
    final keyField = _field('01', key);

    var descField = '';
    if (description != null && description.trim().isNotEmpty) {
      const subfieldHeader = 4; // id (2) + tamanho (2)
      final room = 99 - gui.length - keyField.length - subfieldHeader;
      final maxDesc = room < 40 ? room : 40;
      if (maxDesc > 0) {
        final text = _sanitize(description, maxLength: maxDesc);
        if (text.isNotEmpty) descField = _field('02', text);
      }
    }
    buffer.write(_field('26', '$gui$keyField$descField'));

    buffer.write(_field('52', '0000')); // Merchant Category Code
    buffer.write(_field('53', '986')); // Moeda: Real (BRL)

    if (amount != null && amount > 0) {
      // O campo de valor aceita no máximo 13 caracteres (9999999999.99).
      if (amount > 9999999999.99) {
        throw ArgumentError('Valor acima do limite permitido pelo Pix.');
      }
      buffer.write(_field('54', amount.toStringAsFixed(2)));
    }

    buffer.write(_field('58', 'BR')); // País

    // Nome e cidade são obrigatórios; padrão dos bancos é maiúsculo.
    final name = _sanitize(merchantName, maxLength: 25).toUpperCase();
    final city = _sanitize(merchantCity, maxLength: 15).toUpperCase();
    buffer.write(_field('59', name.isEmpty ? 'NA' : name));
    buffer.write(_field('60', city.isEmpty ? 'NA' : city));

    // Additional Data Field — identificador da transação (txid).
    final txField = _field('05', _cleanTxId(txId));
    buffer.write(_field('62', txField));

    // CRC16 é calculado sobre TODO o payload até aqui, já incluindo o
    // cabeçalho do próprio campo de CRC ("6304"), mas sem o valor do CRC.
    buffer.write('6304');
    final crc = _crc16(buffer.toString());
    buffer.write(crc);

    return buffer.toString();
  }

  static String _field(String id, String value) {
    if (value.length > 99) {
      throw ArgumentError('Campo $id excede 99 caracteres.');
    }
    final length = value.length.toString().padLeft(2, '0');
    return '$id$length$value';
  }

  /// Remove acentos e qualquer caractere fora do ASCII imprimível e
  /// limita o tamanho. Acentos ocupam mais de 1 byte em UTF-8 e fazem
  /// o tamanho declarado do campo não bater com o real, o que invalida
  /// o QR Code no app do banco.
  static String _sanitize(String value, {required int maxLength}) {
    final noAccents = _stripAccents(value);
    final cleaned =
        noAccents.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength).trim()
        : cleaned;
  }

  /// txid: somente letras e números, de 1 a 25 caracteres ("***" = sem txid).
  static String _cleanTxId(String txId) {
    if (txId == '***') return txId;
    final cleaned = txId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) return '***';
    return cleaned.length > 25 ? cleaned.substring(0, 25) : cleaned;
  }

  static String _stripAccents(String input) {
    const from = 'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇç';
    const to = 'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCc';

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      buffer.write(i == -1 ? ch : to[i]);
    }
    return buffer.toString();
  }

  /// CRC16-CCITT (polinômio 0x1021, valor inicial 0xFFFF) — o mesmo
  /// algoritmo usado no padrão EMV para o checksum do BR Code.
  static String _crc16(String data) {
    const polynomial = 0x1021;
    int crc = 0xFFFF;

    for (final byte in data.codeUnits) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}