-- S3 Bank: correções do cartão de crédito. Rodar DEPOIS do 0016 (0016_pin_bcrypt).
-- - Número do cartão válido pelo algoritmo de Luhn.
-- - Número e CVV gerados com gen_random_uuid() (em vez de random()).
-- - Fatura em atraso (meses anteriores não pagos) visível e paga pelo app.
-- - Dono da conta não lê número completo nem hash do CVV pela API.

-- 1) Dígito verificador de Luhn
create or replace function public.card_luhn_check_digit(p_payload text)
returns int
language plpgsql immutable
set search_path = public
as $$
declare
  s int := 0;
  n int := length(p_payload);
  d int;
begin
  for i in 1..n loop
    d := substr(p_payload, n - i + 1, 1)::int;
    if i % 2 = 1 then
      d := d * 2;
      if d > 9 then d := d - 9; end if;
    end if;
    s := s + d;
  end loop;
  return (10 - (s % 10)) % 10;
end $$;

revoke all on function public.card_luhn_check_digit(text) from public, anon, authenticated;

-- 2) Criação do cartão com número válido e aleatoriedade do gen_random_uuid()
create or replace function public.create_virtual_card()
returns table (card_number text, card_expiry text, card_cvv text)
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_rand bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  v_rand2 bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  v_body text := '5';
  v_number text;
  v_cvv text;
  v_expiry date;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  if exists (select 1 from public.credit_cards where account_id = v_acc) then
    raise exception 'cartão já criado';
  end if;

  -- '5' (bandeira simulada) + 14 dígitos aleatórios + dígito verificador = 16 dígitos
  for i in 0..13 loop
    v_body := v_body || (get_byte(v_rand, i) % 10)::text;
  end loop;
  v_number := v_body || public.card_luhn_check_digit(v_body)::text;

  v_cvv := lpad(((get_byte(v_rand2, 0) * 256 + get_byte(v_rand2, 1)) % 1000)::text, 3, '0');

  v_expiry := (date_trunc('month', now() at time zone 'America/Sao_Paulo')
               + interval '4 years' + interval '1 month' - interval '1 day')::date;

  insert into public.credit_cards (account_id, card_number, last4, expiry, cvv_hash)
  values (v_acc, v_number, right(v_number, 4), v_expiry,
          encode(sha256(convert_to(v_cvv, 'UTF8')), 'hex'));

  return query select v_number, to_char(v_expiry, 'MM/YY'), v_cvv;
end $$;

-- 3) Resumo com fatura em atraso (a mais antiga, de meses anteriores)
drop function if exists public.get_card_summary();

create or replace function public.get_card_summary()
returns table (
  has_card boolean,
  card_last4 text,
  card_expiry text,
  card_limit_cents bigint,
  card_used_cents bigint,
  card_available_cents bigint,
  invoice_month date,
  invoice_total_cents bigint,
  invoice_due date,
  overdue_month date,
  overdue_cents bigint
)
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_last4 text;
  v_exp text;
  v_limit bigint := public.card_limit_cents();
  v_used bigint;
  v_month date := public.sp_month_start(now());
  v_inv bigint;
  v_due date;
  v_over_month date;
  v_over bigint := 0;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  select c.last4, to_char(c.expiry, 'MM/YY') into v_last4, v_exp
  from public.credit_cards c where c.account_id = v_acc;

  select coalesce(sum(p.amount_cents), 0) into v_used
  from public.card_purchases p where p.account_id = v_acc and p.paid_at is null;

  select coalesce(sum(p.amount_cents), 0) into v_inv
  from public.card_purchases p
  where p.account_id = v_acc and p.paid_at is null
    and public.sp_month_start(p.purchased_at) = v_month;

  select public.sp_month_start(p.purchased_at) into v_over_month
  from public.card_purchases p
  where p.account_id = v_acc and p.paid_at is null
    and public.sp_month_start(p.purchased_at) < v_month
  order by p.purchased_at asc
  limit 1;

  if v_over_month is not null then
    select coalesce(sum(p.amount_cents), 0) into v_over
    from public.card_purchases p
    where p.account_id = v_acc and p.paid_at is null
      and public.sp_month_start(p.purchased_at) = v_over_month;
  end if;

  v_due := (v_month + interval '1 month' + interval '9 days')::date;

  return query select (v_last4 is not null), v_last4, v_exp, v_limit, v_used,
                      greatest(v_limit - v_used, 0), v_month, v_inv, v_due,
                      v_over_month, v_over;
end $$;

revoke all on function public.get_card_summary() from public, anon;
grant execute on function public.get_card_summary() to authenticated;

-- 4) Dados sensíveis do cartão não ficam expostos pela API
revoke select on public.credit_cards from anon, authenticated;
grant select (account_id, last4, expiry, created_at) on public.credit_cards to authenticated;
