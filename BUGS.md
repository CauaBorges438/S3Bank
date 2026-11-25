# BUGS — S3 Bank

Severidades: crítica, alta, média, baixa. Ordenado por severidade.

## Crítica

| ID | Arquivo / linha | Descrição | Impacto | Situação | Teste |
|----|-----------------|-----------|---------|----------|-------|
| C-01 | `supabase/migrations/0001_schema.sql` L162–163 | `simulate_deposit` concedida a `authenticated`. Qualquer usuário logado cria saldo. | Criação de dinheiro sem pagador, em qualquer conta. | **Pendente (ação manual).** Revogar após os testes de integração usarem uma chave de serviço para depósitos de teste. Comando: `revoke execute on function public.simulate_deposit(bigint, text) from authenticated;` | Integração (depósitos de teste) |

## Alta

| ID | Arquivo / linha | Descrição | Impacto | Situação | Teste |
|----|-----------------|-----------|---------|----------|-------|
| A-01 | `lib/core/pix_payload_parser.dart` L88 | Tamanho negativo em campo TLV (ex.: `26-1`) passava na validação e causava `RangeError`, que `tryParse` não capturava. | Um QR malicioso derrubava o leitor e o app. | **Corrigido**: rejeita `len < 0`. | `test/pix_payload_parser_test.dart` — BUG-001 |
| A-02 | `lib/core/pix_payload_parser.dart` L63 | Valor `NaN` ou `Infinity` era aceito (`NaN <= 0` é falso). | Pagamento com valor inválido chegava até o cálculo de centavos. | **Corrigido**: exige `amount.isFinite`. | `test/pix_payload_parser_test.dart` — BUG-002 |

## Média

| ID | Arquivo / linha | Descrição | Impacto | Situação | Teste |
|----|-----------------|-----------|---------|----------|-------|
| M-01 | `supabase/functions/send-reset-code/index.ts` | Sem limite diário por e-mail. O limite de 5 tentativas era por código, e um código novo podia ser pedido a cada minuto. | Força bruta distribuída sobre o código de 6 dígitos. | **Corrigido**: no máximo 5 códigos por e-mail em 24 horas. | Manual (deploy e chamada repetida) |
| M-02 | `supabase/migrations/0011_transaction_pin.sql` (`pin_hash`) | PIN guardado com SHA-256 simples e sal. Não tem custo computacional. | Se o banco vazar, um PIN de 6 dígitos (10⁶ possibilidades) pode ser quebrado offline em segundos. | **Pendente.** Trocar por função lenta (pgcrypto `crypt` com `gen_salt('bf')`, ou PBKDF2 na edge function). Exige migração nova (0016) e checagem do schema `extensions` do Supabase. | — |
| M-03 | `supabase/migrations/0009_credit_card.sql` (`create_virtual_card`) | Número do cartão virtual gerado sem dígito verificador de Luhn. | Cartão com número inválido na visão real de qualquer validador. | **Pendente.** Gerar o último dígito pelo algoritmo de Luhn em migração nova. Não altera cartões já criados. | — |
| M-04 | `lib/core/boleto.dart` | Validação de boleto só checa 47 dígitos. Não confere dígitos verificadores (módulo 10 e 11). | Código de boleto inválido é aceito. | **Pendente.** Depende de decisão: aplicar a regra oficial de cada campo da linha digitável. | — |
| M-05 | `lib/services/ledger_repository.dart` (`fetchStatement`, limite 100) | Extrato carrega só 100 movimentações, sem paginação. | Movimentações antigas somem da tela. | **Pendente.** Implementar paginação por cursor (`created_at` + `id`). | — |
| M-06 | `lib/providers/auth_provider.dart` (`_mapError`, `changePassword`) | `debugPrint` com status, código e mensagem do Supabase também em build de release. | Vazamento de detalhes de autenticação em logs de dispositivo. | **Pendente.** Envolver os logs em `if (kDebugMode)`. | — |

## Baixa

| ID | Arquivo / linha | Descrição | Impacto | Situação | Teste |
|----|-----------------|-----------|---------|----------|-------|
| B-01 | `.gitignore` | Não bloqueava chaves de assinatura do Android. | Risco de versionar keystore. | **Corrigido.** | — |
| B-02 | `supabase/functions/verify-reset-code/index.ts` | Comparação do hash com `!==`, sem tempo constante. | Vazamento de tempo muito pequeno para hash de 64 caracteres. | **Pendente.** Usar comparação em tempo constante. | — |
| B-03 | `supabase/functions/verify-reset-code/index.ts` (`findUserId`) | Percorre todos os usuários a cada tentativa. | Custo alto e risco de lentidão com muitas contas. | **Pendente.** Buscar o usuário por e-mail diretamente. | — |
| B-04 | `supabase/functions/send-reset-code/index.ts` | Tempo de resposta diferente entre e-mail com conta e sem conta (quando há envio). | Enumeração de contas por tempo, de forma pequena. | **Pendente.** Aceitável para o projeto; registrar. | — |
| B-05 | `supabase/functions/*/index.ts` (CORS) | `Access-Control-Allow-Origin: *`. | Qualquer site pode chamar as funções (sem sessão, não há ganho direto). | **Aceito.** Restringir ao domínio do app se houver web em produção. | — |

## Verificado e sem falha encontrada

- Nenhuma função `security definer` sem `search_path`.
- Nenhuma política RLS com `using (true)`.
- Operações de dinheiro bloqueiam a conta (`for update`) antes de checar saldo.
- Cobrança Pix e boleto usam bloqueio na linha da cobrança, contra pagamento duplicado.
- PIN: bloqueio após 5 erros, autorização de uso único e 2 minutos, e erro na operação desfaz o consumo.
- Limite diário de saídas aplicado no banco, com fuso de São Paulo.
