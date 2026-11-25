-- S3 Bank: PIN de transação guardado com bcrypt (pgcrypto).
-- Rodar DEPOIS do 0015.
--
-- Motivo: o hash anterior (SHA-256 com sal) é rápido demais. Um PIN de 6
-- números poderia ser descoberto em segundos se o banco vazasse. O bcrypt é
-- lento de propósito e resiste a isso.
--
-- ATENÇÃO: os PINs antigos são apagados. O hash antigo não pode ser convertido
-- sem o PIN original. Cada usuário cria o PIN de novo no próximo uso.

create extension if not exists pgcrypto;

delete from public.transaction_pins;

-- Gera o hash bcrypt (o sal vai embutido no próprio hash).
create or replace function public.pin_hash_bcrypt(p_pin text)
returns text
language sql volatile set search_path = public, extensions as $$
  select crypt(p_pin, gen_salt('bf', 10))
$$;

-- Confere o PIN contra o hash bcrypt.
create or replace function public.pin_check(p_pin text, p_hash text)
returns boolean
language sql immutable set search_path = public, extensions as $$
  select crypt(p_pin, p_hash) = p_hash
$$;

-- Cria o PIN, ou troca o atual (nesse caso, exige o PIN atual).
create or replace function public.set_transaction_pin(p_pin text, p_current_pin text default null)
returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_acc uuid;
  r public.transaction_pins%rowtype;
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
    if p_current_pin is null or not public.pin_check(p_current_pin, r.pin_hash) then
      raise exception 'PIN atual incorreto';
    end if;
  end if;

  insert into public.transaction_pins (account_id, salt, pin_hash, attempts, locked_until, updated_at)
  values (v_acc, '', public.pin_hash_bcrypt(p_pin), 0, null, now())
  on conflict (account_id) do update
    set salt = '',
        pin_hash = excluded.pin_hash,
        attempts = 0,
        locked_until = null,
        updated_at = now();
end $$;

-- Confere o PIN. Devolve true ou false. Erro só para bloqueio (o contador
-- de tentativas precisa ser gravado, por isso o erro não é usado para PIN errado).
create or replace function public.verify_transaction_pin(p_pin text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
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

  if p_pin is not null and public.pin_check(p_pin, r.pin_hash) then
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

revoke all on function public.pin_hash_bcrypt(text) from public, anon, authenticated;
revoke all on function public.pin_check(text, text) from public, anon, authenticated;
revoke all on function public.set_transaction_pin(text, text) from public, anon;
grant execute on function public.set_transaction_pin(text, text) to authenticated;
revoke all on function public.verify_transaction_pin(text) from public, anon;
grant execute on function public.verify_transaction_pin(text) to authenticated;
