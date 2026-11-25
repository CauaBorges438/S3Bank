-- S3 Bank: gamificação no servidor (nível e constância).
-- Rodar DEPOIS do 0003. Os pontos são calculados por gatilho no livro-razão:
-- o app não consegue alterar o próprio progresso.
--
-- Regras:
--  - Pontos por aporte em caixinha: 15 + floor(valor em reais / 10).
--  - Constância mensal: um mês com aporte conta. Aportes em meses seguidos
--    aumentam a sequência; cada mês de sequência além do primeiro dá +10% de
--    pontos, com teto de +50%.
--  - Quebrar a constância (passar um mês sem aporte) zera a sequência e o
--    bônus. Os pontos acumulados NÃO são perdidos e o nível NUNCA cai.
--  - Níveis: bronze -> prata (300), prata -> ouro (700), ouro -> diamante (1500).
--    O excedente de pontos passa para o próximo nível.

create table if not exists public.user_progress (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  tier text not null default 'bronze' check (tier in ('bronze','prata','ouro','diamante')),
  points integer not null default 0 check (points >= 0),
  streak_months integer not null default 0 check (streak_months >= 0),
  last_deposit_month date,
  updated_at timestamptz not null default now()
);

alter table public.user_progress enable row level security;

create policy "progresso: ver o próprio" on public.user_progress
  for select using (account_id in (select id from public.accounts where owner_id = auth.uid()));

-- Só o gatilho escreve. Ninguém altera o progresso direto.
revoke insert, update, delete on public.user_progress from anon, authenticated;

create or replace function public.award_savings_points()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_reais numeric;
  v_month date;
  v_base integer;
  v_mult numeric;
  v_gain integer;
  v_req integer;
  v_idx integer;
  v_tiers text[] := array['bronze','prata','ouro','diamante'];
  v_tier text;
  v_points integer;
  v_streak integer;
  v_last date;
begin
  if new.kind <> 'savings_in' then
    return new;
  end if;

  insert into public.user_progress (account_id) values (new.account_id)
  on conflict (account_id) do nothing;

  select tier, points, streak_months, last_deposit_month
    into v_tier, v_points, v_streak, v_last
  from public.user_progress where account_id = new.account_id for update;

  v_reais := (-new.amount_cents)::numeric / 100;
  v_month := date_trunc('month', new.created_at)::date;

  -- constância mensal
  if v_last is null then
    v_streak := 1;
  elsif v_last = v_month then
    null; -- mais um aporte no mesmo mês: a sequência não muda
  elsif v_last = (v_month - interval '1 month')::date then
    v_streak := v_streak + 1;
  else
    v_streak := 1; -- quebrou a constância: zera o bônus
  end if;

  v_base := 15 + floor(v_reais / 10)::int;
  v_mult := 1 + 0.1 * least(greatest(v_streak - 1, 0), 5);
  v_gain := floor(v_base * v_mult)::int;
  v_points := v_points + v_gain;

  -- sobe de nível enquanto houver pontos suficientes
  loop
    v_req := case v_tier
      when 'bronze' then 300
      when 'prata' then 700
      when 'ouro' then 1500
      else null
    end;
    exit when v_req is null or v_points < v_req;
    v_points := v_points - v_req;
    v_idx := array_position(v_tiers, v_tier);
    v_tier := v_tiers[v_idx + 1];
  end loop;

  update public.user_progress
     set tier = v_tier,
         points = v_points,
         streak_months = v_streak,
         last_deposit_month = v_month,
         updated_at = now()
   where account_id = new.account_id;

  return new;
end $$;

drop trigger if exists on_savings_in_points on public.ledger_entries;
create trigger on_savings_in_points
  after insert on public.ledger_entries
  for each row execute function public.award_savings_points();
