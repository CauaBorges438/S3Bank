<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0B0B12,100:6A4CE0&height=200&section=header&text=S3%20Bank&fontSize=56&fontColor=ffffff&fontAlignY=38&desc=Conta%20digital%20gamificada%20com%20n%C3%ADveis%20atrelados%20ao%20CDI&descAlignY=58&descSize=18&descColor=B98CFF" width="100%" />

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Provider](https://img.shields.io/badge/State-Provider-6A4CE0?style=for-the-badge)
![Material 3](https://img.shields.io/badge/Material_3-Dark-0B0B12?style=for-the-badge&logo=materialdesign&logoColor=B98CFF)
![Status](https://img.shields.io/badge/Status-Conectado_ao_Supabase-3355D3?style=for-the-badge)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
[![CI](https://github.com/camposdevs/S3_Bank_flutter/actions/workflows/flutter.yml/badge.svg)](https://github.com/camposdevs/S3_Bank_flutter/actions/workflows/flutter.yml)

</div>

---

<div align="center">

Um app bancário onde **quanto mais constante você é, mais seu dinheiro rende**.
A cada aporte em "Guardar Dinheiro" você ganha pontos de constância, sobe de nível
e desbloqueia um percentual maior do CDI, com um cartão digital que muda de visual junto com você.

Os dados ficam no **Supabase** (Postgres + Auth + RLS): contas, saldo, extrato, caixinhas, chaves Pix e cartão são lidos e gravados no servidor, e toda movimentação de dinheiro passa por funções do banco.

</div>

---

## Funcionalidades

| Área | O que tem |
|------|-----------|
| **Acesso** | Login, cadastro (com confirmação de e-mail) e recuperação de senha em 3 etapas (código por e-mail → nova senha → confirmação), via Supabase Auth |
| **Início** | Saldo com opção de ocultar, nível atual, barra de progresso até o próximo nível e extrato |
| **Pix** | Pagar, receber (QR Code + Pix Copia e Cola no padrão BR Code com CRC16) e gerenciar chaves |
| **Guardar Dinheiro** | Caixinhas com metas, aportes, resgates e rendimento calculado sobre o CDI do nível |
| **Cartão digital** | Cartão com visual do nível, dados mascarados e opção de bloquear |
| **Perfil** | Nome, nível e saída da conta |

---

## Sistema de níveis

Definido em `models/user_tier.dart` (`enum UserTier` + extension com as regras de negócio).

| Nível | Rendimento |
|-------|------------|
| Bronze | 100% do CDI |
| Prata | 115% do CDI |
| Ouro | 130% do CDI |
| Diamante | 140% do CDI |

- A evolução é medida em **pontos de constância** (`UserProvider.consistencyPoints`),
  acumulados a cada aporte (`UserProvider.registerDeposit`). Um aporte vale pontos fixos
  mais uma fração do valor, para premiar o hábito e não só o volume.
- Ao passar do limite, o excedente de pontos é aproveitado no nível seguinte.
- O cartão digital é sincronizado com o nível via `CardProvider.syncTier`,
  então a "skin" muda sozinha quando o usuário sobe de nível.

---

## Como rodar

**Pré-requisitos:** Flutter com Dart `>=3.3.0` (Flutter 3.19 ou superior).

```bash
git clone https://github.com/CauaBorges438/S3Bank.git
cd S3_Bank_flutter
flutter pub get
flutter run
```

Para rodar no navegador:

```bash
flutter run -d chrome
```

> **Para entrar no app:** crie sua conta em **"Abra sua conta"**. Se o projeto Supabase exigir confirmação
> de e-mail, clique no link recebido e depois entre com e-mail e senha (se o e-mail não chegar, a tela de
> login tem o botão **"Reenviar e-mail de confirmação"**). A sessão é guardada pelo Supabase, então ao
> reabrir o app você continua logado. É preciso ter internet.

---

## Arquitetura

Organização por **telas + providers + camada de serviços** que conversa com o Supabase.
Gerenciador de estado: [`provider`](https://pub.dev/packages/provider) (`ChangeNotifier`).

```text
lib/
├── core/
│   ├── theme/                    # AppColors e ThemeData (Material 3, dark)
│   └── pix_payload_generator.dart # BR Code do Pix (EMV + CRC16)
├── models/                       # UserTier, Transaction, SavingsGoal, CardModel
├── services/                     # Supabase: config, BankService (tabelas e funções do banco),
│                                 # BankActions e AccountDataCoordinator (carrega/limpa os
│                                 # providers ao entrar/sair da conta)
├── providers/                    # Auth, User, Wallet, Savings, PixKeys, Card
├── widgets/                      # cartão, saldo, badges, botão com gradiente,
│                                 # fundo e campos das telas de acesso...
├── screens/
│   ├── auth/                     # login, cadastro, esqueci minha senha
│   ├── dashboard/                # início
│   ├── pix/                      # área Pix
│   ├── savings/                  # guardar dinheiro
│   ├── card/                     # cartão digital
│   ├── profile/                  # perfil
│   ├── auth_gate.dart            # alterna login ↔ app conforme a sessão
│   ├── splash_screen.dart
│   └── main_navigation_screen.dart # navegação inferior entre as abas
└── main.dart                     # MultiProvider + MaterialApp
test/                             # testes automatizados
```

---

## Testes

```bash
flutter test
```

Os testes cobrem as regras que não podem quebrar sem ninguém perceber:

| Arquivo | O que garante |
|---------|---------------|
| `user_tier_test.dart` | Percentuais do CDI, ordem dos níveis, pontos de constância, subida de nível (inclusive vários de uma vez) |
| `pix_payload_generator_test.dart` | Estrutura do BR Code, tamanhos dos campos, CRC16 conferido por uma implementação independente, limpeza de acentos |
| `wallet_provider_test.dart` | Envio e recebimento de Pix, saldo insuficiente, valores inválidos, arredondamento de centavos |
| `savings_and_pix_keys_test.dart` | Rendimento por nível, caixinhas, validação de CPF/e-mail/celular/chave aleatória |
| `currency_input_formatter_test.dart` | Máscara de valores em reais nos campos de dinheiro |

Login, cadastro e as funções do banco dependem do servidor e são verificados manualmente no app.

A cada push, o GitHub Actions roda `flutter analyze` e `flutter test`
(`.github/workflows/flutter.yml`).

---

## Conectando ao Supabase

O app usa o projeto Supabase "S3 Bank", que já tem as tabelas `perfis`, `carteiras`, `transacoes`, `caixinhas`, `cartoes`, `chaves_pix`, `regras_nivel` e `taxas_cdi`, com RLS ligada (cada usuário lê só os próprios dados).

- **Autenticação:** Supabase Auth (e-mail + senha). No cadastro, o trigger `handle_new_user` cria perfil, carteira (bônus de R$ 1.000), cartão e a primeira transação. O nome vai em `raw_user_meta_data.nome`.
- **Leitura:** o app lê as tabelas direto.
- **Movimentação de dinheiro:** só pelas funções do banco `enviar_pix`, `receber_pix`, `depositar_caixinha` e `resgatar_caixinha`. Elas validam o saldo e atualizam carteira, extrato, pontos e nível numa única transação.
- **Caixinhas e chaves Pix:** `insert` direto (e `delete` nas chaves), liberado pelas políticas.

Para o código de recuperação de senha chegar por e-mail, o template **Authentication → Email Templates → Reset Password** precisa conter `{{ .Token }}`. O cadastro usa confirmação de e-mail; para entrar logo após criar a conta (útil em testes), desligue "Confirm email" em Authentication → Sign In / Providers → Email.

Ao testar com `flutter run`, use *hot restart* (`R`) e não *hot reload* (`r`) depois de mexer em autenticação: o reload não recria a sessão criada em `main()`.

A URL e a chave pública (`anon`) do projeto já estão em `lib/services/supabase_config.dart`, então basta:

```bash
flutter pub get
flutter run
```

Para apontar para outro projeto, use `--dart-define=SUPABASE_URL=...` e `--dart-define=SUPABASE_ANON_KEY=...`. Nunca coloque a chave `service_role` no app.

## Como cada provider usa o backend

Os providers em `lib/providers/` guardam o estado da tela; quem fala com o Supabase é `lib/services/`.
Ao entrar numa conta, o `AccountDataCoordinator` busca tudo no servidor e entrega aos providers; depois de cada operação, busca de novo.

| Onde | Como funciona |
|------|---------------|
| `AuthProvider` | Supabase Auth (login, cadastro, reenvio de confirmação, recuperação de senha por código) |
| `UserProvider` | Nome, nível e pontos de constância vêm de `perfis`; a subida de nível é calculada no banco (`regras_nivel`) |
| `WalletProvider` | Saldo (`carteiras`) e extrato (`transacoes`); Pix por `enviar_pix` / `receber_pix` |
| `SavingsProvider` | Caixinhas (`caixinhas`); aporte e resgate por `depositar_caixinha` / `resgatar_caixinha` |
| `PixKeysProvider` | Chaves Pix (`chaves_pix`) |
| `CardProvider` | Dados do cartão (`cartoes`), criado no cadastro pelo trigger `handle_new_user` |
| `PixPayloadGenerator` | QR Code estático; cobranças dinâmicas exigem um PSP autorizado pelo Banco Central |

> **Aviso sobre o Pix:** o QR Code gerado é estático e estruturalmente válido.
> Se a chave informada existir de verdade, qualquer banco consegue pagar nela.
> Em demonstrações, use sempre uma chave fictícia.

---

## Roadmap

- [x] Login, cadastro (com confirmação de e-mail) e recuperação de senha via Supabase Auth
- [x] Dados por conta no Supabase, com RLS
- [x] Níveis, pontos de constância e cartão que acompanha o nível
- [x] Pix com QR Code e Copia e Cola
- [x] Camada de serviços entre providers e backend (`BankService`, `AccountDataCoordinator`)
- [x] Movimentação de dinheiro por funções do banco (saldo validado no servidor)
- [ ] Dados do cartão protegidos (hoje número e CVV ficam em texto no banco; discutir no TCC)
- [x] Testes automatizados e CI no GitHub Actions
- [ ] Telas de Dados pessoais, Segurança e Ajuda no perfil

<!--
Quando tiver prints do app, adicione aqui uma seção "Telas" com uma tabela de imagens:
| Login | Início | Pix | Cartão |
|:-:|:-:|:-:|:-:|
| <img src="docs/login.png" width="200"> | ... |
-->

---

## Integrantes

- Denise Gonçalves
- Cauã Borges
- Pedro Campo

## Turma
- 4DS



