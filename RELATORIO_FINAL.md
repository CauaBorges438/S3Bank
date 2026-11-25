# Relatório final da auditoria

Veja AUDIT.md (inventário) e BUGS.md (lista completa, com severidade).

## Pendências (não corrigidas e por quê)
- **C-01** `simulate_deposit`: exige mudar os testes de integração antes de revogar. Decisão sua de quando fazer.
- **M-02** PIN com hash lento: exige migração nova e verificação do schema `extensions`.
- **M-03** Luhn no cartão: exige migração nova, sem alterar cartões existentes.
- **M-04** Dígitos verificadores de boleto: depende da norma adotada no projeto.
- **M-05** Paginação do extrato: mudança de comportamento na tela.
- **M-06** Logs em release: pequena, mas toca em vários arquivos; fazer junto com a revisão de logs.
- **B-02, B-03, B-04**: baixo risco, registrados.

## Ações manuais (só você pode fazer)
1. **Revogar `simulate_deposit`** para `authenticated`, depois de migrar os testes de depósito para uma chave de serviço no CI.
2. **Revogar a chave do Resend** que apareceu em conversa, se ainda não foi feito, e criar outra.
3. **Conferir no painel do Supabase** que RLS está ativo em todas as tabelas de dados.
4. **Configurar rate limit** de autenticação no painel (Authentication > Rate Limits).
5. **Criar a branch** `audit/bugfix-2026-11-23`, aplicar `correcoes.zip` e fazer commit. Eu não tenho acesso ao GitHub para fazer isso.
6. **Não aplicar a migração 0016 em produção** sem revisar: ela ainda não existe, e as pendências M-02 e M-03 a exigem.
