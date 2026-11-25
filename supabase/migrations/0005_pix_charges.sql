-- S3 Bank: cobrança Pix com valor, validade e identificador (txid).
-- Rodar DEPOIS do 0004.
-- Estados: 'open' (pode pagar), 'paid' (paga), 'cancelled'.
-- "Expirada" é calculada: open + expires_at no passado.

create table if not exists public.pix_charges (
  id uuid primary key default gen_random_uuid(),
  txid text not null unique check (txid ~ '^[A-Za-z0-9]{26,35}$'),
  receiver_account_id uuid not null references public.accounts(id) on delete restrict,
  payer_account_id uuid references public.accounts(id),
  amount_cents bigint not null check (amount_cents > 0 and amount_cents <= 999999999999),
  description text,
  status text not null default 'open' check (status in ('open','paid','cancelled')),
  expires_at timestamptz not null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.pix_charges enable row level security;

-- Só o recebedor enxerga as próprias cobranças. O pagador usa get_charge.
create policy "cobrança: ver as próprias" on public.pix_charges
  for select using (receiver_account_id in (select id from public.accounts where owner_id = auth.uid()));

revoke insert, update, delete on public.pix_charges from anon, authenticated;

-- Cria a cobrança e devolve txid, chave Pix do recebedor e validade.
create or replace function public.create_charge(
  p_amount_cents bigint,
  p_description text default null,
  p_expires_minutes int default 30
)
returns table (charge_txid text, charge_pix_key text, charge_expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_key text;
  v_txid text;
  v_exp timestamptz;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'valor inválido'; end if;
  if p_expires_minutes is null then raise exception 'valor inválido'; end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  select k.key_value into v_key
  from public.pix_keys k where k.account_id = v_acc
  order by k.created_at limit 1;
  if v_key is null then raise exception 'cadastre uma chave pix antes de cobrar'; end if;

  v_txid := replace(gen_random_uuid()::text, '-', '');
  v_exp := now() + make_interval(mins => p_expires_minutes);

  insert into public.pix_charges (txid, receiver_account_id, amount_cents, description, expires_at)
  values (v_txid, v_acc, p_amount_cents, nullif(trim(coalesce(p_description, '')), ''), v_exp);

  return query select v_txid, v_key, v_exp;
end $$;

-- Dados da cobrança para quem vai pagar (antes de confirmar).
create or replace function public.get_charge(p_txid text)
returns table (
  charge_amount_cents bigint,
  charge_description text,
  receiver_name text,
  charge_status text,
  charge_expires_at timestamptz,
  charge_pix_key text
)
language plpgsql security definer set search_path = public as $$
declare
  c public.pix_charges%rowtype;
  v_key text;
  v_name text;
  v_status text;
begin
  select * into c from public.pix_charges where txid = p_txid;
  if not found then raise exception 'cobrança não encontrada'; end if;

  select k.key_value into v_key
  from public.pix_keys k where k.account_id = c.receiver_account_id
  order by k.created_at limit 1;

  select p.full_name into v_name
  from public.profiles p
  where p.id = (select a.owner_id from public.accounts a where a.id = c.receiver_account_id);

  v_status := case when c.status = 'open' and c.expires_at < now() then 'expired' else c.status end;

  return query select c.amount_cents, c.description, coalesce(v_name, 'Destinatário'),
                      v_status, c.expires_at, v_key;
end $$;

-- Paga a cobrança: move o dinheiro e marca como paga, numa única transação.
create or replace function public.pay_charge(p_txid text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare
  c public.pix_charges%rowtype;
  v_payer uuid;
  v_bal bigint;
  v_group uuid := gen_random_uuid();
  v_desc text;
begin
  select id into v_payer from public.accounts where owner_id = auth.uid();
  if v_payer is null then raise exception 'conta não encontrada'; end if;

  -- trava a cobrança: duas pessoas não pagam a mesma ao mesmo tempo
  select * into c from public.pix_charges where txid = p_txid for update;
  if not found then raise exception 'cobrança não encontrada'; end if;
  if c.status = 'paid' then raise exception 'cobrança já foi paga'; end if;
  if c.status <> 'open' then raise exception 'cobrança indisponível'; end if;
  if c.expires_at < now() then raise exception 'cobrança expirada'; end if;
  if c.receiver_account_id = v_payer then
    raise exception 'você não pode pagar a sua própria cobrança';
  end if;

  perform 1 from public.accounts where id = v_payer for update;
  select coalesce(sum(amount_cents), 0) into v_bal
  from public.ledger_entries where account_id = v_payer;
  if v_bal < c.amount_cents then raise exception 'saldo insuficiente'; end if;

  v_desc := coalesce(c.description, 'Cobrança Pix');

  insert into public.ledger_entries (account_id, amount_cents, kind, description, counterpart_account_id, group_id)
  values (v_payer, -c.amount_cents, 'pix_out', v_desc, c.receiver_account_id, v_group),
         (c.receiver_account_id, c.amount_cents, 'pix_in', v_desc, v_payer, v_group);

  update public.pix_charges
     set status = 'paid', payer_account_id = v_payer, paid_at = now()
   where id = c.id;

  return c.amount_cents;
end $$;

revoke all on function public.create_charge(bigint, text, int) from public, anon;
grant execute on function public.create_charge(bigint, text, int) to authenticated;
revoke all on function public.get_charge(text) from public, anon;
grant execute on function public.get_charge(text) to authenticated;
revoke all on function public.pay_charge(text) from public, anon;
grant execute on function public.pay_charge(text) to authenticated;
