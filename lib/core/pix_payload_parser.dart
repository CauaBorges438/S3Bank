/// Dados lidos de um QR Code / "Copia e Cola" do Pix (BR Code, EMV).
class PixPayload {
  /// Chave Pix do recebedor (e-mail, CPF, celular ou chave aleatória).
  final String key;

  /// Valor fixo, se o QR trouxer um. Null quando quem paga deve digitar.
  final double? amount;

  final String? merchantName;
  final String? merchantCity;

  /// Identificador da cobrança (campo 62/05). Null em QR estático.
  final String? txid;

  const PixPayload({
    required this.key,
    this.amount,
    this.merchantName,
    this.merchantCity,
    this.txid,
  });
}

/// Lê um BR Code e confere o CRC16. Espelho de [PixPayloadGenerator].
class PixPayloadParser {
  PixPayloadParser._();

  /// Devolve null se o texto não for um Pix válido (formato ou CRC).
  static PixPayload? tryParse(String raw) {
    try {
      return parse(raw);
    } on FormatException {
      return null;
    }
  }

  static PixPayload parse(String raw) {
    final text = raw.trim();
    if (!text.startsWith('000201')) {
      throw const FormatException('Não é um BR Code');
    }

    // O CRC cobre tudo até o próprio campo "6304" (inclusive).
    if (text.length < 8 || !text.substring(0, text.length - 4).endsWith('6304')) {
      throw const FormatException('Sem campo de CRC');
    }
    final expected = text.substring(text.length - 4).toUpperCase();
    final actual = _crc16(text.substring(0, text.length - 4));
    if (expected != actual) {
      throw const FormatException('CRC inválido');
    }

    final top = _readTlv(text);
    final account = top['26'];
    if (account == null) throw const FormatException('Sem conta Pix');
    final key = _readTlv(account)['01'];
    if (key == null || key.isEmpty) throw const FormatException('Sem chave Pix');

    double? amount;
    final amountText = top['54'];
    if (amountText != null) {
      amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        throw const FormatException('Valor inválido');
      }
    }

    final additional = top['62'];
    final txid = additional == null ? null : _readTlv(additional)['05'];

    return PixPayload(
      key: key,
      amount: amount,
      merchantName: top['59'],
      merchantCity: top['60'],
      // "***" é o valor padrão do gerador quando não há cobrança.
      txid: (txid == null || txid == '***') ? null : txid,
    );
  }

  /// Lê campos no formato ID (2) + tamanho (2) + valor.
  static Map<String, String> _readTlv(String data) {
    final out = <String, String>{};
    var i = 0;
    while (i + 4 <= data.length) {
      final id = data.substring(i, i + 2);
      final len = int.tryParse(data.substring(i + 2, i + 4));
      if (len == null || i + 4 + len > data.length) {
        throw const FormatException('Campo TLV inválido');
      }
      out[id] = data.substring(i + 4, i + 4 + len);
      i += 4 + len;
    }
    return out;
  }

  /// CRC16-CCITT (0x1021, inicial 0xFFFF), igual ao do gerador.
  static String _crc16(String data) {
    const polynomial = 0x1021;
    int crc = 0xFFFF;
    for (final byte in data.codeUnits) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ polynomial) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
