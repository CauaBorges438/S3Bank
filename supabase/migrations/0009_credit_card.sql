-- S3 Bank: cartão de crédito virtual, compras e fatura. Rodar DEPOIS do 0008.
--
-- Regras:
--  - Limite do cartão: R$ 3.000,00 (função card_limit_cents).
--  - Compra no cartão NÃO debita o saldo: entra na fatura do mês.
--  - Fatura = compras não pagas do mês (fuso de São Paulo). Vence no dia 10 do mês seguinte.
--  - Pagar a fatura debita o saldo e quita as compras daquele mês.
--  - O CVV não é guardado em texto: só o hash. Ele é mostrado uma vez, na criação.

alter table public.ledger_entries drop constraint if exists ledger_entries_kind_check;
alter table public.ledger_entries add constraint ledger_entries_kind_check
  check (kind in ('deposit','withdrawal','pix_in','pix_out','transfer_in','transfer_out',
                  'fee','adjustment','savings_in','savings_out','boleto_in','boleto_out',
                  'card_payment'));

create or replace function public.card_limit_cents()
returns bigint language sql immutable as $$ select 300000::bigint $$;

create or replace function public.sp_month_start(p_ts timestamptz)
returns date language sql stable as $$
  select (date_trunc('month', p_ts at time zone 'America/Sao_Paulo'))::date
$$;

create table if not exists public.credit_cards (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  card_number text not null unique check (card_number ~ '^[0-9]{16}$'),
  last4 text not null,
  expiry date not null,
  cvv_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.card_purchases (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  merchant text not null check (char_length(trim(merchant)) between 1 and 60),
  category text not null check (category in
    ('alimentacao','moradia','transporte','lazer','saude','compras','poupanca','outros')),
  amount_cents bigint not null check (amount_cents > 0),
  purchased_at timestamptz not null default now(),
  paid_at timestamptz
);

alter table public.credit_cards enable row level security;
alter table public.card_purchases enable row level security;

create policy "cartão: ver o próprio" on public.credit_cards
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));
create policy "compra: ver as próprias" on public.card_purchases
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));

revoke insert, update, delete on public.credit_cards from anon, authenticated;
revoke insert, update, delete on public.card_purchases from anon, authenticated;

-- Cria o cartão virtual (uma vez por conta). Devolve o CVV só desta vez.
create or replace function public.create_virtual_card()
returns table (card_number text, card_expiry text, card_cvv text)
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_number text;
  v_cvv text;
  v_expiry date;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  if exists (select 1 from public.credit_cards where account_id = v_acc) then
    raise exception 'cartão já criado';
  end if;

  -- 16 dígitos, começando com 5 (bandeira simulada)
  v_number := '5' || (select string_agg(floor(random() * 10)::int::text, '')
                      from generate_series(1, 15));
  v_cvv := lpad(floor(random() * 1000)::int::text, 3, '0');
  v_expiry := (date_trunc('month', now() at time zone 'America/Sao_Paulo')
               + interval '4 years' + interval '1 month' - interval '1 day')::date;

  insert into public.credit_cards (account_id, card_number, last4, expiry, cvv_hash)
  values (v_acc, v_number, right(v_number, 4), v_expiry,
          encode(sha256(convert_to(v_cvv, 'UTF8')), 'hex'));

  return query select v_number, to_char(v_expiry, 'MM/YY'), v_cvv;
end $$;

-- Resumo: limite, uso, fatura do mês e vencimento.
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
  invoice_due date
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

  v_due := (v_month + interval '1 month' + interval '9 days')::date;

  return query select (v_last4 is not null), v_last4, v_exp, v_limit, v_used,
                      greatest(v_limit - v_used, 0), v_month, v_inv, v_due;
end $$;

-- Compra no cartão: entra na fatura, sem debitar o saldo agora.
create or replace function public.make_card_purchase(
  p_merchant text,
  p_amount_cents bigint,
  p_category text
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_used bigint;
  v_id uuid;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'valor inválido'; end if;
  if p_merchant is null or char_length(trim(p_merchant)) = 0 then
    raise exception 'informe onde foi a compra';
  end if;
  if p_category not in ('alimentacao','moradia','transporte','lazer','saude','compras','poupanca','outros') then
    raise exception 'categoria inválida';
  end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  if not exists (select 1 from public.credit_cards where account_id = v_acc) then
    raise exception 'crie seu cartão virtual antes de comprar';
  end if;

  perform 1 from public.accounts where id = v_acc for update;

  select coalesce(sum(p.amount_cents), 0) into v_used
  from public.card_purchases p where p.account_id = v_acc and p.paid_at is null;
  if v_used + p_amount_cents > public.card_limit_cents() then
    raise exception 'limite do cartão insuficiente';
  end if;

  insert into public.card_purchases (account_id, merchant, category, amount_cents)
  values (v_acc, trim(p_merchant), p_category, p_amount_cents)
  returning id into v_id;

  return v_id;
end $$;

-- Paga a fatura de um mês: debita o saldo e quita as compras daquele mês.
create or replace function public.pay_card_invoice(p_month date)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_total bigint;
  v_bal bigint;
  v_group uuid := gen_random_uuid();
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  perform 1 from public.accounts where id = v_acc for update;

  select coalesce(sum(p.amount_cents), 0) into v_total
  from public.card_purchases p
  where p.account_id = v_acc and p.paid_at is null
    and public.sp_month_start(p.purchased_at) = date_trunc('month', p_month)::date;
  if v_total = 0 then raise exception 'não há nada a pagar nesta fatura'; end if;

  select coalesce(sum(l.amount_cents), 0) into v_bal
  from public.ledger_entries l where l.account_id = v_acc;
  if v_bal < v_total then raise exception 'saldo insuficiente'; end if;

  insert into public.ledger_entries (account_id, amount_cents, kind, description, group_id)
  values (v_acc, -v_total, 'card_payment', 'Pagamento da fatura do cartão', v_group);

  update public.card_purchases set paid_at = now()
  where account_id = v_acc and paid_at is null
    and public.sp_month_start(purchased_at) = date_trunc('month', p_month)::date;

  return v_total;
end $$;

revoke all on function public.create_virtual_card() from public, anon;
grant execute on function public.create_virtual_card() to authenticated;
revoke all on function public.get_card_summary() from public, anon;
grant execute on function public.get_card_summary() to authenticated;
revoke all on function public.make_card_purchase(text, bigint, text) from public, anon;
grant execute on function public.make_card_purchase(text, bigint, text) to authenticated;
revoke all on function public.pay_card_invoice(date) from public, anon;
grant execute on function public.pay_card_invoice(date) to authenticated;
