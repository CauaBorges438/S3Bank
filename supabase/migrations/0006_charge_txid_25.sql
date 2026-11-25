-- S3 Bank: identificador da cobrança com 25 caracteres.
-- Rodar DEPOIS do 0005.
-- Motivo: o gerador de QR (BR Code) corta o campo txid em 25 caracteres.
-- Com 32, o QR entregava um identificador que o banco não encontrava.

-- cobranças já criadas: encurta o identificador (são só testes, mas por segurança)
update public.pix_charges set txid = left(txid, 25) where char_length(txid) > 25;

alter table public.pix_charges drop constraint if exists pix_charges_txid_check;
alter table public.pix_charges add constraint pix_charges_txid_check
  check (txid ~ '^[A-Za-z0-9]{1,25}$');

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

  -- 25 caracteres hexadecimais: cabe no QR Code e tem colisão desprezível
  v_txid := left(replace(gen_random_uuid()::text, '-', ''), 25);
  v_exp := now() + make_interval(mins => p_expires_minutes);

  insert into public.pix_charges (txid, receiver_account_id, amount_cents, description, expires_at)
  values (v_txid, v_acc, p_amount_cents, nullif(trim(coalesce(p_description, '')), ''), v_exp);

  return query select v_txid, v_key, v_exp;
end $$;
