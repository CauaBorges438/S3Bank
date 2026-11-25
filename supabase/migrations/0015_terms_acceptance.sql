'-- S3 Bank: registro do aceite dos termos de uso e da política de privacidade.
-- Rodar DEPOIS do 0014.
--
-- O app envia a versão e a data do aceite nos metadados do cadastro.
-- O gatilho que cria o perfil grava esses dados na tabela profiles.

alter table public.profiles add column if not exists terms_version text;
alter table public.profiles add column if not exists terms_accepted_at timestamptz;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, cpf, phone, terms_version, terms_accepted_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'Cliente'),
    nullif(new.raw_user_meta_data->>'cpf', ''),
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'terms_version',
    nullif(new.raw_user_meta_data->>'terms_accepted_at', '')::timestamptz
  );
  insert into public.accounts (owner_id) values (new.id);
  return new;
end $$;
'