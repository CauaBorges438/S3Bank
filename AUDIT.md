# Auditoria S3 Bank — inventário e estado

## Escopo lido nesta rodada
- README.md (reescrito), SETUP_ANDROID_IOS.md, pubspec.yaml, analysis_options.yaml, .gitignore,
  .github/workflows/flutter.yml.
- Migrações 0001 a 0015 (schema, RLS, funções RPC, grants, triggers, PIN, cobranças, cartão,
  boletos, termos).
- Edge functions: send-reset-code e verify-reset-code (leitura completa).
- lib/core: pix_payload_parser, pix_payload_generator, boleto, br_validators, statement_filter.
- lib/core/config/supabase_config.dart (verificação de segredos).

## Verificações automáticas feitas
- Segredos versionados: nenhuma service_role key no repositório. A chave em
  `lib/core/config/supabase_config.dart` é a **anon/publishable**, pública por design.
- `.gitignore` cobre `.env`, `build/`, `.dart_tool/`. Foi adicionado: `android/key.properties`,
  `*.jks` e `*.keystore`.
- RLS: 11 tabelas com `enable row level security` nas migrações. Nenhuma política com
  `using (true)` ou `with check (true)`.
- Funções `security definer`: todas declaram `set search_path`.
- Permissões: `simulate_deposit` está concedida a `authenticated` (0001, linha 163).

## Estado de analyze e test
- **Não executado nesta rodada**: o ambiente de auditoria não tem o toolchain Flutter.
- Último estado reportado pelo usuário: `flutter analyze` sem erros (15 avisos, todos `info`);
  `flutter test` com 125 testes passando; integração com 45 passando.
- Para confirmar após as correções, rodar: `flutter analyze`, `flutter test` e, com credenciais,
  `flutter test test/integration`.

## Não auditado nesta rodada (limite de ambiente)
- Teste de concorrência real (requisições paralelas contra o banco).
- Revisão de políticas RLS no painel do Supabase (apenas nos arquivos de migração).
- Fluxos de tela em aparelho, navegação e permissões em iOS (não há pasta `ios/`).
- Branch `audit/bugfix-YYYY-MM-DD` e push: não executados (sem credenciais do GitHub).
