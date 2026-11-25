-- S3 Bank: cadastro de chave Pix por função (mais robusto que insert direto).
-- Rodar DEPOIS do 0002.

create or replace function public.register_pix_key(p_key_type text, p_key_value text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_acc uuid;
  v_id uuid;
begin
  if p_key_type is null or p_key_type not in ('cpf','phone','email','random') then
    raise exception 'tipo inválido';
  end if;
  if p_key_value is null or char_length(trim(p_key_value)) = 0 then
    raise exception 'valor inválido';
  end if;

  select id into v_acc from public.accounts where owner_id = auth.uid();
  if v_acc is null then raise exception 'conta não encontrada'; end if;

  insert into public.pix_keys (account_id, key_type, key_value)
  values (v_acc, p_key_type, trim(p_key_value))
  returning id into v_id;
  return v_id;
exception
  when unique_violation then
    raise exception 'chave já em uso';
end $$;

revoke all on function public.register_pix_key(text, text) from public, anon;
grant execute on function public.register_pix_key(text, text) to authenticated;
