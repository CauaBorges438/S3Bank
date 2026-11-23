-- S3 Bank: autorização de operações com o PIN de transação.
-- Rodar DEPOIS do 0011.
--
-- Como funciona:
--  1. O app chama authorize_transaction_pin(pin) e recebe um id de autorização.
--     PIN errado devolve null (e conta a tentativa). Não gera erro para não
--     desfazer a contagem.
--  2. O app chama a operação *_pin passando o id. A autorização:
--     - vale 2 minutos;
--     - é de uso único;
--     - só funciona para a conta que a gerou.
--  3. Se a operação falhar (ex.: saldo insuficiente), a autorização
--     também é desfeita, porque tudo acontece na mesma transação.
--
-- As funções antigas (pix_transfer, pay_boleto...) continuam existindo nesta
-- etapa. Na etapa seguinte o app passa a usar as versões *_pin e as antigas
-- deixam de ser liberadas para usuários comuns.

create table if not exists public.pin_authorizations (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.pin_authorizations enable row level security;
revoke all on public.pin_authorizations from anon, authenticated;

-- Gera a autorização se o PIN estiver certo. Devolve null se estiver errado.
create or replace function public.authorize_transaction_pin(p_pin text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_id uuid;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  if not public.verify_transaction_pin(p_pin) then
    return null;
  end if;

  insert into public.pin_authorizations (account_id, expires_at)
  values (v_acc, now() + interval '2 minutes')
  returning id into v_id;

  return v_id;
end $$;

-- Consome a autorização. Usada só pelas funções *_pin, dentro da operação.
create or replace function public.consume_pin_authorization(p_auth uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_id uuid;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  update public.pin_authorizations
     set used_at = now()
   where id = p_auth
     and account_id = v_acc
     and used_at is null
     and expires_at > now()
  returning id into v_id;

  if v_id is null then
    raise exception 'confirmação de PIN inválida ou expirada';
  end if;
end $$;

-- Operações com PIN: consomem a autorização e chamam a operação original.
create or replace function public.pix_transfer_pin(
  p_key_value text, p_amount_cents bigint, p_description text, p_auth uuid
) returns uuid
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.pix_transfer(p_key_value, p_amount_cents, p_description);
end $$;

create or replace function public.withdraw_to_bank_pin(
  p_amount_cents bigint, p_bank text, p_account_info text, p_auth uuid
) returns bigint
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.withdraw_to_bank(p_amount_cents, p_bank, p_account_info);
end $$;

create or replace function public.pay_boleto_pin(p_code text, p_auth uuid)
returns bigint
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.pay_boleto(p_code);
end $$;

create or replace function public.pay_charge_pin(p_txid text, p_auth uuid)
returns bigint
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.pay_charge(p_txid);
end $$;

create or replace function public.pay_card_invoice_pin(p_month date, p_auth uuid)
returns bigint
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.pay_card_invoice(p_month);
end $$;

revoke all on function public.authorize_transaction_pin(text) from public, anon;
grant execute on function public.authorize_transaction_pin(text) to authenticated;
revoke all on function public.consume_pin_authorization(uuid) from public, anon, authenticated;
revoke all on function public.pix_transfer_pin(text, bigint, text, uuid) from public, anon;
grant execute on function public.pix_transfer_pin(text, bigint, text, uuid) to authenticated;
revoke all on function public.withdraw_to_bank_pin(bigint, text, text, uuid) from public, anon;
grant execute on function public.withdraw_to_bank_pin(bigint, text, text, uuid) to authenticated;
revoke all on function public.pay_boleto_pin(text, uuid) from public, anon;
grant execute on function public.pay_boleto_pin(text, uuid) to authenticated;
revoke all on function public.pay_charge_pin(text, uuid) from public, anon;
grant execute on function public.pay_charge_pin(text, uuid) to authenticated;
revoke all on function public.pay_card_invoice_pin(date, uuid) from public, anon;
grant execute on function public.pay_card_invoice_pin(date, uuid) to authenticated;
