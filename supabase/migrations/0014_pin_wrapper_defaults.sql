-- S3 Bank: parâmetros opcionais nas operações com PIN.
-- Rodar DEPOIS do 0013.
--
-- As funções pix_transfer_pin e withdraw_to_bank_pin precisam aceitar
-- descrição e dados bancários opcionais, como as versões originais.
-- Sem o valor padrão, o banco não encontra a função quando eles não são passados.

drop function if exists public.pix_transfer_pin(text, bigint, text, uuid);
drop function if exists public.withdraw_to_bank_pin(bigint, text, text, uuid);

create or replace function public.pix_transfer_pin(
  p_key_value text,
  p_amount_cents bigint,
  p_description text default null,
  p_auth uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.pix_transfer(p_key_value, p_amount_cents, p_description);
end $$;

create or replace function public.withdraw_to_bank_pin(
  p_amount_cents bigint,
  p_bank text,
  p_account_info text default null,
  p_auth uuid default null
) returns bigint
language plpgsql security definer set search_path = public as $$
begin
  perform public.consume_pin_authorization(p_auth);
  return public.withdraw_to_bank(p_amount_cents, p_bank, p_account_info);
end $$;

revoke all on function public.pix_transfer_pin(text, bigint, text, uuid) from public, anon;
grant execute on function public.pix_transfer_pin(text, bigint, text, uuid) to authenticated;
revoke all on function public.withdraw_to_bank_pin(bigint, text, text, uuid) from public, anon;
grant execute on function public.withdraw_to_bank_pin(bigint, text, text, uuid) to authenticated;
