<div align="center">

# S3 Bank

**Conta digital com gamificação de constância, construída em Flutter e Supabase.**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Status](https://img.shields.io/badge/Status-Protótipo_acadêmico-3355D3?style=for-the-badge)
[![CI](https://github.com/camposdevs/S3_Bank_flutter/actions/workflows/flutter.yml/badge.svg)](https://github.com/camposdevs/S3_Bank_flutter/actions/workflows/flutter.yml)

</div>

---

> **Aviso:** este é um projeto acadêmico (Trabalho de Conclusão de Curso). Não é uma
> instituição financeira, não está autorizado pelo Banco Central do Brasil e não realiza
> transferências reais para outras instituições. Todos os valores são simulados.

## Sobre o projeto

O S3 Bank é um aplicativo de conta digital em que a constância no hábito de guardar dinheiro
define o nível do usuário, e o nível define o percentual do CDI que as caixinhas rendem.

O projeto demonstra, de ponta a ponta, uma arquitetura bancária simplificada: livro-razão
imutável, regras de negócio no banco de dados, autorização de operações por PIN e isolamento
de dados entre usuários com Row Level Security.

## Funcionalidades

| Área | O que o app faz |
|------|-----------------|
| **Conta e acesso** | Cadastro com nome, CPF, celular e e-mail. Login, sessão persistente e logout. Recuperação de senha por código enviado por e-mail. |
| **Termos e privacidade** | Aceite obrigatório no cadastro, com versão e data registradas. Textos acessíveis pela Central de ajuda. |
| **PIN de transação** | PIN de 6 números, criado no primeiro uso. Exigido em Pix, cobrança, transferência, boleto e pagamento de fatura. Bloqueio de 15 minutos após 5 erros. |
| **Pix** | Envio por chave (e-mail, CPF, celular ou chave aleatória), leitura de QR Code com a câmera e copia e cola no padrão BR Code (com CRC16). |
| **Cobrança Pix** | Receber com valor e validade de 30 minutos. Quem paga vê o nome do recebedor antes de confirmar. Cada cobrança é paga uma única vez. |
| **Caixinhas** | Metas, aportes e resgates. O saldo de cada caixinha é calculado pelo livro-razão. |
| **Boletos** | Emitir um boleto para receber e pagar um boleto pelo código de 47 números. |
| **Saques** | Transferência simulada para outro banco, com limite diário de R$ 5.000,00. |
| **Cartão de débito** | Visual que muda com o nível. Número, validade e CVV ficam ocultos até o usuário pedir. |
| **Cartão de crédito** | Limite de R$ 3.000,00, fatura mensal com vencimento no dia 10, compras e cartão virtual (o CVV é mostrado uma única vez). |
| **Extrato** | Filtros por tipo (entradas e saídas) e por período. Gráfico de saídas por categoria. Detalhe de cada movimentação, com categorização das saídas. |
| **Gamificação** | Pontos por aporte, bônus de constância mensal e níveis Bronze, Prata, Ouro e Diamante. |

## Regras de negócio

| Regra | Valor |
|-------|-------|
| Pontos por aporte em caixinha | `15 + valor em reais / 10` |
| Bônus de constância | +10% por mês seguido de aportes, até +50% |
| Quebra de constância | Zera o bônus. Os pontos acumulados e o nível não são perdidos |
| Níveis (pontos para subir) | Bronze → Prata: 300 · Prata → Ouro: 700 · Ouro → Diamante: 1.500 |
| Limite diário de saídas | R$ 5.000,00 (transferências para outro banco e boletos pagos) |
| Limite do cartão de crédito | R$ 3.000,00 |
| Vencimento da fatura | Dia 10 do mês seguinte |
| Validade da cobrança Pix | 30 minutos |
| Validade do boleto | 3 dias |
| Validade da autorização de PIN | 2 minutos, uso único |

## Arquitetura

```
┌──────────────────────┐        ┌─────────────────────────────────────┐        ┌──────────┐
│  App Flutter         │  HTTPS │  Supabase                           │  API   │  Resend  │
│  Provider (estado)   │ ─────► │  Auth · Postgres (RLS) · Functions  │ ─────► │ (e-mail) │
│  Armazenamento seguro│        │                                     │        └──────────┘
└──────────────────────┘        └─────────────────────────────────────┘
```

**Princípios adotados**

- **Livro-razão imutável.** O app não edita saldos. Toda movimentação é um lançamento, e o
  saldo é a soma dos lançamentos.
- **Regras no banco.** Operações financeiras são funções SQL (`SECURITY DEFINER`) que validam
  saldo, limites, expiração e autorização de PIN dentro de uma única transação.
- **Isolamento por usuário.** Row Level Security em todas as tabelas. Um usuário nunca lê nem
  altera dados de outro.
- **Segredos fora do cliente.** Hashes de senha e PIN, chaves de API de e-mail e o CVV do cartão
  nunca ficam no aplicativo.

### Estrutura do código

```
lib/
├── core/            # Regras puras: formatação, validadores, níveis, PIX (BR Code), termos
├── models/          # Modelos de transação, nível e resumo do cartão
├── providers/       # Estado da aplicação (Provider)
├── services/        # Acesso ao Supabase (LedgerRepository) e coordenação de dados por conta
├── screens/         # Telas, agrupadas por funcionalidade
├── widgets/         # Componentes reutilizáveis (cartões, estados de tela, aviso de PIN)
└── main.dart        # Inicialização do Supabase, providers e bloqueio por biometria
supabase/
├── migrations/      # Schema, regras e funções, em ordem numérica
└── functions/       # Edge Functions de recuperação de senha (envio e confirmação do código)
test/                # Testes unitários e de integração contra o Supabase
```

## Tecnologias

- **Flutter** e **Dart**, com Material 3 em tema escuro
- **Provider** para gerenciamento de estado
- **Supabase**: autenticação, Postgres com RLS e Edge Functions em Deno
- **Resend**: envio de e-mails transacionais
- **mobile_scanner** (leitura de QR Code), **local_auth** (biometria) e **flutter_secure_storage**
  (armazenamento seguro da sessão)

## Segurança

- Senhas de acesso são gerenciadas pelo Supabase Auth. O PIN de transação e os códigos de
  recuperação são guardados apenas como hash com sal.
- O PIN é conferido no banco. Após 5 erros, fica bloqueado por 15 minutos.
- Cada autorização de PIN vale uma vez e por 2 minutos. Se a operação falhar, a autorização
  não é consumida.
- O CVV do cartão virtual é guardado apenas como hash e exibido uma única vez.
- Os códigos de recuperação de senha expiram em 10 minutos e aceitam até 5 tentativas.
- A sessão de acesso fica no armazenamento seguro do aparelho, e o bloqueio por biometria é
  aplicado ao abrir o app em aparelhos que a suportam.

## Como rodar

### Pré-requisitos

- Flutter `>= 3.35` (Dart `>= 3.9`)
- Node.js (para a CLI do Supabase)
- Uma conta no [Supabase](https://supabase.com) e uma no [Resend](https://resend.com)

### 1. Clonar e instalar dependências

```bash
git clone https://github.com/camposdevs/S3_Bank_flutter.git
cd S3_Bank_flutter
flutter pub get
```

### 2. Configurar o Supabase

1. Crie um projeto no Supabase.
2. No **SQL Editor**, execute os arquivos de `supabase/migrations/` **em ordem numérica**, do
   `0001` ao `0015`. Cada um deve terminar com "Success".
3. Em **Authentication > Providers > Email**, desative a confirmação por e-mail para testes.
4. Em **Authentication > Email Templates**, confira que o modelo de recuperação de senha contém
   `{{ .Token }}`.

### 3. Publicar as Edge Functions

```bash
npx supabase login
npx supabase link --project-ref SEU_PROJECT_REF
npx supabase secrets set RESEND_API_KEY=re_sua_chave
npx supabase secrets set RESEND_FROM="S3 Bank <nao-responda@seudominio.com>"
npx supabase functions deploy send-reset-code --no-verify-jwt
npx supabase functions deploy verify-reset-code --no-verify-jwt
```

O envio de e-mail só entrega para o próprio e-mail da conta do Resend enquanto não houver
um domínio verificado.

### 4. Apontar o app para o seu projeto

Edite `lib/core/config/supabase_config.dart` com a URL do projeto e a chave pública
(`publishable` ou `anon`), disponíveis em **Project Settings > API Keys**. A chave pública
pode ficar no aplicativo. A segurança depende das regras de RLS, e não de esconder essa chave.

### 5. Executar

```bash
flutter run                 # Android (emulador ou aparelho)
flutter run -d chrome       # navegador
```

No navegador, a biometria é desligada automaticamente.

## Testes

```bash
flutter analyze
flutter test                # unitários: regras, validadores, formatação e providers
```

Os testes de integração rodam contra um projeto Supabase real. Eles criam contas de teste a
cada execução, por isso são pulados quando as credenciais não são informadas:

```bash
flutter test test/integration \
  --dart-define=SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_PUBLICA
```

Os testes de integração cobrem as regras do banco: isolamento entre usuários, saldo, Pix,
caixinhas, boletos, cartão de crédito, limites, PIN e cobranças.

## Integração contínua

O workflow `.github/workflows/flutter.yml` roda `flutter analyze` e `flutter test` a cada push e
pull request na `main`.

## Migrações do banco

| Arquivo | Conteúdo |
|---------|----------|
| `0001_schema` | Perfis, contas, chaves Pix, livro-razão e RLS |
| `0002_savings_and_pix_server` | Transferências Pix e caixinhas no banco |
| `0003_register_pix_key` | Cadastro de chave Pix por função |
| `0004_gamification_server` | Pontos de constância e níveis calculados no servidor |
| `0005_pix_charges` | Cobranças Pix com validade |
| `0006_charge_txid_25` | Identificador de cobrança compatível com o BR Code |
| `0007_statement_categories` | Categorias das saídas |
| `0008_boletos_and_limits` | Boletos e limite diário de saídas |
| `0009_credit_card` | Cartão de crédito, compras e fatura |
| `0010_password_reset_codes` | Códigos de recuperação de senha |
| `0011_transaction_pin` | PIN de transação com bloqueio |
| `0012_pin_authorization` | Autorização de uso único para operações com PIN |
| `0013_require_pin` | Bloqueio das operações sem PIN para usuários comuns |
| `0014_pin_wrapper_defaults` | Parâmetros opcionais nas operações com PIN |
| `0015_terms_acceptance` | Registro da versão e da data do aceite dos termos |

## Limitações conhecidas

- **Não é um banco real.** Não há autorização do Banco Central, não há integração com o Pix
  oficial e não há transferências reais entre instituições.
- **Sem auditoria de segurança independente.** Um sistema financeiro real passa por revisão
  especializada antes de guardar dinheiro de terceiros.
- **Testes de interface limitados.** As regras de negócio são cobertas por testes automatizados,
  mas o fluxo visual precisa de testes manuais em aparelho.
- **Sem exclusão de conta pelo app.** Pedidos de exclusão são feitos pelo canal de atendimento.

## Documentação legal

Os termos de uso e a política de privacidade estão no próprio aplicativo (Central de ajuda) e
seguem a Lei Geral de Proteção de Dados (Lei 13.709/2018). O texto é um modelo acadêmico e deve
ser revisado por um profissional jurídico antes de qualquer uso real.

## Autor

Desenvolvido por **camposdevs** como Trabalho de Conclusão de Curso.
