import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const json = (body: unknown) =>
  new Response(JSON.stringify(body), {
    headers: { ...cors, 'content-type': 'application/json' },
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
    if (error) {
      console.error('listUsers falhou:', error.message);
      return null;
    }
    if (!data.users.length) return null;
    const user = data.users.find((u) => u.email === email);
    if (user) return user.id;
    if (data.users.length < 200) return null;
  }
}

Deno.serve(async (req) => {
  // Preflight do navegador: precisa ser respondido antes do POST.
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }

  let email: unknown;
  try {
    ({ email } = await req.json());
  } catch {
    return json({ ok: false, error: 'Requisição inválida' });
  }
  const e = String(email ?? '').trim().toLowerCase();

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) {
    return json({ ok: false, error: 'E-mail inválido' });
  }

  // Resposta sempre igual: não revela se o e-mail tem conta.
  const reply = json({ ok: true });

  // No máximo 5 códigos por e-mail em 24 horas.
  const desde = new Date(Date.now() - 24 * 60 * 60_000).toISOString();
  const { count, error: countErr } = await supabase
    .from('password_reset_codes')
    .select('id', { count: 'exact', head: true })
    .eq('email', e)
    .gte('created_at', desde);
  if (countErr) console.error('Contagem de códigos falhou:', countErr.message);
  if ((count ?? 0) >= 5) {
    console.log(`Limite diário atingido: ${e}`);
    return reply;
  }

  // No máximo 1 pedido por minuto por e-mail.
  const { data: last, error: lastErr } = await supabase
    .from('password_reset_codes')
    .select('created_at')
    .eq('email', e)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (lastErr) console.error('Consulta de último pedido falhou:', lastErr.message);
  if (last && Date.now() - new Date(last.created_at).getTime() < 60_000) {
    console.log(`Pedido ignorado (menos de 1 min): ${e}`);
    return reply;
  }

  const userId = await findUserId(e);
  if (!userId) {
    console.log(`E-mail sem conta, nenhum envio: ${e}`);
    return reply;
  }

  const code = newCode();
  const { error: insErr } = await supabase.from('password_reset_codes').insert({
    email: e,
    code_hash: await sha256(`${e}:${code}`),
    expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
  });
  if (insErr) {
    console.error('Falha ao salvar código:', insErr.message);
    return reply;
  }

  const apiKey = Deno.env.get('RESEND_API_KEY');
  if (!apiKey) {
    console.error('RESEND_API_KEY não definida nas secrets da função');
    return reply;
  }

  try {
    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
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
    if (!resp.ok) {
      console.error(`Resend recusou o envio (${resp.status}): ${await resp.text()}`);
    } else {
      console.log(`Código enviado para ${e}`);
    }
  } catch (err) {
    console.error('Falha de rede ao chamar o Resend:', String(err));
  }

  // A resposta é sempre "ok" para não revelar contas; o erro fica no log.
  return reply;
});
