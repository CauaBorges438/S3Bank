-- S3 Bank: códigos de recuperação de senha (enviados pelo Resend).
-- Rodar DEPOIS do 0009. Só as Edge Functions acessam esta tabela.

create table if not exists public.password_reset_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  code_hash text not null,          -- SHA-256 do código; o código puro nunca é guardado
  expires_at timestamptz not null,
  attempts int not null default 0,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists password_reset_codes_email_idx
  on public.password_reset_codes (email, created_at desc);

-- RLS ligado e sem políticas: nem o app nem usuários comuns leem esta tabela.
alter table public.password_reset_codes enable row level security;
