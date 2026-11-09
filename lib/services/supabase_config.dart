/// Credenciais do projeto Supabase "S3 Bank".
///
/// A chave `anon` é PÚBLICA por design: ela só dá acesso ao que as
/// políticas de segurança (RLS) do banco permitem. Nunca coloque a
/// chave `service_role` aqui — ela ignora a RLS.
///
/// Para apontar para outro projeto sem mexer no código:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pvddwerrlqefgrvipxzh.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2ZGR3ZXJybHFlZmdydmlweHpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NDU2MTEsImV4cCI6MjEwNDQyMTYxMX0.ha-4LA7MFrwKCcLq8lEj5IHyeR15B4unLsdvcpTWr_M',
  );

  static void ensureConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError('Supabase não configurado (URL/chave anon vazias).');
    }
  }
}
