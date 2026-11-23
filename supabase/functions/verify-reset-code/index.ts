import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const json = (body: unknown) =>
  new Response(JSON.stringify(body), {
    headers: { 'content-type': 'application/json' },
  });

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function findUserId(email: string): Promise<string | null> {
  for (let page = 1; ; page++) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 200 });
    if (error || !data.users.length) return null;
    const user = data.users.find((u) => u.email === email);
    if (user) return user.id;
    if (data.users.length < 200) return null;
  }
}

Deno.serve(async (req) => {
  const { email, code, password } = await req.json();
  const e = String(email ?? '').trim().toLowerCase();

  if (!/^\d{6}$/.test(String(code ?? ''))) return json({ ok: false, error: 'Código inválido' });
  if (!/^\d{6}$/.test(String(password ?? ''))) {
    return json({ ok: false, error: 'A senha precisa ter 6 números' });
  }

  const { data: row } = await supabase
    .from('password_reset_codes')
    .select('*')
    .eq('email', e)
    .is('used_at', null)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!row) return json({ ok: false, error: 'Código incorreto ou expirado' });
  if (new Date(row.expires_at) < new Date()) return json({ ok: false, error: 'Código expirado' });
  if (row.attempts >= 5) {
    return json({ ok: false, error: 'Muitas tentativas. Peça um novo código' });
  }

  if ((await sha256(`${e}:${code}`)) !== row.code_hash) {
    await supabase
      .from('password_reset_codes')
      .update({ attempts: row.attempts + 1 })
      .eq('id', row.id);
    return json({ ok: false, error: 'Código incorreto' });
  }

  const userId = await findUserId(e);
  if (!userId) return json({ ok: false, error: 'Código incorreto' });

  const { error } = await supabase.auth.admin.updateUserById(userId, { password });
  if (error) return json({ ok: false, error: 'Não foi possível trocar a senha' });

  await supabase
    .from('password_reset_codes')
    .update({ used_at: new Date().toISOString() })
    .eq('id', row.id);
  return json({ ok: true });
});
