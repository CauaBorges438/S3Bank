-- S3 Bank: PIN de transação obrigatório nas operações que movem dinheiro.
-- Rodar DEPOIS do 0012.
--
-- A partir daqui, usuários comuns só conseguem movimentar dinheiro pelas
-- funções *_pin (que exigem uma autorização de PIN). As versões antigas
-- continuam existindo, mas só o banco (dono das funções) pode chamá-las.
--
-- ATENÇÃO: rode esta migração só depois de publicar o app novo, porque o
-- app antigo chama as funções sem PIN e passa a falhar.

revoke all on function public.pix_transfer(text, bigint, text) from authenticated;
revoke all on function public.withdraw_to_bank(bigint, text, text) from authenticated;
revoke all on function public.pay_boleto(text) from authenticated;
revoke all on function public.pay_charge(text) from authenticated;
revoke all on function public.pay_card_invoice(date) from authenticated;
