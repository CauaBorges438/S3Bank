-- S3 Bank: caixinhas (Guardar Dinheiro) no livro-razão.
-- Rodar DEPOIS do 0001_schema.sql.

-- 1) Novos tipos de movimentação e vínculo com a caixinha
alter table public.ledger_entries add column if not exists goal_id uuid;

alter table public.ledger_entries drop constraint if exists ledger_entries_kind_check;
alter table public.ledger_entries add constraint ledger_entries_kind_check
  check (kind in ('deposit','withdrawal','pix_in','pix_out','transfer_in','transfer_out',
                  'fee','adjustment','savings_in','savings_out'));

-- 2) Caixinhas
create table if not exists public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete restrict,
  name text not null check (char_length(name) between 1 and 60),
  target_cents bigint not null check (target_cents > 0),
  created_at timestamptz not null default now()
);

alter table public.ledger_entries
  add constraint ledger_entries_goal_fk foreign key (goal_id) references public.savings_goals(id);

alter table public.savings_goals enable row level security;

create policy "caixinha: ver as próprias" on public.savings_goals
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));
-- Sem insert/update/delete direto: criação e movimentos só via funções.
revoke insert, update, delete on public.savings_goals from anon, authenticated;

-- Saldo de cada caixinha = -(soma dos lançamentos ligados a ela)
create or replace view public.savings_goal_balances
with (security_invoker = true) as
select g.id as goal_id,
       g.account_id,
       g.name,
       g.target_cents,
       g.created_at,
       coalesce(-sum(l.amount_cents), 0)::bigint as saved_cents
from public.savings_goals g
left join public.ledger_entries l on l.goal_id = g.id
group by g.id;

-- 3) Funções
create or replace function public.create_savings_goal(p_name text, p_target_cents bigint)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_id uuid;
begin
  if p_name is null or char_length(trim(p_name)) = 0 then raise exception 'nome inválido'; end if;
  if p_target_cents is null or p_target_cents <= 0 then raise exception 'valor inválido'; end if;
  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;
  insert into public.savings_goals (account_id, name, target_cents)
  values (v_acc, trim(p_name), p_target_cents)
  returning id into v_id;
  return v_id;
end $$;

-- direction: 'in' = guardar (sai da conta corrente), 'out' = resgatar (volta)
create or replace function public.savings_move(p_goal_id uuid, p_amount_cents bigint, p_direction text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_bal bigint;
  v_saved bigint;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'valor inválido'; end if;
  if p_direction not in ('in','out') then raise exception 'valor inválido'; end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  perform 1 from public.savings_goals where id = p_goal_id and account_id = v_acc;
  if not found then raise exception 'caixinha não encontrada'; end if;

  -- trava a conta contra movimentos concorrentes
  perform 1 from public.accounts where id = v_acc for update;

  if p_direction = 'in' then
    select coalesce(sum(amount_cents), 0) into v_bal
    from public.ledger_entries where account_id = v_acc;
    if v_bal < p_amount_cents then raise exception 'saldo insuficiente'; end if;

    insert into public.ledger_entries (account_id, amount_cents, kind, description, goal_id)
    values (v_acc, -p_amount_cents, 'savings_in', 'Guardado em caixinha', p_goal_id);
  else
    select coalesce(-sum(amount_cents), 0) into v_saved
    from public.ledger_entries where goal_id = p_goal_id;
    if v_saved < p_amount_cents then raise exception 'valor maior que o guardado'; end if;

    insert into public.ledger_entries (account_id, amount_cents, kind, description, goal_id)
    values (v_acc, p_amount_cents, 'savings_out', 'Resgatado da caixinha', p_goal_id);
  end if;
end $$;

revoke all on function public.create_savings_goal(text, bigint) from public, anon;
grant execute on function public.create_savings_goal(text, bigint) to authenticated;
revoke all on function public.savings_move(uuid, bigint, text) from public, anon;
grant execute on function public.savings_move(uuid, bigint, text) to authenticated;
