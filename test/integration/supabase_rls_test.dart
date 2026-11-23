import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Testes de integração contra o Supabase REAL: cadastro (trigger), saldo
/// pelo livro-razão, Pix, caixinhas, chaves Pix e RLS.
///
/// Só rodam quando as credenciais são passadas por --dart-define. No CI
/// (sem as variáveis) ficam pulados.
///
/// Pré-requisitos no painel do Supabase:
///   - Migrações 0001 e 0002 executadas (SQL Editor).
///   - Authentication > Providers > Email > desligar "Confirm email".
///
/// Como rodar:
///   flutter test test/integration --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
final _enabled = _url.isNotEmpty && _anonKey.isNotEmpty;

/// Cliente isolado (sessão própria) para cada usuário de teste. O fluxo
/// implícito não exige armazenamento assíncrono, que o teste não configura.
SupabaseClient _newClient() => SupabaseClient(
      _url,
      _anonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

/// O Supabase limita a criação de contas por tempo. Quando isso acontece
/// (429), espera e tenta de novo, em vez de falhar o teste.
Future<AuthResponse> _signUpWithRetry(
  SupabaseClient client, {
  required String email,
  required String label,
}) async {
  for (var tentativa = 1; ; tentativa++) {
    try {
      return await client.auth.signUp(
        email: email,
        password: '123456',
        data: {'full_name': 'Usuário $label', 'cpf': ''},
      );
    } on AuthApiException catch (e) {
      final limitado = '${e.statusCode}' == '429' || e.code == 'over_request_rate_limit';
      if (!limitado || tentativa >= 6) rethrow;
      await Future.delayed(Duration(seconds: 20 * tentativa));
    }
  }
}

/// Cadastra um usuário único e devolve o cliente já logado.
Future<({SupabaseClient client, String uid, String email})> _signUpUser(
  String label,
) async {
  final client = _newClient();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'teste.$label.$stamp@example.com';
  final res = await _signUpWithRetry(
    client,
    email: email,
    label: label,
  );
  if (res.session == null) {
    throw StateError(
      'Cadastro não devolveu sessão. Desligue "Confirm email" em '
      'Authentication > Providers > Email no painel do Supabase.',
    );
  }
  return (client: client, uid: res.user!.id, email: email);
}

/// Id da conta do usuário logado (RLS: só enxerga a própria).
Future<String> _myAccountId(SupabaseClient client, String uid) async {
  final row = await client.from('accounts').select('id').eq('owner_id', uid).single();
  return row['id'] as String;
}

/// Saldo calculado pelo livro-razão (view account_balances).
Future<int> _balanceCents(SupabaseClient client, String accountId) async {
  final row = await client
      .from('account_balances')
      .select('balance_cents')
      .eq('account_id', accountId)
      .single();
  return (row['balance_cents'] as num).toInt();
}

/// Id da única caixinha do usuário logado.
Future<String> _onlyGoalId(SupabaseClient client) async {
  final row = await client.from('savings_goal_balances').select('goal_id').single();
  return row['goal_id'] as String;
}

/// Gera uma autorização de PIN para o usuário (cria o PIN se ainda não tiver).
Future<String> _pinAuth(SupabaseClient client) async {
  final tem = await client.rpc('has_transaction_pin');
  if (tem != true) {
    await client.rpc('set_transaction_pin', params: {'p_pin': '123456'});
  }
  return (await client.rpc('authorize_transaction_pin', params: {'p_pin': '123456'})) as String;
}

void main() {
  final skip = _enabled
      ? null
      : 'Defina SUPABASE_URL e SUPABASE_ANON_KEY com --dart-define para rodar';

  group('Supabase real', () {
    // ------------------------------------------------------------ cadastro e saldo

    test('cadastro cria perfil e conta automaticamente (trigger)', () async {
      final a = await _signUpUser('perfil');
      final profile = await a.client
          .from('profiles')
          .select('full_name')
          .eq('id', a.uid)
          .single();
      expect(profile['full_name'], 'Usuário perfil');
      expect(await _myAccountId(a.client, a.uid), isNotEmpty);
    });

    test('conta nova começa com saldo zero', () async {
      final a = await _signUpUser('zero');
      final accountId = await _myAccountId(a.client, a.uid);
      expect(await _balanceCents(a.client, accountId), 0);
    });

    test('depósito simulado aparece no saldo', () async {
      final a = await _signUpUser('deposito');
      final accountId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 100000,
        'p_description': 'teste',
      });
      expect(await _balanceCents(a.client, accountId), 100000);
    });

    // ------------------------------------------------------------ Pix

    test('Pix entre dois usuários move o saldo nas duas pontas', () async {
      final a = await _signUpUser('pixA');
      final b = await _signUpUser('pixB');
      final accA = await _myAccountId(a.client, a.uid);
      final accB = await _myAccountId(b.client, b.uid);

      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo inicial',
      });
      await a.client.rpc('pix_transfer_pin', params: {'p_auth': await _pinAuth(a.client), 
        'p_key_value': b.email,
        'p_amount_cents': 2500,
        'p_description': 'teste pix',
      });

      expect(await _balanceCents(a.client, accA), 7500);
      expect(await _balanceCents(b.client, accB), 2500);
    });

    test('Pix sem saldo é recusado pelo banco', () async {
      final a = await _signUpUser('semSaldo');
      final b = await _signUpUser('semSaldoDest');
      final accB = await _myAccountId(b.client, b.uid);
      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });

      await expectLater(
        Future(() async => a.client.rpc('pix_transfer_pin', params: {'p_auth': await _pinAuth(a.client), 
              'p_key_value': b.email,
              'p_amount_cents': 999999999,
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('saldo insuficiente'),
        )),
      );
    });

    // ------------------------------------------------------------ RLS (livro-razão)

    test('RLS: um usuário não enxerga o livro-razão de outro', () async {
      final a = await _signUpUser('rlsA');
      final b = await _signUpUser('rlsB');
      final accA = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 5000,
        'p_description': 'privado',
      });

      final visivel = await b.client
          .from('ledger_entries')
          .select('id')
          .eq('account_id', accA);
      expect(visivel, isEmpty);
    });

    test('RLS: escrita direta no livro-razão é bloqueada', () async {
      final a = await _signUpUser('escrita');
      final accountId = await _myAccountId(a.client, a.uid);

      await expectLater(
        Future(() async => a.client.from('ledger_entries').insert({
              'account_id': accountId,
              'amount_cents': 999999,
              'kind': 'deposit',
            })),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('RLS: não é possível alterar lançamentos existentes', () async {
      final a = await _signUpUser('edicao');
      final accountId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 5000,
        'p_description': 'original',
      });

      // Sem permissão de UPDATE, o banco recusa ou não altera nenhuma linha.
      try {
        final changed = await a.client
            .from('ledger_entries')
            .update({'amount_cents': 1})
            .eq('account_id', accountId)
            .select();
        expect(changed, isEmpty);
      } on PostgrestException {
        // recusado pelo banco: também é o comportamento esperado
      }
      expect(await _balanceCents(a.client, accountId), 5000);
    });

    // ------------------------------------------------------------ caixinhas

    test('caixinha: criar, guardar e resgatar movem o saldo certo', () async {
      final a = await _signUpUser('caixa');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo inicial',
      });

      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Viagem',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);

      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 3000,
        'p_direction': 'in',
      });
      expect(await _balanceCents(a.client, accId), 7000);
      final afterIn = await a.client
          .from('savings_goal_balances')
          .select('saved_cents')
          .eq('goal_id', goalId)
          .single();
      expect((afterIn['saved_cents'] as num).toInt(), 3000);

      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 1000,
        'p_direction': 'out',
      });
      expect(await _balanceCents(a.client, accId), 8000);
      final afterOut = await a.client
          .from('savings_goal_balances')
          .select('saved_cents')
          .eq('goal_id', goalId)
          .single();
      expect((afterOut['saved_cents'] as num).toInt(), 2000);
    });

    test('caixinha: guardar sem saldo é recusado', () async {
      final a = await _signUpUser('caixaSemSaldo');
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 10000,
      });
      final goalId = await _onlyGoalId(a.client);

      await expectLater(
        Future(() async => a.client.rpc('savings_move', params: {
              'p_goal_id': goalId,
              'p_amount_cents': 500,
              'p_direction': 'in',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('saldo insuficiente'),
        )),
      );
    });

    test('caixinha: resgatar mais do que o guardado é recusado', () async {
      final a = await _signUpUser('caixaResgate');
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 5000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 10000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 1000,
        'p_direction': 'in',
      });

      await expectLater(
        Future(() async => a.client.rpc('savings_move', params: {
              'p_goal_id': goalId,
              'p_amount_cents': 2000,
              'p_direction': 'out',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('valor maior que o guardado'),
        )),
      );
    });

    test('caixinha: outro usuário não vê nem movimenta a caixinha', () async {
      final a = await _signUpUser('caixaA');
      final b = await _signUpUser('caixaB');
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Privada',
        'p_target_cents': 10000,
      });
      final goalId = await _onlyGoalId(a.client);

      final visivel = await b.client.from('savings_goal_balances').select();
      expect(visivel, isEmpty);

      await expectLater(
        Future(() async => b.client.rpc('savings_move', params: {
              'p_goal_id': goalId,
              'p_amount_cents': 100,
              'p_direction': 'in',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('caixinha não encontrada'),
        )),
      );
    });

    // ------------------------------------------------------------ chaves Pix

    test('chave Pix: cadastrar, listar e remover pela própria conta', () async {
      final a = await _signUpUser('pixKey');
      final accId = await _myAccountId(a.client, a.uid);

      await a.client.from('pix_keys').insert({
        'account_id': accId,
        'key_type': 'email',
        'key_value': a.email,
      });
      final listed = await a.client.from('pix_keys').select('id').eq('key_value', a.email);
      expect(listed.length, 1);

      await a.client.from('pix_keys').delete().eq('key_value', a.email);
      final depois = await a.client.from('pix_keys').select('id').eq('key_value', a.email);
      expect(depois, isEmpty);
    });

    test('chave Pix: outro usuário não consegue cadastrar a mesma chave', () async {
      final a = await _signUpUser('pixDonoA');
      final b = await _signUpUser('pixDonoB');
      final accA = await _myAccountId(a.client, a.uid);
      final accB = await _myAccountId(b.client, b.uid);

      await a.client.from('pix_keys').insert({
        'account_id': accA,
        'key_type': 'email',
        'key_value': a.email,
      });

      await expectLater(
        Future(() async => b.client.from('pix_keys').insert({
              'account_id': accB,
              'key_type': 'email',
              'key_value': a.email,
            })),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('chave Pix: cadastro pela função register_pix_key', () async {
      final a = await _signUpUser('regKey');
      final id = await a.client.rpc('register_pix_key', params: {
        'p_key_type': 'email',
        'p_key_value': a.email,
      });
      expect(id, isNotNull);

      final listed = await a.client.from('pix_keys').select('id').eq('key_value', a.email);
      expect(listed.length, 1);
    });

    test('chave Pix: chave já usada por outra conta é recusada com mensagem clara', () async {
      final a = await _signUpUser('regDupA');
      final b = await _signUpUser('regDupB');
      await a.client.rpc('register_pix_key', params: {
        'p_key_type': 'email',
        'p_key_value': a.email,
      });

      await expectLater(
        Future(() async => b.client.rpc('register_pix_key', params: {
              'p_key_type': 'email',
              'p_key_value': a.email,
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('chave já em uso'),
        )),
      );
    });

    // ------------------------------------------------------------ gamificação

    test('gamificação: aporte em caixinha gera pontos no servidor', () async {
      final a = await _signUpUser('gamif');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 10000,
        'p_direction': 'in',
      });

      // R$ 100 -> 15 + 100/10 = 25 pontos, primeiro mês (sem bônus).
      final row = await a.client
          .from('user_progress')
          .select('tier, points, streak_months')
          .eq('account_id', accId)
          .single();
      expect(row['tier'], 'bronze');
      expect((row['points'] as num).toInt(), 25);
      expect((row['streak_months'] as num).toInt(), 1);
    });

    test('gamificação: resgatar não gera pontos', () async {
      final a = await _signUpUser('gamifResgate');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 10000,
        'p_direction': 'in',
      });
      final antes = await a.client
          .from('user_progress')
          .select('points')
          .eq('account_id', accId)
          .single();

      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 5000,
        'p_direction': 'out',
      });
      final depois = await a.client
          .from('user_progress')
          .select('points')
          .eq('account_id', accId)
          .single();
      expect(depois['points'], antes['points']);
    });

    test('gamificação: progresso de outro usuário não é visível', () async {
      final a = await _signUpUser('gamifA');
      final b = await _signUpUser('gamifB');
      final accA = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 10000,
        'p_direction': 'in',
      });
      expect(await a.client.from('user_progress').select().eq('account_id', accA), isNotEmpty);

      final visivel = await b.client.from('user_progress').select().eq('account_id', accA);
      expect(visivel, isEmpty);
    });

    test('gamificação: usuário não consegue alterar os próprios pontos', () async {
      final a = await _signUpUser('gamifEdit');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 1000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 1000,
        'p_direction': 'in',
      });

      try {
        final changed = await a.client
            .from('user_progress')
            .update({'points': 999999})
            .eq('account_id', accId)
            .select();
        expect(changed, isEmpty);
      } on PostgrestException {
        // recusado pelo banco: também é o comportamento esperado
      }
      final row = await a.client
          .from('user_progress')
          .select('points')
          .eq('account_id', accId)
          .single();
      // R$ 10 -> 15 + 10/10 = 16 pontos; o valor real continua o do servidor.
      expect((row['points'] as num).toInt(), 16);
    });

    // ------------------------------------------------------------ cobranças

    test('cobrança: cria com valor e txid, outro usuário paga e o saldo move', () async {
      final rec = await _signUpUser('cobRec');
      final pag = await _signUpUser('cobPag');
      final accRec = await _myAccountId(rec.client, rec.uid);
      final accPag = await _myAccountId(pag.client, pag.uid);
      await rec.client.from('pix_keys').insert({
        'account_id': accRec,
        'key_type': 'email',
        'key_value': rec.email,
      });
      await pag.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });

      final created = (await rec.client.rpc('create_charge', params: {
        'p_amount_cents': 2500,
        'p_description': 'teste',
        'p_expires_minutes': 30,
      })) as List;
      final txid = created.first['charge_txid'] as String;
      expect(txid.length, 25);

      final info = (await pag.client.rpc('get_charge', params: {'p_txid': txid})) as List;
      expect((info.first['charge_amount_cents'] as num).toInt(), 2500);
      expect(info.first['charge_status'], 'open');

      final paid = await pag.client.rpc('pay_charge_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_txid': txid});
      expect((paid as num).toInt(), 2500);
      expect(await _balanceCents(pag.client, accPag), 7500);
      expect(await _balanceCents(rec.client, accRec), 2500);
    });

    test('cobrança: não pode ser paga duas vezes', () async {
      final rec = await _signUpUser('cobDup');
      final pag = await _signUpUser('cobDupPag');
      final accRec = await _myAccountId(rec.client, rec.uid);
      await rec.client.from('pix_keys').insert({
        'account_id': accRec,
        'key_type': 'email',
        'key_value': rec.email,
      });
      await pag.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      final created = (await rec.client.rpc('create_charge', params: {
        'p_amount_cents': 1000,
        'p_description': 'teste',
        'p_expires_minutes': 30,
      })) as List;
      final txid = created.first['charge_txid'] as String;
      await pag.client.rpc('pay_charge_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_txid': txid});

      await expectLater(
        Future(() async => pag.client.rpc('pay_charge_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_txid': txid})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('cobrança já foi paga'),
        )),
      );
    });

    test('cobrança: expirada não pode ser paga', () async {
      final rec = await _signUpUser('cobExp');
      final pag = await _signUpUser('cobExpPag');
      final accRec = await _myAccountId(rec.client, rec.uid);
      await rec.client.from('pix_keys').insert({
        'account_id': accRec,
        'key_type': 'email',
        'key_value': rec.email,
      });
      await pag.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      // validade no passado: já nasce expirada
      final created = (await rec.client.rpc('create_charge', params: {
        'p_amount_cents': 1000,
        'p_description': 'teste',
        'p_expires_minutes': -1,
      })) as List;
      final txid = created.first['charge_txid'] as String;

      final info = (await pag.client.rpc('get_charge', params: {'p_txid': txid})) as List;
      expect(info.first['charge_status'], 'expired');

      await expectLater(
        Future(() async => pag.client.rpc('pay_charge_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_txid': txid})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('cobrança expirada'),
        )),
      );
    });

    test('cobrança: o próprio recebedor não consegue pagar a sua', () async {
      final rec = await _signUpUser('cobSelf');
      final accRec = await _myAccountId(rec.client, rec.uid);
      await rec.client.from('pix_keys').insert({
        'account_id': accRec,
        'key_type': 'email',
        'key_value': rec.email,
      });
      await rec.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      final created = (await rec.client.rpc('create_charge', params: {
        'p_amount_cents': 1000,
        'p_description': 'teste',
        'p_expires_minutes': 30,
      })) as List;
      final txid = created.first['charge_txid'] as String;

      await expectLater(
        Future(() async => rec.client.rpc('pay_charge_pin', params: {'p_auth': await _pinAuth(rec.client), 'p_txid': txid})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('própria cobrança'),
        )),
      );
    });

    test('cobrança: pagamento sem saldo é recusado', () async {
      final rec = await _signUpUser('cobSemSaldo');
      final pag = await _signUpUser('cobSemSaldoPag');
      final accRec = await _myAccountId(rec.client, rec.uid);
      await rec.client.from('pix_keys').insert({
        'account_id': accRec,
        'key_type': 'email',
        'key_value': rec.email,
      });
      final created = (await rec.client.rpc('create_charge', params: {
        'p_amount_cents': 999999,
        'p_description': 'teste',
        'p_expires_minutes': 30,
      })) as List;
      final txid = created.first['charge_txid'] as String;

      await expectLater(
        Future(() async => pag.client.rpc('pay_charge_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_txid': txid})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('saldo insuficiente'),
        )),
      );
    });

    test('cobrança: outro usuário não lê a tabela de cobranças direto', () async {
      final rec = await _signUpUser('cobRls');
      final outro = await _signUpUser('cobRlsOutro');
      final accRec = await _myAccountId(rec.client, rec.uid);
      await rec.client.from('pix_keys').insert({
        'account_id': accRec,
        'key_type': 'email',
        'key_value': rec.email,
      });
      await rec.client.rpc('create_charge', params: {
        'p_amount_cents': 1000,
        'p_description': 'privada',
        'p_expires_minutes': 30,
      });

      final visivel = await outro.client.from('pix_charges').select();
      expect(visivel, isEmpty);
    });

    // ------------------------------------------------------------ extrato: categorias

    test('extrato: saída pode ser categorizada; entrada não', () async {
      final a = await _signUpUser('catA');
      final b = await _signUpUser('catB');
      final accB = await _myAccountId(b.client, b.uid);
      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('pix_transfer_pin', params: {'p_auth': await _pinAuth(a.client), 
        'p_key_value': b.email,
        'p_amount_cents': 2500,
        'p_description': 'almoço',
      });

      final saida = await a.client
          .from('ledger_entries')
          .select('id')
          .eq('kind', 'pix_out')
          .single();
      await a.client.rpc('set_transaction_category', params: {
        'p_ledger_entry_id': saida['id'],
        'p_category': 'alimentacao',
      });
      final marcada = await a.client
          .from('transaction_categories')
          .select('category')
          .eq('ledger_entry_id', saida['id'] as String)
          .single();
      expect(marcada['category'], 'alimentacao');

      final entrada = await b.client
          .from('ledger_entries')
          .select('id')
          .eq('kind', 'pix_in')
          .single();
      await expectLater(
        Future(() async => b.client.rpc('set_transaction_category', params: {
              'p_ledger_entry_id': entrada['id'],
              'p_category': 'lazer',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('só é possível categorizar saídas'),
        )),
      );
    });

    test('extrato: categoria inválida é recusada', () async {
      final a = await _signUpUser('catInv');
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.from('ledger_entries').select('id').eq('account_id', accId);
      final dep = await a.client.from('ledger_entries').select('id').eq('kind', 'deposit').single();

      await expectLater(
        Future(() async => a.client.rpc('set_transaction_category', params: {
              'p_ledger_entry_id': dep['id'],
              'p_category': 'bobagem',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('categoria inválida'),
        )),
      );
    });

    test('extrato: não categoriza movimentação de outro usuário', () async {
      final a = await _signUpUser('catOwnA');
      final b = await _signUpUser('catOwnB');
      final accB = await _myAccountId(b.client, b.uid);
      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('pix_transfer_pin', params: {'p_auth': await _pinAuth(a.client), 
        'p_key_value': b.email,
        'p_amount_cents': 500,
        'p_description': 'teste',
      });
      final debitoDeA = await a.client
          .from('ledger_entries')
          .select('id')
          .eq('kind', 'pix_out')
          .single();

      await expectLater(
        Future(() async => b.client.rpc('set_transaction_category', params: {
              'p_ledger_entry_id': debitoDeA['id'],
              'p_category': 'lazer',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('lançamento não encontrado'),
        )),
      );
    });

    // ------------------------------------------------------------ saídas e boletos

    test('saída: transferência para outro banco debita a conta', () async {
      final a = await _signUpUser('wdA');
      final accA = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });

      await a.client.rpc('withdraw_to_bank_pin', params: {'p_auth': await _pinAuth(a.client), 
        'p_amount_cents': 3000,
        'p_bank': 'Banco Teste',
        'p_account_info': 'Ag 0001 · CC 12345-6',
      });
      expect(await _balanceCents(a.client, accA), 7000);

      final saida = await a.client
          .from('ledger_entries')
          .select('kind, description')
          .eq('kind', 'withdrawal')
          .single();
      expect((saida['description'] as String).contains('Banco Teste'), isTrue);
    });

    test('saída: limite diário de R\$ 5.000 é aplicado pelo banco', () async {
      final a = await _signUpUser('limA');
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 1000000,
        'p_description': 'saldo',
      });
      await a.client.rpc('withdraw_to_bank_pin', params: {'p_auth': await _pinAuth(a.client), 
        'p_amount_cents': 300000,
        'p_bank': 'Banco Teste',
      });

      await expectLater(
        Future(() async => a.client.rpc('withdraw_to_bank_pin', params: {'p_auth': await _pinAuth(a.client), 
              'p_amount_cents': 300000,
              'p_bank': 'Banco Teste',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('limite diário de saídas atingido'),
        )),
      );

      final resumo = (await a.client.rpc('get_money_out_summary')) as List;
      expect((resumo.first['used_cents'] as num).toInt(), 300000);
      expect((resumo.first['limit_cents'] as num).toInt(), 500000);
    });

    test('boleto: emitido por um, pago por outro, e não pode ser pago de novo', () async {
      final rec = await _signUpUser('bolRec');
      final pag = await _signUpUser('bolPag');
      final accRec = await _myAccountId(rec.client, rec.uid);
      final accPag = await _myAccountId(pag.client, pag.uid);
      await pag.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });

      final created = (await rec.client.rpc('create_boleto', params: {
        'p_amount_cents': 2500,
        'p_description': 'serviço',
        'p_due_days': 3,
      })) as List;
      final code = created.first['boleto_code'] as String;
      expect(code.length, 47);

      final info = (await pag.client.rpc('get_boleto', params: {'p_code': code})) as List;
      expect((info.first['boleto_amount_cents'] as num).toInt(), 2500);
      expect(info.first['boleto_status'], 'open');

      await pag.client.rpc('pay_boleto_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_code': code});
      expect(await _balanceCents(pag.client, accPag), 7500);
      expect(await _balanceCents(rec.client, accRec), 2500);

      await expectLater(
        Future(() async => pag.client.rpc('pay_boleto_pin', params: {'p_auth': await _pinAuth(pag.client), 'p_code': code})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('boleto já foi pago'),
        )),
      );
    });

    test('boleto: não pode pagar o próprio boleto', () async {
      final a = await _signUpUser('bolSelf');
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      final created = (await a.client.rpc('create_boleto', params: {
        'p_amount_cents': 1000,
        'p_description': 'teste',
        'p_due_days': 3,
      })) as List;
      final code = created.first['boleto_code'] as String;

      await expectLater(
        Future(() async => a.client.rpc('pay_boleto_pin', params: {'p_auth': await _pinAuth(a.client), 'p_code': code})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('próprio boleto'),
        )),
      );
    });

    test('boleto: código inexistente é recusado', () async {
      final a = await _signUpUser('bolNone');
      await expectLater(
        Future(() async => a.client.rpc('get_boleto', params: {
              'p_code': '00000000000000000000000000000000000000000000000',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('boleto não encontrado'),
        )),
      );
    });

    // ------------------------------------------------------------ perfil

    test('perfil: edita o próprio nome e não o de outro usuário', () async {
      final a = await _signUpUser('perfA');
      final b = await _signUpUser('perfB');

      await a.client.from('profiles').update({'full_name': 'Nome Novo'}).eq('id', a.uid);
      final meu = await a.client.from('profiles').select('full_name').eq('id', a.uid).single();
      expect(meu['full_name'], 'Nome Novo');

      final alterado = await b.client
          .from('profiles')
          .update({'full_name': 'Invasor'})
          .eq('id', a.uid)
          .select();
      expect(alterado, isEmpty);
    });

    // ------------------------------------------------------------ cartão de crédito

    test('cartão: cria o virtual uma vez e não cria de novo', () async {
      final a = await _signUpUser('cardA');
      final rows = (await a.client.rpc('create_virtual_card')) as List;
      final number = rows.first['card_number'] as String;
      expect(number.length, 16);
      expect(number.startsWith('5'), isTrue);
      expect((rows.first['card_cvv'] as String).length, 3);

      await expectLater(
        Future(() async => a.client.rpc('create_virtual_card')),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('cartão já criado'),
        )),
      );

      final resumo = (await a.client.rpc('get_card_summary')) as List;
      expect(resumo.first['has_card'], isTrue);
      expect(resumo.first['card_last4'], number.substring(12));
    });

    test('cartão: compra sem cartão é recusada; com cartão entra na fatura sem debitar', () async {
      final a = await _signUpUser('cardCompra');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 100000,
        'p_description': 'saldo',
      });

      await expectLater(
        Future(() async => a.client.rpc('make_card_purchase', params: {
              'p_merchant': 'Loja',
              'p_amount_cents': 5000,
              'p_category': 'compras',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('crie seu cartão virtual'),
        )),
      );

      await a.client.rpc('create_virtual_card');
      await a.client.rpc('make_card_purchase', params: {
        'p_merchant': 'Loja',
        'p_amount_cents': 5000,
        'p_category': 'compras',
      });
      // compra no crédito não tira dinheiro da conta agora
      expect(await _balanceCents(a.client, accId), 100000);
      final resumo = (await a.client.rpc('get_card_summary')) as List;
      expect((resumo.first['invoice_total_cents'] as num).toInt(), 5000);
    });

    test('cartão: respeita o limite de R\$ 3.000', () async {
      final a = await _signUpUser('cardLim');
      await a.client.rpc('create_virtual_card');
      await a.client.rpc('make_card_purchase', params: {
        'p_merchant': 'Loja',
        'p_amount_cents': 200000,
        'p_category': 'compras',
      });

      await expectLater(
        Future(() async => a.client.rpc('make_card_purchase', params: {
              'p_merchant': 'Loja',
              'p_amount_cents': 200000,
              'p_category': 'compras',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('limite do cartão insuficiente'),
        )),
      );
    });

    test('cartão: paga a fatura, debita o saldo e quita as compras', () async {
      final a = await _signUpUser('cardFat');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 200000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_virtual_card');
      await a.client.rpc('make_card_purchase', params: {
        'p_merchant': 'Mercado',
        'p_amount_cents': 50000,
        'p_category': 'alimentacao',
      });

      final resumo = (await a.client.rpc('get_card_summary')) as List;
      final mes = resumo.first['invoice_month'] as String;
      final pago = await a.client.rpc('pay_card_invoice_pin', params: {'p_auth': await _pinAuth(a.client), 'p_month': mes});
      expect((pago as num).toInt(), 50000);
      expect(await _balanceCents(a.client, accId), 150000);

      final depois = (await a.client.rpc('get_card_summary')) as List;
      expect((depois.first['invoice_total_cents'] as num).toInt(), 0);

      await expectLater(
        Future(() async => a.client.rpc('pay_card_invoice_pin', params: {'p_auth': await _pinAuth(a.client), 'p_month': mes})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('não há nada a pagar'),
        )),
      );
    });

    test('cartão: fatura sem saldo é recusada', () async {
      final a = await _signUpUser('cardSemSaldo');
      await a.client.rpc('create_virtual_card');
      await a.client.rpc('make_card_purchase', params: {
        'p_merchant': 'Loja',
        'p_amount_cents': 5000,
        'p_category': 'compras',
      });
      final resumo = (await a.client.rpc('get_card_summary')) as List;
      final mes = resumo.first['invoice_month'] as String;

      await expectLater(
        Future(() async => a.client.rpc('pay_card_invoice_pin', params: {'p_auth': await _pinAuth(a.client), 'p_month': mes})),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('saldo insuficiente'),
        )),
      );
    });

    test('cartão: outro usuário não vê as compras', () async {
      final a = await _signUpUser('cardRlsA');
      final b = await _signUpUser('cardRlsB');
      await a.client.rpc('create_virtual_card');
      await a.client.rpc('make_card_purchase', params: {
        'p_merchant': 'Privada',
        'p_amount_cents': 1000,
        'p_category': 'lazer',
      });

      final visivel = await b.client.from('card_purchases').select();
      expect(visivel, isEmpty);
    });

    // ------------------------------------------------------------ PIN de transação

    test('pin: criar, conferir e autorizar uma operação', () async {
      final a = await _signUpUser('pinOk');
      expect(await a.client.rpc('has_transaction_pin'), isFalse);
      await a.client.rpc('set_transaction_pin', params: {'p_pin': '123456'});
      expect(await a.client.rpc('has_transaction_pin'), isTrue);

      final auth = await a.client.rpc('authorize_transaction_pin', params: {'p_pin': '123456'});
      expect(auth, isNotNull);
    });

    test('pin: PIN errado não gera autorização', () async {
      final a = await _signUpUser('pinErr');
      await a.client.rpc('set_transaction_pin', params: {'p_pin': '123456'});

      final auth = await a.client.rpc('authorize_transaction_pin', params: {'p_pin': '000000'});
      expect(auth, isNull);
    });

    test('pin: autorização vale uma vez e só para a operação', () async {
      final a = await _signUpUser('pinUso');
      final b = await _signUpUser('pinUsoDest');
      final accB = await _myAccountId(b.client, b.uid);
      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('set_transaction_pin', params: {'p_pin': '123456'});
      final auth = (await a.client.rpc('authorize_transaction_pin', params: {'p_pin': '123456'})) as String;

      await a.client.rpc('pix_transfer_pin', params: {
        'p_key_value': b.email,
        'p_amount_cents': 1000,
        'p_description': 'teste',
        'p_auth': auth,
      });

      await expectLater(
        Future(() async => a.client.rpc('pix_transfer_pin', params: {
              'p_key_value': b.email,
              'p_amount_cents': 1000,
              'p_description': 'de novo',
              'p_auth': auth,
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('confirmação de PIN inválida ou expirada'),
        )),
      );
    });

    test('pin: operação sem autorização válida é recusada e não move dinheiro', () async {
      final a = await _signUpUser('pinSem');
      final b = await _signUpUser('pinSemDest');
      final accA = await _myAccountId(a.client, a.uid);
      final accB = await _myAccountId(b.client, b.uid);
      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });

      await expectLater(
        Future(() async => a.client.rpc('pix_transfer_pin', params: {
              'p_key_value': b.email,
              'p_amount_cents': 1000,
              'p_description': 'sem pin',
              'p_auth': '00000000-0000-0000-0000-000000000000',
            })),
        throwsA(isA<PostgrestException>()),
      );
      expect(await _balanceCents(a.client, accA), 10000);
      expect(await _balanceCents(b.client, accB), 0);
    });
  }, skip: skip);
}
