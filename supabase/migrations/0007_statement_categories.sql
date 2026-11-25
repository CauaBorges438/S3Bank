-- S3 Bank: categoria de gasto por movimentação (extrato).
-- Rodar DEPOIS do 0006.
-- O livro-razão é imutável: a categoria vive numa tabela à parte.
-- Só saídas (valor negativo) podem ser categorizadas.

create table if not exists public.transaction_categories (
  ledger_entry_id uuid primary key references public.ledger_entries(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  category text not null check (category in
    ('alimentacao','moradia','transporte','lazer','saude','compras','poupanca','outros')),
  updated_at timestamptz not null default now()
);

alter table public.transaction_categories enable row level security;

create policy "categoria: ver as próprias" on public.transaction_categories
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));

-- Escrita só pela função abaixo.
revoke insert, update, delete on public.transaction_categories from anon, authenticated;

create or replace function public.set_transaction_category(p_ledger_entry_id uuid, p_category text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_amount bigint;
begin
  if p_category not in ('alimentacao','moradia','transporte','lazer','saude','compras','poupanca','outros') then
    raise exception 'categoria inválida';
  end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  select l.amount_cents into v_amount
  from public.ledger_entries l
  where l.id = p_ledger_entry_id and l.account_id = v_acc;
  if not found then raise exception 'lançamento não encontrado'; end if;
  if v_amount >= 0 then raise exception 'só é possível categorizar saídas'; end if;

  insert into public.transaction_categories (ledger_entry_id, account_id, category, updated_at)
  values (p_ledger_entry_id, v_acc, p_category, now())
  on conflict (ledger_entry_id)
  do update set category = excluded.category, updated_at = now();
end $$;

revoke all on function public.set_transaction_category(uuid, text) from public, anon;
grant execute on function public.set_transaction_category(uuid, text) to authenticated;
