-- S3 Bank: schema inicial com livro-razão e RLS.
-- Regra de ouro: o saldo NUNCA é editado diretamente.
-- Só se registram movimentações em ledger_entries.

create extension if not exists "pgcrypto";

-- Perfis (1:1 com auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 120),
  cpf text unique check (cpf is null or cpf ~ '^[0-9]{11}$'),
  phone text,
  created_at timestamptz not null default now()
);

-- Contas (uma por usuário no MVP)
create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Chaves Pix
create table if not exists public.pix_keys (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  key_type text not null check (key_type in ('cpf','phone','email','random')),
  key_value text not null,
  created_at timestamptz not null default now(),
  unique (key_type, key_value)
);

-- Livro-razão: cada linha é uma movimentação imutável.
-- amount > 0 = entrada, amount < 0 = saída.
create table if not exists public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete restrict,
  amount_cents bigint not null check (amount_cents <> 0),
  kind text not null check (kind in ('deposit','withdrawal','pix_in','pix_out','transfer_in','transfer_out','fee','adjustment')),
  description text,
  counterpart_account_id uuid references public.accounts(id),
  group_id uuid not null default gen_random_uuid(), -- agrupa as duas pernas de uma transferência
  created_at timestamptz not null default now()
);
create index if not exists ledger_account_created_idx on public.ledger_entries(account_id, created_at desc);

-- Saldo calculado a partir do livro-razão
create or replace view public.account_balances
with (security_invoker = true) as
select a.id as account_id,
       coalesce(sum(l.amount_cents), 0)::bigint as balance_cents
from public.accounts a
left join public.ledger_entries l on l.account_id = a.id
group by a.id;

-- ============ RLS ============
alter table public.profiles       enable row level security;
alter table public.accounts       enable row level security;
alter table public.pix_keys       enable row level security;
alter table public.ledger_entries enable row level security;

create policy "profile: ver o próprio" on public.profiles
  for select using (auth.uid() = id);
create policy "profile: atualizar o próprio" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "conta: ver a própria" on public.accounts
  for select using (auth.uid() = owner_id);

create policy "pix: ver as próprias" on public.pix_keys
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));
create policy "pix: criar nas próprias" on public.pix_keys
  for insert with check (account_id in (select id from public.accounts where owner_id = auth.uid()));
create policy "pix: remover as próprias" on public.pix_keys
  for delete using (account_id in (select id from public.accounts where owner_id = auth.uid()));

create policy "ledger: ver as próprias" on public.ledger_entries
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));
-- Sem policies de insert/update/delete: escrita só via funções SECURITY DEFINER.

-- Garante que ninguém escreve direto no livro-razão nem altera saldos
revoke insert, update, delete on public.ledger_entries from anon, authenticated;
revoke update, delete on public.accounts from anon, authenticated;

-- Criação automática de perfil e conta ao cadastrar
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, cpf, phone)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', 'Cliente'),
          nullif(new.raw_user_meta_data->>'cpf', ''),
          new.raw_user_meta_data->>'phone');
  insert into public.accounts (owner_id) values (new.id);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============ Operações (únicas portas de escrita) ============

-- Transferência Pix interna entre usuários do S3 Bank.
-- Registra as duas pernas atomicamente e valida saldo.
create or replace function public.pix_transfer(
  p_key_value text,
  p_amount_cents bigint,
  p_description text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_from uuid;
  v_to uuid;
  v_balance bigint;
  v_group uuid := gen_random_uuid();
begin
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'valor inválido';
  end if;

  select id into v_from from public.accounts where owner_id = auth.uid();
  if v_from is null then raise exception 'conta não encontrada'; end if;

  select a.id into v_to
  from public.pix_keys k join public.accounts a on a.id = k.account_id
  where k.key_value = p_key_value;
  if v_to is null then raise exception 'chave Pix não encontrada'; end if;
  if v_to = v_from then raise exception 'não é possível enviar para a própria conta'; end if;

  -- trava a conta de origem para evitar gasto duplicado em concorrência
  perform 1 from public.accounts where id = v_from for update;
  select coalesce(sum(amount_cents), 0) into v_balance
  from public.ledger_entries where account_id = v_from;
  if v_balance < p_amount_cents then raise exception 'saldo insuficiente'; end if;

  insert into public.ledger_entries (account_id, amount_cents, kind, description, counterpart_account_id, group_id)
  values (v_from, -p_amount_cents, 'pix_out', p_description, v_to, v_group),
         (v_to,    p_amount_cents, 'pix_in',  p_description, v_from, v_group);

  return v_group;
end $$;

-- Depósito de teste (simulação de Pix/boleto recebido)
create or replace function public.simulate_deposit(p_amount_cents bigint, p_description text default 'Depósito simulado')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_acc uuid;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'valor inválido'; end if;
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  insert into public.ledger_entries (account_id, amount_cents, kind, description)
  values (v_acc, p_amount_cents, 'deposit', p_description)
  returning group_id into v_acc;
  return v_acc;
end $$;

-- Permissões das funções
revoke all on function public.pix_transfer(text, bigint, text) from public, anon;
grant execute on function public.pix_transfer(text, bigint, text) to authenticated;
revoke all on function public.simulate_deposit(bigint, text) from public, anon;
grant execute on function public.simulate_deposit(bigint, text) to authenticated;
