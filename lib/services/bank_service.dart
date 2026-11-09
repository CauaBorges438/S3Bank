import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/savings_goal.dart';
import '../providers/pix_keys_provider.dart';

/// Foto completa da conta do usuário, já no formato JSON que os
/// providers entendem (`restore`).
class AccountSnapshot {
  final Map<String, dynamic> user;
  final double balance;
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> savings;
  final Map<String, dynamic> pixKeys;

  /// `null` se o usuário ainda não tem cartão.
  final Map<String, String>? card;

  const AccountSnapshot({
    required this.user,
    required this.balance,
    required this.transactions,
    required this.savings,
    required this.pixKeys,
    required this.card,
  });
}

/// Acesso ao banco no Supabase. Leitura direta das tabelas (liberada
/// por RLS só para o dono) e escrita financeira SEMPRE pelas funções
/// do servidor (`enviar_pix`, `receber_pix`, `depositar_caixinha`,
/// `resgatar_caixinha`), que validam saldo e atualizam carteira,
/// extrato, pontos e nível numa única transação.
class BankService {
  final SupabaseClient _db;

  BankService([SupabaseClient? client])
      : _db = client ?? Supabase.instance.client;

  static const _txTypes = {
    'pix_enviado': 'pixSent',
    'pix_recebido': 'pixReceived',
    'deposito_caixinha': 'savingsDeposit',
    'resgate_caixinha': 'savingsWithdraw',
  };

  static const _keyTypesFromDb = {
    'cpf': 'cpf',
    'email': 'email',
    'celular': 'phone',
    'aleatoria': 'random',
  };

  static const _keyTypesToDb = {
    PixKeyType.cpf: 'cpf',
    PixKeyType.email: 'email',
    PixKeyType.phone: 'celular',
    PixKeyType.random: 'aleatoria',
  };

  static double _num(Object? v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  /// O banco devolve UTC; o app mostra a hora local.
  static String _localDate(Object? v) =>
      (DateTime.tryParse('$v') ?? DateTime.now()).toLocal().toIso8601String();

  // ------------------------------------------------------------ leitura

  Future<AccountSnapshot> load(String uid) async {
    final res = await Future.wait<dynamic>([
      _db.from('perfis').select().eq('id', uid).single(),
      _db.from('carteiras').select().eq('usuario_id', uid).single(),
      _db
          .from('transacoes')
          .select()
          .eq('usuario_id', uid)
          .order('criado_em', ascending: false)
          .limit(100),
      _db.from('caixinhas').select().eq('usuario_id', uid).order('criado_em'),
      _db.from('chaves_pix').select().eq('usuario_id', uid).order('criado_em'),
      _db.from('cartoes').select().eq('usuario_id', uid).maybeSingle(),
    ]);

    final perfil = Map<String, dynamic>.from(res[0] as Map);
    final carteira = Map<String, dynamic>.from(res[1] as Map);
    final txs = (res[2] as List).cast<Map>();
    final caixinhas = (res[3] as List).cast<Map>();
    final chaves = (res[4] as List).cast<Map>();
    final cartao = res[5] == null ? null : Map<String, dynamic>.from(res[5] as Map);

    return AccountSnapshot(
      user: {
        'name': perfil['nome'],
        'profileImageUrl': perfil['url_foto_perfil'] ?? '',
        'tier': perfil['nivel'], // bronze | prata | ouro | diamante
        'points': perfil['pontos_constancia'],
      },
      balance: _num(carteira['saldo']),
      transactions: [
        for (final t in txs)
          {
            'id': t['id'],
            'type': _txTypes[t['tipo']] ?? 'pixSent',
            'title': t['titulo'],
            'subtitle': t['subtitulo'] ?? '',
            'amount': _num(t['valor']),
            'date': _localDate(t['criado_em']),
          },
      ],
      savings: {
        'goals': [
          for (final c in caixinhas)
            {
              'id': c['id'],
              'name': c['nome'],
              'iconIndex': savingsIconNames.indexOf('${c['nome_icone']}'),
              'targetAmount': _num(c['valor_meta']),
              'currentAmount': _num(c['valor_atual']),
              'createdAt': _localDate(c['criado_em']),
            },
        ],
      },
      pixKeys: {
        'keys': [
          for (final k in chaves)
            {
              'id': k['id'],
              'type': _keyTypesFromDb[k['tipo_chave']] ?? 'random',
              'value': k['valor_chave'],
            },
        ],
      },
      card: cartao == null
          ? null
          : {
              'holderName': '${cartao['nome_titular']}',
              'cardNumber': '${cartao['numero_cartao']}',
              'expiry': '${cartao['validade']}',
              'cvv': '${cartao['cvv']}',
            },
    );
  }

  // ------------------------------------------- operações financeiras

  Future<void> enviarPix(double valor, String destinatario) async {
    await _db.rpc('enviar_pix', params: {
      'p_valor': valor,
      'p_destinatario': destinatario,
    });
  }

  Future<void> receberPix(double valor, String remetente) async {
    await _db.rpc('receber_pix', params: {
      'p_valor': valor,
      'p_remetente': remetente,
    });
  }

  Future<void> depositarCaixinha(String caixinhaId, double valor) async {
    await _db.rpc('depositar_caixinha', params: {
      'p_caixinha_id': caixinhaId,
      'p_valor': valor,
    });
  }

  Future<void> resgatarCaixinha(String caixinhaId, double valor) async {
    await _db.rpc('resgatar_caixinha', params: {
      'p_caixinha_id': caixinhaId,
      'p_valor': valor,
    });
  }

  // ------------------------------------------------ caixinhas e chaves

  Future<void> criarCaixinha({
    required String uid,
    required String nome,
    required int iconIndex,
    required double valorMeta,
  }) async {
    final i = iconIndex.clamp(0, savingsIconNames.length - 1).toInt();
    await _db.from('caixinhas').insert({
      'usuario_id': uid,
      'nome': nome,
      'nome_icone': savingsIconNames[i],
      'valor_meta': valorMeta,
    });
  }

  Future<void> adicionarChavePix({
    required String uid,
    required PixKeyType tipo,
    required String valor,
  }) async {
    await _db.from('chaves_pix').insert({
      'usuario_id': uid,
      'tipo_chave': _keyTypesToDb[tipo],
      'valor_chave': valor,
    });
  }

  Future<void> removerChavePix(String id) async {
    await _db.from('chaves_pix').delete().eq('id', id);
  }
}
