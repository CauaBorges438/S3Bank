-- S3 Bank: boleto simulado (receber e pagar), transferência para outro banco
-- simulada e limite diário de saídas. Rodar DEPOIS do 0007.
--
-- Regras:
--  - Limite diário de saídas: R$ 5.000,00, somando transferências para outro
--    banco e boletos pagos. Pix entre contas do S3 Bank NÃO entra no limite.
--  - O dia é contado no fuso de São Paulo.
--  - Código de boleto: 47 dígitos. Gerado aleatoriamente: é uma simulação.

alter table public.ledger_entries drop constraint if exists ledger_entries_kind_check;
alter table public.ledger_entries add constraint ledger_entries_kind_check
  check (kind in ('deposit','withdrawal','pix_in','pix_out','transfer_in','transfer_out',
                  'fee','adjustment','savings_in','savings_out','boleto_in','boleto_out'));

-- ============ limite diário ============

create or replace function public.daily_out_limit_cents()
returns bigint language sql immutable as $$ select 500000::bigint $$;

create or replace function public.money_out_today(p_account uuid)
returns bigint language sql stable as $$
  select coalesce(-sum(l.amount_cents), 0)::bigint
  from public.ledger_entries l
  where l.account_id = p_account
    and l.kind in ('withdrawal','boleto_out')
    and l.created_at >= (date_trunc('day', now() at time zone 'America/Sao_Paulo')
                         at time zone 'America/Sao_Paulo');
$$;

create or replace function public.get_money_out_summary()
returns table (limit_cents bigint, used_cents bigint)
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
begin
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  return query select public.daily_out_limit_cents(), public.money_out_today(v_acc);
end $$;

-- ============ transferência para outro banco (simulada) ============

create or replace function public.withdraw_to_bank(
  p_amount_cents bigint,
  p_bank text,
  p_account_info text default null
)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_bal bigint;
  v_desc text;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'valor inválido'; end if;
  if p_bank is null or char_length(trim(p_bank)) = 0 then raise exception 'informe o banco de destino'; end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  perform 1 from public.accounts where id = v_acc for update;

  if public.money_out_today(v_acc) + p_amount_cents > public.daily_out_limit_cents() then
    raise exception 'limite diário de saídas atingido';
  end if;

  select coalesce(sum(amount_cents), 0) into v_bal
  from public.ledger_entries where account_id = v_acc;
  if v_bal < p_amount_cents then raise exception 'saldo insuficiente'; end if;

  v_desc := 'Transferência para ' || trim(p_bank)
            || coalesce(' · ' || nullif(trim(coalesce(p_account_info, '')), ''), '');

  insert into public.ledger_entries (account_id, amount_cents, kind, description)
  values (v_acc, -p_amount_cents, 'withdrawal', v_desc);

  return p_amount_cents;
end $$;

-- ============ boletos ============

create table if not exists public.boletos (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[0-9]{47}$'),
  beneficiary_account_id uuid not null references public.accounts(id) on delete restrict,
  payer_account_id uuid references public.accounts(id),
  amount_cents bigint not null check (amount_cents > 0),
  description text,
  status text not null default 'open' check (status in ('open','paid','cancelled')),
  due_date date not null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.boletos enable row level security;

create policy "boleto: ver os que eu emiti" on public.boletos
  for select using (beneficiary_account_id in (select id from public.accounts where owner_id = auth.uid()));

revoke insert, update, delete on public.boletos from anon, authenticated;

create or replace function public.random_boleto_code()
returns text language sql volatile as $$
  select string_agg(floor(random() * 10)::int::text, '') from generate_series(1, 47);
$$;

create or replace function public.create_boleto(
  p_amount_cents bigint,
  p_description text default null,
  p_due_days int default 3
)
returns table (boleto_code text, boleto_due date)
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_code text;
  v_due date;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'valor inválido'; end if;
  if p_due_days is null or p_due_days < 0 or p_due_days > 30 then raise exception 'prazo inválido'; end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  v_code := public.random_boleto_code();
  v_due := (now() at time zone 'America/Sao_Paulo')::date + p_due_days;

  insert into public.boletos (code, beneficiary_account_id, amount_cents, description, due_date)
  values (v_code, v_acc, p_amount_cents, nullif(trim(coalesce(p_description, '')), ''), v_due);

  return query select v_code, v_due;
end $$;

create or replace function public.get_boleto(p_code text)
returns table (
  boleto_amount_cents bigint,
  boleto_description text,
  beneficiary_name text,
  boleto_status text,
  boleto_due date
)
language plpgsql security definer set search_path = public as $$
declare
  b public.boletos%rowtype;
  v_name text;
  v_status text;
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  select * into b from public.boletos where code = p_code;
  if not found then raise exception 'boleto não encontrado'; end if;

  select p.full_name into v_name
  from public.profiles p
  where p.id = (select a.owner_id from public.accounts a where a.id = b.beneficiary_account_id);

  v_status := case when b.status = 'open' and b.due_date < v_today then 'overdue' else b.status end;

  return query select b.amount_cents, b.description, coalesce(v_name, 'Beneficiário'),
                      v_status, b.due_date;
end $$;

create or replace function public.pay_boleto(p_code text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  b public.boletos%rowtype;
  v_payer uuid;
  v_bal bigint;
  v_group uuid := gen_random_uuid();
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  select id into v_payer from public.accounts where owner_id = auth.uid();
  if v_payer is null then raise exception 'conta não encontrada'; end if;

  select * into b from public.boletos where code = p_code for update;
  if not found then raise exception 'boleto não encontrado'; end if;
  if b.status = 'paid' then raise exception 'boleto já foi pago'; end if;
  if b.status <> 'open' then raise exception 'boleto indisponível'; end if;
  if b.due_date < v_today then raise exception 'boleto vencido'; end if;
  if b.beneficiary_account_id = v_payer then
    raise exception 'você não pode pagar o seu próprio boleto';
  end if;

  perform 1 from public.accounts where id = v_payer for update;

  if public.money_out_today(v_payer) + b.amount_cents > public.daily_out_limit_cents() then
    raise exception 'limite diário de saídas atingido';
  end if;

  select coalesce(sum(amount_cents), 0) into v_bal
  from public.ledger_entries where account_id = v_payer;
  if v_bal < b.amount_cents then raise exception 'saldo insuficiente'; end if;

  insert into public.ledger_entries (account_id, amount_cents, kind, description, counterpart_account_id, group_id)
  values (v_payer, -b.amount_cents, 'boleto_out', coalesce(b.description, 'Boleto pago'),
          b.beneficiary_account_id, v_group),
         (b.beneficiary_account_id, b.amount_cents, 'boleto_in', coalesce(b.description, 'Boleto recebido'),
          v_payer, v_group);

  update public.boletos set status = 'paid', payer_account_id = v_payer, paid_at = now()
  where id = b.id;

  return b.amount_cents;
end $$;

revoke all on function public.get_money_out_summary() from public, anon;
grant execute on function public.get_money_out_summary() to authenticated;
revoke all on function public.withdraw_to_bank(bigint, text, text) from public, anon;
grant execute on function public.withdraw_to_bank(bigint, text, text) to authenticated;
revoke all on function public.create_boleto(bigint, text, int) from public, anon;
grant execute on function public.create_boleto(bigint, text, int) to authenticated;
revoke all on function public.get_boleto(text) from public, anon;
grant execute on function public.get_boleto(text) to authenticated;
revoke all on function public.pay_boleto(text) from public, anon;
grant execute on function public.pay_boleto(text) to authenticated;
