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

function newCode(): string {
  const n = new Uint32Array(1);
  crypto.getRandomValues(n);
  return String(n[0] % 1000000).padStart(6, '0');
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
  const { email } = await req.json();
  const e = String(email ?? '').trim().toLowerCase();

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) {
    return json({ ok: false, error: 'E-mail inválido' });
  }

  // Resposta sempre igual: não revela se o e-mail tem conta.
  const reply = json({ ok: true });

  // No máximo 1 pedido por minuto por e-mail.
  const { data: last } = await supabase
    .from('password_reset_codes')
    .select('created_at')
    .eq('email', e)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (last && Date.now() - new Date(last.created_at).getTime() < 60_000) return reply;

  const userId = await findUserId(e);
  if (!userId) return reply;

  const code = newCode();
  await supabase.from('password_reset_codes').insert({
    email: e,
    code_hash: await sha256(`${e}:${code}`),
    expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
  });

  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: Deno.env.get('RESEND_FROM') ?? 'S3 Bank <onboarding@resend.dev>',
      to: [e],
      subject: 'Seu código de verificação',
      html: `<p>Seu código para redefinir a senha é <b>${code}</b>.</p>
             <p>Ele vale por 10 minutos. Se não foi você, ignore este e-mail.</p>`,
    }),
  });

  return reply;
});
