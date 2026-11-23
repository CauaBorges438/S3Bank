import 'dart:math';

import 'package:flutter/material.dart';

import '../services/ledger_repository.dart';

enum PixKeyType { cpf, email, phone, random }

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
// Celular brasileiro sem +55: DDD (11–99) + 9 + 8 dígitos.
final _phoneRegex = RegExp(r'^[1-9][1-9]9\d{8}$');

extension PixKeyTypeX on PixKeyType {
  String get label {
    switch (this) {
      case PixKeyType.cpf:
        return 'CPF';
      case PixKeyType.email:
        return 'E-mail';
      case PixKeyType.phone:
        return 'Celular';
      case PixKeyType.random:
        return 'Chave aleatória';
    }
  }

  String get hint {
    switch (this) {
      case PixKeyType.cpf:
        return '000.000.000-00';
      case PixKeyType.email:
        return 'nome@email.com';
      case PixKeyType.phone:
        return '(11) 91234-5678';
      case PixKeyType.random:
        return '';
    }
  }

  TextInputType get keyboardType {
    switch (this) {
      case PixKeyType.cpf:
        return TextInputType.number;
      case PixKeyType.email:
        return TextInputType.emailAddress;
      case PixKeyType.phone:
        return TextInputType.phone;
      case PixKeyType.random:
        return TextInputType.text;
    }
  }

  String get invalidMessage {
    switch (this) {
      case PixKeyType.cpf:
        return 'CPF inválido';
      case PixKeyType.email:
        return 'E-mail inválido';
      case PixKeyType.phone:
        return 'Celular inválido — use DDD + número (ex.: 11 91234-5678)';
      case PixKeyType.random:
        return 'Chave aleatória inválida';
    }
  }

  /// Devolve a chave no formato que o Pix usa (e que vai no QR Code):
  /// CPF só com dígitos, celular como +55DDDNÚMERO, e-mail e chave
  /// aleatória em minúsculo. Retorna `null` se a chave for inválida.
  String? normalize(String input) {
    final v = input.trim();
    switch (this) {
      case PixKeyType.cpf:
        final digits = v.replaceAll(RegExp(r'\D'), '');
        return _isValidCpf(digits) ? digits : null;

      case PixKeyType.email:
        final email = v.toLowerCase();
        return (email.length <= 77 && _emailRegex.hasMatch(email)) ? email : null;

      case PixKeyType.phone:
        var digits = v.replaceAll(RegExp(r'\D'), '');
        if (v.startsWith('+')) {
          if (!digits.startsWith('55')) return null; // só números do Brasil
          digits = digits.substring(2);
        } else if (digits.length > 11 && digits.startsWith('55')) {
          digits = digits.substring(2);
        }
        return _phoneRegex.hasMatch(digits) ? '+55$digits' : null;

      case PixKeyType.random:
        final uuid = v.toLowerCase();
        return _uuidRegex.hasMatch(uuid) ? uuid : null;
    }
  }
}

/// Valida CPF pelos dois dígitos verificadores.
bool _isValidCpf(String digits) {
  if (digits.length != 11) return false;
  // 111.111.111-11, 000.000.000-00 etc. passam na conta mas são inválidos.
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;

  int checkDigit(int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += int.parse(digits[i]) * (length + 1 - i);
    }
    final result = (sum * 10) % 11;
    return result == 10 ? 0 : result;
  }

  return checkDigit(9) == int.parse(digits[9]) &&
      checkDigit(10) == int.parse(digits[10]);
}

class PixKey {
  final String id;
  final PixKeyType type;

  /// Sempre normalizado (veja [PixKeyTypeX.normalize]).
  final String value;

  const PixKey({required this.id, required this.type, required this.value});

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'value': value,
      };

  factory PixKey.fromJson(Map<String, dynamic> json) => PixKey(
        id: json['id'] as String,
        type: PixKeyType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PixKeyType.random,
        ),
        value: json['value'] as String? ?? '',
      );

  /// Valor exato que vai no campo de chave do payload Pix.
  String get payloadValue => value;

  /// Valor formatado para mostrar na tela.
  String get displayValue {
    switch (type) {
      case PixKeyType.cpf:
        if (value.length != 11) return value;
        return '${value.substring(0, 3)}.${value.substring(3, 6)}.'
            '${value.substring(6, 9)}-${value.substring(9)}';
      case PixKeyType.phone:
        // +5511912345678 -> (11) 91234-5678
        if (value.length != 14) return value;
        final d = value.substring(3);
        return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
      case PixKeyType.email:
      case PixKeyType.random:
        return value;
    }
  }
}

/// Gerencia as chaves Pix do usuário, 100% em memória.
/// TODO(integração-backend): cadastro/remoção de chave Pix precisa,
/// em produção, ser validado e registrado junto ao DICT (Diretório de
/// Identificadores de Contas Transacionais) do Banco Central — algo
/// que só uma instituição autorizada pelo BC pode fazer.
class PixKeysProvider extends ChangeNotifier {
  final List<PixKey> _keys;
  int _idSeq = 0;

  PixKeysProvider() : _keys = _seedKeys();

  LedgerRepository? _ledger;
  String? _syncError;

  /// Liga as chaves ao banco. Sem isso, usa os dados locais.
  void attachLedger(LedgerRepository ledger) {
    _ledger = ledger;
    // Sem chaves de exemplo no modo banco. Antes, elas bloqueavam o cadastro
    // com "Chave já cadastrada" mesmo sem existir no banco.
    _keys.clear();
  }

  bool get isServerBacked => _ledger != null;
  String? get syncError => _syncError;

  List<PixKey> get keys => List.unmodifiable(_keys);

  /// Chave usada por padrão para gerar cobranças (a primeira cadastrada).
  PixKey? get primaryKey => _keys.isEmpty ? null : _keys.first;

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

  /// Mensagem de erro para o campo do formulário, ou `null` se estiver ok.
  String? validateInput(PixKeyType type, String input) {
    if (input.trim().isEmpty) return 'Informe o valor da chave';
    final normalized = type.normalize(input);
    if (normalized == null) return type.invalidMessage;
    if (_keys.any((k) => k.type == type && k.value == normalized)) {
      return 'Chave já cadastrada';
    }
    return null;
  }

  /// Retorna `false` (sem cadastrar) se a chave for inválida ou duplicada.
  bool addKey({required PixKeyType type, required String value}) {
    if (validateInput(type, value) != null) return false;
    _keys.add(PixKey(id: _newId(), type: type, value: type.normalize(value)!));
    notifyListeners();
    return true;
  }

  /// Chave aleatória (EVP) é gerada pelo banco, não digitada pelo usuário.
  /// Aqui geramos um UUID v4 aleatório.
  void addRandomKey() {
    _keys.add(PixKey(
      id: _newId(),
      type: PixKeyType.random,
      value: _generateUuidV4(),
    ));
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'keys': _keys.map((k) => k.toJson()).toList(),
      };

  void restore(Map<String, dynamic> json) {
    final list = (json['keys'] as List?) ?? const [];
    _keys
      ..clear()
      ..addAll(list.map((e) => PixKey.fromJson(Map<String, dynamic>.from(e as Map))));
    notifyListeners();
  }

  /// Dados de exemplo da conta de demonstração.
  void loadDemoData() {
    _keys
      ..clear()
      ..addAll(_seedKeys());
    notifyListeners();
  }

  /// Remove as chaves de exemplo para um cadastro novo.
  void resetForNewAccount() {
    if (_ledger != null) return; // no modo banco, vem do servidor
    _keys.clear();
    notifyListeners();
  }

  /// Esvazia as chaves quando alguém sai.
  void clearSession() {
    _keys.clear();
    notifyListeners();
  }

  /// Busca as chaves do banco. Sem efeito no modo local.
  Future<void> refreshFromServer() async {
    final ledger = _ledger;
    if (ledger == null) return;
    try {
      final rows = await ledger.fetchPixKeys();
      _keys
        ..clear()
        ..addAll(rows.map(_keyFromRow));
      _syncError = null;
    } on LedgerException catch (e) {
      _syncError = e.message;
    } catch (_) {
      _syncError = 'Não foi possível atualizar as chaves Pix';
    }
    notifyListeners();
  }

  /// Cadastra uma chave no banco. Retorna null em sucesso ou a mensagem de erro.
  Future<String?> addKeyRemote({required PixKeyType type, required String value}) async {
    final ledger = _ledger;
    if (ledger == null) return 'Indisponível no momento';
    final error = validateInput(type, value);
    if (error != null) return error;
    try {
      await ledger.insertPixKey(keyType: type.name, keyValue: type.normalize(value)!);
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  /// Chave aleatória gerada aqui e cadastrada no banco.
  Future<String?> addRandomKeyRemote() =>
      addKeyRemote(type: PixKeyType.random, value: _generateUuidV4());

  Future<String?> removeKeyRemote(String id) async {
    final ledger = _ledger;
    if (ledger == null) return 'Indisponível no momento';
    try {
      await ledger.deletePixKey(id);
      await refreshFromServer();
      return null;
    } on LedgerException catch (e) {
      return e.message;
    }
  }

  void removeKey(String id) {
    if (_ledger != null) {
      // No modo banco, a remoção é feita no servidor. Erros ficam em syncError.
      removeKeyRemote(id);
      return;
    }
    _keys.removeWhere((k) => k.id == id);
    notifyListeners();
  }

  static PixKey _keyFromRow(Map<String, dynamic> row) => PixKey(
        id: row['id'] as String,
        type: PixKeyType.values.firstWhere(
          (t) => t.name == row['key_type'],
          orElse: () => PixKeyType.random,
        ),
        value: row['key_value'] as String,
      );

  static String _generateUuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // versão 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static List<PixKey> _seedKeys() {
    return [
      const PixKey(id: 'k1', type: PixKeyType.email, value: 'rafaela@email.com'),
      // CPF fictício, porém com dígitos verificadores válidos (o de antes
      // era só uma máscara e não servia para gerar QR Code nem validar).
      const PixKey(id: 'k2', type: PixKeyType.cpf, value: '52998224725'),
    ];
  }
}