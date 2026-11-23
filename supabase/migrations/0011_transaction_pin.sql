-- S3 Bank: senha de transação (PIN de 6 números) guardada no banco.
-- Rodar DEPOIS do 0010.
--
-- Regras:
--  - O PIN é de 6 números e é separado da senha de login.
--  - Guardado só como hash (sha256 com sal). Nunca em texto puro.
--  - 5 erros seguidos bloqueiam o PIN por 15 minutos.
--  - Só o banco confere o PIN; o app nunca lê o hash.

create table if not exists public.transaction_pins (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  salt text not null,
  pin_hash text not null,
  attempts int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.transaction_pins enable row level security;
revoke all on public.transaction_pins from anon, authenticated;

create or replace function public.pin_hash(p_salt text, p_pin text)
returns text language sql immutable as $$
  select encode(sha256(convert_to(p_salt || ':' || p_pin, 'UTF8')), 'hex')
$$;

-- Diz se a conta já tem PIN cadastrado.
create or replace function public.has_transaction_pin()
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  return exists (select 1 from public.transaction_pins where account_id = v_acc);
end $$;

-- Cria o PIN, ou troca o atual (nesse caso, exige o PIN atual).
create or replace function public.set_transaction_pin(p_pin text, p_current_pin text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  r public.transaction_pins%rowtype;
  v_salt text;
begin
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    raise exception 'O PIN precisa ter 6 números';
  end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  select * into r from public.transaction_pins where account_id = v_acc for update;
  if found then
    if r.locked_until is not null and r.locked_until > now() then
      raise exception 'PIN bloqueado temporariamente. Tente em alguns minutos';
    end if;
    if p_current_pin is null or public.pin_hash(r.salt, p_current_pin) <> r.pin_hash then
      raise exception 'PIN atual incorreto';
    end if;
  end if;

  v_salt := gen_random_uuid()::text;
  insert into public.transaction_pins (account_id, salt, pin_hash, attempts, locked_until, updated_at)
  values (v_acc, v_salt, public.pin_hash(v_salt, p_pin), 0, null, now())
  on conflict (account_id) do update
    set salt = excluded.salt,
        pin_hash = excluded.pin_hash,
        attempts = 0,
        locked_until = null,
        updated_at = now();
end $$;

-- Confere o PIN. Devolve true ou false. Erro só para bloqueio.
-- Devolve false (e não erro) para o contador de tentativas ser gravado.
create or replace function public.verify_transaction_pin(p_pin text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  r public.transaction_pins%rowtype;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  select * into r from public.transaction_pins where account_id = v_acc for update;
  if not found then raise exception 'crie seu PIN de transação antes de continuar'; end if;

  if r.locked_until is not null and r.locked_until > now() then
    raise exception 'PIN bloqueado temporariamente. Tente em alguns minutos';
  end if;

  if p_pin is not null and public.pin_hash(r.salt, p_pin) = r.pin_hash then
    update public.transaction_pins set attempts = 0, locked_until = null
    where account_id = v_acc;
    return true;
  end if;

  update public.transaction_pins
     set attempts = attempts + 1,
         locked_until = case when attempts + 1 >= 5 then now() + interval '15 minutes' else null end
   where account_id = v_acc;
  return false;
end $$;

revoke all on function public.has_transaction_pin() from public, anon;
grant execute on function public.has_transaction_pin() to authenticated;
revoke all on function public.set_transaction_pin(text, text) from public, anon;
grant execute on function public.set_transaction_pin(text, text) to authenticated;
revoke all on function public.verify_transaction_pin(text) from public, anon;
grant execute on function public.verify_transaction_pin(text) to authenticated;
